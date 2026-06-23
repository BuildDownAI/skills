# Mega-Build-Up Jira Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mega-build-up` drive a build-up into Linear *or* Jira by splitting its tracker-touching mechanics into per-tracker adapter docs behind a tracker-neutral core.

**Architecture:** `mega-build-up/SKILL.md` becomes a tracker-neutral shared core (process + rubric). Two adapter docs under `mega-build-up/trackers/` (`linear.md`, `jira.md`) own the mechanics for a fixed set of "seams" (overlap scan, container, doc home, pickup trigger, waves, dependencies, issue creation, status check). The core declares the tracker at session start and follows the matching adapter.

**Tech Stack:** Markdown skill files only. No code, no build step. "Tests" are grep/diff/read-through validation checks against the spec.

## Global Constraints

- Files live in `mega-build-up/SKILL.md` and `mega-build-up/trackers/{linear,jira}.md` — copied verbatim from the spec's file layout.
- Scope is **mega-build-up only**. Do not touch `build-up`, `build-down`, `super-build-down`, `summit-push`, or `smoke-jumper`.
- No Confluence. Jira design+plan docs are **markdown files attached to the container epic**.
- Linear behavior must be **unchanged** after the refactor — the extraction is content-preserving.
- Each adapter MUST document the same fixed seam set, in this order: MCP & discovery · Container · Doc home · Overlap scan · Pickup trigger · Wave staging · Architect routing · Dependencies · Required create fields · Issue type · Issue URL · Status check.
- The pipeline reads issue bodies cold and does not follow links — this rule from the core applies to both adapters.
- Work happens on branch `mega-build-up-jira-adapter` (already created).

---

### Task 1: Extract the Linear adapter

Move every Linear-specific mechanic out of `SKILL.md` into a new `trackers/linear.md`, organized by the fixed seam set. This task **only creates `linear.md`** — `SKILL.md` is neutralized in Task 2. Content is copied verbatim from the current `SKILL.md` regions so Linear behavior is preserved.

**Files:**
- Create: `mega-build-up/trackers/linear.md`
- Read (source regions): `mega-build-up/SKILL.md`

**Interfaces:**
- Produces: `trackers/linear.md` with one `## ` section per seam, named exactly per the Global Constraints seam set. Task 2 and Task 3 rely on these exact section names.

**Source-region → seam extraction map** (copy the prose verbatim from these `SKILL.md` regions):

| Seam section in `linear.md` | Source in current `SKILL.md` |
|---|---|
| MCP & discovery | Environment Detection (lines ~118-122): "Linear MCP" usage |
| Container | Phase 4 Step 1 "Resolve the Linear project" (`list_projects`, create project) |
| Doc home | Phase 4 Step 2 "Attach design + plan documents" (Project Documents, `create_document`, paste-to-description fallback) |
| Overlap scan | Phase 1 "Backlog Overlap Scan" search mechanics (`search_issues`, `list_issues`, `list_projects`) — the *mechanism* only; the classification table stays in core |
| Pickup trigger | Phase 4 Step 4 "Wave 1" (`state: Todo` + `AI-Implement` label) |
| Wave staging | Phase 4 Step 4 Wave 1 / Wave 2+ states (`Todo`, `Backlog`) |
| Architect routing | Phase 4 Step 4 "Architect-routed" (Todo, assigned, no label) |
| Dependencies | Conventions "Dependency phrasing" + the Linear relation mechanic |
| Required create fields | Phase 4 Step 3 issue body + `save_issue` notes from Conventions |
| Issue type | (none for Linear — write "N/A — Linear has no issue-type requirement") |
| Issue URL | Phase 4 Step 3 "Reference design context: {Linear project URL}" |
| Status check | Status Check Mode (`list_projects`, fetch project documents) |

- [ ] **Step 1: Create `trackers/linear.md` with the seam skeleton and a header**

```markdown
# Mega-Build-Up — Linear Tracker Adapter

The core (`../SKILL.md`) delegates every tracker-touching action to this file
when `{{TRACKER}}` is Linear. Section names match the core's seam references
exactly.

## MCP & discovery
## Container
## Doc home
## Overlap scan
## Pickup trigger
## Wave staging
## Architect routing
## Dependencies
## Required create fields
## Issue type
## Issue URL
## Status check
```

- [ ] **Step 2: Fill each section by copying the mapped source prose verbatim**

Walk the extraction map above. For each row, copy the corresponding Linear prose
out of `SKILL.md` into the matching section. Preserve wording, code-fence
commands (`save_issue`, `list_projects`, `create_document`), and the wave
state/label conventions exactly. For "Issue type" write: `N/A — Linear has no
issue-type requirement.`

- [ ] **Step 3: Validate — every Linear mechanic landed**

Run:
```bash
cd /Users/cameronpope/source/BuildDownAI/skills
grep -nE 'save_issue|list_projects|create_document|state: Todo|AI-Implement` label|Backlog' mega-build-up/trackers/linear.md
```
Expected: hits for each of `save_issue`, `list_projects`, `create_document`, `state: Todo`, and `Backlog` — confirming the mechanics were carried over (not yet removed from SKILL.md; that's Task 2).

Run:
```bash
grep -c '^## ' mega-build-up/trackers/linear.md
```
Expected: `12` (one heading per seam).

- [ ] **Step 4: Commit**

```bash
git add mega-build-up/trackers/linear.md
git commit -m "Extract Linear mechanics into mega-build-up/trackers/linear.md

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Neutralize the core SKILL.md

Make `SKILL.md` tracker-agnostic: add `{{TRACKER}}` config, add a Tracker Selection step, and replace each inline Linear mechanic with a pointer to the active adapter's matching seam section. Core *prose* (phases, rubric, grilling tree, approval gates) stays.

**Files:**
- Modify: `mega-build-up/SKILL.md` (Configuration, Environment Detection, Phase 1 overlap scan, Phase 4 Steps 1–4, Status Check, Conventions)

**Interfaces:**
- Consumes: `trackers/linear.md` seam section names from Task 1.
- Produces: a neutral core that references `trackers/<id>.md` by seam name. Task 3's `jira.md` must satisfy the same references.

- [ ] **Step 1: Add `{{TRACKER}}` to Configuration**

In the Configuration section, replace the first bullet:

```markdown
- `{{TRACKER}}` — Linear (this skill assumes Linear MCP; adapt for others)
```

with:

```markdown
- `{{TRACKER}}` — the issue tracker for this build-up: `linear` or `jira`. Determines which `trackers/<id>.md` adapter the core follows for all tracker-touching steps.
```

- [ ] **Step 2: Add a Tracker Selection block to Environment Detection**

After the "Opening declaration" line in Environment Detection, insert:

```markdown
### Tracker Selection

Pick the active tracker at session start and load its adapter:

- Infer `{{TRACKER}}` from the connected MCP / orchestrator mapping (`linear-cloudshare` → `linear`, `atlassian-cloudshare` → `jira`). If both are present or it's ambiguous, ask once.
- Read `trackers/{{TRACKER}}.md`. Every tracker-touching step below (overlap scan, container, doc home, pickup trigger, waves, dependencies, issue creation, status check) follows that adapter's matching `## ` section.
- State the tracker in the opening declaration, e.g. *"…Tracker: Jira (epic BAC-23858, project BAC)."*
```

- [ ] **Step 3: Replace inline Linear mechanics with adapter pointers**

At each seam in the core, replace the Linear-specific instruction with a pointer. Make these exact substitutions (the surrounding prose stays):

- Environment Detection bullets: change "Linear MCP" → "the tracker MCP (see Tracker Selection)"; change Pair pattern "attach it to Linear from chat as a Project Document" → "attach it per the active adapter's **Doc home** section."
- Phase 1 Backlog Overlap Scan, search-strategy steps: change `search_issues` / `list_issues` / `list_projects` mechanics → "search per the active adapter's **Overlap scan** section." Keep the classification table and "No silent overlap" rule.
- Phase 4 Step 1 heading "Resolve the Linear project" → "Resolve the container" with body "Follow the active adapter's **Container** section."
- Phase 4 Step 2 "Attach design + plan documents": body → "Attach both docs per the active adapter's **Doc home** section."
- Phase 4 Step 3.5 overlap reconciliation verbs (move to Todo, add label, etc.): prefix with "Using the active adapter's **Wave staging** / **Pickup trigger** mechanics," and keep the action list as intent.
- Phase 4 Step 4 "Wave staging": replace `state: Todo` + label / `Backlog` / architect specifics → "Wave 1 / Wave 2+ / architect routing per the active adapter's **Pickup trigger**, **Wave staging**, and **Architect routing** sections." Keep the wave *model* and pilot-first sequencing.
- Status Check Mode: change `list_projects` / "fetch the project documents" → "per the active adapter's **Container** and **Doc home** sections."
- Conventions: move the "Linear MCP patterns" block out (now in `linear.md`); keep "Dependency phrasing: always `Blocked by: {ISSUE-ID} (reason)`" as a neutral convention but append "(mechanism is per-adapter — see **Dependencies**)."

- [ ] **Step 4: Validate — no Linear-specific mechanics remain in the core**

Run:
```bash
cd /Users/cameronpope/source/BuildDownAI/skills
grep -nE 'save_issue|list_projects|create_document|state: Todo' mega-build-up/SKILL.md
```
Expected: **no output** (all Linear tool/state mechanics now live in the adapter).

Run:
```bash
grep -nE 'trackers/|active adapter|Tracker Selection|\{\{TRACKER\}\}' mega-build-up/SKILL.md
```
Expected: multiple hits — confirms the core now delegates and the selection step exists.

- [ ] **Step 5: Validate — Linear parity preserved**

Read through `SKILL.md` + `trackers/linear.md` together as a Linear operator would. Confirm every mechanic that was inline before (project create, document attach, wave states, overlap search, dependency relation, status check) is reachable via a pointer + adapter section. No instruction dropped.

- [ ] **Step 6: Commit**

```bash
git add mega-build-up/SKILL.md
git commit -m "Neutralize mega-build-up core; delegate tracker mechanics to adapters

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Write the Jira adapter

Create `trackers/jira.md` with the same seam sections as `linear.md`, encoding the Jira mechanics and the four red-flag gotchas from the spec.

**Files:**
- Create: `mega-build-up/trackers/jira.md`

**Interfaces:**
- Consumes: the core's seam references from Task 2 (must satisfy the same `## ` section names as `linear.md`).

- [ ] **Step 1: Create `trackers/jira.md` with the full content below**

````markdown
# Mega-Build-Up — Jira Tracker Adapter

The core (`../SKILL.md`) delegates every tracker-touching action to this file
when `{{TRACKER}}` is `jira`. Section names match the core's seam references
exactly.

> **The trigger is a field, not a label.** A Jira issue carrying the
> `AI-Implement` label but **without `AI-Implement-Status = Ready`** is never
> picked up by the pipeline. This is the single most common Jira filing mistake.

## MCP & discovery
Use the `atlassian-cloudshare` MCP. Tool names are not hardcoded — discover them
at runtime with ToolSearch (`jira create issue`, `jira search jql`,
`jira edit issue`, `jira add comment`, `jira issue link`, `jira attachment`).
The MCP covers both Jira and Confluence; this adapter uses Jira only.

## Container
The container is a **Jira Epic** under a fixed Jira project (e.g. epic
`BAC-23858` in project `BAC`). Jira forbids epics-under-epics, so every build-up
issue is a flat child with `parent = <epic key>`. Resolve or confirm the epic key
with the operator at session start; do not create a new project. If no epic
exists for this build-up, create one Epic-type issue in the project and use it as
the parent.

## Doc home
Write the Design Decisions and Implementation Plan as local markdown files (per
the core's `{{PLAN_DIR}}` convention), then **attach both files to the container
epic** as Jira attachments. There is no Confluence step. Note in the epic
description that the two attachments are the authoritative design + plan.

## Overlap scan
Run the core's Backlog Overlap Scan with JQL instead of Linear search:
- **Keyword:** `project = <PROJ> AND (summary ~ "<term>" OR description ~ "<term>")`
  across all statuses (do **not** filter to open — stale Backlog issues are the
  ones that get missed).
- **Label/component:** `project = <PROJ> AND labels = "<label>"`.
- **Container:** `parent = <epic>` to list the epic's existing children.
- **File-path:** `description ~ "<path>"` for paths Phase 1 identified.
Feed every hit into the core's classification table.

## Pickup trigger
To make Wave-1 issues get picked up, every one must satisfy the orchestrator
mapping's poll: `(<mapping JQL>) AND cf[AI-Implement-Status] in (Ready, "Plan
Approved")` **and** the Repo field equals the mapping's `repoFieldValue`.
Concretely, on create:
1. Set **`AI-Implement-Status` = `Ready`**.
2. Set the **Repo field** to the mapping's `repoFieldValue` (e.g. `owner/repo`).
3. Ensure the issue satisfies the mapping's **scope JQL** (commonly the project +
   the `AI-Implement` label + the epic parent). Confirm the live scope with the
   operator or the orchestrator mapping.

## Wave staging
- **Wave 1** (no blockers): `AI-Implement-Status = Ready` (see Pickup trigger).
- **Wave 2+** (has blockers): create with `AI-Implement-Status` **unset** (any
  value that isn't `Ready`/`Plan Approved`). The pipeline ignores it. Promote to
  `Ready` during build-down as blockers merge.
- Pilot-first sequencing (from the core) maps to: file all siblings but set
  `AI-Implement-Status = Ready` on **only the pilot**; leave the rest unset until
  the pilot's PR lands, then set them `Ready`.

## Architect routing
Create the issue assigned to the architect with `AI-Implement-Status` **unset**
so the pipeline never picks it up. Do not rely on the label for exclusion — the
Status field is the gate.

## Dependencies
Create a Jira **"Blocks" issue link**. For "Issue B blocked by Issue A", create
the link so that **A is the inward (blocker) issue and B is outward** — i.e. "A
blocks B". The pipeline (`isBlockedByIncomplete`) skips an issue that has an
inward "Blocks" link to a non-`done` issue. Get the direction right or the
dependency will not serialize.

> Default link-type name is "Blocks". An instance that renamed it will fail open
> (the issue dispatches as if unblocked) — confirm the link type name if
> dependencies don't hold.

## Required create fields
Jira create demands more than Linear. Provide all of: `project`, `parent` (epic),
issue type (see Issue type), `summary`, `description`, `priority`, **`Assigned
Team`** (a required custom field), the Repo field, `AI-Implement-Status` (for
Wave 1), and labels (`AI-Implement` + any sync key). Custom-field IDs
(`Assigned Team`, `AI-Implement-Status`, `Repo`) are **instance-specific** — read
them from the orchestrator mapping or the deployment's Jira-mirror design doc.
Never hardcode field IDs in a filed issue.

## Issue type
Derive from the work kind: **Feature → Story · Improvement → Task · Bug → Bug.**

## Issue URL
`{siteUrl}/browse/{KEY}` (e.g. `https://cloudshare.atlassian.net/browse/BAC-123`).
Use this for the human "reference design context" link in issue bodies.

## Status check
For Status Check Mode: list the epic's children (`parent = <epic>`), group by
`AI-Implement-Status`, surface blockers via "Blocks" links. When asked "where's
the design/plan?", fetch the **epic's attachments** (the two markdown docs).

## Red flags (Jira-specific)
- **Filed with the `AI-Implement` label but no `AI-Implement-Status = Ready`.** →
  Never picked up. Set the Status field.
- **Issue description rendered as raw markdown.** → Jira uses ADF; rely on the
  MCP's markdown conversion and **verify rendering on the pilot issue** before
  filing the wave.
- **Hardcoded custom-field IDs.** → Instance-specific; read them from the mapping
  / mirror doc.
- **"Blocks" link created in the wrong direction.** → Blocker must be the inward
  issue. Verify the dependency actually serializes on the pilot.
````

- [ ] **Step 2: Validate — seam parity with the Linear adapter**

Run:
```bash
cd /Users/cameronpope/source/BuildDownAI/skills
diff <(grep '^## ' mega-build-up/trackers/linear.md) <(grep '^## ' mega-build-up/trackers/jira.md)
```
Expected: **no output** (both adapters expose the identical seam section set).

- [ ] **Step 3: Validate — gotchas present**

Run:
```bash
grep -nE 'AI-Implement-Status = Ready|ADF|instance-specific|inward' mega-build-up/trackers/jira.md
```
Expected: hits for all four — confirms the four red flags are documented.

- [ ] **Step 4: Commit**

```bash
git add mega-build-up/trackers/jira.md
git commit -m "Add Jira tracker adapter for mega-build-up

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- Shared core + adapter layout → Tasks 1–3. ✓
- Linear extracted to `linear.md` → Task 1. ✓
- `jira.md` with all seams → Task 3 (full content). ✓
- Tracker Selection + `{{TRACKER}}` → Task 2 Steps 1–2. ✓
- Doc home = epic attachments → `jira.md` Doc home. ✓
- Trigger = Status field; Blocks-link direction; ADF; instance-specific IDs → `jira.md` Red flags. ✓
- Linear parity preserved → Task 2 Step 5. ✓
- Scope = mega-build-up only → Global Constraints. ✓

**2. Placeholder scan:** No "TBD/TODO/handle edge cases". Extraction map in Task 1 names exact source regions; new prose (Tracker Selection, full `jira.md`) is shown in full. ✓

**3. Type consistency:** Seam section names are identical across the Global Constraints list, Task 1 skeleton, Task 2 pointers, and Task 3 content (verified by the Task 3 Step 2 `diff`). `{{TRACKER}}` values (`linear`/`jira`) consistent between Config, Tracker Selection, and adapter filenames. ✓
