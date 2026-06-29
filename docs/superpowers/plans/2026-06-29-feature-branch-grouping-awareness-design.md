# BuildDown skills — feature-branch grouping awareness — Design Decisions

**Tracker:** Linear (`linear-eudoxus`, workspace eudoxus, **team BDS**). Container project: *Feature-branch grouping awareness* (to be created). Parent/tracking issue: **BDS-12**.
**Repo:** `BuildDownAI/skills` (branch base: `testing`).
**Source of truth for the feature:** AI-Implement `docs/feature-branch-grouping.md`, `src/feature-branch.ts`, `src/merge-up.ts` (currently on AI-Implement's `testing` branch).

## Objective

Update the BuildDown skills so they correctly plan for, sequence, and drive work when AI-Implement's **parent/child feature-branch grouping** is in play. Today the skills assume a flat model — every `AI-Implement` issue PRs to the repo base branch and is independently mergeable. Under grouping, a labelled parent with labelled children becomes a *feature node* owning `ai-implement/feature/<key>`; children PR **into that branch**; the tree cascades recursively and rolls up to a single human-reviewed `feature → base` PR. The skills must encode awareness of this so operators don't mis-plan trees or mis-handle roll-ups.

## Scope

**In v1:**
- A new canonical reference: repo-root `docs/feature-branch-grouping.md` (operator-facing adaptation of AI-Implement's doc).
- Compact, self-contained "Feature-branch grouping (Linear only)" sections inlined into the six core skills: `bd-build-down`, `bd-super-build-down`, `bd-summit-push`, `bd-mega-build-up`, `bd-build-up`, `bd-smoke-jumper`.
- Light pointers in `README.md`, `bd-project-setup/SKILL.md`, and this repo's `CLAUDE.md`.

**Deferred:**
- Scheduling relative to AII-141 ("per-project skills-repository integration"). Decided **related, not blocking** — see Overlap. The work proceeds now.

**Out of scope:**
- `bd-belay-on` edits (generic handoff pattern; no strong grouping tie).
- Any change to AI-Implement itself — its `feature-branch.ts` / `merge-up.ts` are read-only sources of truth.
- A Jira grouping path — grouping is **Linear-only**; skills document that boundary but build no Jira support.
- Running these doc-edit issues through the AI-Implement pipeline — they are human-authored; **no `AI-Implement` label**.
- The BDS-5 `bd-` rename (already shipped on `testing`; earlier flag was a stale-checkout artifact).

## Decisions

### Structure: canonical doc + inlined per-skill sections
A skill loaded at runtime only reliably reads files **inside its own dir** (the `trackers/*.md` precedent), and the skills' own cardinal rule is "readable cold — don't rely on links." Therefore the **load-bearing behavior is inlined** into each affected skill (sized to that skill's job), and a single **canonical long-form** lives at repo-root `docs/feature-branch-grouping.md` as the human reference each skill points to. Not doc-only-with-pointers (skills wouldn't be self-contained); not full-model-copied-7× (duplication/drift).

### Canonical doc home
Repo-root `docs/feature-branch-grouping.md`, mirroring AI-Implement's own path. Ships in the repo for humans/maintainers; the inlined sections are what travel into an installed skill's runtime context.

### The grouping model the skills must encode (facts, from AI-Implement source)
- **Feature node:** an `AI-Implement` issue with ≥1 `AI-Implement` child → owns long-running `ai-implement/feature/<key-slug>` (`buildFeatureBranchName`).
- **Children PR into the parent feature branch**, not the repo base. `resolveBaseBranch` walks the `featureBranchChain`, creating each branch from the previous (or base for the first), and **fails open** to base on any error.
- **Race guard:** a parent labelled before any child is **not** worked as a leaf; it waits. So labelling a whole tree at once is safe.
- **Parent's own closing work** dispatches only after **all** labelled children are terminal (completed *or* cancelled), onto its own feature branch.
- **Roll-up (merge-up):**
  - *Internal* (parent is itself a feature node) → **direct `git merge`, no PR**, commit `[ai-implement] Automated feature-branch roll-up` (no issue identifier — so Linear won't auto-link and mark the parent Done before its closing work runs). Can return **`conflict`** → needs a manual merge.
  - *Top of tree* → one PR `[ai-implement] Feature branch ready for review` (head `ai-implement/feature/<top>` → base), **never auto-merged**; the human gate.
- **Done-on-merge** is Linear's GitHub integration, not the orchestrator.
- **Linear-only:** the Jira provider returns no chain and no roll-ups — its issues always PR to base.

### Per-skill behavioral deltas

| Skill | What it must now encode |
|---|---|
| **bd-build-down** | Recognize PR classes by base/title: normal **child PR** (base = a feature branch, *not* `main`) → drive to merge; **top-of-tree roll-up PR** (`[ai-implement] Feature branch ready for review`, base = repo base) → the human-review milestone, merged last after reviewing the whole integrated feature. **Internal roll-ups are not PRs** — don't hunt for them. A roll-up **`conflict`** (children Done but absent from the parent branch) is a **manual-merge** signal. Conflict-resolution base = the **feature branch**, not `main`. Merge order is **bottom-up** (leaves → parent closing work → top PR). |
| **bd-super-build-down** | Same recognition, plus the autonomy hard rule: **never auto-merge the top-of-tree `feature → base` PR.** Drive all leaf + parent-closing PRs, let internal roll-ups happen automatically, dispatch bd-smoke-jumper against the integrated feature branch, post a summary, then **stop and surface the top PR for human merge.** |
| **bd-summit-push** | Sequencing/dependency optimization models the **cascade** (leaves → feature branch → roll-up → top PR), not "all PRs → base." Critical path runs *through* the feature node; the top PR is the terminal human gate. |
| **bd-mega-build-up** | Planning: parent + children = a feature node. Rubric additions: a parent's **own closing work is `Blocked by:` all its children**; children on a feature branch are **more** parallel-safe (isolated branch), but still subject to file-overlap rules. Labelling sequence: whole-tree labelling is safe (race guard); children must carry `AI-Implement` for the parent to advance. |
| **bd-build-up** | Same planning logic, lighter: recognize the parent/child shape, note children PR into the feature branch, point to the canonical doc. |
| **bd-smoke-jumper** | Preview/test targets may live on the **feature branch** (child PRs deploy previews against it); when validating a completed feature, test the **integrated feature branch** before the top PR merges. |

### Peripheral pointers (light)
- `README.md`: catalog note that grouping awareness exists + which skills are grouping-aware + pointer to the canonical doc.
- `bd-project-setup/SKILL.md`: note — to use grouping, **re-sync workflows** so the target repo's `claude-implement.yml` accepts the `base_branch` input; grouping is **Linear-only**.
- `CLAUDE.md` (this repo): one-line pointer to `docs/feature-branch-grouping.md` (honours BDS-11's original "feature branch context in claude.md" ask, which BDS-12 absorbed).

### Trust boundaries / failure modes / observability
- **Trust boundary:** none new — documentation edits to a markdown repo.
- **Failure mode the skills must name:** a conflicted internal roll-up (silent — no PR; surfaces as children Done but missing from the parent feature branch) → manual `git merge`.
- **Rollback:** trivial (revert the doc PRs). No flags.
- **Observability:** n/a (prose changes); the skills themselves gain the *ability* to spot the roll-up-conflict signal.

### Rollout / testing
- Branch base `testing`; each issue = one PR into `testing`.
- "Verification" = human review of the SKILL.md prose (`{{BUILD_CMD}}` = none). Self-review pass per the plan: cross-skill terminology consistency (one name for each concept: *feature node*, *feature branch*, *internal roll-up*, *top-of-tree PR*, *roll-up conflict*).
- Implementation order is **doc-first** (pilot): write `docs/feature-branch-grouping.md`, then the per-skill sections mirror its language. (Pilot-first applies to *implementation order*, not pipeline waves — no `AI-Implement` label.)

## Overlap & Reconciliation

- **BDS-11 "Add feature branch context to claude.md and skills"** — Classification: **Duplicate** (already marked Duplicate/canceled). Action: **none** (superseded by BDS-12); its `CLAUDE.md` ask is honoured by the peripheral-pointers work.
- **AII-141 "Per-project skills-repository integration"** (AI-Implement team, Backlog) — Classification: **Dependency, stale**. The blocking premise (runner-side skills install) was retired when **BDS-3/6/7/8 were cancelled** on the finding that these skills are human planning-time tools, not runner-executed. Action: **proceed now**; link as related, do not block.
- **BDS-1** (BDS twin of AII-141, Done) — Classification: Dependency, satisfied. Action: none.
- **BDS-5** (`bd-` rename, Done) — Classification: Adjacent. Action: none — rename is live on `testing`; reference `plugin/skills/bd-*/SKILL.md` paths.
- **"Per-project skills configuration" project (BDS-2/4/9/10, …)** — no content overlap. Action: none.

## Open Questions

- **Exact child-issue count** — proposed ~8 (canonical doc + 6 core skills + 1 combined "peripheral pointers" issue for README + bd-project-setup + CLAUDE.md). Locked in the Phase 3 plan; default as stated if not changed.
- **Canonical-doc duplication vs AI-Implement's** — the skills-repo doc is operator-framed and will note AI-Implement's doc as the upstream source of truth, rather than copying it verbatim. Default: maintain a focused operator adaptation, link upstream.
