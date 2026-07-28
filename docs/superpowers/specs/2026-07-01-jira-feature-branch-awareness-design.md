# Jira feature-branch awareness across the BuildDown skills — design

**Date:** 2026-07-01
**Status:** Approved (design); implementation plan pending
**Scope decision:** A — caveat-reversal + full `bd-mega-build-up` adapter; defer promoting the single-file
skills to a `trackers/` split (that's AII-149).

## 1. Problem

AI-Implement commit `8dd6de1` ("feat(jira): parent/child feature-branch support", #64) gave the **Jira**
provider full feature-branch grouping at parity with the Linear provider (#57). It touched **zero
shared-core files**: branch naming (`ai-implement/feature/<key>`), the roll-up machinery (`runMergeUps`,
`src/merge-up.ts`), and the top-of-tree human-gate PR are tracker-neutral and already serve Jira. All new logic is in
`src/providers/jira.ts` (`enrichFeatureBranches` + `fetchFeatureNodeRollUps`, previously a `[]` stub), the
pure helpers in `src/providers/jira-hierarchy.ts` (`classifyByChildren`, `ancestorChain`), and one added
`epicLinkFieldId` in `src/providers/jira-fields.ts`.

The BuildDown skills, however, still assert the opposite everywhere. Feature-branch grouping was added to the
skills in BDS-12 (`06d0df5`) **Linear-first, by design** — at that time the Jira provider returned no chain
and no roll-ups, so every grouping section carries an explicit **"(Jira: no grouping — every issue PRs to the
Default Branch)"** caveat. Those caveats are now **wrong**. `docs/feature-branch-grouping.md` declares the
feature "Linear-only" (lines 12–15, 104), and `bd-mega-build-up/trackers/jira.md` has no grouping content at
all — it still frames Jira as a purely flat epic-of-children model.

This change reverses the boundary and writes the Jira grouping mechanism at parity with Linear.

## 2. Two Jira-specific wrinkles (why this is a design change, not find-replace)

1. **Designation is a field, not a label — and there are two distinct predicates.** Linear participation =
   presence of the `AI-Implement` **label**. On Jira, keep two rules separate:
   - **Candidate eligibility** (which issues get *planned/implemented this poll*) = `AI-Implement-Status` ∈
     {`Ready`, `Plan Approved`} **and** Repo field = the mapping's `repoFieldValue`. This is the dispatch
     bucket (`bucketJql`, `jira.ts:209`).
   - **Group designation** (whether an issue *counts toward grouping* — gating its parent, joining the
     ancestor chain, rolling up, being an auto-merge parent) = `AI-Implement-Status` **set to any non-empty
     value** **and** Repo match (`designated()`, `jira.ts:296-298`, `:395-397`). This is **broader**: a child
     that has already moved on to `Implementing` / `PR Ready` / `Done` is *still* designated for grouping.
   A child left un-designated (Status **unset**, or wrong Repo value) is **invisible to the group**: it will
   not gate its parent and will not roll up — it just quietly PRs to the Default Branch on its own. Any skill
   copy that says "add the `AI-Implement` label to the parent and children" is Linear-only. **Do not** tell
   operators that grouping requires Status = Ready specifically — Ready is only for *this poll's* dispatch;
   grouping tracks a child through its whole non-empty-status lifecycle.

2. **Feature-node shape must fit Jira's fixed hierarchy.** Jira forbids epics-under-epics and sub-tasks
   cannot nest. Hierarchy is read from the native `parent` field with a best-effort classic `Epic Link`
   fallback: `effectiveParentKey = native parent ?? Epic Link`.

Everything else is shared and unchanged: `buildFeatureBranchName(KEY) = ai-implement/feature/<slug(KEY)>`
(Jira keys `ABC-123` are already slug-safe), `resolveBaseBranch` cascade cutting, `runMergeUps` (internal
direct-merge roll-up vs top-of-tree human PR), depth cap 5, fail-open-to-Default-Branch on branch resolution.

## 3. Canonical Jira feature-node shape (the key modeling decision)

**The canonical (recommended) feature node is a designated Story with designated sub-task children** — in
general, per §4, *any* designated issue with ≥1 designated child is a feature node; the Story+sub-tasks shape
is the one the filing skills prescribe. The Story owns `ai-implement/feature/<slug(STORY-KEY)>`; its
designated sub-tasks PR **into that branch**, not the Default Branch; the Story's own closing work is
`Blocked by:` all its sub-tasks and runs **last**, on the same branch. When the Story's sub-tasks are all
terminal, the Story is the top of the tree → its feature branch → the single human-gate PR
`ai-implement/feature/<slug(STORY-KEY)> → base`.

**Epics are long-lived tracking entities and MUST stay un-designated — they never map to a feature branch.**
Stories are assigned to an Epic (native `parent`, or classic `Epic Link`) purely for tracking. Because
`ancestorChain()` walks up `effectiveParentKey` only *while each ancestor is designated* and stops at the
first un-designated ancestor, an un-designated tracking Epic **halts the walk** — the designated Story is the
top-of-tree feature node and the Epic is never a feature branch. This is not a special case to code around;
it is the emergent behaviour, and the rule that makes it hold is simply: **never set `AI-Implement-Status` on
the container Epic.** Designating an Epic would turn the *entire* epic into one feature branch and collapse
the wave model — this is an explicit anti-pattern / red flag, not an offered alternative.

Consequences to encode:
- The `jira.md` **Container** section (Jira Epic, issues as flat children with `parent = <epic>`) stays
  correct and is exactly the un-designated tracking container. Grouping is **opt-in**: promote a cohesive
  subset into a designated Story with designated sub-tasks. Add a pointer from Container → Feature-node
  grouping and the "keep the Epic un-designated" rule.
- **Two sub-task prerequisites** (both config, not code — the provider hardcodes no issuetype filter):
  1. **Field context:** the AI-Implement custom fields (`AI-Implement-Status`, `Repo`, `Assigned Team`) must
     be available on the **sub-task** issue type, or sub-task children cannot be designated.
  2. **Scope JQL:** the mapping's scope JQL (`cfg.jql`, interpolated into `bucketJql` at `jira.ts:209`) must
     **not** exclude sub-task issue types (no `issuetype != Sub-task`, no Story/Task/Bug-only allowlist).
     Otherwise designated sub-tasks are still *discovered* as gating children (`childrenJql` `parent in (...)`
     is not scope-gated, `jira.ts:155-160`) but never *dispatched* onto the feature branch — the group hangs.
- **Nesting depth:** Story + sub-tasks is a single-level group (sub-tasks cannot have children). Deeper
  recursion (a feature node whose parent is another feature node) requires team-managed native Story→Story
  parenting; classic Jira cannot parent Story-to-Story, so classic instances use multiple independent
  single-level feature-node Stories under one tracking Epic. Both are fine — the orchestrator caps chains at
  depth 5 regardless.

## 4. AI-Implement Jira mechanics the skills must reflect

- **Designation (two predicates — see §2):** *candidate eligibility* = `AI-Implement-Status` ∈ {Ready, Plan
  Approved} + Repo match (`bucketJql`, `jira.ts:209`); *group designation* (child gating, ancestor-chain
  membership, feature-node roll-up, auto-merge-parent selection) = `AI-Implement-Status` **non-empty** + Repo
  match (`designated()`, `jira.ts:296-298`, `:395-397`). A terminal or in-flight child (non-empty status) is
  still designated, so a parent whose designated children are all terminal is *feature-node-ready*, not
  "none designated → skip".
- **Hierarchy:** `effectiveParentKey = native parent ?? Epic Link`; children discovered via
  `parent in (...)` OR `cf[epicLink] in (...)` and attributed by `effectiveParentKey`.
- **Feature node:** a designated issue with ≥1 designated child. `classifyByChildren`: no children = leaf;
  children but none designated = waiting-parent (SKIP — race guard); ≥1 designated child not all terminal =
  feature-node-blocked (SKIP — wait gate); all designated children terminal = feature-node-ready (closing
  work dispatches onto its own feature branch).
- **Terminal:** `fields.status.statusCategory.key === 'done'` (subsumes Done/Closed and Won't-Do/Cancelled).
- **`featureBranchChain`:** built base-most-first by `ancestorChain()` — walk up `effectiveParentKey` while
  each ancestor is designated, stop at first un-designated ancestor, depth cap 5, cycle-guarded.
- **Roll-ups (shared):** `parentIdentifier != null` → **internal roll-up** = direct `git merge`, **no PR**,
  identifier-free commit (so the tracker doesn't auto-close the parent early). `parentIdentifier == null` →
  **top-of-tree** human-gate PR `[ai-implement] Feature branch ready for review`, never auto-merged, not
  reopened if a human closes it unmerged. 14-day Done lookback; only designated feature nodes roll up.
- **Failure-mode split (Jira-specific):** the gating children query fails **CLOSED** (a transient Jira error
  defers the whole candidate batch that poll, so a feature-node parent never dispatches closing work onto
  base ahead of its children); the branch-targeting ancestor walk fails **OPEN** — ancestor *nesting*
  collapses (a leaf then targets the Default Branch; a feature node still gets its own branch cut from the
  Default Branch, only losing its position under any ancestor) and the candidate still dispatches
  (`jira.ts:363-365` catches and logs; classification still runs).
- **Designate-parent-last:** designate children first (Status + Repo), set every `parent` link and every
  "Blocks" link, then designate the **parent last** — else the parent momentarily looks like a childless leaf
  and dispatches closing work onto base ahead of its children. (The Jira translation of Linear's "label the
  parent last", validated for Linear in #24.)

## 5. Files to change

### Phase 0 — `docs/feature-branch-grouping.md` (the pilot the skills mirror)

(Section numbers below are the **pilot doc's own** sections, not this spec's.)

- Reverse the "Linear-only" callout (doc lines 12–15) and the doc's §6 boundary (line 104): grouping now
  exists on **both** providers.
- Restate the doc's §1 mental model tracker-neutrally, then add a **"Designation & hierarchy per tracker"**
  subsection: Linear = `AI-Implement` label + native parent/children; Jira = `AI-Implement-Status` **set**
  (any non-empty value) + Repo-field match + `effectiveParentKey` (native parent ?? Epic Link) — with the
  two-predicate note from this spec's §2 (candidate-dispatch needs Ready/Plan Approved; *grouping* needs only
  a non-empty status).
- The doc's §3 "Terminal" (line 66): add the Jira mapping = `statusCategory` Done.
- The doc's §4 roll-up "why no PR" (lines 79–81): keep the behaviour tracker-neutral; tag the auto-close
  rationale as Linear-origin (GitHub-for-Linear) and add the Jira analog (Smart Commits / GitHub-for-Jira).
- Add the depth-5 cap and the Jira fail-closed-gating / fail-open-ancestor note.
- Fix the doc's §5 table (mega/build-up row) and §6 boundaries to stop asserting Linear-only. The
  `base_branch` / `claude-implement.yml` 422 re-sync prerequisite is shared and now applies to Jira target
  repos too.
- The doc's §7: also cite `src/providers/jira.ts` and `src/providers/jira-hierarchy.ts`.
- Keep "Default Branch" terminology and the fixed commit/PR strings verbatim.

### Phase 1 — `bd-mega-build-up` (adapter-split skill; done by the seam pattern)

**Core `SKILL.md`:**
- Tracker Selection (line 132): add "feature-node grouping" to the enumerated seam list.
- Pipeline implication #5 (line 54), Hard Rule 10 (line 94), Phase 3 (line 386), Red Flag (line 560): drop
  `(Linear only)` / `(Jira: no grouping…)`; state the model tracker-neutrally and defer the mechanism to the
  active adapter's `## Feature-node grouping` section. Generalize "label the parent LAST" →
  "**designate** the parent LAST" (correct for both the Linear label and the Jira Status field).

**`trackers/linear.md`:** add a `## Feature-node grouping` section capturing the Linear mechanics currently
stranded in the core parentheticals (feature node = `AI-Implement`-labelled parent with ≥1 labelled child;
labelled children PR into the feature branch; parent closing work `Blocked by:` all children, runs last;
label children first / parent last; race-guard window = "children labelled, blocks-relations not yet set").
This is the diff-parity peer the Jira section must match.

**`trackers/jira.md`:** add the `## Feature-node grouping` section (§3 + §4 content: field-designation +
Repo match; native-parent/Epic-Link hierarchy; the Story+sub-tasks shape with the Epic-stays-un-designated
rule; designate-children-first/parent-last; `statusCategory`-Done wait gate; top-of-tree human PR; internal
roll-up = identifier-free direct merge; fail-closed-gating/fail-open-ancestor note; the two sub-task
prerequisites — field context + scope JQL). Reconcile the Container section (lines 17–23) with a pointer + the keep-Epic-
un-designated rule. Add a Jira red flag: "child filed without `AI-Implement-Status` set, or with the wrong
Repo value → silently excluded from the group." Seam parity is verified by diffing the two adapters' `## `
headings.

### Phase 2 — reverse the stale caveats in the single-file skills

Their tracker-neutral bodies already apply to Jira and stay as-is (child-PR base = feature branch; roll-up
conflict = manual `git merge`; aggressive-but-gated sandbox posture with **auth/migrations still escalating**;
bottom-up merge order; `base_branch`/422 re-sync prerequisite). Only the skip lines flip to a dual-path note
keyed on Status-field designation + `statusCategory`-Done terminal:

- **`bd-build-down`** — §2i heading (line 265) drop "(Linear only)"; skip line 304 → dual-path note.
- **`bd-super-build-down`** — §4f heading (line 236) retitle off "(Linear only)"; §4f skip (line 245) →
  dual-path note; de-scope the "never auto-merge the top-of-tree PR" guardrail (line 388) and Tier-3 item 11
  (line 159) from "Linear feature-branch grouping" so they cover Jira.
- **`bd-summit-push`** — §2e skip (line 148) → dual-path note; retitle §2e off "(Linear only)" (line 132);
  manifest "Feature-branch trees" section (line 289) is now emitted for Jira too.
- **`bd-smoke-jumper`** — §2e heading (line 165) retitle off "(Linear only)"; §2e skip (line 176) →
  dual-path note; base-branch capture note (line 107) de-scoped from "Linear".
- **`bd-project-setup`** — notes (lines 386–390): grouping now applies on both providers; the base_branch /
  `claude-implement.yml` re-sync prerequisite applies to Jira target repos too.
- **`bd-build-up`** — reverse the literal inline `(Jira: no grouping)` gating at lines 63 and 217; and make
  the `- **Feature-node trees (Linear grouping)**` bullet (line 294) tracker-neutral (its label-only flow
  needs the Jira designation path added — it is not itself a `(Jira: no grouping)` line). Update the projected
  Jira-style Conventions block (lines 469–473) to state the Jira designation/hierarchy model.
- **`bd-belay-on`** — nothing required (no grouping content). Optional out-of-scope nit only: line 128
  hardcodes `git merge main`, contradicting the "resolve the real Default Branch, never assume main" rule.

### Cross-cutting

- **Version bump (mandatory, same PR):** `plugin/.claude-plugin/plugin.json` **0.6.0 → 0.7.0** (additive →
  minor). CLAUDE.md makes this the only signal `/plugin update` reads; skip it and installs keep serving the
  stale "Jira: no grouping" skills.
- **Invert the old self-review gate:** BDS-12 required "every grouping section states the Jira/flat fallback
  (no grouping)." That gate is now obsolete; the new gate is "every grouping section states the correct
  per-tracker designation." Any remaining "no grouping on Jira" prose is now a defect.

## 6. Terminology (verbatim, itself a self-review gate)

feature node · feature branch (`ai-implement/feature/<key>`) · child PR · internal roll-up (direct `git
merge`, no PR) · top-of-tree PR (`[ai-implement] Feature branch ready for review`) · roll-up conflict · race
guard · Default Branch (never "main"). Fixed commit/PR strings stay exact.

## 7. Validation

Doc-first (mirror BDS-12): rewrite the canonical doc first, then mirror its language into the skills. This
repo is Linear-bound (CLAUDE.md `tracker.kind: linear`), so the Jira grouping path ships only in the plugin
for downstream Jira consumers and **cannot be exercised against a live Jira here** — the goal is
plugin-correctness for those consumers.

Recommended: RED/GREEN subagent-test the behavior-changing Jira prose (the "designate the parent LAST" rule
and the "un-designated child is invisible" red flag) the way #24 tested the Linear rules — i.e., verify a
naive agent reading the skill files reaches the correct behaviour, with the named rationalizations
("it's just a sub-task", "the epic groups it") as counters. To confirm with the author (appetite / worth it
given no live Jira).

## 8. Source of truth

Upstream AI-Implement wins on any conflict: `src/providers/jira.ts`, `src/providers/jira-hierarchy.ts`,
`src/providers/jira-fields.ts`, `src/feature-branch.ts`, `src/merge-up.ts`, `src/pipeline/branch-name.ts`,
and AI-Implement's own `docs/feature-branch-grouping.md`.
