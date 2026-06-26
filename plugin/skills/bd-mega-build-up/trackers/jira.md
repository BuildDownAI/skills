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
- **Issue description rendered as raw markdown.** → Jira uses ADF; rely on the
  MCP's markdown conversion and **verify rendering on the pilot issue** before
  filing the wave.
- **Hardcoded custom-field IDs.** → Instance-specific; read them from the mapping
  / mirror doc.
- **"Blocks" link created in the wrong direction.** → Blocker must be the inward
  issue. Verify the dependency actually serializes on the pilot.
