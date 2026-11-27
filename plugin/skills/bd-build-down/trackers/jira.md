# Build-Down — Jira Tracker Adapter

The core (`../SKILL.md`) delegates tracker-touching steps to this file when
`{{TRACKER}}` is `jira`. Section names match the core's seam references exactly.

> **Completion is not automatic in Jira.** The Jira↔GitHub integration is
> unreliable at transitioning an issue to Done when its PR merges. build-down
> must complete the issue explicitly and verify it — see **Post-merge
> completion**. An un-completed blocker silently keeps its dependents blocked
> (the orchestrator's `isBlockedByIncomplete` only clears once the native status
> category is `done`).

## MCP & discovery

The Atlassian connector is the one found by `../../bd-shared/session-start.md` step 4
(the one tool whose name ends in `__getVisibleJiraProjects`); the project key is `tracker.team` from the binding.
Discover the Jira tools at runtime with ToolSearch (`jira search jql`, `jira get issue`,
`jira transition issue`, `jira edit issue`, `jira add comment`). Two distinct status concepts:
`AI-Implement Status` (the orchestrator's custom-field state machine: `Ready →
Planning → Awaiting Approval → Plan Approved → Implementing → PR Ready`) and the
issue's **native workflow status** (whose `statusCategory` is `done` when
complete). `Awaiting Approval` only appears when the mapping's `autoApprovePlans`
is `false` (check `list_projects`); a person then sets `Plan Approved` to start
implementation. Completion means the native status, not the custom field. The
values a person ever sets by hand are **`Ready`** and **`Plan Approved`** (the
latter only when `autoApprovePlans` is `false`) — `Planning`/`Implementing`/`PR
Ready` are orchestrator-owned; hand-setting them hides the issue from pickup and
burns a concurrency slot (they count as in-flight work). To hold an issue, leave
the field unset.

## Issue scan & states
Scan via JQL on `AI-Implement Status`, within the mapping's scope JQL. Use the
field's `cf[NNNNN]` id (see **Field discovery** in
`../../bd-shared/trackers/jira.md`) — some instances require `cf[N]` form and
reject the display name. Find the numeric id by calling Jira's field-list tool,
locating the entry whose `name` equals `AI-Implement Status`, and extracting the
number from `customfield_NNNNN`. If no field has that name, ask the operator for
the mapping's Status Field override id. Do **not** guess.

- **Ready for triage** (PR posted, gap analysis ready): `cf[NNNNN] = "PR Ready"`.
- **Pipeline working:** `cf[NNNNN] in (Planning, Implementing)`.
- **Pickup queue:** `cf[NNNNN] = Ready`.

## Pickup trigger
To release an issue for pickup: set `AI-Implement Status = Ready`, set the
`AI-Implement Repo` field to the mapping's Repo Field Value (a blank value means
the project's own `owner/repo` — confirm with the operator if unsure), and ensure
the issue satisfies the mapping's scope JQL. The {{IMPLEMENT_LABEL}} alone does
**not** trigger pickup — the Status field does. (Jira pickup is field-driven;
labels are not the signal — see `../../bd-shared/pickup-label.md` rule 5.)

## Post-merge completion
After build-down merges a PR, complete the linked Jira issue explicitly:

1. **Resolve the issue key** from the merged PR — the branch name and/or PR title
   carries the key (e.g. `PROJ-123`). Do not assume a PR↔issue link; resolve it.
2. **Check current native status.** Fetch the issue; if its `statusCategory` is
   already `done`, the integration fired — skip the transition (idempotent).
3. **Transition to Done.** Fire the Jira workflow transition whose target status
   has `statusCategory = done`. Jira has no generic "set status" — you must pick
   a *transition* available from the current status, resolved by target-status
   name. If the transition requires a resolution, set one (read available values;
   names vary per instance — do not hardcode). **If no `done`-category transition
   is available from the current status, or multiple are ambiguous, surface to
   the operator — do not guess.**
4. **Verify.** Re-fetch the issue and confirm `statusCategory === "done"`. If it
   did not transition, report it — this is exactly the unreliability this step
   exists to catch.
5. **Confirm dependents unblock.** Re-check the issues that this one *blocks* —
   the outward side of its `Blocks` links (a dependent's *inward* `Blocks` link is
   what `isBlockedByIncomplete` gates on). Now that it is `done` they are no longer
   blocked by it. Feed any newly eligible issues to **Unblock dependents** and record
   them in this issue's build-down learnings comment.

## Unblock dependents
For each issue that this one *blocks* (the outward side of its `Blocks` links) and
that now has all its blockers in a `done` status category: release it via **Pickup trigger**
(set `AI-Implement Status = Ready`). The orchestrator's next poll will include it
once `isBlockedByIncomplete` returns false.

## Follow-up filing
File a new Jira issue with the `AI-Implement Repo` field set and the
{{IMPLEMENT_LABEL}}. If this session has a build-up epic, parent the issue to it
(`parent = <epic>`); a standalone build-down with no epic skips the parent. For a
scoped fix that should be picked up now, set `AI-Implement Status = Ready`
(Pickup trigger). For planning or architect-routed work, leave `AI-Implement
Status` unset so the pipeline does not pick it up; assign the architect for
architectural findings. Custom-field IDs are instance-specific — read them from
the orchestrator mapping (see **Field discovery** in
`../../bd-shared/trackers/jira.md`).

## Issue URL & key
Issue key is resolved from the PR branch/title. User-facing URL is
`{siteUrl}/browse/{KEY}` (e.g. `https://<your-workspace>.atlassian.net/browse/PROJ-123`).

## Red flags (Jira-specific)
- **Trusting the integration to complete the issue.** → It's unreliable; always
  transition explicitly and re-fetch to verify `done`.
- **Treating `AI-Implement Status` as completion.** → It is not; only a native
  status transition to a `done` category completes the issue and unblocks
  dependents.
- **Generic "set status".** → Jira completes via a workflow *transition* resolved
  by target-status name; surface ambiguity instead of guessing.
- **Assuming the PR↔issue link.** → Resolve the issue key from the PR
  branch/title explicitly.
