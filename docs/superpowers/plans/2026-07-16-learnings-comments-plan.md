# Learnings Comments (BDS-25) Implementation Plan

> **For the implementer (this session, manual):** prose / skill-definition work only — no application
> code, no tests in this repo. Land as one human-reviewed PR from `multi-issue-and-learnings` → `testing`.
> Verification = self-review against BDS-25's acceptance criteria + a render check that markers are
> exact-match and templates are copy-paste clean. BDS-26 is a **later** pass over the same four files.

**Goal:** every build-up/build-down leaves a durable, cross-tracker, queryable learnings comment on the
parent issue, carrying harness+model provenance and (build-down) a PR-outcome taxonomy that names
closed-unmerged as a failure.

**Architecture:** one canonical reference doc (`docs/learnings-comments.md`) that the four
session-owning skills each point to, plus a required closing step + inlined template in each skill.

**Tech Stack:** Markdown skill definitions; `plugin/.claude-plugin/plugin.json` version.

**Tracker container:** BDS-25 (spec, refreshed in Phase 4). Related: BDS-28 (orchestrator exposure),
BDS-26 (later multi-issue pass, adjacent).

---

## Canonical templates (single source — defined here, inlined verbatim into each skill + the doc)

**Build-up** (`# ai-implement-build-up-learnings`):

```
# ai-implement-build-up-learnings

**Feature:** <one line + tree shape>
**Planned by:** <harness · model>          e.g. Claude Code · Opus 4.8

## Decisions & why
- <decision> — <why; what was rejected and the concrete failure it avoids>

## The one idea worth carrying forward
<the single most reusable insight>

## Applies to
<future situations this learning generalizes to>
```

**Build-down** (`# ai-implement-build-down-learnings`):

```
# ai-implement-build-down-learnings

**Feature:** <one line>
**Driven by:** <harness · model>           e.g. Claude Code · Opus 4.8
**PRs implemented by:** <harness · model>  the AI-Implement runner; `unknown (see BDS-28)` until it emits this

## Outcome
Per PR this session drove or observed:
- PR #<n> <title> — <merged | closed-unmerged (failure) | open / never-landed | superseded>

## Deltas from plan
<what actually shipped vs. what was planned>

## Failures & gotchas
<each closed-unmerged PR with the concrete reason it failed; what bit us during landing>

## Status
<landed with these caveats | abandoned because X | superseded by Y>
```

**Provenance rule (both):** self-report the harness + model you're running under. If you cannot
determine the model, ask the operator once — never guess, never silently omit. Format: `harness · model`
(middle dot). Build-down's `**PRs implemented by:**` is read from the PR body when the orchestrator
emits it (BDS-28); until then write `unknown (see BDS-28)`.

---

## Task 1: Canonical reference doc — `docs/learnings-comments.md` (pilot / anchor — do first)

**Shape:** deep-and-targeted (one new file, all the reasoning concentrated here).
**Migration / backfill?** no.

**Files:**
- Create: `docs/learnings-comments.md`

**Pattern anchor:** `docs/feature-branch-grouping.md` (same repo — an operator-framed reference doc the
skills point to; mirror its voice and section-heading style).
**Parallel-safe with:** none (Tasks 2–5 point at this doc; do it first so the pointers resolve).

**Content (sections):**
1. **Purpose** — the compounding mechanism: every build-up/build-down leaves a durable, queryable trace
   of the load-bearing *why*. Cross-tracker, non-developer-accessible, timestamped.
2. **The two markers** — `# ai-implement-build-up-learnings` (forward-looking, posted when a build-up
   finishes) and `# ai-implement-build-down-learnings` (backward-looking, posted/updated when a
   build-down concludes). Exact-match first line. **Never reuse `# ai-implement.yml`** (opposite
   semantics — orchestrator config, stripped from the spec).
3. **Placement & edit semantics** — one canonical comment per marker per issue, **edited in place**
   (edit history preserves the timeline), on the **parent/umbrella** issue (the decision node); narrow
   per-task learnings may go on a child.
4. **Absence is signal** — a build-up comment with **no** build-down sibling means "planned but never
   landed." Never merge the two markers; the gap is queryable state.
5. **Provenance** — self-report + ask-if-unknown; `harness · model` format; build-up = `Planned by`;
   build-down = `Driven by` + `PRs implemented by` (two lines when they differ). Note the BDS-28
   dependency: `PRs implemented by` is `unknown` until the orchestrator emits harness/model on the PR.
6. **PR-outcome taxonomy (build-down)** — `merged | closed-unmerged (failure) | open / never-landed |
   superseded`. Closed-unmerged is a **failure**; record the concrete reason. **Session-only scope**,
   with the documented blind spot (a PR closed with no session running isn't auto-captured; leaned on
   the absence signal).
7. **Both templates** — inline verbatim (from this plan's "Canonical templates").
8. **Which skill owns which marker** — build-up + mega-build-up → build-up marker; build-down +
   super-build-down → build-down marker. summit-push / smoke-jumper feed **into** the build-down
   comment; they do not post their own marker.
9. **Distillation** — the load-bearing decisions a future reader would be *surprised* by, not a copy of
   the plan; link out to a fuller artifact for depth.
10. **Cross-tracker note** — both markers are plain comments; Linear `save_comment` / Jira `addComment`
    both exist, so the convention is identical on both providers.

- [ ] Write `docs/learnings-comments.md` covering sections 1–10 with both templates inlined.

## Task 2: `bd-build-up` — required closing step

**Shape:** deep-and-targeted. **Migration?** no.
**Files:** Modify `plugin/skills/bd-build-up/SKILL.md`.
**Blocked by:** Task 1 (pointer target must exist).
**Pattern anchor:** the skill's own `### After filing` section (line ~355).

- [ ] After `### After filing` (before `### When to suggest bd-build-down handoff`), add a
      `### Closing step — post the build-up learnings comment (required)` subsection: instruct posting
      `# ai-implement-build-up-learnings` on the parent/umbrella issue, one canonical comment edited in
      place, distilled; **inline the build-up template**; state the provenance rule (self-report
      `Planned by: <harness · model>`, ask once if unknown); point to `docs/learnings-comments.md`;
      state it is required ("a build-up that files issues without leaving a learnings comment is not done").
- [ ] Add a `## Key Principles` entry: *"Every build-up ends with a `# ai-implement-build-up-learnings`
      comment on the parent — the compounding trace. Required, not optional."*

## Task 3: `bd-mega-build-up` — Phase 4 capstone step

**Shape:** deep-and-targeted. **Migration?** no.
**Files:** Modify `plugin/skills/bd-mega-build-up/SKILL.md`.
**Blocked by:** Task 1.
**Pattern anchor:** Phase 4 `### Step 5: Post-filing manifest` (line ~507).

- [ ] After Step 5, add `### Step 6: Post the build-up learnings comment (required capstone)`: post
      `# ai-implement-build-up-learnings` on the project/epic parent; same rules as Task 2; **inline the
      build-up template**; provenance rule; pointer to `docs/learnings-comments.md`.
- [ ] Add a `## Red Flags — Stop and Restart the Phase` entry: *"Issues filed but no
      `# ai-implement-build-up-learnings` comment posted. → The compounding trace is the capstone. Post
      it before declaring the build-up done."*

## Task 4: `bd-build-down` — required closing step + PR-outcome taxonomy

**Shape:** deep-and-targeted (the outcome taxonomy carries reasoning). **Migration?** no.
**Files:** Modify `plugin/skills/bd-build-down/SKILL.md`.
**Blocked by:** Task 1.
**Pattern anchor:** Phase 6 `## Session Summary` (line ~456); it already emits "PRs Merged" / "PRs
Worked But Not Merged" tables — the taxonomy formalizes that data.

- [ ] In Phase 6, add `### Closing step — post/update the build-down learnings comment (required)`:
      for each driven parent issue, post/update `# ai-implement-build-down-learnings` (one canonical
      comment, edited in place); **inline the build-down template**; define the PR-outcome taxonomy
      (`merged | closed-unmerged (failure) | open / never-landed | superseded`), calling closed-unmerged
      a **failure** with a concrete reason, detected from the PR state already read via GitHub MCP;
      state abandonment is a valid terminal outcome; state the **session-only scope + documented blind
      spot**; provenance (`Driven by` self-report; `PRs implemented by` from PR body or
      `unknown (see BDS-28)`); pointer to `docs/learnings-comments.md`.
- [ ] Add a `## Key Principles (the non-negotiables)` entry and/or `## Common Failure Patterns` entry:
      session concluded without posting/updating the build-down learnings comment = not done.

## Task 5: `bd-super-build-down` — required autonomous closing step

**Shape:** deep-and-targeted. **Migration?** no.
**Files:** Modify `plugin/skills/bd-super-build-down/SKILL.md`.
**Blocked by:** Task 1.
**Pattern anchor:** Phase 7 `## Session Summary (Autonomous Write)` (line ~317) — the learnings comment
is an autonomous write too (no approval gate, like the summary).

- [ ] In Phase 7, add the same required closing step as Task 4 (post/update
      `# ai-implement-build-down-learnings` on each driven parent), **inline the build-down template**,
      same taxonomy + provenance + session-only scope + BDS-28 fallback; mark it an **autonomous write**
      (consistent with the autonomous summary — do not ask approval).
- [ ] Add it to `### Always log` and a `## Key Principles` entry.

## Task 6: Version bump + release note

**Shape:** wide-and-shallow (one line). **Migration?** no.
**Files:** Modify `plugin/.claude-plugin/plugin.json`.
**Blocked by:** Tasks 1–5 (bump represents the shipped change).

- [ ] `"version": "0.7.0"` → `"0.8.0"` (additive / backward-compatible → minor).
- [ ] Release note = the version-bump commit message (repo convention; no CHANGELOG file exists), e.g.
      *"chore(plugin): bump 0.7.0 → 0.8.0 — learnings comments (BDS-25): required build-up/build-down
      learnings markers with harness+model provenance + PR-outcome taxonomy."*

---

## Self-review checklist (run after applying Tasks 1–6)

1. **Decision coverage:** every design-doc decision maps to a task — provenance (Tasks 1–5), required
   in all four (Tasks 2–5), PR-outcome taxonomy (Tasks 4–5), doc (Task 1), version (Task 6). ✎ confirm.
2. **Marker exact-match:** every inlined `# ai-implement-build-up-learnings` /
   `# ai-implement-build-down-learnings` is spelled identically across all files and the doc; no stray
   `# ai-implement.yml` confusion.
3. **Template consistency:** the build-up template is byte-identical in Task 2, Task 3, and the doc; the
   build-down template is byte-identical in Task 4, Task 5, and the doc.
4. **Provenance wording:** `Planned by` / `Driven by` / `PRs implemented by` used consistently; the
   `unknown (see BDS-28)` fallback appears wherever `PRs implemented by` does.
5. **Pointer resolves:** every skill references `docs/learnings-comments.md` (Task 1 exists).
6. **BDS-25 ACs:** re-read BDS-25's acceptance criteria — all satisfied, plus the three added
   requirements (harness+model, all-four-required, PR-outcome/closed-unmerged).
