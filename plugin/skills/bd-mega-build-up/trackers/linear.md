# Mega-Build-Up — Linear Tracker Adapter

The core (`../SKILL.md`) delegates every tracker-touching action to this file
when `{{TRACKER}}` is Linear. Section names match the core's seam references
exactly.

## MCP & discovery

- **Chat (web/mobile):** Linear MCP, GitHub MCP, conversation memory. Lacks local FS / bash. bd-belay-on to a code-reading agent for codebase reads.
- **Code-execution (terminal):** bash, local FS, git. Lacks project memory. Use for codebase reads, plan file drafting, then hand back to chat for filing.
- **Pair pattern:** Draft the plan locally as a markdown file in `{{PLAN_DIR}}`, then attach it to Linear from chat as a Project Document.

**Opening declaration:** State environment, primary tools, and which mode you'll be running. Example: *"Running in chat. Linear MCP for filing, will draft the plan to `docs/plans/` and attach as a project document. Mode 2 (New Design)."*

## Container

- **New project:** Default name = bd-build-up name from Phase 2. Confirm with user.
- **Existing project:** Use `list_projects` to match. If multiple candidates, present them.
- Create the project via the Linear MCP if new. Capture the project ID and URL.

## Doc home

Linear supports project Documents. Attach both:

1. **Design Decisions** → upload `{{PLAN_DIR}}/{date}-{slug}-design.md` as a project document titled `Design Decisions`.
2. **Implementation Plan** → upload `{{PLAN_DIR}}/{date}-{slug}-plan.md` as a project document titled `Implementation Plan`.

Use the Linear MCP's document creation tool (`create_document` or equivalent). If the MCP version available doesn't support documents, fall back to: paste the markdown into the project description, and link the local files in the first issue's body.

The documents travel with the project. Anyone who picks up an issue can find them via the project link.

## Overlap scan

Search the Linear backlog for existing work that intersects with this bd-build-up. The goal is to surface every overlap and force a decision before any new issue gets filed.

**Search strategy:**

1. **Keyword search.** Extract 5–10 domain terms from the objective (entity names, feature names, route paths, table names). Search Linear via `search_issues` (or `list_issues` + filter) across **all states** including Backlog. Don't restrict to In Progress — stale Backlog issues are exactly the overlap that gets missed.
2. **Label search.** If the bd-build-up touches a known feature area with a label (e.g., `billing`, `auth`, `onboarding`), list all open issues with that label.
3. **Project search.** Check related existing projects via `list_projects`. Pull the issue list for any project whose scope plausibly overlaps.
4. **File-path heuristic.** If Phase 1 codebase research identified specific files this bd-build-up will modify, search issue bodies for those paths.

**Search defaults:** narrow to the user's team and any teams the bd-build-up obviously touches. If signals suggest cross-team overlap, expand. Better to over-search and discard than to miss a duplicate.

## Pickup trigger

- **Wave 1** (no `Blocked by`) → `state: Todo` + label `AI-Implement`. Pipeline picks up within minutes.

**Linear MCP patterns:**
- `state: Todo` + `AI-Implement` label = pipeline pickup.

## Wave staging

Same wave model as `bd-build-up`:

- **Wave 1** (no `Blocked by`) → `state: Todo` + label `AI-Implement`. Pipeline picks up within minutes.
- **Wave 2+** (has `Blocked by`) → `state: Backlog`. Promote to `Todo` during bd-build-down as blockers merge.
- **Architect-routed** (schema, security, infra) → `state: Todo`, assigned to `{{ARCHITECT_NAME}}`, **no** `AI-Implement` label.

File in dependency order so `Blocked by:` references resolve to real issue IDs.

## Architect routing

**Architect-routed** (schema, security, infra) → `state: Todo`, assigned to `{{ARCHITECT_NAME}}`, **no** `AI-Implement` label.

## Dependencies

**Dependency phrasing:** Always `Blocked by: {ISSUE-ID} (reason)`. Not "Depends on," not "Requires." One phrase, one pattern.

**Linear relation mechanic:** use the native blocked-by relation. Add `Blocked by: {ISSUE-ID} (reason)` in the issue body's Dependencies section.

## Required create fields

The issue body itself follows the core's Phase 4 Step 3 template.

**Linear MCP patterns:**
- `save_issue` handles create + update (pass `id` to update).
- Label arrays replace — always pass the full desired list.
- `state: Todo` + `AI-Implement` label = pipeline pickup.
- Documents attach to projects, not to individual issues. One project per bd-build-up.

File via `save_issue` (or Linear MCP equivalent) after explicit approval of the issue manifest.

## Issue type

N/A — Linear has no issue-type requirement.

## Issue URL

The issue body's Task section must include:

```
Reference design context: {Linear project URL}
```

The "reference design context" link is for humans reviewing the PR, not for the agent. The issue body must be **self-contained** — the AI-Implement pipeline reads it cold and won't follow links to fetch context.

## Status check

Same as `bd-build-up` status check. Match the user's reference to a Linear project, list issues grouped by state, surface blockers, identify bd-build-down readiness (issues in In Review or with open PRs).

If the user asks "where's the design for X?" or "what was the plan for X?" — fetch the project documents and surface them, don't reconstruct from issue bodies.

## Feature-node grouping

A **feature node** is a parent issue carrying the `AI-Implement` label with ≥1 `AI-Implement`-labelled
child. It owns `ai-implement/feature/<key>`; its labelled **children PR into that feature branch**, not the
Default Branch. The parent's own closing work is `Blocked by:` **all** its labelled children and runs
**last**, on the parent's own feature branch. Recursive: a child that is itself a labelled parent gets its
own feature branch cut from its parent's. Completed feature branches roll up automatically (internal levels
via a direct `git merge`, the top of the tree as a human-reviewed `feature → base` PR
`[ai-implement] Feature branch ready for review`).

**Designation = the `AI-Implement` label.** Terminal = the issue is Done or Cancelled.

**Designate (label) the parent LAST.** Build the whole tree first — create children + parent, set every
`parent` relationship and every `Blocked by:` relation — then label children, then the parent last of all.
The orchestrator's race guard only skips a parent while *no* child is labelled yet; it does **not** cover
the "children labelled, relations not yet set" window. Label the parent into that window and the
orchestrator classifies it as dispatchable and picks it up in parallel with its children (observed failure).

Full model: `docs/feature-branch-grouping.md`.
