---
name: mega-build-up
description: "Plan a milestone in depth, grill the user adversarially on the design, then file a Linear project with attached design + implementation-plan documents and a sequenced set of parallel-execution-ready issues. Trigger when the user says 'mega-build-up', 'mega build-up', 'deep build-up', 'thorough build-up', 'grill me on this build-up', or describes an objective and wants the design pressure-tested before any issues get filed. Mega-build-up is build-up's heavier cousin: same AI-Implement pipeline awareness and issue-shape discipline, but with an adversarial design-review phase, a detailed implementation plan with exact file paths, and Linear documents attached to the project so the design and plan travel with the work."
---

# Mega Build-Up Skill

A mega-build-up is build-up with senior-engineer pushback and a written-plan deliverable. Same AI-Implement pipeline target. Same Linear destination. Higher rigor on the front end.

**Cardinal rule: grill, then plan, then file.** Three approval gates: (1) design after grilling, (2) plan after drafting, (3) issue list before filing. Don't skip gates to save time — the cost of bad scope filed into Linear is much higher than the cost of one more question.

**Use this over plain `build-up` when:**
- Scope is non-trivial (≥ 8 issues, multi-system, schema changes, or new architecture)
- The user explicitly wants pushback ("grill me," "stress-test this," "I want the senior eng review")
- The plan needs to live as documentation (regulated work, multi-week effort, multiple operators handing off)

**Use plain `build-up` instead when:**
- Scope is small (< 5 issues, well-trodden territory)
- The user is confident and wants speed
- It's a convergence pass over an already-reviewed prototype

If unclear which to use, ask once. Default to `build-up` for speed.

---

## Configuration

- `{{TRACKER}}` — Linear (this skill assumes Linear MCP; adapt for others)
- `{{REPO}}` — GitHub repo, owner/name format
- `{{IMPLEMENT_LABEL}}` — `AI-Implement` (the label that triggers the AI-Implement pipeline)
- `{{ARCHITECT_NAME}}` — human owner for risky changes (migrations, auth, infra). Optional.
- `{{BUILD_CMD}}` — verification command (e.g., `next build`, `tsc --noEmit`, `pytest`)
- `{{PLAN_DIR}}` — local path for plan drafts before they're attached to Linear (default `docs/plans/`)

---

## AI-Implement Pipeline Context

The downstream consumer of this build-up is the **AI-Implement harness** (https://github.com/BuildDownAI/AI-Implement). Knowing how it picks up work shapes how issues should be written.

- The orchestrator polls Linear every ~60s for unblocked issues with the `AI-Implement` label.
- A picked-up issue moves to **In Progress**, runs Claude Code against the ticket spec via `WORKFLOW.md`, opens a PR, then posts a **gap analysis** comment comparing the diff against the spec.
- The Linear issue transitions to **Ready for Review** with a PR link.
- Commenting `/ai-implement` on the PR re-runs Claude in **gap-fill mode** against the same branch.
- Linear is the source of truth. Ad-hoc prompts don't enter the pipeline.

**Implications for issue shape:**
1. **The issue body is the spec.** The pipeline reads it cold — no follow-up questions. Everything must be inline.
2. **Gap analysis only catches what the spec specified.** Vague acceptance criteria → vague gap analysis → bad PRs.
3. **Parallel pickup is the default.** Multiple unblocked `AI-Implement` issues run concurrently across separate branches. Issues must be independently mergeable, or use `Blocked by:` to serialize them.
4. **State + label is the trigger.** `state: Todo` + `AI-Implement` label = picked up within minutes. `Backlog` = parked.

---

## Issue Design Rubric

Every task in the plan and every issue filed must pass the rubric. Phases 3 and 4 reference back here.

### The shape rule (hard constraint)

Every task is **either** wide-and-shallow **or** deep-and-targeted. Never both.

- **Wide & shallow** — touches many files, each touch is mechanical: rename, propagate a type, add the same import, add a tracking call. Low cognitive load per file. Risk: missing a file. Mitigation: explicit file list in the spec.
- **Deep & targeted** — touches few files, each touch requires reasoning: new algorithm, new state machine, new component logic. Concentrated cognitive load. Risk: getting the logic wrong. Mitigation: testable acceptance criteria + test-first.
- **Wide & deep is forbidden.** A task that touches many files AND requires reasoning at each touch point is unsplit. Refuse to file. Split into a deep core change + a wide propagation that's `Blocked by:` it.

### Hard rules (violation = task gets split, no exceptions)

1. **Migration isolation.** Any schema migration is its own task, its own PR. Consumers (API, UI) are downstream tasks with `Blocked by:`.
2. **Backfill isolation.** Data backfills follow the same rule as migrations — separate task, runs after the migration that enables them, blocks any consumer that depends on the backfilled state. Backfills have the same blast-radius and rollback properties as migrations and must not ride along with code changes.
3. **Declarative schema tools (Atlas, etc.) — push back vigorously on column renames.** Projects using Atlas or similar declarative schema tools manage schema as code, not as imperative migrations. A column rename in such a project is a multi-step manual operation (add new column → backfill → cut over reads → cut over writes → drop old column) that the AI-Implement pipeline cannot one-shot safely. **Default response: refuse to file as an AI-Implement task. Recommend it as a manual, scripted, human-driven sequence.** Override only if the user explicitly confirms they understand the cutover steps and wants the agent to do one specific phase as its own task.
4. **Backend before frontend.** API endpoints ship before UI that calls them. Same task = rejected.
5. **No "while you're there" scope.** The task touches only what its title claims. Drive-by refactors are separate tasks.
6. **Spec readable cold.** Title, files, steps, acceptance criteria all in the issue body. No "see design doc" without inlining the load-bearing parts. The AI-Implement pipeline reads the issue body cold and does not follow links.
7. **Acceptance criteria are testable.** Each criterion is a checkbox with a verifiable outcome. "Works correctly" is rejected.

### Soft signals (every task answers every signal)

Each task explicitly answers each signal in the plan. "No, and that's OK because X" is a valid answer. Silence is not.

| Signal | Question | Action if "no" |
|---|---|---|
| **Pattern anchor** | Is there an existing file/PR the agent can mirror? | If genuinely novel, call it out in Notes. If novel by accident, find the closest analog. |
| **Test fixture** | Is there an analogous test the agent can copy? | If first-of-its-kind, the spec must include the full test code. |
| **Trust boundary** | Does the task cross a trust boundary (user input, external API, cross-tenant)? | If yes, boundary must be explicit in the spec — what's validated where, what's authorized where. |
| **Rollback path** | If this breaks in prod, what's the recovery? | Risky changes need a feature flag or rollback note. Mechanical changes don't. |
| **Observability** | What logs/metrics confirm it works in prod? | If the task adds behavior worth verifying, specify the signal. |
| **Parallel-safety** | Does this share file edits with another unblocked task? | If yes, one must block the other or they merge. |

### Rubric evolution

The rubric is living. After each build-down, capture failure classes:
- "This task needed 4 gap-fill rounds because we didn't specify the auth pattern" → add a soft signal for **Auth pattern anchor**.
- "This task one-shotted but produced a regression because we didn't specify the existing-data assumption" → add a soft signal for **Existing-data invariants**.

When a failure class recurs across two or more build-ups, promote it from "lesson learned" to a permanent rubric entry. Edit this skill — don't keep the rubric in someone's head.

---

## Environment Detection

State the environment at session start.

- **Chat (web/mobile):** Linear MCP, GitHub MCP, conversation memory. Lacks local FS / bash. Belay-on to a code-reading agent for codebase reads.
- **Code-execution (terminal):** bash, local FS, git. Lacks project memory. Use for codebase reads, plan file drafting, then hand back to chat for filing.
- **Pair pattern:** Draft the plan locally as a markdown file in `{{PLAN_DIR}}`, then attach it to Linear from chat as a Project Document.

**Opening declaration:** State environment, primary tools, and which mode you'll be running. Example: *"Running in chat. Linear MCP for filing, will draft the plan to `docs/plans/` and attach as a project document. Mode 2 (New Design)."*

---

## Mode Detection

Same modes as `build-up`. Infer from framing; ask only on conflicting signals.

- **Mode 1: Convergence** — code-prototype repo → production. User mentions a prototype path or says "converge."
- **Mode 2: New Design** — objective → issues. Default when no prototype is mentioned. *Handoff-bundle variant:* user provides a design tool's export.
- **Mode 3a: Code-Prototype Brief** — objective → markdown spec for a code-first prototype tool. Skip filing.
- **Mode 3b: Design Brief** — objective → markdown brief for a design-first tool. Skip filing.

Mega-build-up's grilling and detailed-plan phases apply most strongly to **Mode 2** (and Mode 1 when convergence scope is large). For Mode 3 briefs, grilling still applies — it sharpens the brief — but the plan-document phase is replaced by the brief itself.

---

## Phase 1: Orient

Same as `build-up` Phase 1. Understand current state before drafting anything.

- Read prototype + production codebases (Mode 1) or research the codebase for adjacent patterns (Mode 2).
- Check Linear for in-flight overlapping work via `list_issues`.
- List existing projects via `list_projects` so you know whether this build-up creates a new project or attaches to an existing one.
- Ask **at most 2** clarifying questions before moving on. After that, state assumptions and proceed.

The orient phase produces a **working understanding**, not a plan. Don't draft issues yet.

---

## Phase 2: Grill

This is the senior-engineer review. Adversarial in tone, collaborative in intent. The goal is to surface every important decision and force a deliberate answer before any issues get filed.

### Grilling style

**Ask one question at a time.** Wait for the user's answer before moving on. Don't dump a question list.

**Provide your recommended answer with each question.** The user can accept it (fast) or push back (better answer). Recommendations should be opinionated, not safe-defaults.

**If a question can be answered by reading the codebase, read the codebase.** Don't ask the user what they could see for themselves. Belay-on to a code-reading agent if needed.

**Walk the decision tree.** Resolve dependencies between decisions. Don't ask about column types before deciding whether the table exists.

**Push back when the answer is weak.** If the user says "we'll figure that out later" on a load-bearing decision, name what depends on it and ask again. Polite, persistent, specific.

**Stop grilling when the design is decided, not when you run out of questions.** Some build-ups need 3 questions, some need 15. The signal to stop is that the next question would be a detail the implementation can decide on its own.

### What to grill on

Cover at least these branches before declaring the design decided:

1. **Scope boundary.** What's in v1? What's explicitly deferred? Where's the "we could expand later" line?
2. **Data model.** New tables/columns? Migrations? Indexing? Foreign keys? Reuse vs. fresh?
3. **API surface.** New endpoints? Request/response shapes? Auth/permissions? Backwards compatibility?
4. **UI surface.** New routes? New components? Modifications to existing components? Mobile/responsive needs?
5. **Trust boundaries.** Where does user input enter? Where does it leave the system? What's validated where?
6. **Failure modes.** Empty states, error states, race conditions, partial failures. What happens when X is null / 404 / timing-out?
7. **Migration / rollout.** Feature flag? Behind auth? Backfill needed? How do we ship this without breaking existing users?
8. **Testing strategy.** Unit, integration, e2e? What's the minimum bar? Where are the load-bearing tests?
9. **Observability.** What logs/metrics do we need to verify it's working in production?
10. **Out-of-scope confirmations.** "We are NOT doing X, Y, Z in this build-up. Confirm?"

You don't need all 10 every time. You do need to walk the tree and stop at "we have enough to write a plan that won't surprise us."

### Adversarial principles

- **Be specific.** "How does this handle concurrent edits?" beats "Have you thought about edge cases?"
- **Name the failure.** "If two users hit submit simultaneously, the current design double-charges. Are we OK with that, or do we need an idempotency key?"
- **Refuse to be deflected.** "Good question, we'll handle it later" is not an answer to a load-bearing question. Push back: "It changes whether Issue 4 is one issue or three. Let's decide now."
- **Acknowledge good answers.** When the user has clearly thought about something, log it and move on. Don't grill for grilling's sake.
- **Be the senior engineer the user wants on the review, not the one they avoid.** Sharp, not exhausting.

### Output of Phase 2

A short **Design Decisions** doc capturing what was decided. This becomes one of the two documents attached to the Linear project. Format:

```markdown
# {Build-Up Name} — Design Decisions

## Objective
One-paragraph statement of what this build-up achieves.

## Scope
**In v1:** ...
**Deferred:** ...
**Out of scope:** ...

## Decisions
- **Data model:** {what, why, alternatives rejected}
- **API surface:** {what, why}
- **UI surface:** {what, why}
- **Trust boundaries:** {what, why}
- **Failure modes:** {key cases and how they're handled}
- **Rollout:** {flag/migration/backfill plan}
- **Testing:** {strategy and minimum bar}
- **Observability:** {logs/metrics}

## Open Questions
Anything genuinely undecided, with the proposed default if not answered.
```

Save to `{{PLAN_DIR}}/{date}-{slug}-design.md`.

**Approval gate 1:** Present the Design Decisions doc. Get explicit approval ("looks good," "go," "ship it") before moving to Phase 3. Questions or partial feedback = revise and present again.

---

## Phase 3: Draft the Implementation Plan

This is the writing-plans-style detailed plan: file paths, bite-sized steps, no placeholders. The plan is a document attached to the Linear project, **and** the source material for the issue breakdown in Phase 4.

### Plan philosophy

Write for an engineer (or AI agent) with **zero context for the codebase and questionable taste**. They are skilled, but they don't know your toolset, your conventions, or your test design preferences. Document everything they need.

DRY. YAGNI. TDD. Frequent commits.

### File structure first

Before defining tasks, map out which files will be created or modified and what each one is responsible for. Decomposition decisions get locked in here.

- One clear responsibility per file.
- Smaller, focused files over large ones that do too much.
- Files that change together live together.
- Follow existing codebase patterns. Don't unilaterally restructure unless a file you're modifying has grown unwieldy.

### Plan document header

```markdown
# {Feature Name} Implementation Plan

> **For AI-Implement:** Each task below maps to a Linear issue (Phase 4). Steps use checkbox syntax for tracking. The pipeline picks up each issue independently — task descriptions must be self-contained.

**Goal:** One sentence.

**Architecture:** 2-3 sentences on approach.

**Tech Stack:** Key libraries/frameworks.

**Linear Project:** {project name + URL once filed}

---
```

### Task structure

Each task = one parallelizable unit of work = one Linear issue.

````markdown
### Task N: {Component Name}

**Shape:** wide-and-shallow | deep-and-targeted (pick one — never both)
**Migration / backfill?** no | yes (if yes, this task contains ONLY the migration/backfill — no code consumers)

**Files:**
- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts:123-145`
- Test: `tests/exact/path/test.ts`

**Parallel-safe with:** Task M, Task K (no shared file edits, no schema dependency)
**Blocked by:** Task A (reason)

**Rubric:**
- Pattern anchor: `path/to/reference/file.ts` (or "novel — see Notes")
- Test fixture: `tests/path/similar.test.ts` (or "first of its kind — full test in Step 1")
- Trust boundary: none | crosses {boundary} — handled by {mechanism}
- Rollback path: mechanical change, no flag needed | feature flag `flag_name` | revert PR
- Observability: none needed | `metric.name` / `log event` confirms it
- Parallel-safety verified: no file overlap with parallel-safe peers

- [ ] **Step 1: Write the failing test**

```ts
// actual test code
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm test path/to/test.ts`
Expected: FAIL with "X is not defined"

- [ ] **Step 3: Write minimal implementation**

```ts
// actual implementation
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm test path/to/test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add <files>
git commit -m "feat: <message>"
```
````

### No placeholders — these are plan failures

- "TBD" / "TODO" / "implement later" / "fill in details"
- "Add appropriate error handling" / "validate as needed" / "handle edge cases"
- "Write tests for the above" without actual test code
- "Similar to Task N" — repeat the code, the engineer (or agent) may read tasks out of order
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

### Parallel-execution awareness

The AI-Implement pipeline runs unblocked `AI-Implement` issues concurrently. The plan must reflect this:

- **Mark each task with `Parallel-safe with:`** listing other tasks that share no edited files and no logical dependency. This will become the issue's parallelization signal.
- **Mark each task with `Blocked by:`** when serialization is required (schema migration before the API that uses it; API endpoint before the UI that calls it).
- **Backend before frontend.** Always. Never combine schema/API and UI in one task.
- **One file conflict = one merge conflict.** If two tasks both modify the same file in non-trivial ways, they're not parallel-safe — make one block the other or merge them into a single task.

### Self-review

After writing the plan, check it against the Phase 2 design doc with fresh eyes:

1. **Decision coverage.** Every decision in the design doc is implemented by at least one task. Gaps?
2. **Placeholder scan.** Search for the failure patterns above. Fix them.
3. **Type/name consistency.** A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug. Same for column names, route paths, component names.
4. **Parallelization audit.** Which tasks claim `Parallel-safe with:` X — do they really not touch the same files? Re-check.

Fix issues inline. No need to re-review — just fix and move on.

Save to `{{PLAN_DIR}}/{date}-{slug}-plan.md`.

**Approval gate 2:** Present the plan. Get explicit approval before moving to Phase 4.

---

## Phase 4: Linear Project + Documents + Issues

### Step 1: Resolve the Linear project

- **New project:** Default name = build-up name from Phase 2. Confirm with user.
- **Existing project:** Use `list_projects` to match. If multiple candidates, present them.
- Create the project via the Linear MCP if new. Capture the project ID and URL.

### Step 2: Attach design + plan documents

Linear supports project Documents. Attach both:

1. **Design Decisions** → upload `{{PLAN_DIR}}/{date}-{slug}-design.md` as a project document titled `Design Decisions`.
2. **Implementation Plan** → upload `{{PLAN_DIR}}/{date}-{slug}-plan.md` as a project document titled `Implementation Plan`.

Use the Linear MCP's document creation tool (`create_document` or equivalent). If the MCP version available doesn't support documents, fall back to: paste the markdown into the project description, and link the local files in the first issue's body.

The documents travel with the project. Anyone who picks up an issue can find them via the project link.

### Step 3: Generate issues from plan tasks

**One task = one issue.** This is the parallel-subagent-style decomposition.

For each task in the plan, build an issue body that the AI-Implement pipeline can run cold:

```
## Problem / Context

{Why this issue exists. Link to the Linear project for full design context.}

## Task

{Direct from the plan task. Files to create/modify, with exact paths.}

Reference design context: {Linear project URL}

## Steps

{Direct from the plan task — the bite-sized step list, including code blocks.}

## Acceptance Criteria

- [ ] {Specific, testable criterion}
- [ ] {Another}
- [ ] `{{BUILD_CMD}}` passes

## Dependencies

Blocked by: {ISSUE-ID} (reason)
Parallel-safe with: {ISSUE-IDs}

## Shape & Rubric

Shape: {wide-and-shallow | deep-and-targeted}
Migration/backfill: {no | yes — isolated, no consumers in this task}
Pattern anchor: {file/PR reference or "novel"}
Test fixture: {test reference or "full test in Steps"}
Trust boundary: {none | crosses X — handled by Y}
Rollback: {mechanical | flag `name` | revert}
Observability: {none | `metric.name`}

## Notes

{Edge cases, gotchas, decisions from the design doc relevant to this task.}
```

The issue body must be **self-contained**. The AI-Implement pipeline reads it cold and won't follow links to fetch context. The "reference design context" link is for humans reviewing the PR, not for the agent.

### Step 4: Wave staging — file the issues

Same wave model as `build-up`:

- **Wave 1** (no `Blocked by`) → `state: Todo` + label `AI-Implement`. Pipeline picks up within minutes.
- **Wave 2+** (has `Blocked by`) → `state: Backlog`. Promote to `Todo` during build-down as blockers merge.
- **Architect-routed** (schema, security, infra) → `state: Todo`, assigned to `{{ARCHITECT_NAME}}`, **no** `AI-Implement` label.

File in dependency order so `Blocked by:` references resolve to real issue IDs.

**Approval gate 3:** Present the issue manifest before filing — don't file then ask. Issue manifest format:

```
| # | Title | Shape | Migration? | Wave | Labels | Blocked by | Parallel-safe with | Routing |
```

Confirm wave assignments and routing. After explicit approval, file via `save_issue` (or Linear MCP equivalent).

### Step 5: Post-filing manifest

After all issues are filed, present:

- Linear project URL
- Document URLs (design + plan)
- Issue manifest with real issue IDs
- Wave 1 issues (currently being picked up by the pipeline)
- Critical-path summary: longest dependency chain, so the user sees minimum time-to-complete

---

## Status Check Mode

Same as `build-up` status check. Match the user's reference to a Linear project, list issues grouped by state, surface blockers, identify build-down readiness (issues in In Review or with open PRs).

If the user asks "where's the design for X?" or "what was the plan for X?" — fetch the project documents and surface them, don't reconstruct from issue bodies.

---

## Conventions

**Linear MCP patterns:**
- `save_issue` handles create + update (pass `id` to update).
- Label arrays replace — always pass the full desired list.
- `state: Todo` + `AI-Implement` label = pipeline pickup.
- Documents attach to projects, not to individual issues. One project per build-up.

**Dependency phrasing:** Always `Blocked by: {ISSUE-ID} (reason)`. Not "Depends on," not "Requires." One phrase, one pattern.

**Sizing:** see Issue Design Rubric. (Skill archaeology note: earlier versions used a 1/2/3/5/8 story-point scale inherited from `build-up`. It was dropped because abstract sizing didn't capture codebase friction.)

**Plan file naming:** `{{PLAN_DIR}}/{YYYY-MM-DD}-{slug}-design.md` and `-plan.md`. Same date prefix so they sort together.

---

## Key Principles

1. **Three approval gates: design, plan, issues.** Don't skip one to save time.
2. **Grill one question at a time, with a recommended answer.** Walk the decision tree. Stop when the next question would be implementation detail.
3. **The plan is a document, not a comment thread.** It lives as a Linear project document so it survives the build-up session.
4. **One task = one issue.** Plan tasks are sized for parallel pipeline execution. Issue bodies are self-contained because the pipeline reads them cold.
5. **Backend before frontend, always.** Schema → API → UI. Never combined.
6. **Wave 1 to Todo + `AI-Implement`. Get the agents going.** Build-up's job is to launch work, not park it.
7. **Mega vs. plain build-up is a choice about rigor, not a default.** Use plain `build-up` for small, well-trodden scope. Use this when the design needs pressure-testing or the plan needs to live as documentation.

---

## Red Flags — Stop and Restart the Phase

- **Filed issues without all three approvals.** → Close the un-approved issues. Restart from the gate you skipped.
- **Plan has TODOs / TBDs / "handle edge cases".** → Plan failure. Fix before filing.
- **Two tasks edit the same file but are marked parallel-safe.** → Parallel-safety bug. One must block the other or they merge.
- **Schema and UI in one task.** → Backend-before-frontend violation. Split.
- **A task is wide AND deep.** → Shape rule violation. Split into a deep core + a wide propagation that's blocked by it.
- **Migration or backfill is bundled with code that consumes it.** → Hard rule violation. Migration/backfill becomes its own task; consumer becomes a downstream task with `Blocked by:`.
- **Atlas (or other declarative-schema) project, and the task is "rename column X to Y".** → Refuse to file as AI-Implement. Recommend manual scripted cutover (add → backfill → cut over reads → cut over writes → drop). Override only if user confirms a single-phase task.
- **Issue body says "see design doc" without inlining the spec.** → Pipeline can't read links. Inline the spec.
- **Grilling skipped because "the user seemed sure".** → Mega-build-up exists for the grill. If skipping was right, plain `build-up` was the right skill.

---

## Relationship to Other Skills

- **`build-up`** — lighter version. Same destination (Linear + AI-Implement), no grilling phase, no plan document, issue bodies are written at filing time rather than derived from a plan.
- **`build-down`** — the next session. Drives filed issues to merge. Promotes Backlog issues to Todo as blockers merge.
- **`super-build-down`** — autonomous build-down. Mega-build-ups produce well-specified issues, which is the input super-build-down needs.
- **`belay-on`** — use for environment hops. Chat→code-reading agent during Phase 1 codebase reads. Code-execution→chat for filing.
- **`smoke-jumper`** — use during build-down to validate PRs against the design decisions doc.
