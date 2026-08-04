---
name: bd-mega-build-up
description: "Plan a milestone in depth, grill the user adversarially on the design, then file a tracker project/epic with attached design + implementation-plan documents and a sequenced set of parallel-execution-ready issues. Trigger when the user says 'bd-mega-build-up', 'mega bd-build-up', 'deep bd-build-up', 'thorough bd-build-up', 'grill me on this bd-build-up', or describes an objective and wants the design pressure-tested before any issues get filed. bd-mega-build-up is bd-build-up's heavier cousin: same AI-Implement pipeline awareness and issue-shape discipline, but with an adversarial design-review phase, a detailed implementation plan with exact file paths, and design + plan documents attached to the project/epic so they travel with the work."
metadata:
  suite: builddown
---

# Mega Build-Up Skill

A bd-mega-build-up is bd-build-up with senior-engineer pushback and a written-plan deliverable. Same AI-Implement pipeline target. Same tracker destination (Linear or Jira). Higher rigor on the front end.

**Cardinal rule: grill, then plan, then file.** Three approval gates: (1) design after grilling, (2) plan after drafting, (3) issue list before filing. Don't skip gates to save time — the cost of bad scope filed into the tracker is much higher than the cost of one more question.

**Use this over plain `bd-build-up` when:**
- Scope is non-trivial (≥ 8 issues, multi-system, schema changes, or new architecture)
- The user explicitly wants pushback ("grill me," "stress-test this," "I want the senior eng review")
- The plan needs to live as documentation (regulated work, multi-week effort, multiple operators handing off)

**Use plain `bd-build-up` instead when:**
- Scope is small (< 5 issues, well-trodden territory)
- The user is confident and wants speed
- It's a convergence pass over an already-reviewed prototype

If unclear which to use, ask once. Default to `bd-build-up` for speed.

---

## Configuration

- `{{TRACKER}}` — the issue tracker for this bd-build-up: `linear` or `jira`. Determines which `trackers/<id>.md` adapter the core follows for all tracker-touching steps.
- `{{REPO}}` — GitHub repo, owner/name format
- `{{IMPLEMENT_LABEL}}` — `AI-Implement` (the label that triggers the AI-Implement pipeline)
- `{{ARCHITECT_NAME}}` — human owner for risky changes (migrations, auth, infra). Optional.
- `{{BUILD_CMD}}` — verification command (e.g., `next build`, `tsc --noEmit`, `pytest`)
- `{{PLAN_DIR}}` — local path for plan drafts before they're attached to the tracker container (default `docs/plans/`). These are **local working artifacts**: they drive the grilling and produce the Phase 4 Step 6 build-up learnings comment (and, if a tracker container exists, its attached design/plan documents). **Generally do not commit them to the code repo** — the durable record is the distilled `# ai-implement-build-up-learnings` comment plus any canonical reference doc the change introduces.

---

## AI-Implement Pipeline Context

The downstream consumer of this bd-build-up is the **AI-Implement harness** (https://github.com/BuildDownAI/AI-Implement). Knowing how it picks up work shapes how issues should be written.

- The orchestrator polls the tracker every ~60s for unblocked issues marked for AI-Implement (exact mechanism per the active adapter's **Pickup trigger** section).
- A picked-up issue moves to **In Progress**, runs Claude Code against the ticket spec via `WORKFLOW.md`, opens a PR, then posts a **gap analysis** comment comparing the diff against the spec.
- The issue transitions to **Ready for Review** with a PR link.
- Commenting `/ai-implement` on the PR re-runs Claude in **gap-fill mode** against the same branch.
- The tracker is the source of truth. Ad-hoc prompts don't enter the pipeline.

**Implications for issue shape:**
1. **The issue body is the spec.** The pipeline reads it cold — no follow-up questions. Everything must be inline.
2. **Gap analysis only catches what the spec specified.** Vague acceptance criteria → vague gap analysis → bad PRs.
3. **Parallel pickup is the default.** Multiple unblocked `AI-Implement` issues run concurrently across separate branches. Issues must be independently mergeable, or use `Blocked by:` to serialize them.
4. **The pickup signal is tracker-specific.** Linear uses state + label; Jira uses a Status field. The pickup signal present = picked up within minutes; parked = not picked up. (Exact mechanism per the active adapter's **Pickup trigger** section.)
5. **Parent/child trees become feature nodes (both trackers).** A *designated* parent issue with designated children becomes a *feature node* owning `ai-implement/feature/<key>`; its children PR **into that feature branch**, not the **Default Branch**, and the tree rolls up to a single human-reviewed `feature → base` PR. Plan the tree, the designation order, and the parent's deferred closing work accordingly. "Designated" and the concrete filing mechanics are tracker-specific — see the active adapter's **Feature-node grouping** section; full model: `docs/feature-branch-grouping.md`.

---

## Issue Design Rubric

Every task in the plan and every issue filed must pass the rubric. Phases 3 and 4 reference back here.

### The shape rule (hard constraint)

Every task is **either** wide-and-shallow **or** deep-and-targeted. Never both.

- **Wide & shallow** — touches many files, each touch is mechanical: rename, propagate a type, add the same import, add a tracking call. Low cognitive load per file. Risk 1: missing a file — mitigation: explicit file list in the spec. Risk 2: **turn-budget exhaustion** — the AI-Implement runner caps Claude turns per implement pass (a project Max-Turns setting, commonly ~50); at ~2–4 turns/file (read + edit + verify), >~12–15 files risks hitting the cap before the agent finishes and pushes. When a wide-and-shallow issue approaches the threshold, either **(1) split** (deep core change + wide propagation blocked by it) or **(2) raise the project's Max Turns** before dispatch and note it on the issue.
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
8. **Information-coupled tasks count as deep.** If a task's per-touch decision requires reading code or context outside that task's named files (e.g. "for each viewset, decide whether to paginate based on what the FE expects"), the task is **deep-and-targeted scoped to a smaller surface**, not wide-and-shallow — even if each individual edit is one line. The agent's per-touch cognitive load is `per-file edit + inter-task lookup`, not just `per-file edit`. Symptom: the spec contains the phrase *"for each X, decide whether…"* with no inlined heuristic. Fix: either inline the decision rule so each touch is truly mechanical, or split into one deep-and-targeted task per surface.

9. **Schema-tightening requires a writer census in the additive phase.** Any plan whose endpoint is a tighter constraint on an existing column (`NOT NULL`, `UNIQUE`, narrowed type, new `CHECK`, new FK) **must enumerate every writer to that table/column** — production code AND test fixtures AND seed scripts — and ensure each one is updated to satisfy the new constraint **before** the cleanup PR ships. The additive PR is not done when columns + backfill are in; it's done when every future write will also satisfy the future constraint. Otherwise the cleanup PR detonates against unmigrated writers (regression test suites, REST endpoints, background jobs, importers, factories) and the only signal is CI failures on the destructive PR.

   **Census method is stack-agnostic** — the goal is enumeration, not a specific search syntax. Examples of writer surfaces to walk (non-exhaustive, mix freely across stacks):
   - **ORM creates/updates:** `Model.objects.create` / `bulk_create` / `update` / `save` (Django); `DbSet.Add` / `Update` + `SaveChanges` (EF Core); `session.add` / `bulk_save_objects` (SQLAlchemy); `Model.create` / `findOrCreate` (Sequelize, ActiveRecord); query-builder `insertInto(...).values(...)` / `updateTable(...).set(...)` (Kysely, Knex).
   - **Raw SQL:** `INSERT INTO <table>` / `UPDATE <table> SET` in any language's string literals, migration files, fixture SQL, seed scripts.
   - **Test fixtures and factories:** FactoryBoy / factory_bot / Bogus / fishery / fixture JSON / fixture YAML / `@BeforeEach` helpers / shared test seeders. **Test fixtures are writers** — schema-tightening breaks them the same way it breaks prod writers, and forgetting them is the most common census miss.
   - **Background jobs, importers, webhooks:** cron tasks, queue workers, CSV/email/SFTP ingestion, third-party webhooks.
   - **Admin tooling:** Django admin save hooks, scaffolded CRUD, internal admin scripts, REPL/notebook snippets in the repo.

   **Output:** the additive phase plan lists every writer found, with a checkbox per writer for "now satisfies the future constraint." A writer the plan can't list is a writer the plan hasn't found. **Phase 2 grilling must include the census** — refer to the Phase 2 grilling tree's "Migration / rollout" branch, sub-question *"Have we enumerated every writer?"*.

   **Cleanup-phase preflight is a code question, not a data question.** Replace "all existing rows satisfy the constraint" with "**(a)** zero writers in the census omit the column, **and (b)** CI on a throwaway branch with the constraint pre-applied is green." A `SELECT COUNT(*) WHERE col IS NULL` tells you about the past; it tells you nothing about the next write.

10. **Feature-node parents defer their own work (both trackers).** When a plan uses a parent/child feature node, the parent's *own* closing work is `Blocked by:` **all** its designated children — it dispatches only after every child is terminal (Done/Cancelled; on Jira, `statusCategory` = done), onto the parent's own feature branch `ai-implement/feature/<key>`. Children PR **into the parent's branch**, never the reverse: a parent task that must merge to the Default Branch *before* its children is a grouping violation — split the parent's closing work out and block it on the children. Designation is the `{{IMPLEMENT_LABEL}}` label on Linear and a non-empty `AI-Implement-Status` + Repo match on Jira (active adapter's **Feature-node grouping** section). See `docs/feature-branch-grouping.md`.

**Silent `max_turns` failure mode.** When the runner hits the turn cap mid-edit, it pushes *nothing* — no partial PR, no branch. The issue reads as never picked up. Diagnose by checking the implement run's result field directly (`result=max_turns` = killed mid-edit, not still queued). A wide-and-shallow issue with >~12–15 files is the primary trigger — file count is the tell.

**Reshaping an existing detailed issue.** The rubric above is designed for authoring tasks from scratch. When bd-mega-build-up reshapes an existing, already-detailed issue (condensing it to hit the size target), there is a distinct risk: **right-sizing can silently drop a substantive acceptance item** the original spelled out. Before finalizing a reshape:
1. **Diff the reshaped version against the original.** Identify every substantive acceptance item. Confirm each is preserved or explicitly split out.
2. **Split, don't drop.** If right-sizing forces a cut, move the dropped requirement into a sibling issue — never omit it silently.
3. **Surface the cut for confirmation.** Name what was dropped and ask for explicit confirmation before filing.

### Soft signals (every task answers every signal)

Each task explicitly answers each signal in the plan. "No, and that's OK because X" is a valid answer. Silence is not.

| Signal | Question | Action if "no" |
|---|---|---|
| **Pattern anchor** | Is there an existing file/PR the agent can mirror? | If genuinely novel, call it out in Notes. If novel by accident, find the closest analog. **For new files specifically: the spec MUST cite an existing sibling file by exact path** (e.g., *"create `django/X/tests_pagination.py` (sibling to existing `tests_lifecycle.py`)"*), not by description (*"create a pagination test file"*). Agents do not infer file-path conventions reliably — even when a convention is obvious from a `ls` of the directory, three parallel agents will pick three different paths. When sibling issues are parallel, each must anchor to a sibling file in **its own** app surface, not in a peer issue's app. |
| **Test fixture** | Is there an analogous test the agent can copy? | If first-of-its-kind, the spec must include the full test code. |
| **Trust boundary** | Does the task cross a trust boundary (user input, external API, cross-tenant)? | If yes, boundary must be explicit in the spec — what's validated where, what's authorized where. |
| **Rollback path** | If this breaks in prod, what's the recovery? | Risky changes need a feature flag or rollback note. Mechanical changes don't. |
| **Observability** | What logs/metrics confirm it works in prod? | If the task adds behavior worth verifying, specify the signal. |
| **Parallel-safety** | Does this share file edits with another unblocked task? | If yes, one must block the other or they merge. |

### Rubric evolution

The rubric is living. After each bd-build-down, capture failure classes:
- "This task needed 4 gap-fill rounds because we didn't specify the auth pattern" → add a soft signal for **Auth pattern anchor**.
- "This task one-shotted but produced a regression because we didn't specify the existing-data assumption" → add a soft signal for **Existing-data invariants**.

When a failure class recurs across two or more bd-build-ups, promote it from "lesson learned" to a permanent rubric entry. Edit this skill — don't keep the rubric in someone's head.

---

## Environment Detection

State the environment at session start.

- **Chat (web/mobile):** the tracker MCP (see Tracker Selection), GitHub MCP, conversation memory. Lacks local FS / bash. bd-belay-on to a code-reading agent for codebase reads.
- **Code-execution (terminal):** bash, local FS, git. Lacks project memory. Use for codebase reads, plan file drafting, then hand back to chat for filing.
- **Pair pattern:** Draft the plan locally as a markdown file in `{{PLAN_DIR}}`, then attach it per the active adapter's **Doc home** section.

### Tracker Selection

Pick the active tracker at session start and load its adapter:

- Infer `{{TRACKER}}` from the connected MCP / orchestrator mapping (`linear-<workspace>` → `linear`, `atlassian-<workspace>` → `jira`). If both are present or it's ambiguous, ask once.
- Read `trackers/{{TRACKER}}.md`. Every tracker-touching step below (overlap scan, container, doc home, pickup trigger, waves, dependencies, issue creation, status check, feature-node grouping) follows that adapter's matching `## ` section.
- State the tracker in the opening declaration, e.g. *"…Tracker: Jira (epic PROJ-1234, project PROJ)."*

**Jira-style (projected — full adaptation tracked in [AII-149](https://linear.app/eudoxus/issue/AII-149/adapt-builddown-best-practice-skills-to-jira)):**
`trackers/jira.md` documents the Jira MCP binding and filing differences (Epic container, `AI-Implement-Status` field gate, `transition_issue` for state). The full skill conversion — Jira MCP wiring, verb replacement (`save_issue` → `create_issue`/`update_issue`), and container/pickup logic — is the work of AII-149; `trackers/jira.md` is the projected spec. `tracker.kind: jira` in `CLAUDE.md` is the signal that the Jira adapter is active.

**Opening declaration:** State environment, primary tools, tracker, and which mode you'll be running. Example: *"Running in chat. Tracker MCP for filing, will draft the plan to `docs/plans/` and attach to the container per the active adapter. Mode 2 (New Design)."* (Adjust tracker name per `{{TRACKER}}`; see Tracker Selection above.)

---

## Mode Detection

Same modes as `bd-build-up`. Infer from framing; ask only on conflicting signals.

- **Mode 1: Convergence** — code-prototype repo → production. User mentions a prototype path or says "converge."
- **Mode 2: New Design** — objective → issues. Default when no prototype is mentioned. *Handoff-bundle variant:* user provides a design tool's export.
- **Mode 3a: Code-Prototype Brief** — objective → markdown spec for a code-first prototype tool. Skip filing.
- **Mode 3b: Design Brief** — objective → markdown brief for a design-first tool. Skip filing.

bd-mega-build-up's grilling and detailed-plan phases apply most strongly to **Mode 2** (and Mode 1 when convergence scope is large). For Mode 3 briefs, grilling still applies — it sharpens the brief — but the plan-document phase is replaced by the brief itself.

---

## Phase 1: Orient

Understand current state before drafting anything.

- Read prototype + production codebases (Mode 1) or research the codebase for adjacent patterns (Mode 2).
- List existing projects per the active adapter's **Container** section so you know whether this bd-build-up creates a new project or attaches to an existing one.
- **Run the Backlog Overlap Scan** (below). This is not optional — there is almost always existing tracker work that overlaps, and unaddressed overlap produces duplicate issues, file conflicts, and superseded work that lingers forever.
- Ask **at most 2** clarifying questions before moving on. After that, state assumptions and proceed.

The orient phase produces a **working understanding**, not a plan. Don't draft issues yet.

### KG recon (if a KG is bound)

Before drafting the plan, consult the project's knowledge graph for prior learnings, decisions, and issues about this objective. Follow `docs/kg-recon.md`: derive queries from **the objective in the user's words + its key nouns**, call **only** `kg.search_tool` (hybrid-search), and note KG staleness. Advisory and non-blocking. If the project has no KG bound, skip silently.

### Backlog Overlap Scan

Search the tracker backlog for existing work that intersects with this bd-build-up. The goal is to surface every overlap and force a decision before any new issue gets filed.

**Search strategy:** search per the active adapter's **Overlap scan** section.

**Search defaults:** narrow to the user's team and any teams the bd-build-up obviously touches. If signals suggest cross-team overlap, expand. Better to over-search and discard than to miss a duplicate.

**Classify each hit** into one of these categories. Each category has a default action:

| Classification | Definition | Default action |
|---|---|---|
| **Duplicate** | Existing issue describes the same work | Don't re-file. Reference the existing issue ID. If stale, revive it (per the active adapter's **Wave staging** / **Pickup trigger** sections) instead of filing fresh. |
| **Subset** | Existing issue is broader; our work is a piece of it | Either fold our work into existing scope, OR split the existing issue and replace one piece with ours. |
| **Superset** | Our planned work covers what the existing issue describes | File ours. Close the existing as superseded, link to the new issue. |
| **Adjacent** | Same files/area, different intent | Risk: file conflicts when both run via the pipeline. Add `Blocked by:` to one or coordinate sequencing in the plan. |
| **Dependency** | Existing issue must complete before ours can start | Add `Blocked by: {existing-id}` to our new issue. Don't duplicate the existing work. |
| **Stale** | Existing issue is in scope but sitting in Backlog with no activity (> 60 days, no recent comments) | Decide: revive, supersede, or close as won't-do. Don't ignore. |

**No silent overlap.** Every classified hit produces a decision before Phase 2 ends. Carry the list into Phase 2 grilling — overlap decisions are explicit grill questions.

**Output:** an `Overlap Inventory` — a short list of `{existing-issue-id, title, classification, proposed action}` rows. This feeds the design doc's Overlap & Reconciliation section (Phase 2) and the filing actions (Phase 4).

---

## Phase 2: Grill

This is the senior-engineer review. Adversarial in tone, collaborative in intent. The goal is to surface every important decision and force a deliberate answer before any issues get filed.

### Grilling style

**Ask one question at a time.** Wait for the user's answer before moving on. Don't dump a question list.

**Provide your recommended answer with each question.** The user can accept it (fast) or push back (better answer). Recommendations should be opinionated, not safe-defaults.

**If a question can be answered by reading the codebase, read the codebase.** Don't ask the user what they could see for themselves. bd-belay-on to a code-reading agent if needed.

**Walk the decision tree.** Resolve dependencies between decisions. Don't ask about column types before deciding whether the table exists.

**Push back when the answer is weak.** If the user says "we'll figure that out later" on a load-bearing decision, name what depends on it and ask again. Polite, persistent, specific.

**Stop grilling when the design is decided, not when you run out of questions.** Some bd-build-ups need 3 questions, some need 15. The signal to stop is that the next question would be a detail the implementation can decide on its own.

### What to grill on

Cover at least these branches before declaring the design decided:

1. **Scope boundary.** What's in v1? What's explicitly deferred? Where's the "we could expand later" line?
2. **Data model.** New tables/columns? Migrations? Indexing? Foreign keys? Reuse vs. fresh?
3. **API surface.** New endpoints? Request/response shapes? Auth/permissions? Backwards compatibility?
4. **UI surface.** New routes? New components? Modifications to existing components? Mobile/responsive needs?
5. **Trust boundaries.** Where does user input enter? Where does it leave the system? What's validated where?
6. **Failure modes.** Empty states, error states, race conditions, partial failures. What happens when X is null / 404 / timing-out?
7. **Migration / rollout.** Feature flag? Behind auth? Backfill needed? How do we ship this without breaking existing users? **If the rollout ends in a tighter constraint (`NOT NULL`, `UNIQUE`, narrower type, new FK/CHECK): have we enumerated every writer to the affected table/column** — production code, test fixtures, factories, seed scripts, background jobs, importers, admin tooling — **and made each one satisfy the future constraint in the additive PR?** (See Hard Rule 9.) Force the writer census now; don't defer to "we'll find them when CI breaks."
8. **Testing strategy.** Unit, integration, e2e? What's the minimum bar? Where are the load-bearing tests?
9. **Observability.** What logs/metrics do we need to verify it's working in production?
10. **Out-of-scope confirmations.** "We are NOT doing X, Y, Z in this bd-build-up. Confirm?"
11. **Backlog overlap decisions.** For each hit in the Overlap Inventory, walk through the classification and confirm the action. "Issue ABC-123 is a Subset — fold ours in, or split theirs?" Don't let stale Backlog issues haunt the bd-build-up.

You don't need all 10 every time. You do need to walk the tree and stop at "we have enough to write a plan that won't surprise us."

### Adversarial principles

- **Be specific.** "How does this handle concurrent edits?" beats "Have you thought about edge cases?"
- **Name the failure.** "If two users hit submit simultaneously, the current design double-charges. Are we OK with that, or do we need an idempotency key?"
- **Refuse to be deflected.** "Good question, we'll handle it later" is not an answer to a load-bearing question. Push back: "It changes whether Issue 4 is one issue or three. Let's decide now."
- **Acknowledge good answers.** When the user has clearly thought about something, log it and move on. Don't grill for grilling's sake.
- **Be the senior engineer the user wants on the review, not the one they avoid.** Sharp, not exhausting.

### Output of Phase 2

A short **Design Decisions** doc capturing what was decided. This becomes one of the two documents attached to the tracker container. Format:

```markdown
# {Build-Up Name} — Design Decisions

## Objective
One-paragraph statement of what this bd-build-up achieves.

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

## Overlap & Reconciliation
For each overlapping existing tracker issue:
- **{ISSUE-ID} {title}** — Classification: {Duplicate | Subset | Superset | Adjacent | Dependency | Stale}. Action: {revive | fold in | supersede | block-by | close | ignore-with-rationale}.

If "ignore-with-rationale," state the rationale. Silence is not a valid entry.

## Open Questions
Anything genuinely undecided, with the proposed default if not answered.
```

Save to `{{PLAN_DIR}}/{date}-{slug}-design.md`.

**Approval gate 1:** Present the Design Decisions doc. Get explicit approval ("looks good," "go," "ship it") before moving to Phase 3. Questions or partial feedback = revise and present again.

---

## Phase 3: Draft the Implementation Plan

This is the writing-plans-style detailed plan: file paths, bite-sized steps, no placeholders. The plan is a document attached to the tracker container, **and** the source material for the issue breakdown in Phase 4.

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

> **For AI-Implement:** Each task below maps to a tracker issue (Phase 4). Steps use checkbox syntax for tracking. The pipeline picks up each issue independently — task descriptions must be self-contained.

**Goal:** One sentence.

**Architecture:** 2-3 sentences on approach.

**Tech Stack:** Key libraries/frameworks.

**Tracker Container:** {project/epic name + URL once filed}

---
```

### Task structure

Each task = one parallelizable unit of work = one tracker issue.

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
- **Feature-node trees (both trackers).** Children of a feature node each PR into the *same* feature branch on isolated child branches, so they don't collide on base — they're **more** parallel-safe, not less (normal file-overlap rules still apply *within* the feature branch). Mark the parent's closing-work task `Blocked by:` every child. **Build the whole tree before any designation goes on, then designate the parent BEFORE the children** — a designated parent with no children yet is classified as a leaf and dispatched standalone (observed failure), so the complete tree (children + parent relationships + every `blocks`/`Blocks` relation) must exist first; and a child designated while its parent is undesignated resolves an empty ancestor chain and cuts its PR from the repo base branch, silently bypassing grouping — so parent first, then children. The race guard makes parent-first safe: a designated parent whose children exist but carry no designation is a *waiting parent* and is skipped until its children release. "Designate" is tracker-specific (Linear label vs Jira `AI-Implement-Status` + Repo) — see the active adapter's **Feature-node grouping** section and `docs/feature-branch-grouping.md`.
- **Multi-issue mode.** To group *otherwise-unrelated* issues as one reviewable unit, add a **fenced** `# ai-implement.yml` block (`feature_branch.mode: "multi-issue"`; unfenced = ignored) to the **parent's description** → its branch becomes `ai-implement/multi-issue/<key>` instead of `ai-implement/feature/<key>`, **identical in every other respect**. Default (label / no block) is feature-node. Write examples as `# ai-implement.yml (example)` — a bare marker line is stripped from the issue's own spec. See `docs/feature-branch-grouping.md`.

### Self-review

After writing the plan, check it against the Phase 2 design doc with fresh eyes:

1. **Decision coverage.** Every decision in the design doc is implemented by at least one task. Gaps?
2. **Placeholder scan.** Search for the failure patterns above. Fix them.
3. **Type/name consistency.** A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug. Same for column names, route paths, component names.
4. **Parallelization audit — mandatory output for grouped siblings (BDS-33).** Which tasks claim
   `Parallel-safe with:` X — do they really not touch the same files? For every grouped tree,
   produce the **cross-sibling file-intersection result explicitly** (never silence):
   - **Parse each sibling's declared files with the dispatch guard's own contract** — the
     `- Create/Modify/Test/Delete:` bullet lines under a `## Files` heading. **A sibling that
     parses to 0 files FAILS the audit** until its body carries the canonical `## Files` block
     (the orchestrator's fail-open guard is blind to it otherwise — proven on AII-264's own
     tree, where prose-declared files parsed to zero and the guard would have silently
     fail-opened).
   - **Any pairwise intersection ⇒ chain the overlapping siblings with `Blocked by:`**
     (serialize the hotspot) or re-split task boundaries. State the verdict per pair
     (`A ∩ B = ∅` or the shared paths).
   Sequencing beyond serialization belongs to bd-summit-push (BDS-16) — reference it, don't
   duplicate it.

Fix issues inline. No need to re-review — just fix and move on.

Save to `{{PLAN_DIR}}/{date}-{slug}-plan.md`.

**Approval gate 2:** Present the plan. Get explicit approval before moving to Phase 4.

---

## Phase 4: Container + Documents + Issues

### Step 1: Resolve the container

Follow the active adapter's **Container** section.

### Step 2: Attach design + plan documents

Attach both docs per the active adapter's **Doc home** section.

### Step 3: Generate issues from plan tasks

**One task = one issue.** This is the parallel-subagent-style decomposition.

For each task in the plan, build an issue body that the AI-Implement pipeline can run cold:

```
## Problem / Context

{Why this issue exists. Link to the container for full design context.}

## Task

{Direct from the plan task. Files to create/modify, with exact paths.}

Reference design context: {issue container URL — see the active adapter's **Issue URL** section}

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

### Step 3.5: Execute overlap reconciliation actions

Before filing new issues, work through the design doc's Overlap & Reconciliation section. Using the active adapter's **Wave staging** / **Pickup trigger** mechanics, take the committed action for each entry:

- **Revive (Duplicate, stale):** move the existing issue to the active state, apply the pipeline label, attach to this bd-build-up's container, comment with a link to the design doc.
- **Fold in (Subset):** comment on the existing issue noting it's been absorbed into the new scope; close it once the corresponding new issue is filed and link them.
- **Split (Subset, opposite direction):** edit the existing issue to narrow its scope; file the remaining piece(s) as part of this bd-build-up.
- **Supersede (Superset):** after filing the new issue, close the existing one with a comment linking to the superseder.
- **Block-by (Adjacent or Dependency):** add `Blocked by: {existing-id}` to the new issue's body before filing.
- **Close (Stale, won't-do):** close with a comment explaining the decision and linking to the bd-build-up's container for context.

These actions are not optional cleanup — they are part of filing the bd-build-up. Skip them and the backlog accumulates ghost issues that conflict with active work.

### Step 4: Wave staging — file the issues

Wave 1 / Wave 2+ / architect routing per the active adapter's **Pickup trigger**, **Wave staging**, and **Architect routing** sections.

File in dependency order so `Blocked by:` references resolve to real issue IDs.

#### Pilot-first sequencing for repeated patterns

**Trigger:** the wave contains **≥ 3 issues applying the same task template to different surfaces** (e.g., "enable pagination on `/employees/`", "…on `/assignments/`", "…on `/calculations/`"; or "convert app X serializers to explicit fields", same for app Y, app Z).

When the trigger fires, **file them all** but release only the **first** for pickup (per the active adapter's **Pickup trigger** section). The rest stay parked (per the active adapter's **Wave staging** section) until the pilot lands. Pick the pilot to be the one whose surface is smallest or best-understood — it sets the pattern.

Then in bd-build-down, after the pilot's PR lands:

1. Inspect the PR for unspecified-but-load-bearing details the agent had to invent — file paths, naming, edge cases, peripheral updates (MCP sync, type exports, mock fixtures) the spec didn't enumerate.
2. Update the remaining N-1 issue bodies to **inline whatever the pilot got right** (and correct whatever it got wrong). The earlier issues' "Pattern anchor" should now point at the freshly-merged PR.
3. **Then** release the rest for pickup in parallel (per the active adapter's **Pickup trigger** section).

**Cost:** one extra bd-build-down checkpoint (a few minutes after the pilot merges). **Benefit:** N-1 issues land cleanly the first time instead of N issues hitting the same systemic miss in parallel and producing N PRs to gap-fill.

**When NOT to apply pilot-first:** the wave contains ≤ 2 same-pattern siblings (parallel-safety rules already cover that), or the issues only superficially resemble each other (different app, different shape, different decisions — no reusable pattern). The trigger is *same task template*, not *same project area*.

**Approval gate 3:** Present the issue manifest before filing — don't file then ask. Issue manifest format:

```
| # | Title | Shape | Migration? | Wave | Labels | Blocked by | Parallel-safe with | Files overlap | Routing |
```

**Files overlap** carries the Phase 3 intersection verdict per issue (`∅`, or `sibling-key: paths`
with the `Blocked by:` that resolves it; `UNPARSEABLE` = the audit failed — fix the `## Files`
block before filing). Confirm wave assignments and routing. After explicit approval, file per the active adapter's **Required create fields** section.

### Step 5: Post-filing manifest

After all issues are filed, present:

- Container URL (project/epic — per the active adapter's **Container** section)
- Document URLs (design + plan — per the active adapter's **Doc home** section)
- Issue manifest with real issue IDs
- Wave 1 issues (currently being picked up by the pipeline)
- Critical-path summary: longest dependency chain, so the user sees minimum time-to-complete

### Step 6: Post the build-up learnings comment (required capstone)

The build-up is not done until the learnings comment is posted. On the project/epic parent (or umbrella issue), post a `# ai-implement-build-up-learnings` comment — **one canonical comment per issue, edited in place**, distilled to the load-bearing *why* a future reader would be surprised by (not a second copy of the plan). The marker is an exact-match first line; never reuse `# ai-implement.yml` (opposite semantics — orchestrator config, stripped from the spec). Works identically on Linear (`save_comment`) and Jira (`addComment`). Full convention: `docs/learnings-comments.md`.

**Provenance:** self-report the harness + model you planned under (e.g. `Claude Code · Opus 4.8`). If you cannot determine the model, ask the operator once — never guess or silently omit.

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

---

## Status Check Mode

Same as `bd-build-up` status check. Match the user's reference to the active container per the active adapter's **Container** section, list issues grouped by state, surface blockers, identify bd-build-down readiness (issues in In Review or with open PRs).

If the user asks "where's the design for X?" or "what was the plan for X?" — fetch the project documents per the active adapter's **Doc home** section and surface them, don't reconstruct from issue bodies.

---

## Conventions

**Dependency phrasing:** Always `Blocked by: {ISSUE-ID} (reason)`. Not "Depends on," not "Requires." One phrase, one pattern (mechanism is per-adapter — see **Dependencies**).

**Sizing:** see Issue Design Rubric. (Skill archaeology note: earlier versions used a 1/2/3/5/8 story-point scale inherited from `bd-build-up`. It was dropped because abstract sizing didn't capture codebase friction.)

**Plan file naming:** `{{PLAN_DIR}}/{YYYY-MM-DD}-{slug}-design.md` and `-plan.md`. Same date prefix so they sort together.

**Design/plan docs are working artifacts, not repo content.** They exist to drive the grilling and to produce the Step 6 build-up learnings comment (and, where a tracker container exists, its attached documents). **Do not commit them to the code repo by default** — keep them local, or attach to the tracker container per the active adapter's **Doc home** section. The distilled `# ai-implement-build-up-learnings` comment is the durable index; commit to the repo only the canonical reference docs a change actually ships (e.g. a `docs/*.md` the skills point to).

---

## Key Principles

1. **Three approval gates: design, plan, issues.** Don't skip one to save time.
2. **Grill one question at a time, with a recommended answer.** Walk the decision tree. Stop when the next question would be implementation detail.
3. **The plan is a document, not a comment thread.** It lives as a tracker container document so it survives the bd-build-up session.
4. **One task = one issue.** Plan tasks are sized for parallel pipeline execution. Issue bodies are self-contained because the pipeline reads them cold.
5. **Backend before frontend, always.** Schema → API → UI. Never combined.
6. **Wave 1 to the pickup-ready state per the active adapter. Get the agents going.** bd-build-up's job is to launch work, not park it.
7. **Mega vs. plain bd-build-up is a choice about rigor, not a default.** Use plain `bd-build-up` for small, well-trodden scope. Use this when the design needs pressure-testing or the plan needs to live as documentation.

---

## Red Flags — Stop and Restart the Phase

- **Filed issues without all three approvals.** → Close the un-approved issues. Restart from the gate you skipped.
- **Plan has TODOs / TBDs / "handle edge cases".** → Plan failure. Fix before filing.
- **Two tasks edit the same file but are marked parallel-safe.** → Parallel-safety bug. One must block the other or they merge.
- **Schema and UI in one task.** → Backend-before-frontend violation. Split.
- **A task is wide AND deep.** → Shape rule violation. Split into a deep core + a wide propagation that's blocked by it.
- **Spec contains a per-touch decision rule whose inputs aren't in the spec** (e.g., *"for each viewset, decide whether to paginate based on what the FE expects"*, but the FE audit is in a different deferred task). → Hard-rule-8 violation: the task is wide-and-deep in disguise. Fix: either inline the decision heuristic so each touch is mechanical (often by *preserving* current behavior across the board and deferring the real decisions to per-surface follow-ups), or split into one deep-and-targeted task per surface.
- **New-file path specified only by description** (e.g., *"create a pagination test file"* with no exact sibling path cited). → Pattern-anchor violation. Three agents will produce three different paths; one of them will likely collide with an existing module. Cite an exact sibling file by full path.
- **≥ 3 same-pattern sibling issues filed all with `AI-Implement` at once.** → You're betting the spec is complete enough that three cold agents converge. They usually don't, and the failure mode is N parallel PRs all making the same omission (MCP sync, file-path convention, peripheral consumer) at once. Demote all but one to no-label, run the pilot, learn from its PR, then re-label the rest. (See Phase 4 → Pilot-first sequencing.)
- **Migration or backfill is bundled with code that consumes it.** → Hard rule violation. Migration/backfill becomes its own task; consumer becomes a downstream task with `Blocked by:`.
- **Feature-node tree designated out of order.** → Two designation races, both observed: a parent designated before its children *exist* is classified as a leaf and dispatches standalone; a child designated before its *parent* resolves an empty ancestor chain and PRs against the repo base branch, bypassing grouping. Build the whole tree first (children + every relation), then designate the parent, then the children (Phase 3 → parallel-execution awareness). Designation = Linear label / Jira `AI-Implement-Status` + Repo (active adapter's **Feature-node grouping** section).
- **Schema-tightening plan with no writer census.** → Hard Rule 9 violation. The cleanup PR will detonate against unmigrated writers (REST endpoints, background jobs, importers, test fixtures, factories, seed scripts) and surface only as CI failures on the destructive PR. Run the writer census in Phase 2 — across whatever ORM / query builder / raw SQL / fixture conventions the stack uses — and embed each writer as an explicit task (or task line item) in the additive PR's plan. Cleanup-phase preflight is "census is empty + CI on a throwaway-with-constraint branch is green," not "`SELECT COUNT(*) WHERE col IS NULL` returned zero."
- **Atlas (or other declarative-schema) project, and the task is "rename column X to Y".** → Refuse to file as AI-Implement. Recommend manual scripted cutover (add → backfill → cut over reads → cut over writes → drop). Override only if user confirms a single-phase task.
- **Phase 1 produced no Overlap Inventory.** → Backlog scan was skipped or too narrow. Re-run with broader keywords. Mature backlogs always have hits.
- **Overlap Inventory entry has no committed action.** → Silent overlap. Force a decision in Phase 2 grilling before approving the design.
- **Issue body says "see design doc" without inlining the spec.** → Pipeline can't read links. Inline the spec.
- **Grilling skipped because "the user seemed sure".** → bd-mega-build-up exists for the grill. If skipping was right, plain `bd-build-up` was the right skill.
- **Issues filed but no `# ai-implement-build-up-learnings` comment posted.** → The compounding trace is the capstone of Phase 4, not an optional extra. Post it on the parent (Step 6) before declaring the build-up done.
- **Wide-and-shallow issue with >~12–15 files filed without checking the turn budget.** → File count is the tell for runner cap risk. Either split (deep core + wide propagation blocked by it) or raise the project's Max Turns before dispatch and note it on the issue. Don't discover the ceiling when a run dies at it and pushes nothing.
- **Reshape of an existing detailed issue with no diff against the original.** → Reshape-without-diff risks silently dropping a substantive acceptance item. Diff the reshaped version against the original; split-not-drop any item that was cut; surface the cut for user confirmation before filing.

---

## Relationship to Other Skills

- **`bd-build-up`** — lighter version. Same destination (Linear + AI-Implement), no grilling phase, no plan document, issue bodies are written at filing time rather than derived from a plan.
- **`bd-build-down`** — the next session. Drives filed issues to merge. Promotes Backlog issues to Todo as blockers merge.
- **`bd-super-build-down`** — autonomous bd-build-down. bd-mega-build-ups produce well-specified issues, which is the input bd-super-build-down needs.
- **`bd-belay-on`** — use for environment hops. Chat→code-reading agent during Phase 1 codebase reads. Code-execution→chat for filing.
- **`bd-smoke-jumper`** — use during bd-build-down to validate PRs against the design decisions doc.
