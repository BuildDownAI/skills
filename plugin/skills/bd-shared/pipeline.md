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

## Landing cost and consolidation

How skills read the orchestrator deploy posture and group same-subsystem issues to reduce
the number of deploys a plan triggers.

### The probe

If `kg.mcp_server` is set in the project's `## Knowledge graph` CLAUDE.md block, call
`mcp__<kg.mcp_server>__get_deploy_posture` and read four fields:

| Field | Type | Meaning |
|---|---|---|
| `mergeCost` | string | Cost of one merge: `"deploy+image"`, `"image"`, or `"none"` |
| `autoDeploy` | boolean | Every merge triggers a deploy automatically |
| `deploy.held` | boolean | Deploys are queued but not running |
| `runnerChannel.matchesHead` | boolean | The runner is building from the current branch head |

**Graceful degradation.** If `kg.mcp_server` is absent, skip the probe — no tool call. Say
so in one line in the opening declaration and continue with unchanged behaviour. If the tool
call errors (tool not found, auth failure, unexpected response), posture = unknown. Say so in
one line in the opening declaration and continue with unchanged behaviour.
`get_deploy_posture` is a forward reference to AII-542; until that ships, every call errors
and skills degrade to posture = unknown.

### Posture line (opening declaration)

State the posture next to the environment and tracker lines:

| Condition | Posture line |
|---|---|
| `mergeCost: "deploy+image"`, `autoDeploy: true` | `Landing cost: deploy+image on every merge to <branch>.` |
| Same, with `deploy.held: true` | `Landing cost: deploy+image on every merge to <branch> (deploy held).` |
| `mergeCost: "image"`, `autoDeploy: true` | `Landing cost: image build on every merge to <branch>.` |
| `mergeCost: "none"` | `Landing cost: none — no deploy on merge.` |
| No MCP bound | `Landing cost: unknown — no orchestrator MCP bound.` |
| Tool error | `Landing cost: unknown — get_deploy_posture unavailable.` |

### Consolidation rule

Default to one multi-issue group — a parent with `feature_branch.mode: "multi-issue"`,
children as native sub-issues — when **all** hold:

1. `mergeCost` is `"deploy+image"` or `"image"`.
2. Two or more issues in the plan touch the same subsystem.
3. None of them is a hotfix, and none is needed alone to unblock a live verification.

Otherwise file standalone.

**Subsystem detection — dual-heuristic, ordered:**

1. **Primary — top-level directory.** Extract the leading path segment from every path in
   each issue's `## Files` section. Issues sharing a segment are same-subsystem. Sufficient
   when no KG is bound.
2. **Secondary — KG subsystem index.** When a KG is bound, use the subsystem label from the
   matching doc nodes to split false positives or merge near-misses.

Issues with no parseable `## Files` section have unknown subsystem and are excluded from
consolidation. File them standalone.

**Exceptions — state in the plan header:**

- **Hotfix.** A hotfix issue is never consolidated. All issues in its subsystem group are
  filed standalone. Plan header: `Filed standalone: hotfix issue exempted.`
- **Live blocker.** An issue needed alone to unblock a live verification is never
  consolidated. Plan header: `Filed standalone: live-blocker exempted.`

### Plan header additions

Add two lines after the critical-path line:

```
Landing cost: <posture line>
Filing: <choice and reason>
```

| Situation | Filing line |
|---|---|
| Consolidated group of N | `Filed as one group: N merges → 1 deploy.` |
| Standalone — low cost | `Filed standalone: merge cost is none.` |
| Standalone — single subsystem | `Filed standalone: only one issue per subsystem.` |
| Standalone — hotfix | `Filed standalone: hotfix issue exempted.` |
| Standalone — live blocker | `Filed standalone: live-blocker exempted.` |
| Standalone — unknown posture | `Filed standalone: posture unknown, defaulting to independent issues.` |

### Multi-issue parent shape

When filing a consolidated group:

1. **Parent issue.** Its description must contain a fenced `# ai-implement.yml` block with
   `feature_branch.mode: "multi-issue"` — see §Multi-issue mode for the exact format. An
   unfenced marker is ignored.
2. **Child issues.** File as native sub-issues of the parent, with `Blocked by:` relations
   mirroring dependency order.
3. **Designation order — build the tree first.** File all children, designate the parent,
   then designate the children. See §Designation order above and `./feature-branch-grouping.md`.

### Worked example

**Scenario:** three same-subsystem fixes on an autodeploying orchestrator.

Setup: `kg.mcp_server: orch-myapp` in CLAUDE.md. Plan contains:

1. Fix validation — `## Files`: `plugin/skills/bd-shared/ste.md`
2. Fix wording — `## Files`: `plugin/skills/bd-shared/pipeline.md`
3. Fix example — `## Files`: `plugin/skills/bd-shared/kg-binding.md`

**Probe.** `mcp__orch-myapp__get_deploy_posture` returns
`{ mergeCost: "deploy+image", autoDeploy: true, deploy.held: false }`.

**Posture line:** `Landing cost: deploy+image on every merge to testing.`

**Subsystem detection.** All three issues declare files under `plugin/` → same top-level
directory. One subsystem, three issues.

**Consolidation check:**
- `mergeCost: "deploy+image"` ✓
- Three issues, same subsystem ✓
- None is a hotfix; none blocks a live verification ✓
→ Consolidation fires.

**Plan header:**

```
Landing cost: deploy+image on every merge to testing.
Filing: Filed as one group: 3 merges → 1 deploy.
```

**Filing sequence:**
1. Create parent issue with fenced `# ai-implement.yml` block, `feature_branch.mode: "multi-issue"`.
2. File three child sub-issues with `Blocked by:` relations.
3. Designate parent, then designate children.

Branch: `ai-implement/multi-issue/<parent-key>`.

## Diagnosing a silent failure

When the runner hits the turn cap mid-edit it pushes **nothing** — no partial PR, no branch.
The issue reads as though it was never picked up.

Check the implement run's result field directly. `result=max_turns` means the run was killed
mid-edit, not that it is still queued. A wide-and-shallow issue over ~12–15 files is the
primary trigger; see [`issue-shape.md`](./issue-shape.md).
