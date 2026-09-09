#!/usr/bin/env python3
"""Verify an issue body's file claims against the repository, before filing.

Two failure modes this catches, both observed in real build-ups:

1. A path that does not exist, or a `Create:` for a path that already does.
   The dispatch guard parses `## Files` and *fails open* on anything it cannot
   read, so a wrong path is never reported — the issue simply dispatches with no
   overlap protection and the implementer invents a location.

2. A path that exists but is not what the issue says it is. This is the one that
   bites hardest, because every existence check passes. An issue described
   `sources/[feedId]/page.tsx` as "1367 lines" with a metadata block to extend;
   it is a 40-line redirect stub with no UI at all. The 1367-line file was
   `sources/page.tsx` — a different file, one path segment away. The implementer
   correctly skipped the work, and the reviewer wrongly called it a silent drop.

3. An issue whose shape violates issue-shape.md: a new module plus more than a
   few consumers (wide-and-deep), too many declared entries for one implement
   pass, or a contract surface changed in the same issue as a new module. The
   observed case: one "foundation" issue creating a classifier and wiring it
   into eight call sites, a callback body, and a database column. Three review
   rounds; every blocking finding at a seam. The rubric said to split it; prose
   is walked past, a non-zero exit is not.

So this prints what each file *actually is* next to what the issue claims, fails
on any numeric line-count claim that does not match, and fails on a shape
violation unless --no-shape is given.

Usage:
    verify-issue-files.py BODY.md --repo /path/to/repo
    gh issue view 123 --json body --jq .body | verify-issue-files.py - --repo .

Exit codes: 0 clean, 1 violations found, 2 bad invocation.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# The machine-read contract from issue-body.md. Keep in sync with the dispatch
# guard: `- Verb: `path`` with an optional :line-range inside the backticks.
FILES_BULLET = re.compile(
    r"^\s*[-*]\s+(Create|Modify|Test|Delete)\s*:\s*`([^`]+?)`", re.IGNORECASE
)
LINE_RANGE_SUFFIX = re.compile(r":\d+(?:-\d+)?$")

# "1367 lines", "1,367 lines", "~40 lines" — a claim we can check.
LINE_CLAIM = re.compile(r"(?:~|approximately\s+|about\s+)?([\d,]{2,})\s+lines?\b", re.IGNORECASE)
# Any backticked path-looking token, so a claim can be attributed to a file.
INLINE_PATH = re.compile(r"`([^`\s]*/[^`\s]*\.[A-Za-z0-9]+)(?::\d+(?:-\d+)?)?`")

# Shape thresholds (issue-shape.md, "The shape rule"). Overridable per invocation.
DEFAULT_MAX_CONSUMERS = 3   # Modify: source files alongside a Create: source file
DEFAULT_MAX_ENTRIES = 12    # every declared bullet, tests and docs included
# Paths that are contract surfaces: readers and validators live on the other side
# of a process boundary. A Create: in the same issue as a Modify: here is hard
# rule 13 (contract change isolation). Substring match on the declared path;
# extend per project with --contract.
DEFAULT_CONTRACT_MARKERS = (
    "migrations/", "migration", "schema", "run-config", "callback", "envelope",
    "openapi", ".proto", ".graphql", "/contracts/", "/api/types",
)
DOC_SUFFIXES = (".md", ".mdx", ".rst", ".txt")
TEST_MARKERS = ("__tests__/", "/tests/", "/test/", ".test.", ".spec.", "_test.", "spec/")


def is_doc(path: str) -> bool:
    return path.lower().endswith(DOC_SUFFIXES)


def is_test(path: str) -> bool:
    return any(m in path for m in TEST_MARKERS)


def check_shape(
    entries: list[tuple[str, str, int]],
    max_consumers: int,
    max_entries: int,
    contract_markers: tuple[str, ...],
) -> list[str]:
    """Shape violations per issue-shape.md. Each one is a split, not a note."""
    problems: list[str] = []
    creates = [p for v, p, _ in entries if v == "Create" and not is_doc(p) and not is_test(p)]
    modifies = [p for v, p, _ in entries if v == "Modify" and not is_doc(p) and not is_test(p)]

    if len(entries) > max_entries:
        problems.append(
            f"shape: {len(entries)} declared entries (limit {max_entries}, tests and docs count). "
            "Split: deep core + wide propagation blocked by it."
        )
    if creates and len(modifies) > max_consumers:
        problems.append(
            f"shape: {len(creates)} new module(s) plus {len(modifies)} modified source file(s) — "
            f"wide-and-deep (consumer limit {max_consumers}). Split: the module with its tests "
            "and NO consumers first, then a wiring issue `Blocked by:` it."
        )
    if creates:
        contract_hits = [p for p in modifies if any(m in p.lower() for m in contract_markers)]
        if contract_hits:
            problems.append(
                "shape: a new module and a contract surface change in one issue (hard rule 13): "
                + ", ".join(f"`{p}`" for p in contract_hits)
                + ". The producer and the contract are different reviews — split them."
            )
    return problems


def find_files_section(body: str) -> list[tuple[str, str, int]]:
    """Return (verb, path, line_no) for each bullet under a `## Files` heading."""
    out: list[tuple[str, str, int]] = []
    in_section = False
    for i, line in enumerate(body.splitlines(), start=1):
        if re.match(r"^\s*#{1,6}\s+Files\s*$", line, re.IGNORECASE):
            in_section = True
            continue
        if in_section and re.match(r"^\s*#{1,6}\s+\S", line):
            break  # next heading ends the section
        if in_section:
            m = FILES_BULLET.match(line)
            if m:
                verb = m.group(1).capitalize()
                path = LINE_RANGE_SUFFIX.sub("", m.group(2).strip())
                out.append((verb, path, i))
    return out


def count_lines(p: Path) -> int | None:
    try:
        with p.open("rb") as fh:
            return sum(1 for _ in fh)
    except OSError:
        return None


def first_meaningful_line(p: Path) -> str:
    """A one-line 'what is this' hint, so a mis-identified file is obvious."""
    try:
        with p.open(encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                s = raw.strip()
                if not s or s.startswith(("//", "#", "/*", "*", "--", '"use')):
                    continue
                return s[:72]
    except OSError:
        pass
    return ""


def check_line_claims(body: str, repo: Path) -> list[str]:
    """Flag '<n> lines' claims that disagree with the file named on the same line."""
    problems: list[str] = []
    for i, line in enumerate(body.splitlines(), start=1):
        claims = LINE_CLAIM.findall(line)
        paths = INLINE_PATH.findall(line)
        if not claims or not paths:
            continue
        for path in paths:
            target = repo / path
            actual = count_lines(target)
            if actual is None:
                continue
            for claim in claims:
                stated = int(claim.replace(",", ""))
                # Only flag an order-of-magnitude-ish miss; prose rounds.
                if stated == actual:
                    continue
                tolerance = max(10, int(actual * 0.15))
                if abs(stated - actual) > tolerance:
                    problems.append(
                        f"line {i}: claims {stated} lines for `{path}`, "
                        f"actual is {actual}"
                    )
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("body", help="issue body file, or - for stdin")
    ap.add_argument("--repo", default=".", help="repository root (default: cwd)")
    ap.add_argument(
        "--quiet", action="store_true", help="only print problems, not the inventory"
    )
    ap.add_argument("--no-shape", action="store_true", help="skip the issue-shape checks")
    ap.add_argument("--max-consumers", type=int, default=DEFAULT_MAX_CONSUMERS,
                    help=f"Modify: source files allowed alongside a Create: (default {DEFAULT_MAX_CONSUMERS})")
    ap.add_argument("--max-entries", type=int, default=DEFAULT_MAX_ENTRIES,
                    help=f"declared ## Files entries allowed (default {DEFAULT_MAX_ENTRIES})")
    ap.add_argument("--contract", action="append", default=[],
                    help="extra path substring that marks a contract surface (repeatable)")
    args = ap.parse_args()

    repo = Path(args.repo).resolve()
    if not repo.is_dir():
        print(f"error: --repo {repo} is not a directory", file=sys.stderr)
        return 2

    body = sys.stdin.read() if args.body == "-" else Path(args.body).read_text()

    entries = find_files_section(body)
    problems: list[str] = []

    if not entries:
        # Fail-open is exactly the trap: the guard cannot see prose file mentions.
        print(
            "VIOLATION: no parseable `## Files` bullets found.\n"
            "  The dispatch guard reads `- Create|Modify|Test|Delete: `path`` and\n"
            "  fails OPEN on anything else — this issue would dispatch with no\n"
            "  file-overlap protection at all."
        )
        return 1

    rows: list[tuple[str, str, str, str]] = []
    for verb, path, line_no in entries:
        target = repo / path
        exists = target.exists()
        n = count_lines(target) if exists else None
        hint = first_meaningful_line(target) if exists else ""

        if verb in ("Modify", "Delete") and not exists:
            problems.append(f"line {line_no}: {verb} target does not exist: `{path}`")
        if verb == "Create" and exists:
            problems.append(
                f"line {line_no}: Create target already exists (should be Modify): `{path}`"
            )

        rows.append(
            (
                verb,
                path,
                "—" if n is None else f"{n} lines",
                hint if exists else "MISSING",
            )
        )

    problems.extend(check_line_claims(body, repo))
    if not args.no_shape:
        problems.extend(
            check_shape(
                entries,
                args.max_consumers,
                args.max_entries,
                DEFAULT_CONTRACT_MARKERS + tuple(m.lower() for m in args.contract),
            )
        )

    if not args.quiet:
        width = max(len(r[1]) for r in rows)
        print("Files declared:\n")
        for verb, path, size, hint in rows:
            print(f"  {verb:<7} {path:<{width}}  {size:>11}   {hint}")
        print()

    if problems:
        print(f"{len(problems)} violation(s):\n")
        for p in problems:
            print(f"  - {p}")
        print(
            "\nRead each file before describing it. A path that exists is not "
            "evidence\nthat it is the file you think it is. A shape violation is a split, "
            "not a note."
        )
        return 1

    if not args.quiet:
        print("No violations. Line counts above are the ground truth — check them")
        print("against what the issue body claims about each file.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
