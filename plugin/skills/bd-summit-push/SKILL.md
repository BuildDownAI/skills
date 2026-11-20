---
name: bd-summit-push
description: "Strategic assault planning for a milestone push. Trigger this skill when the user says 'bd-summit-push', 'summit push', 'strategic push', 'optimize the push', 'plan the assault', 'what order should we send these', or asks to evaluate a bd-build-up plan before filing or sending issues to the AI coding agent. A bd-summit-push sits between bd-build-up (planning) and bd-build-down (landing) — it takes a set of planned or filed issues and optimizes their sequencing, dependency graph, and issue body quality for maximum one-shot success rate through the AI coding agent pipeline. It also runs pre-flight checks during bd-build-down to anticipate architectural blindspots before merging. Use this skill when the user wants to be strategic rather than spray-and-pray with the agent pipeline, or wants to de-risk a merge sequence."
metadata:
  suite: builddown
  client: any
  requires: [tracker]
---

# Summit-Push Skill

bd-summit-push is the strategic layer between bd-build-up and bd-build-down. bd-build-up creates the work. bd-build-down lands it. bd-summit-push makes both smarter.

**The metaphor:** You don't summit Everest by running at it. You stage camps, acclimatize, pick weather windows, send the right climbers in the right order. bd-summit-push does the same for AI-coding-agent batches — evaluates what's planned, optimizes the attack order, hardens issue descriptions for one-shot success, and during bd-build-down, anticipates architectural blindspots that cause PRs to fail or need rework.

**Two modes:**

1. **Pre-push (before filing or before the agent picks up work)** — evaluate a bd-build-up plan or a set of filed-but-not-started issues. Optimize sequencing, harden issue bodies, identify one-shot killers, produce a push manifest.

2. **Mid-push (standalone risk scan)** — evaluate open PRs and queued issues for architectural risk. Anticipate merge conflicts, migration collisions, convention violations. Usually invoked automatically from bd-super-build-down; can be run standalone when the user wants a risk scan without being in a bd-build-down session.

---

## Configuration

- `{{TRACKER}}` — the issue tracker (Linear or Jira)
- `{{REPO}}` — the GitHub repo, owner/name format
- `{{IMPLEMENT_LABEL}}` — label that triggers the AI coding agent pipeline. Resolved at session start per `../bd-shared/pickup-label.md`.
- `{{ARCHITECT_NAME}}` — the human who owns risky changes (migrations, auth, infra). Optional.
- `{{BUILD_CMD}}` — verification command for typed code
- The skill assumes a Blindspot Table (below) populated with the project's known failure modes. Update it as the codebase evolves.

---

## Environment and Pipeline Context

### Environment detection

Same as bd-build-up and bd-build-down.

**Chat (primary for bd-summit-push):**
- Has: tracker MCP, GitHub MCP, project context, conversation memory
- Use for: plan evaluation, issue body hardening, manifest generation, risk reporting
- Blast radius is an estimate from project knowledge and issue descriptions. An anchor nobody opened holds its issue (Phase 3c), so verify through a code-reading agent or the GitHub connector

**Code-execution:**
- Has: bash, local filesystem, git — can verify blast radius against actual code
- Use when: deep convention checks are needed, file overlap must be verified against real repo state

**Code-reading agent:**
- Useful for: cross-file pattern verification when an issue references patterns that need to be confirmed
- Return findings to chat for manifest generation

**Opening declaration:** Run `../bd-shared/session-start.md` first; its printed lines open the reply. Then state: the environment, the input (plan vs. filed issues vs. open PRs), and the mode (pre-push vs. mid-push). Print the resolved `{{IMPLEMENT_LABEL}}` and its source (from session-start binding).

### Relationship to other skills

- **bd-build-up → bd-summit-push → bd-build-up:** bd-build-up drafts a plan, bd-summit-push hardens it, bd-build-up files the hardened version. Invoked when the plan has 5+ issues with dependencies, or the user says "bd-summit-push this."
- **bd-super-build-down invokes Mode 2 automatically** for 5+ open PRs — don't duplicate its work, consume the scan output instead.
- **bd-build-down's own Phase 2h** does merge-sequencing for smaller PR counts. bd-summit-push Mode 2 is not needed for routine bd-build-downs.

---

## When to Use This Skill

**Pre-push triggers:**
- bd-build-up plan drafted, the user wants to review before filing
- Issues filed but not yet picked up (still in Backlog, or in Todo but pipeline hasn't started)
- The user is about to promote a batch from Backlog → Todo and wants to be strategic about order
- The user wants to evaluate whether a set of issues can realistically land in a single cycle

**Mid-push triggers:**
- Multiple PRs open and the user wants proactive merge-order planning without running a full bd-build-down
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

- A bd-build-up plan presented in the current conversation
- A set of tracker issue IDs to evaluate (`get_issue` on each)
- A project or milestone filter ("evaluate everything in the X project that's in Backlog or Todo")
- A raw list of objectives to be decomposed — in this case, run bd-build-up first, then bd-summit-push the result

For each issue, capture: title, description/body, labels, dependencies (`blockedBy`), routing (assignee or `{{IMPLEMENT_LABEL}}`).

### Phase 1b: KG recon (if a KG is bound)

Before sequencing, consult the project's knowledge graph for prior learnings, decisions, and
issues touching this plan's surfaces. Follow `../bd-shared/kg-recon.md`: derive 1–3 queries from **the
plan's key nouns + the issue set's shared files/components**, call **only** `mcp__<prefix>__<kg.searchTool>`
(the resolved hybrid-search tool from `../bd-shared/kg-recon.md`, where `<prefix>` is the orchestrator server from `../bd-shared/session-start.md` step 1), and cite any hit that changes
a sequencing or hold call (e.g. a prior failure class on a surface an issue touches). Advisory
and non-blocking; silent skip when no KG is bound.

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

In chat: blast radius is an estimate from description + project knowledge. In code-execution: verify against actual repo state. Mark each overlap as verified or estimated.

**2e. Feature-branch grouping (both trackers)**

When the plan contains a parent/child **feature node** (`../bd-shared/feature-branch-grouping.md`), the dependency
graph is not "all PRs → base." Model the **cascade**:

- Leaf children PR into their parent's **grouped branch** (`ai-implement/<mode>/<key>` — `feature` or `multi-issue`; same cascade either way, only the path segment differs), not the Default Branch.
- A parent's **own closing work** is implicitly `Blocked by:` all its labelled children — it runs only
  after they're terminal. Schedule it last on the parent's branch.
- **Internal roll-ups** (child feature branch → parent branch) are automatic direct merges, **not nodes
  that need scheduling**.
- The **critical path runs *through* the feature node** and ends at the single **top-of-tree
  `feature → base` PR** (the human gate). Time-to-land = longest leaf→…→top chain, plus the human review.
- **Labelling sequence:** label the whole tree at filing, in one pass, parent before children
  (`../bd-shared/pipeline.md` § Wave release). The blocking relations sequence the children. Don't
  sequence a parent to merge to the Default Branch before its children.

(Applies on **both** trackers — Linear via {{IMPLEMENT_LABEL}}, Jira via a non-empty `AI-Implement-Status` + matching Repo field; "terminal" = Linear Done/Cancelled or Jira `statusCategory` = done. See `../bd-shared/feature-branch-grouping.md`.)

### Phase 3: Issue Quality Audit

Find what would make each issue fail in the pipeline, and fix it before the agent sees it.

**3a. Failure-mode checklist**

Cross-reference every issue against the full Blindspot Table (see Conventions below) and this checklist:

| Failure Mode | What to Look For | Fix |
|---|---|---|
| **API route invention** | Issue says "create an API for X" without specifying the exact path | Add explicit file path, handler function, HTTP method |
| **Missing codebase context** | Describes what to build but not where it fits | Add the `## Files` list and a pattern anchor |
| **Ambiguous acceptance criteria** | Criteria subjective ("should work well") or untestable | Rewrite each per body rule 3 in `../bd-shared/issue-body.md` |
| **Migration without schema context** | "Add a field" without table or column type | Name the table, column, and type; isolate the migration per hard rule 1 in `../bd-shared/issue-shape.md` |
| **Frontend without API contract** | UI issue doesn't specify the query or response shape | Add exact query or endpoint path and response shape |
| **Security/RLS gap** | Touches tenant-scoped tables without mentioning row-level security | Add security context note; route policy changes to the architect |
| **Too large** | Reaches the size threshold in `../bd-shared/issue-shape.md` with no `Stays whole:` reason | Split, or state why it stays whole |
| **Snapshot delta — needs accept-new-baseline** | KG-repo issue whose `Snapshot delta:` value includes "needs accept-new-baseline" | Flag in High-Risk Items; note that bd-build-down must sequence the guard dry-run and the acceptance step before the issue merges |
| **Missing test requirements** | No verification specified | Add `{{BUILD_CMD}}` passes + specific UI/API verification |
| **Mock data confusion** | Criteria imply real data is available when only mock data exists | Note "empty state acceptable" or specify data wiring |
| **Storage bypass** | File upload issue without referencing the project's blob/file storage convention | Specify the storage layer explicitly |

**3b. Issue body hardening**

Rewrite each issue that fails the checklist in the canonical template and body rules,
`../bd-shared/issue-body.md`. Keep its `## Files` section in the exact bullet form, because the
overlap guard reads it.

**3c. The hold check**

Run the filing check in `../bd-shared/issue-body.md` on every issue. Mark each one **ready**, or
**held** with the condition that holds it. Held is yes or no, not a score. Fix a held issue before
it is filed or labelled. A migration or auth issue keeps its routing to the architect.

### Phase 4: Push Manifest

Produce the final output:

```
# Summit Push Manifest: {name}
Generated: {date}
Scope: {N} issues, {tracks} parallel tracks

## Push Order

**Wave 1 (no dependencies — send immediately):**
- {ISSUE-ID}: {title} — {ready | held: condition} — Track: {track}

**Wave 2 (depends on Wave 1):**
- {ISSUE-ID}: {title} — {ready | held: condition} — Blocked by: {deps}

(continue for Wave 3+)

## Parallel Tracks

- Track A: {description} — Issues: {list} — No overlap
- Track B: {description} — Issues: {list} — ⚠️ Overlaps with Track A on {files}

## Feature-branch trees (both trackers)

{For each feature node: its feature branch `ai-implement/feature/<key>`, the child issues that PR into it,
and the parent's deferred closing work. Grouped children form a track whose merges target the feature
branch, not base. The tree's terminal node is the top-of-tree `feature → base` PR — the human gate, merged
last, never auto-merged. Every issue in a tree is released at filing; its waves show the order the
blocking relations enforce. Omit this section only when there are no feature nodes (either tracker).}

## Migration Sequence

{Ordered list of issues with SQL migrations — the architect must apply these (or auto-applied per project policy)}

## High-Risk Items

{Held issues, each with the condition that holds it and the fix}

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

**If pre-filing (bd-build-up hasn't filed yet):**
- Update the in-session plan with hardened descriptions and optimized sequencing
- Re-resolve `{{IMPLEMENT_LABEL}}` per `../bd-shared/pickup-label.md` before handing back.
- Hand back to bd-build-up Phase 3 for filing, which releases per `../bd-shared/pipeline.md` § Wave release

**If post-filing (issues already in tracker):**
- Update issue descriptions in the tracker via `save_issue` with hardened versions
- Only update the `description` field — preserve existing labels, state, assignee, estimate
- A description edit after the orchestrator planned the issue does not change its acceptance bar (`../bd-shared/issue-body.md` body rule 5)
- Release any issue that the release rule says should already carry the pickup signal. Leave standalone wave 2+ held until its blockers land, so their lessons reach its body

---

## Mode 2: Mid-Push (Risk Scan)

This mode is usually invoked automatically from bd-super-build-down for 5+ open PRs. Run standalone when the user wants a risk scan without being in a bd-build-down session.

### Phase 1: Current State Assessment

Pull state of everything in flight:

- **Open PRs** via GitHub MCP (`list_pull_requests`, `get_pull_request`, `get_pull_request_status`, `get_pull_request_files`)
- **Issues in `In Progress`** or carrying the `AI-Working` label, via tracker MCP
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
- Pre-draft the `git merge <base branch>` agent comment for the second PR (its base — feature branch for a grouped child, else the **Default Branch**, never assumed `main`)

**2d. Dependency gap detection**

- Any in-progress issue working on something that depends on an unmerged PR?
- Any queued issue about to be picked up by the agent before its dependency lands? Check that a native blocking relation holds it; the body's `Blocked by:` line alone does not.

**2e. Codebase drift detection**

- PRs modifying the same area — later PRs may be working against a stale view of the Default Branch
- Flag any PR open for >3 days — increasingly likely to need rebase

### Phase 3: Risk Report

```
# Mid-Push Risk Report
As of: {date/time}

## Immediate Actions Needed

(Things that should be done now, in priority order. "Immediate" means: an action that, if delayed, will cause rework or damage. Examples: a queued issue whose blocker has no native blocking relation; a merge order that must be enforced today to avoid conflicts compounding.)

## Predicted Conflicts

| PR A | PR B | Conflicting Files | Recommended Order | Resolution Draft Ready? |

## Migration Risks

(Migration ordering issues across open PRs — flag for the architect, with raw SQL)

## Convention Risks

(PRs or queued issues likely to hit failure modes from the Blindspot Table)

## Safe to Send Next

(Queued issues with no dependency or conflict risk — ready for agent pickup)

## Hold

(Issues to keep without the pickup signal, with reason)
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

### Tracker MCP patterns (Linear-style)

- `save_issue` for create/update, label arrays replace (always pass full list)
- When hardening an issue description, update ONLY the `description` field — preserve labels, state, assignee, estimate
- `blockedBy` relations hold dispatch: the orchestrator does not pick up an issue until each blocker is Done, Canceled, or Duplicate. They also drive bd-summit-push's dependency analysis
- `relatedTo` accepts arrays of issue ID strings

**Jira-style (projected — full adaptation tracked in AII-149):**
- MCP binding: the Atlassian connector found by session-start step 4 (`tracker.kind: jira` in the binding)
- Description updates: `editJiraIssue` scoped to `description` field; `issuelinks` for `blockedBy`/`relatedTo`
- Wave state: no direct `state` field — use `transitionJiraIssue` + `AI-Implement-Status` custom field for pipeline gating. Human-set values are exactly two: `Ready` (dispatch now) or **unset** (held). `Planning`/`Implementing`/`PR Ready` are orchestrator-owned — hand-setting them hides the issue from pickup and burns a concurrency slot

### Filing states (aligned with bd-build-up)

Follow `../bd-shared/pipeline.md` § Wave release and the active tracker adapter's **Wave staging** section. Exception: the user says "stage only, don't start" → file everything without the pickup signal.

---

## Key Principles

1. **bd-summit-push is strategic, not mechanical.** The manifest is an analytical artifact — the user reviews it and decides. bd-summit-push does not file or promote without the user's approval.
2. **Mark each issue ready or held.** A held issue is fixed or split before the agent sees it.
3. **Migrations serialize.** Two migrations touching the same tables are not independent — flag and sequence.
4. **Release per the wave rule.** A feature-branch tree goes out whole at filing; a standalone chain goes out one wave at a time.
5. **Cross-reference the blindspot table.** Phase 3 auditing isn't complete without it.
6. **Pipeline timing is measured, not assumed.** Use recent actual performance, not fixed hours-per-issue estimates.
7. **Mode 2 is automatic inside bd-super-build-down.** Standalone invocation only when the user wants a risk scan outside a bd-build-down.
