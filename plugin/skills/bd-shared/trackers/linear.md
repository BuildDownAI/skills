# Build-Up — Linear Tracker Adapter

**Shared by `bd-build-up` and `bd-mega-build-up`.** Both skills delegate every tracker-touching
action to this file when `{{TRACKER}}` is `linear`. Section names match the seam references in
each skill exactly.

Sections marked **(mega only)** describe artifacts plain `bd-build-up` does not produce.
Everything else applies to both.

## MCP & discovery

- **Chat (web/mobile):** Linear MCP, GitHub MCP, conversation memory. Lacks local FS / bash. bd-belay-on to a code-reading agent for codebase reads.
- **Code-execution (terminal):** bash, local FS, git. Lacks project memory. Use for codebase reads and — in bd-mega-build-up — for writing ADRs and glossary entries into the repo, then hand back to chat for filing.
- **Pair pattern (mega only):** Write the ADRs to `{{ADR_DIR}}` in the repo during the grill, then link them into Linear from chat as a Project Document.

**Opening declaration:** State environment, primary tools, and which mode you'll be running. Example: *"Running in chat. Linear MCP for filing. Mode 2 (New Design)."*

## Container

- **New project:** Default name = the build-up name. Confirm with the user.
- **Existing project:** Use `list_projects` to match. If multiple candidates, present them.
- Create the project via the Linear MCP if new. Capture the project ID and URL.

Every issue in the build-up attaches to the same project, so the body of work stays queryable
as a unit.

## Doc home (mega only)

The **repo** is the home for the grill's decisions — ADRs in `docs/adr/`, terminology in
`CONTEXT.md` (see `../decision-docs.md`). Linear carries a pointer to them, not a
second copy.

Create one project document titled `Design Decisions` holding a short index: one line per ADR
written for this build-up, each with its repo path, its one-line decision statement, and a
permalink to the file on the default branch. Add any glossary terms this build-up introduced.

Use the Linear MCP's document creation tool (`create_document` or equivalent). If the available
MCP version has no document support, put the index in the project description instead.

The index travels with the project, so anyone who picks up an issue can reach the design from
the project link. The ADRs themselves stay in the repo, where a coding agent working in that
code will find them without a tracker lookup.

## Overlap scan

Run the shared Backlog Overlap Scan (`../overlap-scan.md`) with these Linear searches. The
goal is to surface every overlap and force a decision before any new issue gets filed.

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

The shared wave model (`../pipeline.md`), in Linear terms:

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

The issue body itself follows the shared template in `../issue-body.md`.

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

Match the user's reference to a Linear project via `list_projects`, list its issues via
`list_issues` grouped by state, surface blockers, and identify bd-build-down readiness (issues
in In Review or with open PRs).

If the user asks "where's the design for X?" — fetch the project's `Design Decisions` document
and follow it to the ADRs. Don't reconstruct the design from issue bodies.

## Feature-node grouping

A **feature node** is a parent issue carrying the `AI-Implement` label with ≥1 `AI-Implement`-labelled
child. It owns `ai-implement/feature/<key>`; its labelled **children PR into that feature branch**, not the
Default Branch. The parent's own closing work is `Blocked by:` **all** its labelled children and runs
**last**, on the parent's own feature branch. Recursive: a child that is itself a labelled parent gets its
own feature branch cut from its parent's. Completed feature branches roll up automatically (internal levels
via a direct `git merge`, the top of the tree as a human-reviewed `feature → base` PR
`[ai-implement] Feature branch ready for review`).

**Multi-issue mode.** A parent whose **description** carries a **fenced** `# ai-implement.yml` block with
`feature_branch.mode: "multi-issue"` owns `ai-implement/multi-issue/<key>` instead — for grouping
*otherwise-unrelated* issues as one reviewable unit. Identical to the above in every respect except the
branch path segment. The selector lives in the description, not a label; write examples as
`# ai-implement.yml (example)` (a bare marker is stripped from that issue's spec).

**Designation = the `AI-Implement` label.** Terminal = the issue is Done or Cancelled.

**Build the whole tree first, then label the parent BEFORE the children.** Create children + parent, set
every `parent` relationship and every `Blocked by:` relation — then label the parent, then the children.
A labelled parent with *no children yet* is classified as a leaf and dispatched standalone (observed
failure), so the complete tree must exist before any label goes on. And a child labelled while its parent
is *unlabelled* resolves an empty ancestor chain and cuts its PR from the repo base branch, silently
bypassing grouping — so the parent is labelled first. The race guard makes that safe: a labelled parent
whose children carry no label yet is a *waiting parent* and is skipped until its children release.

Full model: `../feature-branch-grouping.md`.
