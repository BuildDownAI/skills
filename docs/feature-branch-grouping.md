# Feature-branch grouping (operator reference for the BuildDown skills)

How AI-Implement turns a parent/child issue tree — on **either** the Linear or the Jira provider — into a
cascade of git branches, and what that means when you **plan** work (bd-build-up / bd-mega-build-up /
bd-summit-push) and **land** it (bd-build-down / bd-super-build-down / bd-smoke-jumper).

This is the operator-facing summary. The implementation and the authoritative behaviour live upstream
in AI-Implement: `docs/feature-branch-grouping.md`, `src/feature-branch.ts`, `src/merge-up.ts`
(`BuildDownAI/AI-Implement`). When this doc and the upstream source disagree, **upstream wins** — update
this doc.

> **Both providers.** Feature-branch grouping exists on **both** the Linear and the Jira providers (Jira
> reached parity in AI-Implement #64). What differs is only *how an issue joins a group* — see
> "Designation & hierarchy per tracker" below. "Default Branch" throughout means the repo's configured
> default — `mapping.defaultBranch`, e.g. `testing`; **not** necessarily `main`.

---

## 1. Mental model

An issue tree — Linear or Jira — maps onto a tree of git branches.

- A **feature node** is a *designated* issue (designation per the table below) that has at least one
  designated child. It owns a long-running **feature branch** `ai-implement/feature/<key>`.
- Its designated **children PR into that feature branch**, not into the **Default Branch**.
- The tree is **recursive**: a child that is itself a feature node gets its own feature branch cut from
  its parent's, and so on.
- A feature node can also carry **its own closing work** (work not done in any child — e.g. a final
  cleanup). That work runs **last**, after all children land, on the node's own feature branch.
- Completed feature branches **roll up** into their parent's branch automatically; the single
  top-of-tree merge into the **Default Branch** is left as a human-reviewed PR.

**Two grouping modes — identical except the branch name.** A grouping parent owns
`ai-implement/<mode>/<key>`, where `<mode>` comes from a `# ai-implement.yml` block in the parent's
**description** (`feature_branch.mode`); absent or unreadable → `feature`.

- **`feature`** (default) — groups *sub-parts of one feature*: `ai-implement/feature/<key>`.
- **`multi-issue`** — groups *otherwise-unrelated issues* that should still land as one reviewable unit:
  `ai-implement/multi-issue/<key>`.

```
# ai-implement.yml (example)
feature_branch:
  mode: "multi-issue"
```

The mode's **only** effect anywhere is the branch path segment. Dispatch, child PRs, recursion, roll-up,
the human gate, classification (§3), and gating are **identical** between the modes — a reader who looks
for other differences won't find any. The grouped issues are meant to be enumerated in the top-of-tree
roll-up PR body (§4, `Grouped issues:` — pending AII-227), not in the branch name. Write every in-issue example with
`# ai-implement.yml (example)` — a bare `# ai-implement.yml` first line is the real marker and gets
stripped from that issue's own spec.

```
testing                                  (the repo's Default Branch)
└─ ai-implement/feature/PROJ-100         parent PROJ-100 (feature node)
   ├─ ai-implement/feature/PROJ-101      child PROJ-101 (also a feature node)
   │   ├─ child PR: PROJ-103 ──────────► feature/PROJ-101
   │   └─ child PR: PROJ-104 ──────────► feature/PROJ-101
   └─ child PR: PROJ-102 ──────────────► feature/PROJ-100
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

Each poll, AI-Implement classifies every **designated**, non-terminal issue (designation per the table
above — the `AI-Implement` label on Linear, a non-empty `AI-Implement-Status` + Repo match on Jira):

- **Leaf** (no children) → dispatched; its PR targets the nearest feature-node ancestor branch (or base).
- **Feature node, children not all terminal** → skipped; its branch is cut lazily when the first child
  dispatches.
- **Feature node, all children terminal** → its own closing work dispatches onto its feature branch.
- **Parent with children but none *designated* yet** → **race guard**: skipped, *not* worked as a leaf.
  This is why you can designate a whole tree at once (or top-down) without the parent being implemented
  prematurely. ("Designate" = apply the `AI-Implement` label on Linear, or set `AI-Implement-Status` + Repo
  on Jira.)

"Terminal" means **Done or Cancelled** (on Jira, any status whose `statusCategory` is `done`) — a cancelled
child doesn't block its parent forever.

**Planning consequence:** designate the whole tree at once and let the gates sequence it. A parent's own
closing work is effectively `Blocked by:` all its designated children. Never write a parent that must merge
to the Default Branch *before* its children — children PR into the parent's branch, not the reverse.

**Depth cap & failure modes.** Ancestor chains are capped at **depth 5** on both providers. On Jira the two
queries fail in opposite directions by design: the **gating-children** query fails **closed** (a transient
Jira error defers the whole candidate batch that poll, so a feature-node parent never dispatches its closing
work onto base ahead of its children), while the **branch-targeting ancestor walk** fails **open** (nesting
collapses — a leaf then targets the Default Branch, a feature node still gets its own branch cut from the
Default Branch, only losing its position under any ancestor). Branch resolution always fails open to the
Default Branch.

## 4. The roll-up (merge-up)

When a feature node completes, its branch merges into its parent's branch. **There are two kinds, and
they look different to a landing skill:**

- **Internal roll-up** (the parent is itself a feature node) → a **direct `git merge`, not a PR**
  (commit message `[ai-implement] Automated feature-branch roll-up`, deliberately free of any issue
  identifier). *Why no PR:* a roll-up PR's base name and title encode the parent's key, so the tracker's
  GitHub integration would auto-link it and mark the parent **Done on merge — before its own closing work
  runs** (Linear's GitHub integration; the Jira analog is Smart Commits / GitHub-for-Jira). A plain,
  identifier-free merge commit gives the integration nothing to link.
  - These do **not** appear in the open-PR list. Don't look for them and don't create them.
  - A direct merge can **conflict** → a **roll-up conflict** that needs a manual `git merge`.
- **Top-of-tree PR** (no feature-node parent) → an open `feature → base` PR titled
  `[ai-implement] Feature branch ready for review`, **never auto-merged**. This is the **human gate**.
  Its body **will** enumerate a **`Grouped issues:`** list of the grouped child issues (**both modes**) —
  this compensates for the branch name not carrying the child keys, so a landing skill can confirm every
  child made it in. *(Pending orchestrator support — **AII-227**; until it ships, the roll-up PR references
  only the parent via `Fixes <parent>`, so verify child landing against the tracker hierarchy instead.)*

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
| **bd-mega-build-up / bd-build-up** | Plan parent + children as a feature node; the parent's closing work is `Blocked by:` all children; whole-tree **designation** is race-guard-safe; children PR into the feature branch. Linear designates by label; Jira by `AI-Implement-Status` + Repo (canonical shape: a Story with sub-task children under an un-designated tracking Epic). |
| **bd-smoke-jumper** | Child-PR previews reflect the feature-in-progress (on top of the feature branch); the integrated feature branch at the top PR is the highest-value smoke target. |

## 6. Boundaries & prerequisites

- **Both providers.** Grouping works on Linear and Jira. The only per-tracker difference is designation +
  hierarchy (see the table in §1). An issue that isn't designated on its tracker falls back to the flat
  model (PRs to the Default Branch) — that's the graceful degradation, not a provider limitation.
- **Workflows must accept `base_branch`.** AI-Implement passes the resolved feature branch to the runner
  as the `base_branch` workflow input. The target repo's `claude-implement.yml` must accept it — **re-sync
  workflows before relying on grouping (on either tracker's target repos)**, or grouped dispatch 422s. (Un-synced repos still work for the
  non-grouped path, because the orchestrator only sends `base_branch` when grouping moved it off the
  default.)
- **Fails open.** Any branch-resolution error falls back to the Default Branch, so a grouping failure never
  blocks the work — it just degrades to the flat model for that issue.

## 7. Upstream source of truth

- `BuildDownAI/AI-Implement` → `docs/feature-branch-grouping.md` (full operator/developer reference)
- `src/feature-branch.ts` — `resolveBaseBranch` (cascade branch creation + PR-base resolution)
- `src/merge-up.ts` — `runMergeUps` (internal direct merge vs top-of-tree human PR)
- `src/pipeline/branch-name.ts` — `buildFeatureBranchName` (`ai-implement/feature/<key-slug>`)
- `src/providers/jira.ts` — `enrichFeatureBranches` + `fetchFeatureNodeRollUps` (Jira designation, gating, roll-up discovery)
- `src/providers/jira-hierarchy.ts` — `classifyByChildren`, `ancestorChain` (Jira feature-node shape + chain walk)
