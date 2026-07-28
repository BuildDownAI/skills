# Feature-branch grouping awareness — Implementation Plan

> **For implementation:** Each task below maps to a BDS child issue under BDS-12. Tasks edit markdown only; "verification" is human review of the prose (`{{BUILD_CMD}}` = none). Tasks are self-contained. **No `AI-Implement` label** — these are human-authored doc edits. Implementation order is **doc-first** (Task 1 is the pilot; Tasks 2–8 mirror its terminology).

**Goal:** Teach the BuildDown skills to plan, sequence, and drive work under AI-Implement parent/child feature-branch grouping.

**Architecture:** One canonical operator reference (`docs/feature-branch-grouping.md`) + compact self-contained grouping sections inlined into the six core skills + light pointers in README / bd-project-setup / CLAUDE.md.

**Tech Stack:** Markdown. Repo `BuildDownAI/skills`, base branch `testing`, skills under `plugin/skills/bd-*/SKILL.md`.

**Tracker Container:** BDS project *Feature-branch grouping awareness*; parent issue BDS-12.

**Shared terminology (use these exact terms in every file — consistency is a self-review gate):**
*feature node* · *feature branch* (`ai-implement/feature/<key>`) · *child PR* (targets a feature branch) · *internal roll-up* (direct merge, no PR) · *top-of-tree PR* (`[ai-implement] Feature branch ready for review`, the human gate) · *roll-up conflict* (children Done but missing from the parent feature branch → manual merge) · *race guard* · *Linear-only*.

---

## Task 1 (PILOT): Canonical reference `docs/feature-branch-grouping.md`

**Shape:** deep-and-targeted. **Migration/backfill?** no.
**Files:** Create `docs/feature-branch-grouping.md` (repo root `docs/`, sibling to existing `docs/superpowers/`).
**Parallel-safe with:** Tasks 2–8 (distinct files). **Blocked by:** none. Implement FIRST.
**Rubric:** Pattern anchor — AI-Implement's own `docs/feature-branch-grouping.md` (upstream source of truth; adapt, don't copy verbatim). Test fixture — n/a (prose). Trust boundary — none. Rollback — revert PR. Observability — n/a. Parallel-safety — sole owner of this file.

**Content outline (operator-framed — what it means for *planning and landing*, not orchestrator internals):**
1. **Mental model** — the branch-tree diagram; feature node = labelled parent with ≥1 labelled child, owns `ai-implement/feature/<key>`; children PR into it; recursive; rolls up to one human-reviewed `feature → base` PR.
2. **What changes vs the flat model** — children no longer PR to base; sequencing runs *through* the feature node; one human-gate PR at the top instead of N independent merges.
3. **Classification & the race guard** — whole-tree labelling is safe; a parent labelled with no labelled child waits; parent's own closing work runs only after all children terminal (Done *or* Cancelled).
4. **The roll-up (merge-up)** — **internal = direct git merge, no PR** (commit `[ai-implement] Automated feature-branch roll-up`, deliberately identifier-free so Linear won't mark the parent Done early); a roll-up can **conflict** → manual merge; **top-of-tree = one PR** `[ai-implement] Feature branch ready for review`, never auto-merged.
5. **Which skill cares about what** — a one-row-per-skill table pointing into each skill's inlined section.
6. **Boundaries** — **Linear-only** (Jira always PRs to base); requires the target repo's `claude-implement.yml` to accept the `base_branch` input (re-sync workflows); fails open to base on any grouping error.
7. **Upstream source of truth** — link AI-Implement `docs/feature-branch-grouping.md`, `src/feature-branch.ts`, `src/merge-up.ts`.

**Acceptance criteria:**
- [ ] File exists at `docs/feature-branch-grouping.md` with the 7 sections above.
- [ ] States internal roll-ups are direct merges (no PR) and only the top-of-tree is a PR.
- [ ] States the Linear-only boundary and the `base_branch` workflow-sync requirement.
- [ ] Uses the shared terminology exactly; links AI-Implement upstream as source of truth.

---

## Task 2: bd-build-down grouping awareness (heaviest)

**Shape:** deep-and-targeted. **Files:** Modify `plugin/skills/bd-build-down/SKILL.md`.
**Parallel-safe with:** all other tasks. **Blocked by:** Task 1 (mirror terminology).
**Rubric:** Pattern anchor — existing Phase 2 subsections (2e–2h) set the voice. Trust boundary — none. Rollback — revert PR. Parallel-safety — sole owner of this file.

**Edit 2.1 — new subsection after §2h (insert after line 263, before the `---` at 264/265):**
```markdown
### 2i. Feature-branch grouping (Linear only)

When AI-Implement parent/child **feature-branch grouping** is in play, not every PR targets the
repo base branch. See `docs/feature-branch-grouping.md` for the full model. What changes for triage:

- **Recognize the PR class by base branch + title:**
  - **Child PR** — base is a feature branch `ai-implement/feature/<key>` (not the repo base). Drive it
    to merge like any normal PR, but *all conflict and diff operations use that feature branch as base,
    not `main`* (see §2f, §2h).
  - **Top-of-tree PR** — title `[ai-implement] Feature branch ready for review`, head
    `ai-implement/feature/<key>` → repo base. This is the **human-review gate for the whole integrated
    feature.** Review the feature branch as a unit; merge it **last**, after every child has landed.
- **Internal roll-ups are NOT PRs.** AI-Implement merges a completed child feature branch into its
  parent's branch with a direct `git merge` (commit `[ai-implement] Automated feature-branch roll-up`).
  Don't look for a roll-up PR and don't try to create one.
- **A roll-up can conflict silently.** Symptom: a child issue is Done but its work is missing from the
  parent feature branch (or the parent's closing-work PR is missing expected child changes). That's a
  **roll-up conflict** needing a manual `git merge` of the child feature branch into the parent — surface
  it as a manual step (Phase 5), don't `@agent` it.
- **Merge order is bottom-up:** leaf child PRs → parent's closing-work PR → (internal roll-ups happen
  automatically) → top-of-tree PR last.

(Jira: no grouping — every PR targets the base branch; skip this subsection.)
```

**Edit 2.2 — §2f (lines 226, "git merge main"):** change *"instructing `git merge main`"* to *"instructing `git merge <the PR's base branch>` (the feature branch for a grouped child PR, else `main`)"*.

**Edit 2.3 — §2h (line 248):** change the diff command to use the PR's actual base: `git diff --name-only origin/<base>...origin/{branch}` and add a sentence: *"For grouped child PRs the base is the feature branch, not `main` — compare against the PR's real base."*

**Edit 2.4 — Phase 3 conflict template (line 290) + Posting rules (line 316) + ID note:** generalize `git merge main` to `git merge <base branch>` with a parenthetical that base = the PR's target (feature branch for grouped children). Keep the existing main-default wording for the flat case.

**Edit 2.5 — Phase 4 Merge criteria (after line 340):** add a bullet:
```markdown
- ✅ Not the **top-of-tree `feature → base` PR** — that one is a human-review gate (see §2i); surface it,
  review the integrated feature, and merge it explicitly last, never as a routine auto-merge.
```

**Acceptance criteria:**
- [ ] §2i exists with PR-class recognition, internal-roll-ups-aren't-PRs, roll-up-conflict signal, bottom-up order.
- [ ] §2f / §2h / Phase 3 templates no longer hard-code `git merge main` for grouped child PRs.
- [ ] Merge criteria flags the top-of-tree PR as a human gate.
- [ ] Linear-only caveat present; points to `docs/feature-branch-grouping.md`.

---

## Task 3: bd-super-build-down grouping awareness + human-gate guardrail

**Shape:** deep-and-targeted. **Files:** Modify `plugin/skills/bd-super-build-down/SKILL.md`.
**Parallel-safe with:** all. **Blocked by:** Task 1.
**Rubric:** Pattern anchor — existing Tier classification + Autonomy Guardrails. Rollback — revert PR. Sole owner of file.

**Edit 3.1 — Phase 2 Tier 3 escalation list (after line 158, item 11):**
```markdown
11. The **top-of-tree `feature → base` roll-up PR** (`[ai-implement] Feature branch ready for review`) —
    always a human gate; never auto-merged.
```

**Edit 3.2 — "Never auto-merge when" (after line 375):**
```markdown
- The PR is the **top-of-tree `feature → base` roll-up PR** (title `[ai-implement] Feature branch ready
  for review`). bd-super-build-down drives every leaf and parent-closing PR to merge and lets internal
  roll-ups happen automatically, but the final feature-branch merge is a deliberate human review of the
  whole integrated feature. Smoke-jump the feature branch, post the summary, and **surface this PR for a
  human — do not merge it.**
```

**Edit 3.3 — Agent comment conventions (line 424):** same `git merge main` → base-branch generalization as Task 2 (note: "for grouped child PRs the base is the feature branch").

**Edit 3.4 — new short subsection in Phase 4 (after 4e/before Phase 5) or a note under Phase 6 Queue Assessment:**
```markdown
### Feature-branch grouping (Linear only)

For a grouped tree (`docs/feature-branch-grouping.md`): work child PRs (base = a feature branch) in the
usual tiers; internal roll-ups are automatic direct merges (not PRs — don't chase them); if a child is
Done but its work is missing from the parent branch, that's a **roll-up conflict** → log it as a manual
step, don't `@agent`. The **top-of-tree PR is always Tier 3** (human gate) — see Autonomy Guardrails.
```

**Acceptance criteria:**
- [ ] Top-of-tree PR appears in Tier 3 and in "Never auto-merge when."
- [ ] Phase 4 explains: drive children, internal roll-ups automatic, roll-up conflict = manual step, top PR = human gate.
- [ ] Agent-comment conventions generalized off `git merge main` for grouped children.
- [ ] Points to `docs/feature-branch-grouping.md`.

---

## Task 4: bd-summit-push cascade-aware sequencing

**Shape:** deep-and-targeted. **Files:** Modify `plugin/skills/bd-summit-push/SKILL.md`.
**Parallel-safe with:** all. **Blocked by:** Task 1.
**Rubric:** Pattern anchor — Phase 2 Dependency Graph Analysis (96–131). Sole owner of file.

**Edit 4.1 — new subsection in Phase 2 Dependency Graph Analysis (after line 131):**
```markdown
#### Feature-branch grouping (Linear only)

When the plan contains a parent/child **feature node** (`docs/feature-branch-grouping.md`), the
dependency graph is not "all PRs → base." Model the **cascade**:

- Leaf children → their parent **feature branch** (`ai-implement/feature/<key>`), not the base.
- A parent's **own closing work** is implicitly `Blocked by:` all its labelled children (it runs only
  after they're terminal). Put it last on the parent's branch.
- Internal roll-ups (child feature branch → parent branch) are automatic direct merges — not nodes that
  need scheduling.
- The **critical path runs *through* the feature node** and ends at the single top-of-tree
  `feature → base` PR (the human gate). Time-to-land = longest leaf→…→top chain, plus the human review.
- Labelling sequence: whole-tree labelling is safe (race guard); a parent advances only once its children
  carry `{{IMPLEMENT_LABEL}}`.

(Jira: no grouping — keep the flat "all PRs → base" model.)
```

**Edit 4.2 — Push Order / Parallel Tracks manifest (lines 251–265):** add a note that grouped children form a track whose merges target the feature branch, and the top-of-tree PR is the track's terminal human gate.

**Acceptance criteria:**
- [ ] Phase 2 models the cascade (leaf → feature branch → roll-up → top PR), not all-PRs-to-base.
- [ ] Parent closing work shown as blocked-by-all-children; critical path ends at the top-of-tree PR.
- [ ] Linear-only caveat; points to `docs/feature-branch-grouping.md`.

---

## Task 5: bd-mega-build-up grouping-aware planning + rubric

**Shape:** deep-and-targeted. **Files:** Modify `plugin/skills/bd-mega-build-up/SKILL.md`.
**Parallel-safe with:** all. **Blocked by:** Task 1.
**Rubric:** Pattern anchor — AI-Implement Pipeline Context (39–55), Issue Design Rubric (57–115), Parallel-execution awareness (375). Sole owner of file.

**Edit 5.1 — AI-Implement Pipeline Context (after line 55, the implications list):** add implication #5:
```markdown
5. **Parent/child trees become feature nodes (Linear only).** A parent issue labelled `{{IMPLEMENT_LABEL}}`
   with labelled children owns a feature branch `ai-implement/feature/<key>`; children PR into it, and the
   tree rolls up to one human-reviewed `feature → base` PR. Plan the tree, the labelling order, and the
   parent's deferred closing work accordingly. Full model: `docs/feature-branch-grouping.md`.
```

**Edit 5.2 — Issue Design Rubric, after Hard Rule 9 (line 91), add Hard Rule 10:**
```markdown
10. **Feature-node parents defer their own work (Linear grouping).** When a plan uses a parent/child
    feature node, the parent's *own* closing work is `Blocked by:` **all** its labelled children — it
    dispatches only after every child is terminal (Done or Cancelled), onto the parent's own feature
    branch. A parent whose body mixes closing work with "and also coordinates the children" is fine; a
    parent that must merge to base *before* its children is a grouping violation — children PR into the
    parent's branch, not the other way around. (Jira: no grouping; ignore.)
```

**Edit 5.3 — Parallel-execution awareness (after line 383):** add:
```markdown
- **Grouped children are more parallel-safe, not less.** Children of a feature node each PR into the same
  feature branch on isolated child branches — they don't collide on base. Normal file-overlap rules still
  apply *within* the feature branch. Mark the parent's closing-work task `Blocked by:` every child.
- **Labelling order (Linear grouping):** label the whole tree at once — the race guard keeps a parent from
  being worked before a child carries `{{IMPLEMENT_LABEL}}`. Don't file a parent expecting it to merge to
  base first.
```

**Acceptance criteria:**
- [ ] Pipeline Context gains the feature-node implication.
- [ ] Hard Rule 10 (feature-node parents defer own work) added.
- [ ] Parallel-execution section notes grouped-children safety + labelling order.
- [ ] Linear-only throughout; points to `docs/feature-branch-grouping.md`.

---

## Task 6: bd-build-up grouping-aware planning (lighter)

**Shape:** deep-and-targeted. **Files:** Modify `plugin/skills/bd-build-up/SKILL.md`.
**Parallel-safe with:** all. **Blocked by:** Task 1.
**Rubric:** Pattern anchor — "The AI coding agent pipeline" (58), Issue design principles (192), Filing waves (282). Sole owner of file.

**Edit 6.1 — "The AI coding agent pipeline" (after line 65):** add a short paragraph: parent/child trees become feature nodes on Linear; children PR into `ai-implement/feature/<key>`; one human-gate `feature → base` PR at top; pointer to `docs/feature-branch-grouping.md`.

**Edit 6.2 — Issue design principles (192–227):** add a principle: when decomposing into a parent + children, recognize the feature node; the parent's closing work is blocked by all children; children target the feature branch; whole-tree labelling is race-guard-safe.

**Edit 6.3 — Filing/waves (282–306):** note that for a feature node, labelling the tree releases children to PR into the feature branch (not base); the parent advances after children land.

**Acceptance criteria:**
- [ ] Pipeline section notes feature nodes (Linear) + pointer.
- [ ] Issue-design principles cover parent-defers-closing-work + children-target-feature-branch.
- [ ] Filing/waves note grouping labelling behavior. Linear-only caveat present.

---

## Task 7: bd-smoke-jumper feature-branch test targets

**Shape:** deep-and-targeted. **Files:** Modify `plugin/skills/bd-smoke-jumper/SKILL.md`.
**Parallel-safe with:** all. **Blocked by:** Task 1.
**Rubric:** Pattern anchor — Phase 1 collect (101), §2c/§2d classify + test profile (130–165). Sole owner of file.

**Edit 7.1 — Phase 1 "For each target PR, collect" (after line 109):** add: *"the PR's **base branch** — for a grouped child PR this is a feature branch `ai-implement/feature/<key>`, not the repo base; the preview deploy belongs to that PR against its feature branch."*

**Edit 7.2 — new note in §2d or Phase 4 (after line 165):**
```markdown
### Feature-branch grouping (Linear only)

Under parent/child grouping (`docs/feature-branch-grouping.md`), child PRs target a feature branch, so a
child's preview reflects the feature-in-progress, not base. Two implications:
- Test a **child PR's** preview as usual, but read its results as "this slice on top of the feature
  branch," not "on top of production base."
- When a feature is complete, the **top-of-tree `feature → base` PR** is the moment to smoke-test the
  **whole integrated feature branch** before a human merges it — that's the highest-value smoke target.
```

**Acceptance criteria:**
- [ ] Phase 1 collects the PR's base branch and notes the feature-branch case.
- [ ] A grouping note explains child-PR previews vs the integrated-feature smoke at the top PR.
- [ ] Linear-only caveat; points to `docs/feature-branch-grouping.md`.

---

## Task 8: Peripheral pointers (README + bd-project-setup + CLAUDE.md)

**Shape:** wide-and-shallow (same mechanical "add a pointer" across 3 light files). **Files:** Modify `README.md`, `plugin/skills/bd-project-setup/SKILL.md`, `CLAUDE.md`.
**Parallel-safe with:** all (no other task touches these files). **Blocked by:** Task 1.
**Rubric:** Pattern anchor — existing catalog/notes sections. Trust boundary — none. Rollback — revert PR.

**Edit 8.1 — `README.md`:** in the skills catalog/overview, add a short line: feature-branch grouping awareness exists; bd-build-down/super-build-down/summit-push/mega-build-up/build-up/smoke-jumper are grouping-aware (Linear only); see `docs/feature-branch-grouping.md`.

**Edit 8.2 — `plugin/skills/bd-project-setup/SKILL.md` Notes (after line 376):**
```markdown
- **Feature-branch grouping (Linear only).** If a project will use AI-Implement parent/child
  feature-branch grouping, re-sync workflows so the target repo's `claude-implement.yml` accepts the
  `base_branch` input (un-synced repos 422 on grouped dispatch). Grouping is Linear-only — the Jira path
  always PRs to the base branch. See `docs/feature-branch-grouping.md`.
```

**Edit 8.3 — `CLAUDE.md` (this repo):** add a one-line pointer under the AI-Implement handoff section: *"Feature-branch grouping behavior the skills must respect: see `docs/feature-branch-grouping.md`."*

**Acceptance criteria:**
- [ ] README notes grouping awareness + which skills + pointer.
- [ ] bd-project-setup Notes covers `base_branch` re-sync + Linear-only.
- [ ] CLAUDE.md points to the canonical doc.

---

## Self-review checklist (run after all tasks)

1. **Terminology consistency** — every file uses the shared terms verbatim (feature node / feature branch / internal roll-up / top-of-tree PR / roll-up conflict / race guard / Linear-only). No drift.
2. **Linear-only guard** — every grouping section states the Jira/flat fallback.
3. **No "see doc" without inlined behavior** — each skill's operative behavior is inlined; the doc pointer is supplementary, not load-bearing.
4. **Direct-merge correctness** — no file describes internal roll-ups as PRs.
5. **Human-gate correctness** — both build-down skills reserve the top-of-tree PR for a human; super-build-down never auto-merges it.
6. **Cross-references resolve** — every `docs/feature-branch-grouping.md` pointer is to the real path.

## Issue manifest (preview — Phase 4 Gate 3)

| # | Title | Shape | File(s) | Wave | Blocked by |
|---|---|---|---|---|---|
| 1 | Canonical doc: feature-branch grouping reference | deep | `docs/feature-branch-grouping.md` | pilot | — |
| 2 | bd-build-down: feature-branch grouping awareness | deep | bd-build-down/SKILL.md | 2 | #1 |
| 3 | bd-super-build-down: grouping + human-gate guardrail | deep | bd-super-build-down/SKILL.md | 2 | #1 |
| 4 | bd-summit-push: cascade-aware sequencing | deep | bd-summit-push/SKILL.md | 2 | #1 |
| 5 | bd-mega-build-up: grouping-aware planning + rubric | deep | bd-mega-build-up/SKILL.md | 2 | #1 |
| 6 | bd-build-up: grouping-aware planning | deep | bd-build-up/SKILL.md | 2 | #1 |
| 7 | bd-smoke-jumper: feature-branch test targets | deep | bd-smoke-jumper/SKILL.md | 2 | #1 |
| 8 | Peripheral pointers (README + bd-project-setup + CLAUDE.md) | wide | README.md, bd-project-setup/SKILL.md, CLAUDE.md | 2 | #1 |

All children: team BDS, project *Feature-branch grouping awareness*, parent BDS-12, **no `AI-Implement` label**.
