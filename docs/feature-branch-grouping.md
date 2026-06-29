# Feature-branch grouping (operator reference for the BuildDown skills)

How AI-Implement turns a Linear parent/child issue tree into a cascade of git branches, and what
that means when you **plan** work (bd-build-up / bd-mega-build-up / bd-summit-push) and **land** it
(bd-build-down / bd-super-build-down / bd-smoke-jumper).

This is the operator-facing summary. The implementation and the authoritative behaviour live upstream
in AI-Implement: `docs/feature-branch-grouping.md`, `src/feature-branch.ts`, `src/merge-up.ts`
(`BuildDownAI/AI-Implement`). When this doc and the upstream source disagree, **upstream wins** — update
this doc.

> **Linear-only.** Feature-branch grouping exists only on the Linear provider. On Jira there is no
> grouping: every `AI-Implement` issue PRs straight to the **Default Branch** (the repo's configured
> default — `mapping.defaultBranch`, e.g. `testing`; **not** necessarily `main`), and everything below is
> moot. The skills' grouping sections all carry this caveat.

---

## 1. Mental model

A Linear issue tree maps onto a tree of git branches.

- A **feature node** is an issue that carries the `AI-Implement` label *and* has at least one
  `AI-Implement` child. It owns a long-running **feature branch** `ai-implement/feature/<key>`.
- Its labelled **children PR into that feature branch**, not into the **Default Branch**.
- The tree is **recursive**: a child that is itself a feature node gets its own feature branch cut from
  its parent's, and so on.
- A feature node can also carry **its own closing work** (work not done in any child — e.g. a final
  cleanup). That work runs **last**, after all children land, on the node's own feature branch.
- Completed feature branches **roll up** into their parent's branch automatically; the single
  top-of-tree merge into the **Default Branch** is left as a human-reviewed PR.

```
testing                                  (the repo's Default Branch)
└─ ai-implement/feature/PROJ-100         parent PROJ-100 (feature node)
   ├─ ai-implement/feature/PROJ-101      child PROJ-101 (also a feature node)
   │   ├─ child PR: PROJ-103 ──────────► feature/PROJ-101
   │   └─ child PR: PROJ-104 ──────────► feature/PROJ-101
   └─ child PR: PROJ-102 ──────────────► feature/PROJ-100
```

## 2. What changes vs the flat model

The skills were written for a **flat** model: every `AI-Implement` issue PRs to the Default Branch and is
independently mergeable, ordered only by `Blocked by:`. Under grouping:

- **Children no longer PR to the Default Branch.** A child PR's base is its parent's feature branch. Diff,
  conflict, and merge operations use that feature branch, not the Default Branch.
- **Sequencing runs *through* the feature node**, not around it. The critical path is leaf → … →
  feature branch → top-of-tree PR.
- **One human-gate PR at the top** replaces N independent merges. The reviewer sees the whole integrated
  feature once, instead of merging each child to the Default Branch separately.

## 3. Classification & the race guard

Each poll, AI-Implement classifies every `AI-Implement`, non-terminal issue:

- **Leaf** (no children) → dispatched; its PR targets the nearest feature-node ancestor branch (or base).
- **Feature node, children not all terminal** → skipped; its branch is cut lazily when the first child
  dispatches.
- **Feature node, all children terminal** → its own closing work dispatches onto its feature branch.
- **Parent with children but none labelled `AI-Implement` yet** → **race guard**: skipped, *not* worked
  as a leaf. This is why you can label a whole tree at once (or top-down) without the parent being
  implemented prematurely.

"Terminal" means **Done or Cancelled** — a cancelled child doesn't block its parent forever.

**Planning consequence:** label the whole tree at once and let the gates sequence it. A parent's own
closing work is effectively `Blocked by:` all its labelled children. Never write a parent that must merge
to the Default Branch *before* its children — children PR into the parent's branch, not the reverse.

## 4. The roll-up (merge-up)

When a feature node completes, its branch merges into its parent's branch. **There are two kinds, and
they look different to a landing skill:**

- **Internal roll-up** (the parent is itself a feature node) → a **direct `git merge`, not a PR**
  (commit message `[ai-implement] Automated feature-branch roll-up`, deliberately free of any issue
  identifier). *Why no PR:* a roll-up PR's base name and title encode the parent's key, so Linear's
  GitHub integration would auto-link it and mark the parent **Done on merge — before its own closing
  work runs.** A plain merge commit gives Linear nothing to link.
  - These do **not** appear in the open-PR list. Don't look for them and don't create them.
  - A direct merge can **conflict** → a **roll-up conflict** that needs a manual `git merge`.
- **Top-of-tree PR** (no feature-node parent) → an open `feature → base` PR titled
  `[ai-implement] Feature branch ready for review`, **never auto-merged**. This is the **human gate**.

**Roll-up conflict — the silent failure mode.** Because internal roll-ups aren't PRs, a conflicted one
surfaces only as: a child issue is **Done** but its work is **missing from the parent feature branch**
(or the parent's closing-work PR is missing expected child changes). Treat that as a **manual merge**
step — merge the child feature branch into the parent yourself; don't `@agent` it.

## 5. Which skill cares about what

| Skill | What grouping changes |
|---|---|
| **bd-build-down** | Recognize a **child PR** (base = a feature branch) vs the **top-of-tree PR** (human gate, merged last). Internal roll-ups aren't PRs. A roll-up conflict = manual merge. Conflict base = the feature branch, not the Default Branch. Merge bottom-up. |
| **bd-super-build-down** | Same, plus: **never auto-merge the top-of-tree PR** — drive the children, let internal roll-ups happen, smoke-test the integrated branch, then surface the top PR for a human. |
| **bd-summit-push** | Model the cascade (leaf → feature branch → roll-up → top PR); the critical path ends at the top-of-tree human gate. |
| **bd-mega-build-up / bd-build-up** | Plan parent + children as a feature node; the parent's closing work is `Blocked by:` all children; whole-tree labelling is race-guard-safe; children PR into the feature branch. |
| **bd-smoke-jumper** | Child-PR previews reflect the feature-in-progress (on top of the feature branch); the integrated feature branch at the top PR is the highest-value smoke target. |

## 6. Boundaries & prerequisites

- **Linear-only** — Jira always PRs to the Default Branch; no grouping.
- **Workflows must accept `base_branch`.** AI-Implement passes the resolved feature branch to the runner
  as the `base_branch` workflow input. The target repo's `claude-implement.yml` must accept it — **re-sync
  workflows before relying on grouping**, or grouped dispatch 422s. (Un-synced repos still work for the
  non-grouped path, because the orchestrator only sends `base_branch` when grouping moved it off the
  default.)
- **Fails open.** Any branch-resolution error falls back to the Default Branch, so a grouping failure never
  blocks the work — it just degrades to the flat model for that issue.

## 7. Upstream source of truth

- `BuildDownAI/AI-Implement` → `docs/feature-branch-grouping.md` (full operator/developer reference)
- `src/feature-branch.ts` — `resolveBaseBranch` (cascade branch creation + PR-base resolution)
- `src/merge-up.ts` — `runMergeUps` (internal direct merge vs top-of-tree human PR)
- `src/pipeline/branch-name.ts` — `buildFeatureBranchName` (`ai-implement/feature/<key-slug>`)
