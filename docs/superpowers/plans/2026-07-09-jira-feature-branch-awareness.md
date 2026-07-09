# Jira feature-branch awareness across the BuildDown skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reverse the now-wrong "Jira: no grouping" caveats across the BuildDown skills and write the Jira feature-branch grouping mechanism at parity with Linear, so the plugin serves correct guidance to downstream Jira consumers.

**Architecture:** Doc-first (mirror BDS-12). Rewrite the canonical operator doc `docs/feature-branch-grouping.md` first, then mirror its language into (a) the `bd-mega-build-up` adapter split — core `SKILL.md` + new `## Feature-node grouping` sections in `trackers/linear.md` and `trackers/jira.md`, and (b) the single-file skills' stale caveat lines. Behavior-changing Jira prose is RED/GREEN subagent-tested the way #24 tested the Linear rules. Close with the mandatory plugin version bump and a grep gate proving no stale caveats survive.

**Tech Stack:** Markdown skill files only. No code, no build step. Validation is (1) `grep` for residual stale caveats and (2) a subagent behavioral eval for the two behavior-changing Jira rules.

**Source spec:** `docs/superpowers/specs/2026-07-01-jira-feature-branch-awareness-design.md` (Approved). Read it before starting — this plan implements its §5 file list.

## Global Constraints

- **Terminology (verbatim, itself a self-review gate):** feature node · feature branch (`ai-implement/feature/<key>`) · child PR · internal roll-up (direct `git merge`, no PR) · top-of-tree PR (`[ai-implement] Feature branch ready for review`) · roll-up conflict · race guard · **Default Branch** (never "main"). Fixed commit string `[ai-implement] Automated feature-branch roll-up` and PR title `[ai-implement] Feature branch ready for review` stay exact.
- **Source of truth:** Upstream AI-Implement wins on any conflict — `src/providers/jira.ts`, `src/providers/jira-hierarchy.ts`, `src/providers/jira-fields.ts`, `src/feature-branch.ts`, `src/merge-up.ts`, `src/pipeline/branch-name.ts`, and AI-Implement's own `docs/feature-branch-grouping.md`.
- **Two Jira predicates, never conflate them:** *candidate eligibility* (dispatched this poll) = `AI-Implement-Status` ∈ {`Ready`, `Plan Approved`} + Repo match. *Group designation* (child gating, ancestor-chain membership, roll-up, auto-merge-parent) = `AI-Implement-Status` **set to any non-empty value** + Repo match. Grouping tracks a child through its whole non-empty-status lifecycle — do **not** tell operators grouping requires Status = Ready.
- **Jira hierarchy:** `effectiveParentKey = native parent ?? Epic Link`. Tracking **Epics MUST stay un-designated** (never set `AI-Implement-Status` on the container Epic) — designating one collapses the whole epic into a single feature branch (explicit anti-pattern).
- **Jira terminal:** `fields.status.statusCategory.key === 'done'` (subsumes Done/Closed and Won't-Do/Cancelled).
- **Depth cap:** ancestor chains are capped at depth 5 on both providers.
- **Version bump is mandatory in this same PR:** `plugin/.claude-plugin/plugin.json` `0.6.0 → 0.7.0`. It is the only signal `/plugin update` reads.
- All paths below are relative to `/Users/cameronpope/source/BuildDownAI/skills`.

---

### Task 1: Rewrite the pilot doc `docs/feature-branch-grouping.md`

This is the source every skill mirrors. Do it first and completely; later tasks copy its language.

**Files:**
- Modify: `docs/feature-branch-grouping.md`

**Interfaces:**
- Produces: the tracker-neutral mental model, the **"Designation & hierarchy per tracker"** subsection, the Jira terminal/roll-up/failure-mode language, and the depth-5 cap — all of which Tasks 2–6 quote or point to.

- [ ] **Step 1: Reverse the intro (lines 3–5) to be tracker-neutral**

Replace:
```
How AI-Implement turns a Linear parent/child issue tree into a cascade of git branches, and what
that means when you **plan** work (bd-build-up / bd-mega-build-up / bd-summit-push) and **land** it
(bd-build-down / bd-super-build-down / bd-smoke-jumper).
```
with:
```
How AI-Implement turns a parent/child issue tree — on **either** the Linear or the Jira provider — into a
cascade of git branches, and what that means when you **plan** work (bd-build-up / bd-mega-build-up /
bd-summit-push) and **land** it (bd-build-down / bd-super-build-down / bd-smoke-jumper).
```

- [ ] **Step 2: Reverse the "Linear-only" callout (lines 12–15)**

Replace the entire blockquote:
```
> **Linear-only.** Feature-branch grouping exists only on the Linear provider. On Jira there is no
> grouping: every `AI-Implement` issue PRs straight to the **Default Branch** (the repo's configured
> default — `mapping.defaultBranch`, e.g. `testing`; **not** necessarily `main`), and everything below is
> moot. The skills' grouping sections all carry this caveat.
```
with:
```
> **Both providers.** Feature-branch grouping exists on **both** the Linear and the Jira providers (Jira
> reached parity in AI-Implement #64). What differs is only *how an issue joins a group* — see
> "Designation & hierarchy per tracker" below. "Default Branch" throughout means the repo's configured
> default — `mapping.defaultBranch`, e.g. `testing`; **not** necessarily `main`.
```

- [ ] **Step 3: Add the "Designation & hierarchy per tracker" subsection**

Immediately after the `## 1. Mental model` block (after the code fence that ends at line 40, before `## 2.`), and change the opening sentence of §1 first. Replace line 21:
```
A Linear issue tree maps onto a tree of git branches.
```
with:
```
An issue tree — Linear or Jira — maps onto a tree of git branches.
```
Then insert this new subsection between the §1 code fence and `## 2. What changes vs the flat model`:
```

### Designation & hierarchy per tracker

"Feature node," "child," and "terminal" mean the same *shape* on both providers; only the predicate that
puts an issue into a group differs.

| | **Linear** | **Jira** |
|---|---|---|
| **Group designation** (counts toward grouping: gates its parent, joins the ancestor chain, rolls up, can be an auto-merge parent) | carries the `AI-Implement` **label** | `AI-Implement-Status` **set to any non-empty value** *and* Repo field = the mapping's `repoFieldValue` |
| **Candidate dispatch** (worked *this* poll) | `state: Todo` + `AI-Implement` label | `AI-Implement-Status` ∈ {`Ready`, `Plan Approved`} + Repo match |
| **Hierarchy source** | native parent / children | `effectiveParentKey = native parent ?? Epic Link` |
| **Terminal** | issue is Done or Cancelled | `fields.status.statusCategory.key === 'done'` (Done/Closed + Won't-Do/Cancelled) |

**The Jira designation predicate is broader than dispatch.** A child that has already moved on to
`Implementing` / `PR Ready` / `Done` is *still designated* for grouping — so a parent whose designated
children are all terminal is **feature-node-ready**, not "no children designated → skip." A child left with
`AI-Implement-Status` **unset** (or the wrong Repo value) is **invisible to the group**: it neither gates
its parent nor rolls up — it just quietly PRs to the Default Branch on its own.

**Jira Epics stay un-designated.** A tracking Epic is a long-lived container, never a feature branch. The
ancestor walk stops at the first un-designated ancestor, so an un-designated Epic halts the walk and the
designated Story below it is the top of the tree. **Never set `AI-Implement-Status` on the container Epic** —
doing so collapses the entire epic into one feature branch (anti-pattern).
```

- [ ] **Step 4: Make classification (line 56) tracker-neutral and fix "Terminal" (line 66)**

Replace line 56:
```
Each poll, AI-Implement classifies every `AI-Implement`, non-terminal issue:
```
with:
```
Each poll, AI-Implement classifies every **designated**, non-terminal issue (designation per the table
above — the `AI-Implement` label on Linear, a non-empty `AI-Implement-Status` + Repo match on Jira):
```
Then replace line 66:
```
"Terminal" means **Done or Cancelled** — a cancelled child doesn't block its parent forever.
```
with:
```
"Terminal" means **Done or Cancelled** (on Jira, any status whose `statusCategory` is `done`) — a cancelled
child doesn't block its parent forever.
```
Also update the race-guard bullet (line 62) to be designation-neutral. Replace:
```
- **Parent with children but none labelled `AI-Implement` yet** → **race guard**: skipped, *not* worked
  as a leaf. This is why you can label a whole tree at once (or top-down) without the parent being
  implemented prematurely.
```
with:
```
- **Parent with children but none *designated* yet** → **race guard**: skipped, *not* worked as a leaf.
  This is why you can designate a whole tree at once (or top-down) without the parent being implemented
  prematurely. ("Designate" = apply the `AI-Implement` label on Linear, or set `AI-Implement-Status` + Repo
  on Jira.)
```

- [ ] **Step 5: Tag the roll-up "why no PR" rationale per tracker (lines 79–81)**

Replace:
```
  identifier). *Why no PR:* a roll-up PR's base name and title encode the parent's key, so Linear's
  GitHub integration would auto-link it and mark the parent **Done on merge — before its own closing
  work runs.** A plain merge commit gives Linear nothing to link.
```
with:
```
  identifier). *Why no PR:* a roll-up PR's base name and title encode the parent's key, so the tracker's
  GitHub integration would auto-link it and mark the parent **Done on merge — before its own closing work
  runs** (Linear's GitHub integration; the Jira analog is Smart Commits / GitHub-for-Jira). A plain,
  identifier-free merge commit gives the integration nothing to link.
```

- [ ] **Step 6: Add the depth-5 cap and the Jira failure-mode split**

At the end of `## 3. Classification & the race guard` (after the "Planning consequence" paragraph at line 70), append:
```

**Depth cap & failure modes.** Ancestor chains are capped at **depth 5** on both providers. On Jira the two
queries fail in opposite directions by design: the **gating-children** query fails **closed** (a transient
Jira error defers the whole candidate batch that poll, so a feature-node parent never dispatches its closing
work onto base ahead of its children), while the **branch-targeting ancestor walk** fails **open** (nesting
collapses — a leaf then targets the Default Branch, a feature node still gets its own branch cut from the
Default Branch, only losing its position under any ancestor). Branch resolution always fails open to the
Default Branch.
```

- [ ] **Step 7: Reverse the §5 table row and the §6 boundaries**

In the §5 table, replace the mega/build-up row:
```
| **bd-mega-build-up / bd-build-up** | Plan parent + children as a feature node; the parent's closing work is `Blocked by:` all children; whole-tree labelling is race-guard-safe; children PR into the feature branch. |
```
with:
```
| **bd-mega-build-up / bd-build-up** | Plan parent + children as a feature node; the parent's closing work is `Blocked by:` all children; whole-tree **designation** is race-guard-safe; children PR into the feature branch. Linear designates by label; Jira by `AI-Implement-Status` + Repo (canonical shape: a Story with sub-task children under an un-designated tracking Epic). |
```
Then replace the §6 first bullet (line 104):
```
- **Linear-only** — Jira always PRs to the Default Branch; no grouping.
```
with:
```
- **Both providers.** Grouping works on Linear and Jira. The only per-tracker difference is designation +
  hierarchy (see the table in §1). An issue that isn't designated on its tracker falls back to the flat
  model (PRs to the Default Branch) — that's the graceful degradation, not a provider limitation.
```
And in the §6 "Workflows must accept `base_branch`" bullet (lines 105–109), change "The target repo's" prerequisite to note it applies to Jira target repos too — replace `**re-sync workflows before relying on grouping**` with `**re-sync workflows before relying on grouping (on either tracker's target repos)**`.

- [ ] **Step 8: Extend §7 upstream source list**

Replace the §7 list (lines 115–118) with:
```
- `BuildDownAI/AI-Implement` → `docs/feature-branch-grouping.md` (full operator/developer reference)
- `src/feature-branch.ts` — `resolveBaseBranch` (cascade branch creation + PR-base resolution)
- `src/merge-up.ts` — `runMergeUps` (internal direct merge vs top-of-tree human PR)
- `src/pipeline/branch-name.ts` — `buildFeatureBranchName` (`ai-implement/feature/<key-slug>`)
- `src/providers/jira.ts` — `enrichFeatureBranches` + `fetchFeatureNodeRollUps` (Jira designation, gating, roll-up discovery)
- `src/providers/jira-hierarchy.ts` — `classifyByChildren`, `ancestorChain` (Jira feature-node shape + chain walk)
```

- [ ] **Step 9: Self-check the doc**

Run: `grep -ni "linear-only\|linear only\|no grouping\|always PRs to" docs/feature-branch-grouping.md`
Expected: **no output** (all stale caveats gone).
Run: `grep -c "Default Branch" docs/feature-branch-grouping.md` — expect a non-zero count and verify no bare "main" crept in with `grep -n "\bmain\b" docs/feature-branch-grouping.md` (only acceptable in the "not necessarily main" phrasing).

- [ ] **Step 10: Commit**

```bash
git add docs/feature-branch-grouping.md
git commit -m "docs(feature-branch-grouping): reverse Linear-only; add Jira designation & hierarchy"
```

---

### Task 2: `bd-mega-build-up/SKILL.md` core caveat reversal

**Files:**
- Modify: `plugin/skills/bd-mega-build-up/SKILL.md` (lines 54, 94, 132, 386, 560)

**Interfaces:**
- Consumes: the doc's designation model (Task 1).
- Produces: the core's `## Feature-node grouping` seam reference that Tasks 3 and 4 satisfy in the adapters.

- [ ] **Step 1: Pipeline implication #5 (line 54) — drop "(Linear only)" / "(Jira: no grouping…)"**

Replace:
```
5. **Parent/child trees become feature nodes (Linear only).** A parent issue labelled `{{IMPLEMENT_LABEL}}` with `{{IMPLEMENT_LABEL}}` children becomes a *feature node* owning `ai-implement/feature/<key>`; its children PR **into that feature branch**, not the **Default Branch**, and the tree rolls up to a single human-reviewed `feature → base` PR. Plan the tree, the labelling order, and the parent's deferred closing work accordingly. Full model: `docs/feature-branch-grouping.md`. (Jira: no grouping — every issue PRs to the Default Branch.)
```
with:
```
5. **Parent/child trees become feature nodes (both trackers).** A *designated* parent issue with designated children becomes a *feature node* owning `ai-implement/feature/<key>`; its children PR **into that feature branch**, not the **Default Branch**, and the tree rolls up to a single human-reviewed `feature → base` PR. Plan the tree, the designation order, and the parent's deferred closing work accordingly. "Designated" and the concrete filing mechanics are tracker-specific — see the active adapter's **Feature-node grouping** section; full model: `docs/feature-branch-grouping.md`.
```

- [ ] **Step 2: Hard Rule 10 (line 94) — drop the Jira exclusion**

Replace:
```
10. **Feature-node parents defer their own work (Linear feature-branch grouping).** When a plan uses a parent/child feature node, the parent's *own* closing work is `Blocked by:` **all** its labelled children — it dispatches only after every child is terminal (Done or Cancelled), onto the parent's own feature branch `ai-implement/feature/<key>`. Children PR **into the parent's branch**, never the reverse: a parent task that must merge to the Default Branch *before* its children is a grouping violation — split the parent's closing work out and block it on the children. (See `docs/feature-branch-grouping.md`. Jira: no grouping — ignore this rule.)
```
with:
```
10. **Feature-node parents defer their own work (both trackers).** When a plan uses a parent/child feature node, the parent's *own* closing work is `Blocked by:` **all** its designated children — it dispatches only after every child is terminal (Done/Cancelled; on Jira, `statusCategory` = done), onto the parent's own feature branch `ai-implement/feature/<key>`. Children PR **into the parent's branch**, never the reverse: a parent task that must merge to the Default Branch *before* its children is a grouping violation — split the parent's closing work out and block it on the children. Designation is the `{{IMPLEMENT_LABEL}}` label on Linear and a non-empty `AI-Implement-Status` + Repo match on Jira (active adapter's **Feature-node grouping** section). See `docs/feature-branch-grouping.md`.
```

- [ ] **Step 3: Tracker Selection seam list (line 132) — add "feature-node grouping"**

Replace:
```
- Read `trackers/{{TRACKER}}.md`. Every tracker-touching step below (overlap scan, container, doc home, pickup trigger, waves, dependencies, issue creation, status check) follows that adapter's matching `## ` section.
```
with:
```
- Read `trackers/{{TRACKER}}.md`. Every tracker-touching step below (overlap scan, container, doc home, pickup trigger, waves, dependencies, issue creation, status check, feature-node grouping) follows that adapter's matching `## ` section.
```

- [ ] **Step 4: Phase 3 feature-node bullet (line 386) — generalize "Label the parent LAST" → "designate the parent LAST"**

Replace:
```
- **Feature-node trees (Linear grouping).** Children of a feature node each PR into the *same* feature branch on isolated child branches, so they don't collide on base — they're **more** parallel-safe, not less (normal file-overlap rules still apply *within* the feature branch). Mark the parent's closing-work task `Blocked by:` every child. **Label the parent LAST — build the whole tree (children + parent relationships + every `blocks` relation) before any `{{IMPLEMENT_LABEL}}` label goes on, then label children first and the parent last of all.** The orchestrator's race guard only covers "parent labelled, *no* child labelled yet"; it does **not** cover "children labelled, relations not yet established" — label the parent into that window and the orchestrator classifies it as dispatchable and picks it up in parallel with its children (observed failure). See `docs/feature-branch-grouping.md`.
```
with:
```
- **Feature-node trees (both trackers).** Children of a feature node each PR into the *same* feature branch on isolated child branches, so they don't collide on base — they're **more** parallel-safe, not less (normal file-overlap rules still apply *within* the feature branch). Mark the parent's closing-work task `Blocked by:` every child. **Designate the parent LAST — build the whole tree (children + parent relationships + every `blocks`/`Blocks` relation) before any designation goes on, then designate children first and the parent last of all.** The orchestrator's race guard only covers "parent designated, *no* child designated yet"; it does **not** cover "children designated, relations not yet established" — designate the parent into that window and the orchestrator classifies it as dispatchable and picks it up in parallel with its children (observed failure). "Designate" is tracker-specific (Linear label vs Jira `AI-Implement-Status` + Repo) — see the active adapter's **Feature-node grouping** section and `docs/feature-branch-grouping.md`.
```

- [ ] **Step 5: Red Flag (line 560) — generalize off "labelled"**

Replace:
```
- **Feature-node parent labelled `{{IMPLEMENT_LABEL}}` before its children and their `blocks` relations exist.** → Labelling race: the orchestrator's guard only skips a parent when *no* child is labelled yet, so labelling the parent into the "children labelled, relations not yet set" window makes it dispatch in parallel with its children (observed). Build the whole tree first; label children, then the parent last (Phase 3 → parallel-execution awareness).
```
with:
```
- **Feature-node parent designated before its children and their `blocks`/`Blocks` relations exist.** → Designation race: the orchestrator's guard only skips a parent when *no* child is designated yet, so designating the parent into the "children designated, relations not yet set" window makes it dispatch in parallel with its children (observed). Build the whole tree first; designate children, then the parent last (Phase 3 → parallel-execution awareness). Designation = Linear label / Jira `AI-Implement-Status` + Repo (active adapter's **Feature-node grouping** section).
```

- [ ] **Step 6: Verify no stale core caveats remain**

Run: `grep -ni "linear only\|jira: no grouping\|jira: no group" plugin/skills/bd-mega-build-up/SKILL.md`
Expected: **no output**.

- [ ] **Step 7: Commit**

```bash
git add plugin/skills/bd-mega-build-up/SKILL.md
git commit -m "docs(bd-mega-build-up): make core feature-node prose tracker-neutral"
```

---

### Task 3: Add `## Feature-node grouping` to `trackers/linear.md`

This captures the Linear mechanics currently stranded in the core parentheticals, so the core can defer to it. It is the diff-parity peer the Jira section (Task 4) must match by `## ` heading.

**Files:**
- Modify: `plugin/skills/bd-mega-build-up/trackers/linear.md`

**Interfaces:**
- Produces: a `## Feature-node grouping` heading that the core's seam list (Task 2) references and that Task 5's heading-diff check compares against Jira.

- [ ] **Step 1: Append the section after `## Status check` (end of file)**

Append:
```

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
```

- [ ] **Step 2: Commit**

```bash
git add plugin/skills/bd-mega-build-up/trackers/linear.md
git commit -m "docs(bd-mega-build-up): add Linear Feature-node grouping adapter section"
```

---

### Task 4: Add `## Feature-node grouping` to `trackers/jira.md` + reconcile Container + red flag

The meatiest task: the new Jira grouping mechanism at parity with Linear. Its `## ` heading must match Task 3's.

**Files:**
- Modify: `plugin/skills/bd-mega-build-up/trackers/jira.md` (Container section lines 17–23; Red flags section; append new section)

**Interfaces:**
- Consumes: the doc's designation table + Global Constraints (two predicates, Epic-stays-un-designated, statusCategory-Done terminal).
- Produces: the `## Feature-node grouping` heading validated by Task 5.

- [ ] **Step 1: Add a grouping pointer + keep-Epic-un-designated rule to the Container section**

Replace the Container section (lines 17–23):
```
## Container
The container is a **Jira Epic** under a fixed Jira project (e.g. epic
`BAC-23858` in project `BAC`). Jira forbids epics-under-epics, so every bd-build-up
issue is a flat child with `parent = <epic key>`. Resolve or confirm the epic key
with the operator at session start; do not create a new project. If no epic
exists for this bd-build-up, create one Epic-type issue in the project and use it as
the parent.
```
with:
```
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
```

- [ ] **Step 2: Add the Jira grouping red flag**

Replace the Red flags section's first bullet block. Find:
```
## Red flags (Jira-specific)
- **Filed with the `AI-Implement` label but no `AI-Implement-Status = Ready`.** →
  Never picked up. Set the Status field.
```
Replace with:
```
## Red flags (Jira-specific)
- **Filed with the `AI-Implement` label but no `AI-Implement-Status = Ready`.** →
  Never picked up. Set the Status field.
- **Feature-node child filed without `AI-Implement-Status` set, or with the wrong Repo value.** →
  Silently **excluded from the group**: it neither gates its parent nor rolls up — it just quietly PRs to
  the Default Branch on its own. Designate every intended child (non-empty Status + matching Repo). "It's
  just a sub-task" and "the epic groups it" are the rationalizations that cause this.
- **`AI-Implement-Status` set on the container Epic.** → Collapses the whole epic into a single feature
  branch. Keep tracking Epics un-designated; designate the Story feature node instead.
```

- [ ] **Step 3: Append the `## Feature-node grouping` section (end of file)**

Append:
```

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
```

- [ ] **Step 4: Commit**

```bash
git add plugin/skills/bd-mega-build-up/trackers/jira.md
git commit -m "docs(bd-mega-build-up): add Jira Feature-node grouping adapter section"
```

---

### Task 5: RED/GREEN behavioral eval of the two Jira grouping rules (recommended)

The spec (§7) flags this as "confirm with author — appetite / worth it given no live Jira." **Ask the author before running.** If declined, skip to Task 6. This mirrors #24: verify a naive agent reading the skill reaches the correct behavior, with the named rationalizations as counters.

**Files:**
- No file changes. Creates transient eval prompts only (scratchpad).

**Interfaces:**
- Consumes: `trackers/jira.md` (Task 4) + `bd-mega-build-up/SKILL.md` (Task 2).

- [ ] **Step 1: RED baseline — capture that a naive agent gets it wrong pre-fix**

If you still have the pre-Task-4 `trackers/jira.md` (via `git stash` or a scratch checkout of the parent commit), dispatch a subagent given **only** the old `jira.md` + core `SKILL.md` and this scenario, via the Agent tool:
> "Filing a Jira feature node: a Story `BAC-500` with three sub-tasks `BAC-501/502/503`. Using only these skill files, list the exact order in which you set `AI-Implement-Status` on the four issues and wire the `Blocks` links, and say what happens if you leave `BAC-503`'s `AI-Implement-Status` unset."
Expected (RED): the agent has no grouping guidance — it does not know to designate the parent last, and does not identify that an unset-Status child is silently excluded from the group. Record the answer.

(If reconstructing the old file is not worth it, note "RED trivially holds — old jira.md has zero grouping content" and proceed.)

- [ ] **Step 2: GREEN — same scenario against the fixed files**

Dispatch a fresh subagent (Agent tool) given the **post-Task-4** `trackers/jira.md` + core `SKILL.md` and the identical scenario. Explicitly seed the rationalizations to counter:
> "…A teammate argues 'BAC-503 is just a sub-task, the epic groups it anyway, and I can set its Status later.' Evaluate that."
Expected (GREEN), the agent must state:
  1. Designate the **children first** (`AI-Implement-Status` + Repo on 501/502/503), wire `parent` + `Blocks` links, then set the Story `BAC-500` **last**.
  2. Leaving `BAC-503` un-designated makes it **invisible to the group** — it won't gate the Story and won't roll up; it PRs to the Default Branch on its own. The "epic groups it" claim is wrong; the Epic must stay un-designated.

- [ ] **Step 3: Gate on the result**

If GREEN fails on either point, the prose is ambiguous — revise `trackers/jira.md` (Task 4) until a fresh agent reaches both conclusions, then re-run. Record the final transcript in the PR description. No commit needed unless Step-3 revisions were made (then amend Task 4's commit or add a fixup).

---

### Task 6: Reverse the stale caveats in the single-file skills

Mechanical flips. Each file's grouping *body* already applies to Jira; only the skip/heading caveats change. Use this **canonical dual-path note** wherever a `(Jira: no grouping …)` skip line is replaced (adjust the label token to match the file — literal `AI-Implement` for the landing/analysis skills, `{{IMPLEMENT_LABEL}}` for `bd-build-up`):
> (Applies on **both** trackers — Linear via the `AI-Implement` label, Jira via a non-empty `AI-Implement-Status` + matching Repo field; "terminal" = Linear Done/Cancelled or Jira `statusCategory` = done. See `docs/feature-branch-grouping.md`.)

**Files:**
- Modify: `plugin/skills/bd-build-down/SKILL.md` (lines 265, 304)
- Modify: `plugin/skills/bd-super-build-down/SKILL.md` (lines 159, 236, 245, 388)
- Modify: `plugin/skills/bd-summit-push/SKILL.md` (lines 132, 148, 289)
- Modify: `plugin/skills/bd-smoke-jumper/SKILL.md` (lines 107, 165, 176)
- Modify: `plugin/skills/bd-project-setup/SKILL.md` (lines 386–390)
- Modify: `plugin/skills/bd-build-up/SKILL.md` (lines 63, 217, 294, 469–473)

- [ ] **Step 1: bd-build-down**

Line 265 heading — replace `### 2i. Feature-branch grouping (Linear only)` with `### 2i. Feature-branch grouping (both trackers)`.
Line 304 skip — replace `(Jira: no grouping — every PR targets the base branch; skip this subsection.)` with the canonical dual-path note (literal `AI-Implement` variant).

- [ ] **Step 2: bd-super-build-down**

Line 159 Tier-3 item 11 — replace `always a human gate, never auto-merged (Linear feature-branch grouping)` with `always a human gate, never auto-merged (feature-branch grouping — both trackers)`.
Line 236 heading — replace `### 4f. Feature-branch grouping (Linear only)` with `### 4f. Feature-branch grouping (both trackers)`.
Line 245 skip — replace `(Jira: no grouping — every PR targets the base branch; skip this.)` with the canonical dual-path note.
Line 388 guardrail — replace `Under Linear feature-branch grouping,` with `Under feature-branch grouping (Linear or Jira),`.

- [ ] **Step 3: bd-summit-push**

Line 132 heading — replace `**2e. Feature-branch grouping (Linear only)**` with `**2e. Feature-branch grouping (both trackers)**`.
Line 148 skip — replace `(Jira: no grouping — keep the flat "all PRs → base" model.)` with the canonical dual-path note.
Line 289 manifest note — replace `Omit this section when there are no feature nodes / on Jira.` with `Omit this section only when there are no feature nodes (either tracker).`

- [ ] **Step 4: bd-smoke-jumper**

Line 107 base-branch note — replace `for a grouped **child PR** (Linear feature-branch grouping) this is a feature branch` with `for a grouped **child PR** (feature-branch grouping — Linear or Jira) this is a feature branch`.
Line 165 heading — replace `### 2e. Feature-branch grouping (Linear only)` with `### 2e. Feature-branch grouping (both trackers)`.
Line 176 skip — replace `(Jira: no grouping — every PR targets base; skip this.)` with the canonical dual-path note.

- [ ] **Step 5: bd-project-setup**

Replace the note (lines 386–390):
```
- **Feature-branch grouping (Linear only).** If a project will use AI-Implement parent/child
  *feature-branch grouping*, re-sync workflows so the target repo's `claude-implement.yml` accepts the
  `base_branch` input — un-synced repos 422 on grouped dispatch (the non-grouped path keeps working).
  Grouping is **Linear-only**: the Jira path always PRs to the base branch. Full model:
  `docs/feature-branch-grouping.md`.
```
with:
```
- **Feature-branch grouping (both trackers).** If a project will use AI-Implement parent/child
  *feature-branch grouping*, re-sync workflows so the target repo's `claude-implement.yml` accepts the
  `base_branch` input — un-synced repos 422 on grouped dispatch (the non-grouped path keeps working). This
  applies to **Linear and Jira** target repos alike; only designation differs (Linear label vs Jira
  `AI-Implement-Status` + Repo field). Full model: `docs/feature-branch-grouping.md`.
```

- [ ] **Step 6: bd-build-up — the three caveat lines**

Line 63 — replace:
```
- **Parent/child trees become feature nodes (Linear only).** A parent labelled `{{IMPLEMENT_LABEL}}` with labelled children owns a feature branch `ai-implement/feature/<key>`; children PR **into that branch**, not the **Default Branch**, and the tree rolls up to one human-reviewed `feature → base` PR. See `docs/feature-branch-grouping.md`. (Jira: no grouping.)
```
with:
```
- **Parent/child trees become feature nodes (both trackers).** A *designated* parent with designated children owns a feature branch `ai-implement/feature/<key>`; children PR **into that branch**, not the **Default Branch**, and the tree rolls up to one human-reviewed `feature → base` PR. Designation is the `{{IMPLEMENT_LABEL}}` label on Linear and a non-empty `AI-Implement-Status` + matching Repo field on Jira. See `docs/feature-branch-grouping.md`.
```
Line 217 — replace `**Label the parent LAST**` with `**Designate the parent LAST**`, replace the two occurrences of "label" in "label children, then the parent" with "designate", and replace the trailing `(Jira: no grouping.)` with the canonical dual-path note (`{{IMPLEMENT_LABEL}}` variant). Concretely replace:
```
**Feature-node trees (Linear grouping).** When you decompose into a parent + children, the labelled parent becomes a *feature node*: children PR into its feature branch `ai-implement/feature/<key>` (not the Default Branch), and the parent's own closing work is `Blocked by:` all its children (it runs last). **Label the parent LAST** — build the whole tree (children + parent relationships + every `blocks` relation) first, then label children, then the parent. The race guard only covers "parent labelled, *no* child labelled yet"; it does **not** cover "children labelled, relations not yet set," and labelling the parent into that window makes the orchestrator pick it up in parallel with its children (observed failure). See `docs/feature-branch-grouping.md`. (Jira: no grouping.)
```
with:
```
**Feature-node trees (both trackers).** When you decompose into a parent + children, the *designated* parent becomes a *feature node*: children PR into its feature branch `ai-implement/feature/<key>` (not the Default Branch), and the parent's own closing work is `Blocked by:` all its children (it runs last). **Designate the parent LAST** — build the whole tree (children + parent relationships + every `blocks`/`Blocks` relation) first, then designate children, then the parent. The race guard only covers "parent designated, *no* child designated yet"; it does **not** cover "children designated, relations not yet set," and designating the parent into that window makes the orchestrator pick it up in parallel with its children (observed failure). Designation is the `{{IMPLEMENT_LABEL}}` label on Linear and a non-empty `AI-Implement-Status` + matching Repo field on Jira. See `docs/feature-branch-grouping.md`.
```
Line 294 — replace `- **Feature-node trees (Linear grouping)** → file the parent and children unlabelled,` with `- **Feature-node trees (both trackers)** → file the parent and children un-designated,`; and replace `label **children first and the parent last**` with `designate **children first and the parent last**`, and the two later "labelled"/"label" references with designation-neutral wording. Concretely replace:
```
- **Feature-node trees (Linear grouping)** → file the parent and children unlabelled, set the parent relationships and every `blocks` relation, then label **children first and the parent last** — never the parent before its children's labels and relations exist (the race guard doesn't cover that window; the orchestrator would pick the parent up in parallel with its children). The children PR into the feature branch `ai-implement/feature/<key>` (not the Default Branch); the parent's own closing work waits until every child lands. Don't expect the parent to merge to the Default Branch before its children. See `docs/feature-branch-grouping.md`.
```
with:
```
- **Feature-node trees (both trackers)** → file the parent and children un-designated, set the parent relationships and every `blocks`/`Blocks` relation, then designate **children first and the parent last** — never the parent before its children's designation and relations exist (the race guard doesn't cover that window; the orchestrator would pick the parent up in parallel with its children). The children PR into the feature branch `ai-implement/feature/<key>` (not the Default Branch); the parent's own closing work waits until every child lands. Don't expect the parent to merge to the Default Branch before its children. Designation is the `{{IMPLEMENT_LABEL}}` label on Linear and a non-empty `AI-Implement-Status` + matching Repo field on Jira. See `docs/feature-branch-grouping.md`.
```

- [ ] **Step 7: bd-build-up — update the projected Jira Conventions block (lines 469–473)**

Append a grouping line to the Jira-style block so it states the Jira designation/hierarchy model. Replace:
```
- Labels exist in Jira but the pickup gate is the status field — setting only a label is a silent no-op
```
with:
```
- Labels exist in Jira but the pickup gate is the status field — setting only a label is a silent no-op
- Feature-node grouping: a *designated* Story (non-empty `AI-Implement-Status` + matching Repo) with designated sub-task children owns `ai-implement/feature/<key>`; sub-tasks PR into it; the tracking Epic stays un-designated. Hierarchy = native parent ?? Epic Link. Designate children first, the Story last.
```

- [ ] **Step 8: Verify no stale caveats remain anywhere in the single-file skills**

Run: `grep -rni "linear only\|linear-only\|jira: no group\|no grouping" plugin/skills/bd-build-down plugin/skills/bd-super-build-down plugin/skills/bd-summit-push plugin/skills/bd-smoke-jumper plugin/skills/bd-project-setup plugin/skills/bd-build-up`
Expected: **no output**.

- [ ] **Step 9: Commit**

```bash
git add plugin/skills/bd-build-down plugin/skills/bd-super-build-down plugin/skills/bd-summit-push plugin/skills/bd-smoke-jumper plugin/skills/bd-project-setup plugin/skills/bd-build-up
git commit -m "docs(bd-skills): reverse stale Jira: no grouping caveats in single-file skills"
```

---

### Task 7: Version bump + final repo-wide gate

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json`

- [ ] **Step 1: Bump the plugin version 0.6.0 → 0.7.0**

In `plugin/.claude-plugin/plugin.json`, change `"version": "0.6.0"` to `"version": "0.7.0"`.

- [ ] **Step 2: Final repo-wide caveat gate**

Run: `grep -rni "linear only\|linear-only\|no grouping\|jira: no group" plugin/ docs/feature-branch-grouping.md`
Expected: **no output**. Any hit is a residual defect from Tasks 1/2/6 — fix it before proceeding. (The BDS-12 self-review gate is inverted: "every grouping section states the correct per-tracker designation," and any remaining "no grouping on Jira" prose is now a defect.)

- [ ] **Step 3: Adapter heading parity check**

Run: `diff <(grep '^## ' plugin/skills/bd-mega-build-up/trackers/linear.md) <(grep '^## ' plugin/skills/bd-mega-build-up/trackers/jira.md)`
Expected: both adapters contain a `## Feature-node grouping` line (the diff will show other section differences, which are expected — only confirm the new heading is present in both).

- [ ] **Step 4: Commit**

```bash
git add plugin/.claude-plugin/plugin.json
git commit -m "chore(plugin): bump 0.6.0 -> 0.7.0 for Jira feature-branch grouping parity"
```

- [ ] **Step 5: Commit the design spec (currently untracked)**

```bash
git add docs/superpowers/specs/2026-07-01-jira-feature-branch-awareness-design.md docs/superpowers/plans/2026-07-09-jira-feature-branch-awareness.md
git commit -m "docs(superpowers): commit Jira feature-branch awareness design + plan"
```

---

## Self-Review

**Spec coverage** (against `2026-07-01-jira-feature-branch-awareness-design.md` §5):
- Phase 0 (doc rewrite) → Task 1 (all sub-bullets: intro, callout, mental model, designation subsection, terminal, roll-up rationale, depth-5 + failure split, §5 table, §6 boundaries, §7 sources). ✔
- Phase 1 core `SKILL.md` (lines 54, 94, 132, 386, 560 + designate-parent-last generalization) → Task 2. ✔
- Phase 1 `trackers/linear.md` grouping section → Task 3. ✔
- Phase 1 `trackers/jira.md` grouping section + Container reconcile + red flag + two sub-task prereqs → Task 4. ✔
- Phase 2 single-file skills (bd-build-down, bd-super-build-down, bd-summit-push, bd-smoke-jumper, bd-project-setup, bd-build-up) → Task 6. ✔ (bd-belay-on line 128 is explicitly out-of-scope in the spec — not touched.)
- Cross-cutting: version bump → Task 7 Step 1; inverted self-review gate → Task 7 Step 2. ✔
- Validation §7 (RED/GREEN) → Task 5 (gated on author confirmation, as the spec requests). ✔

**Placeholder scan:** No "TBD"/"add appropriate…" placeholders — every edit gives exact old→new text. ✔

**Type/naming consistency:** The adapter section heading is `## Feature-node grouping` in both Task 3 and Task 4, and the core seam list (Task 2 Step 3) uses "feature-node grouping" — consistent. The dual-path note is defined once in Task 6 and reused. Fixed strings (`[ai-implement] Feature branch ready for review`, `[ai-implement] Automated feature-branch roll-up`, `ai-implement/feature/<key>`) are byte-identical to the pilot doc. ✔

**Note on line numbers:** the `Modify: …:NNN` line references were captured against the current working tree. If an earlier task shifts line numbers within the same file, match on the quoted `old_string` text (always unique) rather than the line number.
