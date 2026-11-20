# Issue body — the canonical template

Shared reference for `bd-build-up`, `bd-mega-build-up`, `bd-summit-push`, and the follow-up
issues `bd-build-down` files. Every filed issue uses this shape.

The body has two audiences in this order: a **human** skimming the board, then a **coding
agent** reading cold. The opening paragraph serves the human. Everything after it serves the
agent. Write all prose in the body in Simplified Technical English — see [`ste.md`](./ste.md).
Paths, code blocks, headings, and the `## Shape` fields keep their current form.

## Template

```
{Opening paragraph — 2–4 plain STE sentences, before any heading. What this issue is,
and why it exists. A human must understand the issue from this paragraph alone.}

## Problem / Context

Current state, and what this issue enables.

## Task

What to build, precisely: routes and request/response shapes, schema columns and types,
UI layout and interaction detail, component names as they exist in the codebase, and every
adjacent change the work needs.

Design reference: {ADR path, prototype route, or design screen — for the human reviewer}

## Files

- Create: `exact/path/to/new-file.ts`
- Modify: `exact/path/to/existing.ts`
- Test: `tests/exact/path/test.ts`
- Delete: `exact/path/to/dead-file.ts`

## Acceptance Criteria

- [ ] One claim, checkable from the diff or by a command in the implementer's sandbox
- [ ] `{{BUILD_CMD}}` passes

## Dependencies

Blocked by: {ISSUE-ID} (reason)
Parallel-safe with: {ISSUE-IDs}

## Shape

Shape: {wide-and-shallow | deep-and-targeted}
Stays whole: {omit below 7 countable files and 7 criteria | why the issue stays whole}
Migration/backfill: {no | yes — isolated, no consumers in this issue}
Pattern anchor: {exact file or PR, or "novel"}
Test fixture: {test path, or the cases a first-of-its-kind test covers}
Trust boundary: {none | crosses X, handled by Y}
Rollback: {mechanical | flag `name` | revert}
Observability: {none | `metric.name`}
Setting surface: {none | <page> · <control> · settings-table row, env `NAME` as seed}
Snapshot delta: {none | per-part: `<part.nt>` <direction> <rough size>[; needs accept-new-baseline]}

## Notes

Edge cases, gotchas, and the decisions from the grill that bear on this issue.
```

## How the orchestrator reads the body

When planning runs, the planner reads the body and posts an Acceptance Bar comment: numbered
claims taken from the criteria. The implementer builds from the body and the plan. The reviewer
reads only the source and the diff, runs no commands, and grades each numbered claim as written.
The rules below follow from that.

## Body rules

1. **Verify every fact, count, and anchor against the code**, per
   [`anchor-verification.md`](./anchor-verification.md). The reviewer grades each criterion as a
   literal claim and enforces the body's text over correct code. Observed: a body said one
   component reads a token, two did, and a correct run failed review three times. Count call
   sites with a search, not from memory.
2. **Name every file and every adjacent change the task needs.** The reviewer reverts needed
   work that the body does not name as unrequested scope. A config allowance, a second reader,
   or a doc line the work needs belongs in `## Task` and `## Files`.
3. **Write six or fewer criteria where the work allows**, because each one is a claim the
   reviewer grades (see [`issue-shape.md`](./issue-shape.md) § Size). Make no criterion
   contradict another: one criterion's grep forbade a name that another's test required, and the
   implementer built the name from fragments to pass both. Make each one checkable from the diff
   or by a command that runs in the implementer's sandbox. The sandbox has no live service,
   deployed environment, or browser, so a criterion that needs one loops the run until a person
   supplies the evidence. Put that evidence in an operator
   issue instead: no pickup signal, `Blocked by:` the implementation issue, closed by a person.
   Inside a tree, an open operator child also holds the parent's closing run.
4. **Close every decision before filing.** An open choice leaves the implementer to pick, and
   the reviewer grades the pick against text that did not decide it.
5. **Settle the body before the orchestrator plans the issue.** The planner fixes the acceptance
   bar when it plans. A body edit after that does not change the bar, so the reviewer keeps
   grading the old claims. To change the bar after planning, post a new comment that starts with
   the exact header `## ✅ AI Planning: Acceptance Bar`. The next run reads the newest one.

## Declare the surface. Do not script the work.

The implementer is a capable model. It does not need its edits dictated step by step, and a
scripted plan goes stale the moment the codebase moves under it. The most prescriptive bodies
in a sample had trouble 2 times in 6, no better than the rest.

**Declare** — exact file paths, the schema and API contract (a type shape or a state table is
fine as a code block), the criteria, the pattern anchor to mirror, the trust boundary, and every
decision.

**Do not script** — a numbered `read this, then edit that, then run the test` sequence, code for
work the agent can write, or a restatement of the repo's own conventions.

**The one exception is an exact string or value the reviewer will grade**: an error message, a
log line, a constant, a header name. Verify it against the code before you quote it, because the
reviewer grades a quoted string as the requirement. Observed: a body prescribed wrong comment
text, and the reviews flip-flopped between that text and the correct behaviour.

## Every constraint carries the failure it prevents

A bare constraint is an instruction. A constraint plus its failure mode is a *reason*, and a
reason survives contact with an implementer who finds the constraint inconvenient.

State the constraint, then the concrete thing that breaks without it:

| Instead of | Write |
|---|---|
| "`opts` is required." | "`opts` is required **because** a call site that omits the entity must fail to compile rather than silently return unfiltered rows." |
| "Resolve the IDs once." | "Resolve the IDs once — this endpoint already issues many queries per request, and a second resolve per predicate makes a known slow path worse." |
| "Do not use an embedded `!inner` join." | "Do not use an embedded `!inner` join — an entity in two selected projects returns twice, and every count downstream is wrong." |

With no stated consequence, an implementer weighing "required or optional" picks the one that
compiles against today's callers. Observed: a required argument shipped as
`opts?: { entity?: T }` with `if (!opts?.entity) return query`, which turned "filter by project"
into "return everything". The reason matters most where the violation is **silent**: a dropped
filter, a truncated result, a widened scope.

## `## Files` is machine-read

Keep the exact bullet form. The orchestrator's dispatch guard parses
`- Create|Modify|Test|Delete: ` followed by a backticked path. A `:line-range` suffix inside the
backticks is fine.

**The guard compares only siblings on one feature branch.** Declared overlap defers the later
sibling until the first merges. The guard skips standalone issues, so two standalone issues that
edit one file need a `Blocked by:` between them.

**An issue with no parseable bullets fails open.** It dispatches beside any sibling that edits
the same files. Every file the work touches belongs in this list. Prose mentions inside
`## Task` are invisible to the guard.

### Shared helper files

List a shared helper as `Modify:` in every sibling that extends it. A shared helper is a file
that one issue creates and sibling issues extend: a test kit, a contract suite, a fixture, a
shared type file. The guard defers the later sibling only when both issues declare the file. A
sibling that only reads the helper does not declare it.

**Example.** Issue A creates `src/__tests__/helpers/contract.ts`. Issues B and C each extend it.
Both B and C declare `Modify: src/__tests__/helpers/contract.ts`. Without that declaration, the
guard can run B and C in parallel and cause a merge conflict.

## The filing check

Run it on every drafted body before you file it, and again before you label a filed issue.

**When a shell exists**, run [`tools/verify-issue-files.py`](./tools/verify-issue-files.py)
against the body and the repo, and paste its output into the session:

```sh
verify-issue-files.py draft.md --repo /path/to/repo
# or, on an already-filed issue:
gh issue view 123 --json body --jq .body | verify-issue-files.py - --repo .
```

It fails on a `Modify:` or `Delete:` target that does not exist, a `Create:` target that does, a
body with no parseable bullets, a `"<n> lines"` claim that disagrees with the file, and the shape
rules in [`issue-shape.md`](./issue-shape.md). It warns at 7 countable entries. Read the
inventory it prints, not only the exit code. Observed: a body called a page "1367 lines", and the
inventory showed 40, because the long file was one path segment away.

**When no shell exists** (chat), apply the same checks by reading. Open each `## Files` path
through the GitHub connector or a code-reading agent (`bd-belay-on`). Confirm each `Create:` path
is new, count the countable entries, and check each line-count claim. Say in the session that the
check ran by reading.

**Hold the issue**, and fix it before you file or label it, when any of these is true:

1. It reaches the size threshold in [`issue-shape.md`](./issue-shape.md) § Size with no
   `Stays whole:` reason.
2. A criterion cannot be checked by reading source or by a command in the implementer's sandbox
   (body rule 3).
3. A stated fact, count, or anchor is not verified against the code (body rule 1), or a design
   decision is left open (body rule 4).
4. It carries a migration or an auth change. Route it to the architect with no pickup signal
   (below). A PR that carries one still escalates in `bd-build-down`.

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
phrase, one pattern — bd-build-down reads it to sequence merges. The tracker-native relation is
what holds dispatch; the body line does not. Its mechanics are in the adapter's
**Dependencies** section.

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
