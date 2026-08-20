# Learnings comments

A durable, cross-tracker record of the load-bearing **why** behind a piece of work — the decisions,
the rejected alternatives, and (after landing) what actually shipped and what failed. Kept as a
**marked comment on the parent issue** so it is: cross-tracker (works identically on Linear and Jira),
accessible to non-developers (no git PR needed), and timestamped/provenanced.

This is the compounding mechanism for the whole `bd-*` family: every build-up and build-down leaves a
trace that future planning — and a future knowledge-graph ingester — can read.

## The two markers

| Marker (exact-match first line) | Content | Posted when |
|---|---|---|
| `# ai-implement-build-up-learnings` | Forward-looking rationale — decisions & why | a build-up finishes (design decided, issues filed) |
| `# ai-implement-build-down-learnings` | Backward-looking reality — outcome, deltas, failures | a build-down concludes (posted, then updated in place) |

- The marker is an **exact-match first line**. A comment whose first line is the marker is
  machine-findable regardless of its contents, which keeps a future ingester cheap.
- **Never reuse `# ai-implement.yml`.** That marker means orchestrator config and is *stripped from the
  issue spec* — the opposite semantics. These learnings markers are ordinary, durable comments.

## Placement & edit semantics

- **One canonical comment per marker per issue, edited in place.** Not append-only, not multiple. Edit
  history preserves the timeline.
- **Distilled, not exhaustive.** Capture the load-bearing decisions a future reader would be
  *surprised* by — not a second copy of the plan. Link out to a fuller artifact (an in-repo plan doc)
  if depth is wanted; the comment is the durable index.

### Where each marker lands (the placement rule — BDS-39)

| Event | Comment | Where |
|---|---|---|
| Build-up finishes (design decided, issues filed) | ONE build-up comment | The **parent / umbrella issue** — and it **names the children it covers**, so a reader landing on a child knows where the rationale lives. Children get no build-up comment of their own. |
| An issue's PR **merges** | A build-down comment | **That issue** — the merge-time findings: smoke fixes, review-iteration causes, what the landing surfaced. Marker on line 1, same as always. |
| A chain / tree **completes** (or a session closes) | The build-down **capstone** | The **parent / umbrella issue** — cross-issue patterns and the outcome table, naming the children covered. The per-issue comments carry the detail; the capstone carries the arc. |

**Why per-issue, not parent-only (the PR-invisibility rationale):** the KG spine ingests a PR's
title, body, and state — **never its comment threads**. A smoke report or review finding posted
only on the PR is invisible to the graph forever. The PR comment remains the review-facing copy;
**mirror every learnings-worthy finding into the issue's build-down comment**, because the issue
comment is the copy the KG can see. Observed live 2026-08-19 on the KGB-2 chain: four issues'
merge-time findings existed only as GitHub PR comments, and the graph showed "learnings missing".

## Absence is signal

A build-up comment with **no** build-down sibling means "planned but never landed" — a real, queryable
state. Never merge the two markers into one; the gap between them is information.

This also partially covers a known blind spot: a PR closed without merging while no build-down session
is running is not auto-captured (see PR-outcome, below), but the missing build-down comment still flags
"never landed."

## Provenance — harness + model

Every learnings comment records the **harness** (Claude Code, OpenCode, …) and **model** (Opus 4.8,
GLM 5.2, …) behind the work, on a `harness · model` line (middle dot).

- **Self-report + ask-if-unknown.** State the harness + model you are running under. If you genuinely
  cannot determine the model, **ask the operator once** — never guess, never silently omit.
- **Build-up** records one line — the planning agent:
  `**Planned by:** <harness · model>`.
- **Build-down** records **two lines when they differ**:
  - `**Driven by:** <harness · model>` — the agent running the build-down.
  - `**PRs implemented by:** <harness · model>` — the AI-Implement runner that actually wrote the PRs.
    Read it from the PR body's provenance line — the orchestrator stamps
    `harness · model · provider` on every PR. ("Planned by Opus, PRs written by GLM, driven by Opus" is exactly the
    provenance a future reader needs — collapsing it hides which agent/model produced which outcome.)

> **Provenance is emitted (AII-229 — shipped).** The orchestrator stamps `Generated with AI-Implement ·
> harness: … · model: … · provider: …` on every PR body, so `PRs implemented by` reads directly from the
> PR. If a PR lacks the line (older PR / non-standard runner), fall back to `unknown`.

## PR outcome (build-down)

For each PR the session **drove or observed**, record its outcome using this taxonomy:

| Outcome | Meaning |
|---|---|
| `merged` | Landed. |
| `closed-unmerged (failure)` | PR closed without merging. **A failure** — record the concrete reason. |
| `open / never-landed` | Still open at session end, or planned but never PR'd. |
| `superseded` | Replaced by another PR / issue. |

`closed-unmerged` is detected from the PR state the session already reads (GitHub `state=CLOSED` and not
merged). Abandonment is a valid, valuable terminal outcome — "killed because X" is a learning, not a gap.

**Scope is session-only.** You record PRs this session drove or observed. A PR closed with **no**
build-down session running is *not* auto-captured — that is a deliberate boundary, partially covered by
the absence signal above. Do not go reconcile historical closed PRs unless explicitly asked.

## Which skill owns which marker

| Skill | Marker | When |
|---|---|---|
| `bd-build-up`, `bd-mega-build-up` | `# ai-implement-build-up-learnings` | required closing step |
| `bd-build-down`, `bd-super-build-down` | `# ai-implement-build-down-learnings` | required session-close step |

`bd-summit-push` (sequencing) and `bd-smoke-jumper` (testing) run **within** a build-down and fold their
findings **into** the build-down comment — they do not post their own marker. This preserves
one-canonical-comment-per-marker-per-issue. Per the placement rule above, a smoke finding worth
keeping folds into the **issue's** build-down comment (the KG-visible copy), not only the PR's
smoke-report comment.

## Cross-tracker

Both markers are plain comments. Linear (`save_comment`) and Jira (`addComment`) both support comment
writes, so the convention is identical on both providers — zero new API surface.

## Templates

**Build-up:**

```
# ai-implement-build-up-learnings

**Feature:** <one line + tree shape>
**Planned by:** <harness · model>          e.g. Claude Code · Opus 4.8

## Decisions & why
- <decision> — <why; what was rejected and the concrete failure it avoids>

## The one idea worth carrying forward
<the single most reusable insight>

## Applies to
<future situations this learning generalizes to>
```

**Build-down:**

```
# ai-implement-build-down-learnings

**Feature:** <one line>
**Driven by:** <harness · model>           e.g. Claude Code · Opus 4.8
**PRs implemented by:** <harness · model>  the AI-Implement runner (from the PR body's `harness · model · provider` line)

## Outcome
Per PR this session drove or observed:
- PR #<n> <title> — <merged | closed-unmerged (failure) | open / never-landed | superseded>

## Deltas from plan
<what actually shipped vs. what was planned>

## Failures & gotchas
<each closed-unmerged PR with the concrete reason it failed; what bit us during landing>

## Status
<landed with these caveats | abandoned because X | superseded by Y>
```
