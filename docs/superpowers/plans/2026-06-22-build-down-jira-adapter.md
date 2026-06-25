# Build-Down Jira Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `build-down` drive a session against Linear or Jira via a tracker-neutral core + per-tracker adapter docs, and add a Jira post-merge completion safeguard (transition issue to Done, verify, unblock dependents).

**Architecture:** Split `build-down/SKILL.md` into a tracker-neutral core that delegates tracker-touching steps to `build-down/trackers/linear.md` and `build-down/trackers/jira.md` by named seam — mirroring the mega-build-up adapter pattern. The Jira adapter's **Post-merge completion** seam encodes the explicit transition-to-Done safeguard.

**Tech Stack:** Markdown skill files only. No code, no build step. "Tests" are grep/diff/read-through validation checks.

## Global Constraints

- Files: `build-down/SKILL.md` and `build-down/trackers/{linear,jira}.md`. Scope is **build-down only** — do not touch `super-build-down`, `smoke-jumper`, `summit-push`, `build-up`, or `mega-build-up`.
- build-down's seam set (each adapter documents these as `## ` sections, in order): **MCP & discovery · Issue scan & states · Pickup trigger · Post-merge completion · Unblock dependents · Follow-up filing · Issue URL & key**.
- Linear behavior must be **unchanged**: the Linear adapter's Post-merge completion keeps relying on the Linear↔GitHub auto-close with the core's existing "move to Done" as fallback.
- The Jira Post-merge completion procedure is **idempotent** (skip if already `done`), **verifies** by re-fetch, and **surfaces ambiguity to the operator** rather than guessing the transition.
- `AI-Implement-Status` (custom field) is the orchestrator state machine; the issue's **native workflow status** (`statusCategory = done`) is the real completion signal. These are distinct.
- Work happens on branch `build-down-jira-adapter` (already created).

---

### Task 1: Extract the Linear adapter

Create `build-down/trackers/linear.md` capturing the Linear mechanics for build-down's 7 seams. This task **only creates `linear.md`** — `SKILL.md` is neutralized in Task 2. Content is drawn from the current Linear-specific assumptions in `SKILL.md` so Linear behavior is preserved.

**Files:**
- Create: `build-down/trackers/linear.md`
- Read (source): `build-down/SKILL.md`

**Interfaces:**
- Produces: `trackers/linear.md` with one `## ` section per seam, named exactly per Global Constraints. Tasks 2 and 3 rely on these exact names.

**Source-region → seam map** (draw the Linear mechanics from these `SKILL.md` regions):

| Seam | Source in `SKILL.md` |
|---|---|
| MCP & discovery | Environment detection — the tracker MCP (Linear) |
| Issue scan & states | Phase 1 tracker scan: `list_issues` by `In Progress` / `In Review` / `Todo`+`{{IMPLEMENT_LABEL}}` |
| Pickup trigger | Pipeline context + Conventions: `state: Todo` + `{{IMPLEMENT_LABEL}}` |
| Post-merge completion | Phase 4: rely on Linear↔GitHub auto-close; fallback "Move the linked tracker issue to `Done`" |
| Unblock dependents | Phase 4: `blockedBy` cleared → set `Todo` + `{{IMPLEMENT_LABEL}}` |
| Follow-up filing | Phase 5: `Todo` / `Backlog` + `{{IMPLEMENT_LABEL}}` by filing context |
| Issue URL & key | Linked issue ID from branch/PR title; Linear issue URL |

- [ ] **Step 1: Create `trackers/linear.md` with header + 7 seam skeleton**

```markdown
# Build-Down — Linear Tracker Adapter

The core (`../SKILL.md`) delegates tracker-touching steps to this file when
`{{TRACKER}}` is Linear. Section names match the core's seam references exactly.

## MCP & discovery
## Issue scan & states
## Pickup trigger
## Post-merge completion
## Unblock dependents
## Follow-up filing
## Issue URL & key
```

- [ ] **Step 2: Fill each seam from the mapped source**

Write the Linear mechanics into each section, faithful to current `SKILL.md` behavior:
- **MCP & discovery:** Linear MCP (`linear-cloudshare`); `list_issues` / `get_issue` / `save_issue`.
- **Issue scan & states:** `list_issues` filtered by `state: "In Progress"`, `state: "In Review"`, and `state: "Todo"` + label `{{IMPLEMENT_LABEL}}`. In Review = ready for triage; In Progress = pipeline working.
- **Pickup trigger:** `state: Todo` + `{{IMPLEMENT_LABEL}}` = picked up within minutes. `save_issue` with `id` to update; label arrays replace (pass the full list).
- **Post-merge completion:** The Linear↔GitHub integration auto-closes the linked issue when its PR merges. As a fallback, set the issue `state: Done` via `save_issue`. No verification step is required — the integration is reliable.
- **Unblock dependents:** After merge, for each issue whose `blockedBy` is now fully cleared, set `state: Todo` + `{{IMPLEMENT_LABEL}}` to release it.
- **Follow-up filing:** `save_issue` with `state: Todo` + `{{IMPLEMENT_LABEL}}` for scoped fixes (pipeline picks up); `state: Backlog` for planning; architect-routed = `Backlog`, assigned, no `{{IMPLEMENT_LABEL}}`.
- **Issue URL & key:** Linked issue ID comes from the PR branch name or title; use the Linear issue URL for comments/summaries.

- [ ] **Step 3: Validate**

Run:
```bash
cd /Users/cameronpope/source/BuildDownAI/skills
grep -c '^## ' build-down/trackers/linear.md          # expect 7
grep -nE 'In Review|state: Todo|Linear↔GitHub|blockedBy' build-down/trackers/linear.md   # expect hits
```
Expected: `7` seam headings; hits confirming the Linear mechanics landed.

- [ ] **Step 4: Commit**

```bash
git add build-down/trackers/linear.md
git commit -m "Extract Linear mechanics into build-down/trackers/linear.md

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Neutralize the core SKILL.md

Make `build-down/SKILL.md` delegate tracker-touching steps to the active adapter. Add a Tracker Selection block (Configuration already defines `{{TRACKER}}`). Keep all neutral prose (triage, gap-analysis, merge criteria, escalation, comment templates, session summary).

**Files:**
- Modify: `build-down/SKILL.md`

**Interfaces:**
- Consumes: the 7 seam section names from Task 1.
- Produces: a neutral core whose pointers Task 3's `jira.md` must also satisfy.

- [ ] **Step 1: Add a Tracker Selection block to Environment detection**

After the "Opening declaration" line in `## Environment and Pipeline Context` → `### Environment detection`, insert:

```markdown
### Tracker Selection

Pick the active tracker at session start and load its adapter:

- Infer `{{TRACKER}}` from the connected MCP / orchestrator mapping (`linear-cloudshare` → Linear, `atlassian-cloudshare` → Jira). If ambiguous, ask once.
- Read `trackers/<tracker>.md`. Every tracker-touching step below (issue scan, pickup trigger, post-merge completion, unblock, follow-up filing) follows that adapter's matching `## ` section.
- State the tracker in the opening declaration.
```

- [ ] **Step 2: Replace inline Linear mechanics with adapter pointers**

Make these exact substitutions (surrounding prose stays):

- **Pipeline context** (`### The AI coding agent pipeline`): the bullet "When an issue is in **Todo** with the `{{IMPLEMENT_LABEL}}` label → the agent picks it up within minutes" → "When an issue carries the pickup signal (per the active adapter's **Pickup trigger** section) → the agent picks it up within minutes". Leave the In Progress / In Review *concepts* but append "(exact states per the active adapter's **Issue scan & states** section)" to the working/In-Review bullet.
- **Phase 1 tracker scan:** replace the three `list_issues` state-filter bullets with: "Scan the tracker per the active adapter's **Issue scan & states** section (working state, ready-for-triage state, and the pickup queue)."
- **Phase 4 Merge Execution**, the post-merge bullets: replace "Move the linked tracker issue to `Done`" → "Complete the linked issue per the active adapter's **Post-merge completion** section." Replace the "Check if the merge unblocks any `blockedBy` issues — update those to `Todo`…" bullet → "Release any issues the merge unblocks, per the active adapter's **Unblock dependents** section."
- **Phase 5 Follow-up filing:** keep the intent (scoped → pickup-ready; planning → parked; architectural → parked + architect). Replace the concrete `state: Todo`/`Backlog` + label mechanics in the "Filing context matters" list with "...per the active adapter's **Follow-up filing** section" while preserving which *context* maps to pickup-ready vs parked.
- **Key Principles #3:** "Discovery in build-down → Todo + `{{IMPLEMENT_LABEL}}` if scoped. Backlog only for planning." → "Discovery in build-down → pickup-ready (per the active adapter) if scoped. Parked only for planning."
- **Conventions:** replace the "**Tracker MCP patterns (assuming Linear-style):**" block (the `save_issue`/label/`state:` bullets) with: "**Tracker MCP patterns:** see the active adapter's **MCP & discovery**, **Pickup trigger**, and **Issue scan & states** sections." Keep the Label conventions, Routing rules, and Migration context blocks (they are tracker-neutral).

- [ ] **Step 3: Validate — no Linear-only state mechanics remain in the core**

Run:
```bash
cd /Users/cameronpope/source/BuildDownAI/skills
grep -nE 'state: "?Todo"?|state: "?In Review"?|assuming Linear-style|Move the linked tracker issue to `Done`' build-down/SKILL.md
```
Expected: **no output**.

Run:
```bash
grep -nE 'active adapter|Tracker Selection|trackers/' build-down/SKILL.md
```
Expected: multiple hits.

- [ ] **Step 4: Validate — neutral prose preserved**

Read through `SKILL.md`: confirm gap-analysis triage (Phase 2), merge criteria (Phase 4), escalation rules (2d/2e), agent comment templates (Phase 3), and the session summary (Phase 6) are intact and unaltered. Confirm every tracker-touching step now points to a real seam in `linear.md`.

- [ ] **Step 5: Commit**

```bash
git add build-down/SKILL.md
git commit -m "Neutralize build-down core; delegate tracker mechanics to adapters

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Write the Jira adapter

Create `build-down/trackers/jira.md` with the same 7 seams as `linear.md`, the post-merge completion safeguard, and the Jira gotchas.

**Files:**
- Create: `build-down/trackers/jira.md`

**Interfaces:**
- Consumes: the core's seam references (must satisfy the same `## ` section names as `linear.md`).

- [ ] **Step 1: Create `trackers/jira.md` with the full content below**

````markdown
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
````

- [ ] **Step 2: Validate — seam parity with the Linear adapter**

Run:
```bash
cd /Users/cameronpope/source/BuildDownAI/skills
diff <(grep '^## ' build-down/trackers/linear.md) <(grep '^## ' build-down/trackers/jira.md | grep -v 'Red flags')
```
Expected: **no output** (the 7 canonical seams are identical and ordered; `## Red flags (Jira-specific)` is an accepted extra section).

- [ ] **Step 3: Validate — completion safeguard present**

Run:
```bash
grep -nE 'statusCategory|transition|Re-fetch|surface to the operator|isBlockedByIncomplete' build-down/trackers/jira.md
```
Expected: hits confirming the 5-step procedure (idempotent check, transition, verify, unblock) and the gotchas are present.

- [ ] **Step 4: Commit**

```bash
git add build-down/trackers/jira.md
git commit -m "Add Jira tracker adapter for build-down with post-merge completion safeguard

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- Shared core + adapters → Tasks 1–3. ✓
- 7-seam set in both adapters → Task 1 skeleton + Task 3 content (verified by Task 3 Step 2 diff). ✓
- Tracker Selection → Task 2 Step 1. ✓
- Post-merge completion (resolve key · idempotent skip · transition-by-name · verify · unblock) → `jira.md` Post-merge completion. ✓
- Surface-don't-guess on ambiguous transition → `jira.md` step 3 + red flag. ✓
- Linear parity (auto-close + Done fallback, no verification imposed) → `linear.md` Post-merge completion + Task 2 preserves neutral prose. ✓
- `AI-Implement-Status` ≠ completion → `jira.md` MCP & discovery + red flag. ✓
- Scope = build-down only → Global Constraints. ✓

**2. Placeholder scan:** No "TBD/TODO/handle edge cases". Task 1 names exact source regions; Task 3 gives full `jira.md` content; Task 2 gives exact substitutions. ✓

**3. Type/name consistency:** Seam section names identical across Global Constraints, Task 1 skeleton, Task 2 pointers, and Task 3 content (verified by Task 3 Step 2 diff). Status concepts (`AI-Implement-Status` field vs native `statusCategory = done`) named consistently across spec and adapter. ✓
