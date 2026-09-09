# The AI-Implement pipeline — what happens after filing

Shared reference for `bd-build-up` and `bd-mega-build-up`. How the downstream harness
(https://github.com/BuildDownAI/AI-Implement) picks up work, and the filing mechanics that
follow from it.

## The loop

1. The orchestrator polls the tracker every ~60s for unblocked issues that carry the pickup
   signal.
2. A picked-up issue moves to **In Progress**, runs Claude Code against the issue body via
   `WORKFLOW.md`, opens a PR, and posts a **gap analysis** comment comparing the diff against
   the spec.
3. The issue moves to **Ready for Review** with a PR link.
4. Commenting `/ai-implement` on the PR re-runs Claude in gap-fill mode on the same branch.

The tracker is the source of truth. An ad-hoc prompt never enters the pipeline.

**What this means for issue bodies.** The pipeline reads the body cold and asks no follow-up
questions, so everything it needs is inline. Gap analysis only catches what the spec
specified — a vague acceptance criterion produces a vague gap analysis and a bad PR.

**The pickup signal is tracker-specific.** Linear uses state plus a label; Jira uses a status
field. Read the active adapter's **Pickup trigger** section. On Jira, setting only a label is
a silent no-op.

## Wave staging

Build-up launches work. It does not park it.

- **Wave 1** — issues with no unmet blockers → the pickup-ready state with the pipeline
  signal. The orchestrator takes them within minutes.
- **Wave 2+** — issues with unmet blockers → parked. bd-build-down promotes them as their
  blockers merge.
- **Architect-routed** — schema, security, and infrastructure work → assigned to the architect
  with no pipeline signal. The architect sequences their own work.

File in dependency order so each `Blocked by:` resolves to a real issue ID.

A well-staged build-up has Wave 1 running by the time the session ends. The only exceptions
are a user who says "stage everything, do not start," and brief-only modes that file nothing.

## Parallel dispatch

Multiple unblocked issues run concurrently on separate branches. Issues are independently
mergeable, or they carry `Blocked by:` to serialize them.

- **Two issues that edit the same file are not parallel-safe.** One blocks the other, or they
  merge into one issue.
- **The dispatch guard reads `## Files`.** The orchestrator parses `- Create|Modify|Test|Delete: `
  bullets with a backticked path and defers the later of two siblings that declare the same
  file until the first one's PR merges — turning a guaranteed conflict into clean
  serialization. An issue with no parseable `## Files` section **fails open**: it dispatches
  regardless of overlap. Prose file mentions inside `## Task` are not parsed.

## Feature-node grouping

A **designated** parent issue with designated children becomes a *feature node*. It owns the
branch `ai-implement/feature/<key>`. Its children PR **into that branch** rather than the
default branch, and the tree rolls up to one human-reviewed `feature → base` PR.

Children on a shared feature branch are **more** parallel-safe than free-standing issues, not
less — they never collide on base. Normal file-overlap rules still apply between them.

**Designation** means the pipeline label on Linear, and a non-empty `AI-Implement-Status` plus
a matching Repo field on Jira. See the active adapter's **Feature-node grouping** section.

### Designation order (two observed races)

**Build the whole tree first. Then designate the parent. Then designate the children.**

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

## The first issue of a chain is the smallest

A chain's first issue is the only one nothing else can start before, and it sets the pattern
every later issue mirrors. Make it the **smallest** issue in the chain — half the normal shape
ceiling — even when the "foundation" feels like it wants to be complete. A large first issue
delays the whole chain by its review rounds and teaches every follow-on its mistakes. The
foundation is the module; the wiring is the second issue.

## Pilot-first sequencing

**Trigger:** a wave holds **three or more issues applying the same template to different
surfaces** — *"enable pagination on `/employees/`"*, *"…on `/assignments/`"*, *"…on
`/calculations/`"*.

File them all, but release only the **first** for pickup. Pick the pilot with the smallest or
best-understood surface; it sets the pattern. Park the rest.

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

## Diagnosing a silent failure

When the runner hits the turn cap mid-edit it pushes **nothing** — no partial PR, no branch.
The issue reads as though it was never picked up.

Check the implement run's result field directly. `result=max_turns` means the run was killed
mid-edit, not that it is still queued. A wide-and-shallow issue over ~12–15 files is the
primary trigger; see [`issue-shape.md`](./issue-shape.md).
