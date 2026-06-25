# Build-Down — Linear Tracker Adapter

The core (`../SKILL.md`) delegates tracker-touching steps to this file when
`{{TRACKER}}` is Linear. Section names match the core's seam references exactly.

## MCP & discovery

Use the configured Linear MCP server (named `linear-<workspace>` in your MCP config). The three operations this skill relies on are:

- `list_issues` — query issues by state and/or label
- `get_issue` — fetch a single issue (acceptance criteria, body, blockedBy)
- `save_issue` — create or update an issue (pass `id` to update; omit to create)

At session start, confirm the Linear MCP is available and state it in the opening declaration. All tracker reads and writes go through these three calls — no direct API calls or browser-based Linear access.

## Issue scan & states

Pull current board state using three parallel `list_issues` calls:

1. `list_issues` filtered by `state: "In Progress"` — agent is actively working; pipeline is running
2. `list_issues` filtered by `state: "In Review"` — PR is open and ready for triage
3. `list_issues` filtered by `state: "Todo"` and label `{{IMPLEMENT_LABEL}}` — queued for agent pickup

**State semantics:**
- `In Progress` — agent has picked up the issue and is working; a PR branch exists or is being opened. Expected, not alarming.
- `In Review` — agent has finished its pass and the PR is ready. This is the primary triage queue.
- `Todo` + `{{IMPLEMENT_LABEL}}` — in the agent queue; pickup happens within minutes of the label being present.

Any custom working state (e.g., a team-specific "Working" column) is treated the same as `In Progress`. Note it at orientation if present.

## Pickup trigger

An issue is picked up by the AI coding agent when it has both:

- `state: Todo` (set to `"Todo"` via `save_issue`)
- label `{{IMPLEMENT_LABEL}}`

Pickup happens within minutes. Do not manually move an issue to `In Progress` — the pipeline sets that state automatically when it starts work.

When releasing a previously blocked issue for pickup, set both conditions simultaneously via `save_issue`:

```
save_issue(id: <issue-id>, state: "Todo", labels: ["{{IMPLEMENT_LABEL}}", ...other labels])
```

**Label array behavior:** Linear's `save_issue` replaces the full label list — it does not append. Always pass the complete desired label array, including any existing labels you want to retain.

## Post-merge completion

The Linear↔GitHub integration auto-closes the linked issue when its PR merges. No manual state change is required in the normal case — the integration is reliable and fires promptly after merge.

**Fallback (if the auto-close does not fire):** Call `save_issue` with `id: <issue-id>` and `state: "Done"`. No verification step is needed before or after — check the issue state only if you have reason to believe the integration is degraded.

Do not invent a manual transition workflow for Linear. The auto-close is the expected path; the `save_issue` fallback is for edge cases only.

## Unblock dependents

After each merge, check whether the merged issue was listed in any other issue's `blockedBy` field. Use `get_issue` on candidate issues (identified during orientation or from the tracker's dependency graph).

For each issue whose `blockedBy` list is now fully cleared (all blocking issues are in `Done`):

1. Set `state: "Todo"` and add `{{IMPLEMENT_LABEL}}` to the label list via `save_issue`
2. Log in the session summary under "Unblocked Work": issue ID, what it was blocked by, new state

Do this immediately after each merge — don't batch unblocks to end of session. An unblocked issue gets into the agent queue faster if released as soon as the blocker merges.

## Follow-up filing

Use `save_issue` (no `id`) to create new issues. The initial state depends on filing context:

| Filing context | State | Labels | Assignment |
|---|---|---|---|
| Mid-session scoped fix, ready for agent | `Todo` | `{{IMPLEMENT_LABEL}}` + relevant tags | — |
| Mid-session discovery, needs planning | `Backlog` | — | — |
| Out-of-scope gap, clean and scoped | `Todo` | `{{IMPLEMENT_LABEL}}` | — |
| Out-of-scope gap, needs discussion | `Backlog` | — | — |
| Architectural finding | `Backlog` | — | `{{ARCHITECT_NAME}}` |

Default toward `Todo` + `{{IMPLEMENT_LABEL}}` when the work is well-scoped and deterministic. `Backlog` is for planning and discussion, not for parking work that could start now.

Architect-routed issues: set `state: "Backlog"`, assign to `{{ARCHITECT_NAME}}`, omit `{{IMPLEMENT_LABEL}}` — these are not agent-ready.

## Issue URL & key

**Locating the linked issue:** The Linear issue ID is embedded in the PR branch name or PR title by convention (e.g., `abc-123-feature-description` or `[ABC-123]` in the title). Extract it from whichever is present; prefer branch name when both exist.

Use `get_issue` with that ID to retrieve the full issue record (acceptance criteria, body, blockedBy, labels).

**Issue URL:** Construct the Linear URL as `https://linear.app/<team>/issue/<issue-id>` for use in session summary comments and PR descriptions. Use this URL when referencing issues in GitHub PR comments or session summaries — do not use bare issue IDs where a link would be clearer.
