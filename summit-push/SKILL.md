---
name: summit-push
description: "Strategic assault planning for a milestone push. Trigger this skill when the user says 'summit-push', 'summit push', 'strategic push', 'optimize the push', 'plan the assault', 'what order should we send these', or asks to evaluate a build-up plan before filing or sending issues to the AI coding agent. A summit-push sits between build-up (planning) and build-down (landing) — it takes a set of planned or filed issues and optimizes their sequencing, dependency graph, and issue body quality for maximum one-shot success rate through the AI coding agent pipeline. It also runs pre-flight checks during build-down to anticipate architectural blindspots before merging. Use this skill when the user wants to be strategic rather than spray-and-pray with the agent pipeline, or wants to de-risk a merge sequence."
---

# Summit-Push Skill

Summit-push is the strategic layer between build-up and build-down. Build-up creates the work. Build-down lands it. Summit-push makes both smarter.

**The metaphor:** You don't summit Everest by running at it. You stage camps, acclimatize, pick weather windows, send the right climbers in the right order. Summit-push does the same for AI-coding-agent batches — evaluates what's planned, optimizes the attack order, hardens issue descriptions for one-shot success, and during build-down, anticipates architectural blindspots that cause PRs to fail or need rework.

**Two modes:**

1. **Pre-push (before filing or before the agent picks up work)** — evaluate a build-up plan or a set of filed-but-not-started issues. Optimize sequencing, harden issue bodies, identify one-shot killers, produce a push manifest.

2. **Mid-push (standalone risk scan)** — evaluate open PRs and queued issues for architectural risk. Anticipate merge conflicts, migration collisions, convention violations. Usually invoked automatically from super-build-down; can be run standalone when the user wants a risk scan without being in a build-down session.

---

## Configuration

- `{{TRACKER}}` — the issue tracker (Linear, Jira, GitHub Issues)
- `{{REPO}}` — the GitHub repo, owner/name format
- `{{IMPLEMENT_LABEL}}` — label that triggers the AI coding agent pipeline
- `{{ARCHITECT_NAME}}` — the human who owns risky changes (migrations, auth, infra). Optional.
- `{{BUILD_CMD}}` — verification command for typed code
- The skill assumes a Blindspot Table (below) populated with the project's known failure modes. Update it as the codebase evolves.

---

## Environment and Pipeline Context

### Environment detection

Same as build-up and build-down.

**Chat (primary for summit-push):**
- Has: tracker MCP, GitHub MCP, project context, conversation memory
- Use for: plan evaluation, issue body hardening, manifest generation, risk reporting
- Blast radius analysis relies on project knowledge and issue descriptions — slightly more conservative confidence scores than in code-execution

**Code-execution:**
- Has: bash, local filesystem, git — can verify blast radius against actual code
- Use when: deep convention checks are needed, file overlap must be verified against real repo state
- Higher confidence scores justified when verified against code

**Code-reading agent:**
- Useful for: cross-file pattern verification when an issue references patterns that need to be confirmed
- Return findings to chat for manifest generation

**Opening declaration:** State the environment, the input (plan vs. filed issues vs. open PRs), and the mode (pre-push vs. mid-push).

### Relationship to other skills

- **Build-up → summit-push → build-up:** Build-up drafts a plan, summit-push hardens it, build-up files the hardened version. Invoked when the plan has 5+ issues with dependencies, or the user says "summit-push this."
- **Super-build-down invokes Mode 2 automatically** for 5+ open PRs — don't duplicate its work, consume the scan output instead.
- **Build-down's own Phase 2h** does merge-sequencing for smaller PR counts. Summit-push Mode 2 is not needed for routine build-downs.

---

## When to Use This Skill

**Pre-push triggers:**
- Build-up plan drafted, the user wants to review before filing
- Issues filed but not yet picked up (still in Backlog, or in Todo but pipeline hasn't started)
- The user is about to promote a batch from Backlog → Todo and wants to be strategic about order
- The user wants to evaluate whether a set of issues can realistically land in a single cycle

**Mid-push triggers:**
- Multiple PRs open and the user wants proactive merge-order planning without running a full build-down
- Rework patterns appearing (PRs failing CI, inventing endpoints, missing conventions) and the user wants root-cause diagnosis
- The user wants to evaluate whether remaining queued issues are safe to send given what's already in flight

**Required tools:**
- **Tracker MCP** — for reading issue state, dependencies, descriptions
- **GitHub MCP** — required for Mode 2 (reading open PR state)
- **Project knowledge** — codebase conventions, known failure modes

---

## Mode 1: Pre-Push (Plan Optimization)

### Phase 1: Ingest the Plan

Accept input in any of these forms:

- A build-up plan presented in the current conversation
- A set of tracker issue IDs to evaluate (`get_issue` on each)
- A project or milestone filter ("evaluate everything in the X project that's in Backlog or Todo")
- A raw list of objectives to be decomposed — in this case, run build-up first, then summit-push the result

For each issue, capture: title, description/body, labels, dependencies (`blockedBy`), estimate, routing (assignee or `{{IMPLEMENT_LABEL}}`).

### Phase 2: Dependency Graph Analysis

Build the full dependency graph and evaluate it.

**2a. Critical path identification**
- Longest dependency chain = minimum time-to-complete
- Bottlenecks: single issues blocking 3+ downstream — highest-priority, need the best issue descriptions
- Independent tracks that can run in parallel — group them

**2b. Dependency correctness**

Check for three failure modes:

- **Circular dependencies** — fatal, must fix before filing
- **Missing dependencies** — common patterns:
  - Frontend issue doesn't depend on the API route it consumes
  - API route doesn't depend on the migration that creates its table/columns
  - Two issues both add migrations but aren't sequenced
- **Over-specified dependencies** — issues marked blocked that could actually run in parallel. Reduces throughput.

**2c. Migration sequencing**

- Identify all issues touching the database schema or adding SQL migrations
- Check the project's migration policy: are migrations auto-applied on deploy, or manually applied by the architect?
- Verify the plan's dependency graph enforces correct migration ordering
- Flag any case where two "independent" issues both modify the same tables — they are not independent

**2d. Blast radius analysis**

For each issue, estimate which files it will touch based on description and codebase knowledge.

- Identify file overlap between issues — these will conflict if running in parallel
- Flag high-overlap pairs explicitly: "Issues {ID-X} and {ID-Y} both modify `{path}` — serialize them or expect conflict resolution"

In chat: blast radius is an estimate from description + project knowledge. In code-execution: verify against actual repo state. State confidence accordingly.

### Phase 3: One-Shot Quality Audit

Evaluate each issue description for one-shot success likelihood through the AI coding agent.

**3a. Failure-mode checklist**

Cross-reference every issue against the full Blindspot Table (see Conventions below) and this checklist:

| Failure Mode | What to Look For | Fix |
|---|---|---|
| **API route invention** | Issue says "create an API for X" without specifying the exact path | Add explicit file path, handler function, HTTP method |
| **Missing codebase context** | Describes what to build but not where it fits | Add "Files to modify" and "Existing patterns to follow" sections |
| **Ambiguous acceptance criteria** | Criteria subjective ("should work well") or untestable | Rewrite as specific verifiable checks with `{{BUILD_CMD}}` |
| **Migration without schema context** | "Add a field" without table, column type, or SQL | Add exact SQL migration, reference existing schema source of truth |
| **Frontend without API contract** | UI issue doesn't specify the query or response shape | Add exact query or endpoint path and response shape |
| **Security/RLS gap** | Touches tenant-scoped tables without mentioning row-level security | Add security context note; route policy changes to the architect |
| **Too large** | Touches 5+ files across multiple concerns | Split into smaller issues with clear boundaries |
| **Missing test requirements** | No verification specified | Add `{{BUILD_CMD}}` passes + specific UI/API verification |
| **Mock data confusion** | Criteria imply real data is available when only mock data exists | Note "empty state acceptable" or specify data wiring |
| **Storage bypass** | File upload issue without referencing the project's blob/file storage convention | Specify the storage layer explicitly |

**3b. Issue body hardening**

For issues that fail the checklist, draft improved descriptions using this standard:

```
## Problem / Context

Current state, why this issue exists, what it enables.
File paths and component names for context.
Existing patterns to follow (link to similar code).

## Task

Specifics:
- Exact files to create or modify (paths in the codebase)
- API routes: exact path, HTTP method, request/response shape
- Database: exact table, columns, query pattern
- UI: component path, props interface, parent page integration

Reference prototype when applicable:
Design reference: code-prototype at `/app/path`
OR
Design reference: design project "{name}" — screen "{screen}"

## Acceptance Criteria

- [ ] Specific, testable checks
- [ ] `{{BUILD_CMD}}` passes (if typed code touched)
- [ ] UI renders correctly at specified route

## Codebase References

- "Follow the pattern in {file}:{component}"
- "Wire to existing query at {path}"

## What NOT to Do

(Populate from the Blindspot Table — pick the 2-4 most relevant for this issue's type)
- Do not create new route trees outside existing structure
- Do not bypass row-level security — all queries must respect tenant scoping
- Do not create direct file upload endpoints — use the canonical storage layer

## Dependencies

Blocked by: {ISSUE-ID} (brief reason)

## Notes

Edge cases, known gotchas, decisions made during planning.
```

**3c. One-shot confidence scoring**

Rate each issue 1–5 using concrete criteria:

- **5 — Lock:**
  - Touches 1-2 files with explicit paths
  - References an existing pattern in the codebase by name/path
  - Acceptance criteria are fully objective and runnable
  - No migrations, no security implications, no schema changes
  - → Expect to one-shot

- **4 — Strong:**
  - Touches ≤5 files with explicit paths
  - References existing patterns OR has very clear task description
  - Acceptance criteria mostly objective
  - If migrations present, they're clearly scoped
  - → 80%+ one-shot rate

- **3 — Coin flip:**
  - Reasonable description but missing codebase context
  - OR touches multiple files without explicit paths
  - OR acceptance criteria have subjective elements
  - → 50/50 — expect agent follow-ups

- **2 — Risky:**
  - Ambiguous scope or unclear fit
  - Requires architectural decisions during implementation
  - Touches auth/security without explicit routing to the architect
  - → Will likely need agent comments or rework

- **1 — Send back:**
  - Too large (6+ files or multi-concern)
  - Too vague (no specific paths or patterns)
  - Hits a known failure mode from the blindspot table
  - → Needs rewrite before the agent picks it up

**Target: every issue ships at 4 or 5. Anything below gets hardened in Phase 3b or split.**

### Phase 4: Push Manifest

Produce the final output:

```
# Summit Push Manifest: {name}
Generated: {date}
Scope: {N} issues, {points} story points, {tracks} parallel tracks

## Push Order

**Wave 1 (no dependencies — send immediately):**
- {ISSUE-ID}: {title} — Confidence: {score}/5 — Track: {track}

**Wave 2 (depends on Wave 1):**
- {ISSUE-ID}: {title} — Confidence: {score}/5 — Blocked by: {deps}

(continue for Wave 3+)

## Parallel Tracks

- Track A: {description} — Issues: {list} — No overlap
- Track B: {description} — Issues: {list} — ⚠️ Overlaps with Track A on {files}

## Migration Sequence

{Ordered list of issues with SQL migrations — the architect must apply these (or auto-applied per project policy)}

## High-Risk Items

{Issues with confidence < 4, with specific concerns}

## Blast Radius Map

{Which issues overlap on which files}

## Estimated Timeline

Pipeline turnaround varies by queue depth and issue complexity — from minutes to a few hours per issue. Use actual recent performance as the calibration, not a fixed estimate. Flag the critical path length in issue count rather than hours.

- Wave 1 issue count: {N}
- Critical path length: {N issues} (minimum waves to complete)
- Full push issue count: {N}
```

### Phase 5: Apply Changes

After the user approves the manifest:

**If pre-filing (build-up hasn't filed yet):**
- Update the in-session plan with hardened descriptions and optimized sequencing
- Hand back to build-up Phase 3 for filing (with the build-up default: Wave 1 → Todo + `{{IMPLEMENT_LABEL}}`, Wave 2+ → Backlog)

**If post-filing (issues already in tracker):**
- Update issue descriptions in the tracker via `save_issue` with hardened versions
- Only update the `description` field — preserve existing labels, state, assignee, estimate
- If Wave 1 issues are currently in Backlog and should now move → promote to Todo
- Do NOT promote Wave 2+ to Todo yet — let Wave 1 land first to reveal conflicts and inform sequencing

---

## Mode 2: Mid-Push (Risk Scan)

This mode is usually invoked automatically from super-build-down for 5+ open PRs. Run standalone when the user wants a risk scan without being in a build-down session.

### Phase 1: Current State Assessment

Pull state of everything in flight:

- **Open PRs** via GitHub MCP (`list_pull_requests`, `get_pull_request`, `get_pull_request_status`, `get_pull_request_files`)
- **Issues in `In Progress`** or agent-working state via tracker MCP
- **Issues in `Todo`** with `{{IMPLEMENT_LABEL}}` (queued but not yet picked up)

### Phase 2: Architectural Risk Scan

**2a. Convention compliance prediction**

For queued issues, based on the description and files they'll likely touch:

- Will the agent follow the project's framework conventions? Does the issue reference specific paths in existing structure, or is it vague enough that the agent might invent new route trees?
- Does the issue specify security/RLS context for tenant-scoped work?
- Does the issue specify the canonical storage layer for file uploads?

Flag issues likely to hit blindspots before they're picked up.

**2b. Merge conflict prediction**

Given open PRs:

- Which pairs will conflict when one merges? Use `get_pull_request_files` to compare changed paths
- Pre-draft agent conflict resolution comments for predicted conflicts
- Prioritize: which PR should merge first to minimize total conflict resolution work?

**2c. Migration collision detection**

- Are multiple open PRs adding SQL migrations?
- Which should merge first? (Simpler/additive before destructive, typically)
- Pre-draft the `git merge main` agent comment for the second PR

**2d. Dependency gap detection**

- Any in-progress issue working on something that depends on an unmerged PR?
- Any queued issue about to be picked up by the agent before its dependency lands? (Should be held in Backlog until the blocker merges.)

**2e. Codebase drift detection**

- PRs modifying the same area — later PRs may be working against a stale view of main
- Flag any PR open for >3 days — increasingly likely to need rebase

### Phase 3: Risk Report

```
# Mid-Push Risk Report
As of: {date/time}

## Immediate Actions Needed

(Things that should be done now, in priority order. "Immediate" means: an action that, if delayed, will cause rework or damage. Examples: a queued Todo issue that should be held because its blocker isn't merged; a merge order that must be enforced today to avoid conflicts compounding.)

## Predicted Conflicts

| PR A | PR B | Conflicting Files | Recommended Order | Resolution Draft Ready? |

## Migration Risks

(Migration ordering issues across open PRs — flag for the architect, with raw SQL)

## Convention Risks

(PRs or queued issues likely to hit failure modes from the Blindspot Table)

## Safe to Send Next

(Queued issues with no dependency or conflict risk — ready for agent pickup)

## Hold

(Queued issues that should NOT be promoted to Todo yet, with reason)
```

---

## Conventions

### Blindspot Table (project-specific — populate per repo)

This table captures known failure modes the AI coding agent has hit on this codebase. Update as new patterns emerge. Sample entries — replace with the project's actual blindspots:

| Pattern Category | Description | Detection | Prevention |
|---|---|---|---|
| **API route invention** | Agent creates new route paths instead of using existing structure | Issue says "create an API for X" without exact path | Specify exact file path |
| **Security/RLS bypass** | Issues touching tenant-scoped tables without security context | Issue modifies tables with `tenant_id` (or equivalent) without mentioning RLS | Route security changes to the architect; include RLS note in issue body |
| **Storage layer bypass** | File upload issues where direct upload endpoints get created | File upload issue without canonical storage reference | Specify the storage layer explicitly |
| **Migration ordering** | Two issues adding SQL migrations filed without serialization | Two issues both add `.sql` files to migrations dir | Serialize same-schema migrations; document dependency in issue body |
| **Mock data confusion** | Agent tries to fix "empty state" display when it's a data gap | Acceptance criteria imply data should be present when only mocks exist | Note "empty state is acceptable — mock data not required" when appropriate |
| **Convention drift** | Frontend patterns deviate from existing component library usage | Issue describes UI without referencing existing component patterns | Reference existing component by name/path |
| **Auth config drift** | Changes to auth flow without routing to the architect | Issue touches auth provider, middleware, or session handling | Route to the architect; do not label `{{IMPLEMENT_LABEL}}` |

### Confidence scoring calibration

When scoring issues 1-5, anchor on concrete properties:

- File count (1-2 = 5, ≤5 = 4, multiple without paths = 3, 6+ = 2)
- Path specificity (exact paths = 5, named patterns = 4, vague = 3, missing = 2 or 1)
- Acceptance criteria (testable + `{{BUILD_CMD}}` = 5, mostly objective = 4, subjective elements = 3, untestable = 2)
- Codebase references (explicit = 5, implicit via pattern naming = 4, missing = 3)
- Risk factors (none = +0, migration present = -1 unless crisp, security/auth = -1 unless routed to the architect)

Two scorers using this rubric should land within 1 point of each other on the same issue. If they don't, the rubric failed and the issue description is probably the problem.

### Tracker MCP patterns (Linear-style)

- `save_issue` for create/update, label arrays replace (always pass full list)
- When hardening an issue description, update ONLY the `description` field — preserve labels, state, assignee, estimate
- `blockedBy` arrays are informational (don't block automation but do drive summit-push's dependency analysis)
- `relatedTo` accepts arrays of issue ID strings

### Filing states (aligned with build-up)

- Wave 1 (no dependencies) → `state: Todo` with `{{IMPLEMENT_LABEL}}` — triggers pipeline pickup
- Wave 2+ (waiting on blockers) → `state: Backlog` — promote as blockers merge
- Architect-routed → `state: Todo`, assigned to architect, no `{{IMPLEMENT_LABEL}}`
- Exception: user explicitly says "stage only, don't start" → all → Backlog

Summit-push respects these defaults when applying changes. Do not move issues to Todo that should be waiting.

---

## Key Principles

1. **Summit-push is strategic, not mechanical.** The manifest is an analytical artifact — the user reviews it and decides. Summit-push does not file or promote without the user's approval.
2. **Target 4 or 5 on every issue.** Anything below gets hardened or split before the agent sees it.
3. **Migrations serialize.** Two migrations touching the same tables are not independent — flag and sequence.
4. **Wave 1 sends, Wave 2+ waits.** Mirror build-up's default.
5. **Cross-reference the blindspot table.** Phase 3 auditing isn't complete without it.
6. **Pipeline timing is measured, not assumed.** Use recent actual performance, not fixed hours-per-issue estimates.
7. **Mode 2 is automatic inside super-build-down.** Standalone invocation only when the user wants a risk scan outside a build-down.
