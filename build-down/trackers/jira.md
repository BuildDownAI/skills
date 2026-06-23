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
Use the `atlassian-cloudshare` MCP. Discover the Jira tools at runtime with
ToolSearch (`jira search jql`, `jira get issue`, `jira transition issue`,
`jira edit issue`, `jira add comment`). Two distinct status concepts:
`AI-Implement-Status` (the orchestrator's custom-field state machine: Ready →
Planning → Plan Approved → Implementing → PR Ready) and the issue's **native
workflow status** (whose `statusCategory` is `done` when complete). Completion
means the native status, not the custom field.

## Issue scan & states
Scan via JQL on `AI-Implement-Status`, within the mapping's scope JQL:
- **Ready for triage** (PR posted, gap analysis ready): `AI-Implement-Status = "PR Ready"`.
- **Pipeline working:** `AI-Implement-Status in (Planning, Implementing)`.
- **Pickup queue:** `AI-Implement-Status = Ready`.
Reference the field by its resolved `cf[NNNNN]` id (instance-specific — read from
the orchestrator mapping), not the display name.

## Pickup trigger
To release an issue for pickup: set `AI-Implement-Status = Ready`, set the Repo
field to the mapping's `repoFieldValue`, and ensure the issue satisfies the
mapping's scope JQL. The `AI-Implement` label alone does **not** trigger pickup —
the Status field does.

## Post-merge completion
After build-down merges a PR, complete the linked Jira issue explicitly:

1. **Resolve the issue key** from the merged PR — the branch name and/or PR title
   carries the key (e.g. `BAC-123`). Do not assume a PR↔issue link; resolve it.
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
5. **Confirm dependents unblock.** Re-check issues `Blocks`-linked to this one;
   now that it is `done` they are no longer blocked by it. Feed any newly
   eligible issues to **Unblock dependents** and the session summary's "Unblocked
   Work".

## Unblock dependents
For each issue that was `Blocks`-linked to the just-completed issue and now has
all its blockers in a `done` status category: release it via **Pickup trigger**
(set `AI-Implement-Status = Ready`). The orchestrator's next poll will include it
once `isBlockedByIncomplete` returns false.

## Follow-up filing
File a new Jira issue as a child of the build-up epic (`parent = <epic>`), with
the Repo field set and the `AI-Implement` label. For a scoped fix that should be
picked up now, set `AI-Implement-Status = Ready` (Pickup trigger). For planning
or architect-routed work, leave `AI-Implement-Status` unset so the pipeline does
not pick it up; assign the architect for architectural findings. Custom-field IDs
are instance-specific — read them from the orchestrator mapping.

## Issue URL & key
Issue key is resolved from the PR branch/title. User-facing URL is
`{siteUrl}/browse/{KEY}` (e.g. `https://cloudshare.atlassian.net/browse/BAC-123`).

## Red flags (Jira-specific)
- **Trusting the integration to complete the issue.** → It's unreliable; always
  transition explicitly and re-fetch to verify `done`.
- **Treating `AI-Implement-Status` as completion.** → It is not; only a native
  status transition to a `done` category completes the issue and unblocks
  dependents.
- **Generic "set status".** → Jira completes via a workflow *transition* resolved
  by target-status name; surface ambiguity instead of guessing.
- **Assuming the PR↔issue link.** → Resolve the issue key from the PR
  branch/title explicitly.
