# Issue body — the canonical template

Shared reference for `bd-build-up` and `bd-mega-build-up`. Every filed issue uses this shape.

The body has two audiences in this order: a **human** skimming the board, then a **coding
agent** reading cold. The opening paragraph serves the human. Everything after it serves the
agent. Write the title and the opening paragraph in Simplified Technical English — see
[`ste.md`](./ste.md).

## Template

```
{Opening paragraph — 2–4 plain STE sentences, before any heading. What this issue is,
and why it exists. A human must understand the issue from this paragraph alone.}

## Problem / Context

Current state, and what this issue enables.

## Task

What to build, precisely: routes and request/response shapes, schema columns and types,
UI layout and interaction detail, component names as they exist in the codebase.

Design reference: {ADR path, prototype route, or design screen — for the human reviewer}

## Files

- Create: `exact/path/to/new-file.ts`
- Modify: `exact/path/to/existing.ts`
- Test: `tests/exact/path/test.ts`
- Delete: `exact/path/to/dead-file.ts`

## Acceptance Criteria

- [ ] Independently verifiable outcome
- [ ] `{{BUILD_CMD}}` passes

## Dependencies

Blocked by: {ISSUE-ID} (reason)
Parallel-safe with: {ISSUE-IDs}

## Shape

Shape: {wide-and-shallow | deep-and-targeted}
Migration/backfill: {no | yes — isolated, no consumers in this issue}
Pattern anchor: {exact file or PR, or "novel"}
Test fixture: {test path, or "full test inlined above"}
Trust boundary: {none | crosses X, handled by Y}
Rollback: {mechanical | flag `name` | revert}
Observability: {none | `metric.name`}
Setting surface: {none | <page> · <control> · settings-table row, env `NAME` as seed}
Snapshot delta: {none | per-part: `<part.nt>` <direction> <rough size>[; needs accept-new-baseline]}

## Notes

Edge cases, gotchas, and the decisions from the grill that bear on this issue.
```

## Declare the surface. Do not script the work.

The implementer is a capable model. It does not need its edits dictated step by step, and a
scripted plan goes stale the moment the codebase moves under it.

**Declare** — exact file paths, the schema and API contract, testable acceptance criteria,
the pattern anchor to mirror, the trust boundary, and any decision the agent could not
reasonably reach on its own.

**Do not script** — a numbered `read this, then edit that, then run the test` sequence, full
implementation code for work the agent can write, or a restatement of the repo's own
conventions.

Two carve-outs, where a code block beats prose:

- **A first-of-its-kind test.** Nothing in the repo to mirror, so inline the whole test.
- **A snippet that encodes a decision more precisely than prose** — a state machine, a
  reducer, a schema, a type shape. Inline the decision-rich part, not a working demo.

## Every constraint carries the failure it prevents

A bare constraint is an instruction. A constraint plus its failure mode is a *reason*, and a
reason survives contact with an implementer who finds the constraint inconvenient.

State the constraint, then the concrete thing that breaks without it:

| Instead of | Write |
|---|---|
| "`opts` is required." | "`opts` is required **because** a call site that omits the entity must fail to compile rather than silently return unfiltered rows." |
| "Resolve the IDs once." | "Resolve the IDs once — this endpoint already issues many queries per request, and a second resolve per predicate makes a known slow path worse." |
| "Do not use an embedded `!inner` join." | "Do not use an embedded `!inner` join — an entity in two selected projects returns twice, and every count downstream is wrong." |

**Why this matters more than it looks.** An implementer weighing "required vs optional" with no
stated consequence will reasonably pick the one that compiles against today's callers — and
optional-with-a-fallback compiles. The spec was followed in letter, the constraint evaporated,
and nothing failed loudly enough to notice. Observed: a `required` argument shipped as
`opts?: { entity?: T }` with `if (!opts?.entity) return query`, which turned "filter by project"
into "return everything" for any caller that forgot it.

This applies with most force to constraints whose violation is **silent** — a dropped filter, a
truncated result, a widened scope. Where the violation is loud, prose is enough.

## `## Files` is machine-read

Keep the exact bullet form. The orchestrator's dispatch guard parses
`- Create|Modify|Test|Delete: ` followed by a backticked path — a `:line-range` suffix inside
the backticks is fine. Declared overlap between two dispatchable siblings defers the later one
until the first merges.

**An issue with no parseable `## Files` section fails open.** It dispatches in parallel
regardless of overlap and falls back on conflict auto-recovery. Every file the work touches
belongs in this list. Prose mentions inside `## Task` are invisible to the guard.

### Verify the list before filing (required — no output, no filing)

Run [`tools/verify-issue-files.py`](./tools/verify-issue-files.py) against the drafted body and
the repo, and paste its output into the session before the approval gate. A red result blocks
filing; a green result is the evidence the plan was checked. It is a few seconds, and it checks
what review reliably does not:

```sh
verify-issue-files.py draft.md --repo /path/to/repo
# or, on an already-filed issue:
gh issue view 123 --json body --jq .body | verify-issue-files.py - --repo .
```

It fails on a `Modify`/`Delete` target that does not exist, a `Create` target that already
does, a body with no parseable bullets at all, and any `"<n> lines"` claim that disagrees with
the file. It also prints each file's real line count and first meaningful line.

It also enforces the shape rules from [`issue-shape.md`](./issue-shape.md): a `Create:` entry
with more than three `Modify:` consumers, more than 12 declared entries, or a contract surface
(migrations, schema, API/callback/envelope definitions — extend with `--contract`) modified in
the same issue as a `Create:`. Each of those is a split, not a warning to note and file past.

**Read that inventory, not just the exit code.** The exit code catches wrong paths; the
inventory catches the more common error — a path that exists and is not the file you think it
is. One issue described a page as "1367 lines" with a metadata block to extend; the inventory
showed 40 lines, because the 1367-line file was a sibling one path segment away. Every
existence check had passed.

## Labels, routing, and metadata

- **Project** — every issue in the build-up attaches to the same container, so the body of
  work stays queryable as a unit.
- **Labels** — the issue type (Bug / Feature / Improvement), plus the pipeline signal for
  agent-routed work, plus surface labels (`frontend`, `backend`, `convergence`) as they apply.
- **Priority** — as decided in the plan.
- **Assignee** — the architect for schema, security, and infrastructure work. Unassigned for
  agent-routed work.

**Routing rules:**

| Route | What goes there | How it is filed |
|---|---|---|
| **Architect** (`{{ARCHITECT_NAME}}`) | Schema migrations, security policy, infrastructure, complex architecture | Assigned directly, **no** pipeline signal |
| **Agent pipeline** | Frontend work, UI fixes, well-defined backend tasks | Pipeline signal, unassigned |
| **User decision** | Product judgment that cannot be pre-decided | Called out explicitly in the body |

Single-operator setups drop the architect route. Risky issues are still filed; they go to the
user's own queue.

## Dependency phrasing

Always `Blocked by: {ISSUE-ID} (reason)`. Never "Depends on", "Requires", or "After". One
phrase, one pattern — bd-build-down reads it to sequence merges. The tracker-native relation
mechanism is per-adapter; see the adapter's **Dependencies** section.

## Setting surface

`Setting surface:` names where an operator goes to change a flag or env var at runtime.
Set it to `none` only when the issue genuinely introduces no operator-facing configuration.

For every other case, name the page, the control, the storage mechanism, and the env var
that seeds it on first boot:

```
Setting surface: /admin#runners · runner-mode select · settings-table row, env `RUNNER_MODE` as seed
```

**Why this field exists.** An env-only flag requires a deploy or `fly secrets set` to
change — the operator has no UI path once the service is running. Naming the admin surface
at filing time makes the gap visible before implementation, not at the incident where someone
discovers there is no toggle. The `env NAME as seed` clause enforces the canonical pattern:
the env var seeds the settings table on first boot and the table is the runtime source of
truth; this is not endorsement of env-only storage.

## Snapshot delta

`Snapshot delta:` names the expected effect on each affected KG snapshot part when an issue in
a KG source repo changes what ingest emits — classifier rules, node types, `doc_exclude`, or
`sources.yml` scope. Required for any such emitter change; `bd-build-up` and `bd-mega-build-up`
refuse to file one without it.

Set it to `none` only when the change provably cannot alter any snapshot part. The build-up skills
ask the user to confirm `none` explicitly; it is not accepted silently.

For every other case, name each part that changes, the direction, a rough size, and whether the
orchestrator's `accept-new-baseline` is required:

```
Snapshot delta: `comment.nt` shrinks by every bot Decision, roughly −60%; needs accept-new-baseline
```

*KGB-16 example:* KGB-16 typed tracker issue comments, narrowing which comments became nodes. The
value above is the delta that should have been stated at filing time. Nobody asked; the guard refused
the first refresh after it merged.

**Why this field exists.** A KG ingest change has a downstream artefact whose size is guarded.
Naming the expected delta at filing time makes the assumption explicit — and gives the guard a
baseline to compare against when the refresh runs, rather than discovering the mismatch at the
incident where the guard blocks production.
