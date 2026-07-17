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
`BAC-23858` in project `BAC`). Jira forbids epics-under-epics, so every bd-build-up
issue is a flat child with `parent = <epic key>`. Resolve or confirm the epic key
with the operator at session start; do not create a new project. If no epic
exists for this bd-build-up, create one Epic-type issue in the project and use it as
the parent.

The Epic is a long-lived **tracking container** and MUST stay **un-designated** — never set
`AI-Implement-Status` on it. Grouping is opt-in *below* the Epic: to run a cohesive subset as a feature
node, promote it into a designated **Story with designated sub-task children** (see **Feature-node
grouping**). Designating the Epic itself would collapse the entire epic into one feature branch — an
anti-pattern, not an option.

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
  `Ready` during bd-build-down as blockers merge.
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
- **Feature-node child filed without `AI-Implement-Status` set, or with the wrong Repo value.** →
  Silently **excluded from the group**: it neither gates its parent nor rolls up — it just quietly PRs to
  the Default Branch on its own. Designate every intended child (non-empty Status + matching Repo). "It's
  just a sub-task" and "the epic groups it" are the rationalizations that cause this.
- **`AI-Implement-Status` set on the container Epic.** → Collapses the whole epic into a single feature
  branch. Keep tracking Epics un-designated; designate the Story feature node instead.
- **Issue description rendered as raw markdown.** → Jira uses ADF; rely on the
  MCP's markdown conversion and **verify rendering on the pilot issue** before
  filing the wave.
- **Hardcoded custom-field IDs.** → Instance-specific; read them from the mapping
  / mirror doc.
- **"Blocks" link created in the wrong direction.** → Blocker must be the inward
  issue. Verify the dependency actually serializes on the pilot.

## Feature-node grouping

Jira reached feature-branch parity with Linear in AI-Implement #64. The shape is identical; only designation
and hierarchy differ.

**Designation is a field, not a label — and there are two predicates. Keep them separate:**
- **Group designation** (counts toward grouping — gates its parent, joins the ancestor chain, rolls up, can
  be an auto-merge parent) = `AI-Implement-Status` **set to any non-empty value** *and* the Repo field =
  the mapping's `repoFieldValue`. This is **broader** than dispatch: a child already at `Implementing` /
  `PR Ready` / `Done` is *still designated*, so a parent whose designated children are all terminal is
  **feature-node-ready**, not "none designated → skip."
- **Candidate dispatch** (worked *this* poll) = `AI-Implement-Status` ∈ {`Ready`, `Plan Approved`} + Repo
  match. Do **not** tell operators grouping needs Status = Ready — Ready is only for this poll's dispatch.

**Terminal** = `fields.status.statusCategory.key === 'done'` (Done/Closed + Won't-Do/Cancelled).
**Hierarchy** = `effectiveParentKey = native parent ?? Epic Link` (classic Epic Link is the best-effort
fallback).

**Canonical shape: a designated Story with designated sub-task children, under an un-designated tracking
Epic.** The Story owns `ai-implement/feature/<slug(STORY-KEY)>`; its designated sub-tasks PR **into that
branch**, not the Default Branch; the Story's own closing work is `Blocks`-linked from all its sub-tasks and
runs **last** on the same branch. When the sub-tasks are all terminal, the Story is the top of the tree →
its feature branch → the single human-gate PR `[ai-implement] Feature branch ready for review`. The Epic
stays un-designated, which halts the ancestor walk at the Story — so the Epic is never a feature branch.

**Multi-issue mode.** A Story whose **description** carries a **fenced** `# ai-implement.yml` block with
`feature_branch.mode: "multi-issue"` owns `ai-implement/multi-issue/<slug(STORY-KEY)>` instead — for
grouping *otherwise-unrelated* issues as one reviewable unit. Identical to the above except the branch
path segment; the `AI-Implement-Status` / Repo designation and Epic rules are unchanged. Write examples as
`# ai-implement.yml (example)` (a bare marker is stripped from that issue's spec).

**Two sub-task prerequisites (config, not code — the provider hardcodes no issuetype filter):**
1. **Field context:** `AI-Implement-Status`, `Repo`, and `Assigned Team` must be available on the
   **sub-task** issue type, or sub-task children cannot be designated.
2. **Scope JQL:** the mapping's scope JQL must **not** exclude sub-tasks (no `issuetype != Sub-task`, no
   Story/Task/Bug-only allowlist). Otherwise designated sub-tasks are *discovered* as gating children but
   never *dispatched* onto the feature branch — the group hangs.

**Nesting:** Story + sub-tasks is a single-level group (sub-tasks can't have children). Deeper recursion
needs team-managed native Story→Story parenting; classic Jira can't parent Story-to-Story, so classic
instances use multiple independent single-level feature-node Stories under one tracking Epic. Both are fine
— the orchestrator caps chains at depth 5 regardless.

**Designate children first, parent last.** Set every child's `AI-Implement-Status` + Repo, wire every
`parent` link and every `Blocks` link, then designate the **parent last**. Designate the parent early and it
momentarily looks like a childless leaf and dispatches its closing work onto base ahead of its children
(the Jira translation of Linear's "label the parent last").

**Roll-ups (shared):** an internal roll-up (parent is itself a feature node) is a direct `git merge`, **no
PR**, with an identifier-free commit so GitHub-for-Jira / Smart Commits don't auto-close the parent early. A
**roll-up conflict** surfaces as a child that is terminal but whose work is missing from the parent feature
branch — resolve with a manual `git merge`, never `@agent`. The top-of-tree `feature → base` PR is the
human gate, never auto-merged.

**Failure-mode split:** the gating-children query fails **closed** (a transient Jira error defers the whole
candidate batch that poll, so a feature-node parent never dispatches closing work onto base ahead of its
children); the branch-targeting ancestor walk fails **open** (nesting collapses — a leaf targets the
Default Branch, a feature node still gets its own branch cut from the Default Branch, only losing its
position under any ancestor).

Full model: `docs/feature-branch-grouping.md`.
