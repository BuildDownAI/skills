# The AI-Implement pipeline — what happens after filing

Shared reference for `bd-build-up`, `bd-mega-build-up`, `bd-summit-push`, and the landing
skills. How the downstream harness (https://github.com/BuildDownAI/AI-Implement) picks up
work, and the filing mechanics that follow from it.

## The loop

1. The orchestrator polls the tracker every ~60s for issues that carry the pickup signal and
   have no unfinished blocker.
2. When planning is on, the planner posts three comments: an Implementation Map, an Acceptance
   Bar, and Risks & Open Questions. The reviewer grades each numbered claim of the Acceptance
   Bar.
3. The implementer runs against the issue body via `WORKFLOW.md`, opens a PR, and posts a
   **gap analysis** comment comparing the diff against the spec.
4. The issue moves to **Ready for Review** with a PR link.
5. Commenting `/ai-implement` on the PR re-runs the implementer in gap-fill mode on the same
   branch.

The tracker is the source of truth. An ad-hoc prompt never enters the pipeline.

**A stopped issue is not always visible in the tracker.** After three counted failures of one
phase, or at the PR's gap-fill limit, the orchestrator parks the issue and stops dispatching
it. On Linear a parked issue carries no label; the orchestrator holds the park in its own
record. An issue that carries the pickup signal and does not move is read with
`get_issue_dispatch_status` (see `bd-system-questions`), which reports the park and any
failing setup check. An admin clears a park with `unpark_issue`. Removing and re-adding the
pickup label does not clear it. This park is the orchestrator's; it is not an issue held
without the pickup signal.

**What this means for issue bodies.** The pipeline reads the body cold, asks no follow-up
questions, and fixes the acceptance bar when it plans. The body rules are in
[`issue-body.md`](./issue-body.md).

**The pickup signal is tracker-specific.** Linear uses a label; Jira uses a status field. Read
the active adapter's **Pickup trigger** section. On Jira, setting only a label is a silent
no-op.

## Wave release

Build-up launches work. It does not park it.

- **Inside a feature-branch tree**, give every agent-routed issue the pickup signal at filing,
  in one pass, parent before children. The tracker's blocking relations do the sequencing: the orchestrator
  skips an issue until each blocker is Done, Canceled, or Duplicate. On Jira only a link type
  named exactly `Blocks` holds an issue. The tree needs no hand release, because each child
  lands on the feature branch and the whole tree gets one roll-up review and one human gate.
- **A standalone dependency chain** keeps hand release. File wave 1 with the pickup signal.
  File wave 2 and later without it. A session (`bd-build-down`, `bd-super-build-down`)
  releases each issue when every blocker is Done. A standalone issue merges straight to the
  default branch with no roll-up review, so the session first checks the dependent's body
  against what its blocker shipped. The edit must come before release, because the planner
  fixes the acceptance bar when it plans.
- **Same-template siblings** follow pilot-first (below), in a tree or out of one.
- **Architect-routed** — schema, security, and infrastructure work → assigned to the architect
  with no pickup signal. The architect sequences their own work.

File in dependency order so each `Blocked by:` resolves to a real issue ID. A Canceled blocker
releases its dependents too. Closing an implementation PR without a merge cancels its issue, so
point each `Blocked by:` at the replacement issue before you close the PR.

A well-staged build-up has wave 1 running by the time the session ends. The only exceptions
are a user who says "stage everything, do not start," and brief-only modes that file nothing.

## Parallel dispatch

Multiple unblocked issues run concurrently on separate branches. Issues are independently
mergeable, or they carry `Blocked by:` to serialize them.

- **Two issues that edit the same file are not parallel-safe.** One blocks the other, or they
  merge into one issue.
- **The dispatch guard reads `## Files`**, and only between siblings on one feature branch. It
  defers the later sibling until the first one's PR merges. It skips standalone issues.
  Details: [`issue-body.md`](./issue-body.md) § `## Files` is machine-read.

## Feature-node grouping

A **designated** parent issue with designated children becomes a *feature node*. It owns the
branch `ai-implement/feature/<key>`. Its children PR **into that branch** rather than the
default branch, and the tree rolls up to one human-reviewed `feature → base` PR.

Children on a shared feature branch are **more** parallel-safe than free-standing issues, not
less — they never collide on base. Normal file-overlap rules still apply between them.

**Designation** means the pipeline label on Linear, and a non-empty `AI-Implement-Status` plus
a matching Repo field on Jira. See the active adapter's **Feature-node grouping** section. The
Linear pipeline label is resolved at session start — see `./pickup-label.md`.

### Designation order

**Build the whole tree first. Then designate the parent and every child in one pass, parent
first.**

- A parent designated **before its children exist** is classified as a leaf and dispatched
  standalone. So every child, every parent relationship, and every `blocks` relation exists
  before any designation goes on.
- A child designated **while its parent is undesignated** resolves an empty ancestor chain and
  cuts its PR from the repo base branch, silently bypassing grouping. So the parent is
  designated first.

Parent-first is safe because of the race guard: a designated parent whose children exist but
carry no designation yet is a *waiting parent*, and the orchestrator skips it until the
children are released.

Full model: `./feature-branch-grouping.md`.

### Multi-issue mode

To group *otherwise-unrelated* issues into one reviewable unit, put a **fenced** marked block
in the parent's description:

```
# ai-implement.yml (example)
feature_branch:
  mode: "multi-issue"
```

The branch becomes `ai-implement/multi-issue/<key>` instead of `ai-implement/feature/<key>`.
Everything else is identical — designation order, blocking, roll-up, the human gate. An
unfenced marker is ignored and the parent stays in feature mode. Always write the example with
the `(example)` suffix: a bare `# ai-implement.yml` first line is the real marker and gets
stripped from that issue's own spec.

## Pilot-first sequencing

**Trigger:** a wave holds **three or more issues applying the same template to different
surfaces** — *"enable pagination on `/employees/`"*, *"…on `/assignments/`"*, *"…on
`/calculations/`"*.

File them all, but give only the **first** the pickup signal. Pick the pilot with the smallest
or best-understood surface; it sets the pattern. File the rest without the pickup signal, in a
tree or out of one.

Then in bd-build-down, once the pilot's PR lands:

1. Read the PR for load-bearing details the agent had to invent — file paths, naming, edge
   cases, peripheral updates the spec never enumerated.
2. Update the remaining issue bodies to inline what the pilot got right, and correct what it
   got wrong. Their pattern anchor now points at the freshly merged PR.
3. Release the rest in parallel.

**Cost:** one bd-build-down checkpoint, a few minutes after the pilot merges. **Benefit:** the
remaining issues land clean the first time, instead of every one of them repeating the same
systemic miss in parallel.

**Skip pilot-first** when the wave holds two or fewer same-pattern siblings, or when the
issues only look alike — different app, different shape, different decisions. The trigger is
*same task template*, not *same project area*.

## Diagnosing a run that hit its limit

A Claude run that reaches its turn limit opens a draft PR, posts a `MAX_TURNS_EXHAUSTED`
failure, and skips review. Read the failure before you re-run it: the usual cause is an issue
past the size threshold in [`issue-shape.md`](./issue-shape.md) § Size, and the fix is a
split.
