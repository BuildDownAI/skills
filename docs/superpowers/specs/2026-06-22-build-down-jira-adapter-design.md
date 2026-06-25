# Build-Down — Tracker-Agnostic Core + Jira Adapter (Design)

**Date:** 2026-06-22
**Status:** Approved (design); implementation plan to follow.

## Objective

Make the `build-down` skill drive a build-down session against **either Linear
or Jira**, matching the tracker-agnostic structure introduced for
`mega-build-up`. Additionally, add a **Jira-specific post-merge completion
safeguard**: when build-down merges a PR, it must explicitly and verifiably
transition the linked Jira issue to a Done status, because the Jira↔GitHub
integration is unreliable at auto-completing issues on merge.

## Background — why completion matters in Jira

In Jira there are two independent status concepts:

- **`AI-Implement-Status`** — the orchestrator's own custom-field state machine
  (`Ready` → `Planning` → `Plan Approved` → `Implementing` → `PR Ready`). Its
  terminal value is `PR Ready`; **the orchestrator never marks completion.** (See
  `STATUS_VALUES` in `ai-implement/src/providers/jira-fields.ts`.)
- The issue's **native workflow status**, whose `statusCategory.key` becomes
  `done` when the issue is completed. This is the real completion signal.

When a PR merges, an external integration is supposed to transition the native
status to Done. In Linear the Linear↔GitHub integration does this reliably; in
Jira it is unreliable. The consequence has teeth beyond a stale-looking board:
the orchestrator's dependency gate `isBlockedByIncomplete`
(`ai-implement/src/providers/jira.ts:78`) only stops blocking
dependents once the blocker's `statusCategory` is `done`. **A merged-but-not-Done
Jira issue silently keeps its dependents blocked, stalling the pipeline.**

So build-down — which already owns the post-merge "move the issue to Done" step
(`build-down/SKILL.md:343`) — must, for Jira, perform that transition explicitly
and verify it rather than trusting the integration.

## Scope

**In v1:**
- Refactor `build-down/SKILL.md` into a tracker-neutral shared core.
- Add `build-down/trackers/linear.md` and `build-down/trackers/jira.md` adapters.
- Add a Tracker Selection step (build-down's Configuration already has
  `{{TRACKER}}`; make selection explicit and load the adapter).
- Add the Jira post-merge completion safeguard (transition → verify → unblock
  check) to the Jira adapter.

**Deferred:**
- `super-build-down` (shares build-down's mechanics; adopts the same adapters
  next, not in this change).
- `smoke-jumper`, `summit-push`, `build-up` — still Linear-coupled; out of scope.

**Out of scope:**
- Any change to the AI-Implement orchestrator code.
- Changing the Jira workflow itself (transition names, resolution config) — the
  adapter adapts to whatever the instance has.

## Architecture

Shared core + per-tracker adapter docs, mirroring `mega-build-up`. build-down's
core already uses generic verbs (`list_issues` / `get_issue` / `save_issue`) and
generic state words, so it is closer to neutral already — but the `{{TRACKER}}`
placeholder currently papers over the structural label-vs-field difference
(Linear "Todo + label" vs Jira "`AI-Implement-Status` field"). The split makes
that explicit.

### File layout

```
build-down/
  SKILL.md            # tracker-neutral core: triage, gap-analysis, merge, summary
  trackers/
    linear.md         # Linear mechanics
    jira.md           # Jira mechanics + post-merge completion safeguard
```

### Seam set

build-down touches the tracker differently than mega-build-up (it triages,
merges, completes, and files follow-ups rather than filing a project), so it has
its own seam set. Seam names reused from the mega-build-up adapters where they
genuinely match, so a reader who knows one adapter recognizes the shared seams.

| Seam | Linear | Jira |
|---|---|---|
| MCP & discovery | `linear-<workspace>` | `atlassian-<workspace>` (ToolSearch for Jira tools at runtime) |
| Issue scan & states | `list_issues` by `In Progress` / `In Review` / `Todo`+label | JQL by `AI-Implement-Status` values + native status |
| Pickup trigger | `Todo` + `{{IMPLEMENT_LABEL}}` | `AI-Implement-Status = Ready` + repo field + mapping JQL |
| Post-merge completion | rely on Linear↔GitHub auto-close; fallback move to `Done` | **explicit idempotent transition to Done + verify + unblock check** (below) |
| Unblock dependents | `blockedBy` cleared → set `Todo` + label | set `AI-Implement-Status = Ready` on now-unblocked issues |
| Follow-up filing | `Todo` / `Backlog` + label | `AI-Implement-Status` + repo field + epic parent |
| Issue URL / key | Linear URL | `{siteUrl}/browse/{KEY}` |

The core's prose (gap-analysis triage, merge criteria, escalation rules, agent
comment templates, session summary) is tracker-neutral and stays in `SKILL.md`,
delegating only the tracker-touching lines to the active adapter by seam name.

## Post-merge completion procedure (Jira adapter)

After build-down merges a PR, the Jira **Post-merge completion** seam runs:

1. **Resolve the issue key** from the merged PR — the branch name and/or PR
   title carries the Jira key (e.g. `PROJ-123`). Do not assume a PR↔issue link;
   resolve the key explicitly.
2. **Check current native status.** If the issue's `statusCategory` is already
   `done`, the integration fired — skip the transition (idempotent; coexists with
   the integration when it works).
3. **Transition to Done.** Use the Jira MCP transition tool, resolving the
   transition by target-status name (Jira transitions are workflow-specific IDs,
   not a generic "set status"). Pick a transition whose target status has
   `statusCategory = done`. If the transition requires a resolution, set one;
   resolution names vary per instance, so read available values rather than
   hardcoding. **If no `done`-category transition is available from the current
   status, or multiple candidates are ambiguous, surface to the operator — do
   not guess.**
4. **Verify.** Re-fetch the issue and confirm `statusCategory === "done"`. If the
   transition silently failed, report it (the unreliability this safeguard
   exists to catch).
5. **Confirm dependents unblock.** Re-check issues `Blocks`-linked to this one;
   now that it is `done`, they are no longer blocked by it. Note any that are now
   eligible — this feeds the session summary's "Unblocked Work" section and the
   core's unblock-dependents step.

This directly targets the pipeline-stall risk: an un-completed blocker keeps its
dependents skipped by `isBlockedByIncomplete`.

## Linear parity

Linear behavior is unchanged. The Linear adapter's Post-merge completion seam
keeps relying on the Linear↔GitHub integration to auto-close the issue, with the
core's existing "move to Done" as a fallback. No new behavior is imposed on
Linear users.

## Components & responsibilities

- **`SKILL.md`** — triage logic, gap-analysis handling, merge criteria,
  escalation rules, comment templates, session summary, key principles. Neutral;
  delegates tracker-touching steps to the active adapter by seam name.
- **`trackers/linear.md`** — Linear mechanics for each seam (extracted/expressed
  from the current inline Linear assumptions).
- **`trackers/jira.md`** — Jira mechanics for each seam, plus the post-merge
  completion safeguard and the Jira gotchas.

## Jira gotchas (surface as red flags in the adapter)

- **Transition-by-name, not status-set.** Jira has no generic "set status"; you
  fire a workflow transition whose target is a `done`-category status. Resolve it
  by target name; surface ambiguity instead of guessing.
- **Resolution may be required.** Some workflows require a resolution on the Done
  transition. Read available values; don't hardcode.
- **Don't assume the PR↔issue link.** Resolve the issue key from the PR
  branch/title explicitly.
- **Verify, don't trust.** The whole reason this seam exists is that the
  auto-integration is unreliable — always re-fetch and confirm `done`.
- **`AI-Implement-Status` ≠ completion.** Setting the custom field does not
  complete the issue; only a native-status transition to a `done` category does.

## Testing / validation

No automated tests (prose skill files). Validation is:
1. **Linear parity** — the refactored core + `linear.md` give a Linear operator
   the same instructions as today; the post-merge step still defers to the
   Linear integration.
2. **Seam coverage** — every tracker-touching pointer in the core resolves to a
   seam section present in both adapters.
3. **Jira dry-run walkthrough** — on a real merged Jira PR: resolve the key,
   transition to Done, re-fetch to confirm `done`, and confirm a dependent
   becomes eligible.

## Open questions

None blocking. `super-build-down` adoption and the rest of the family are
explicitly deferred.
