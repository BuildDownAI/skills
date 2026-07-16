# Learnings Comments (BDS-25) — Design Decisions

## Objective

Make every BuildDown build-up and build-down session leave a durable, queryable, cross-tracker
record of the load-bearing *why* behind the work — as **marked comments on the parent issue** —
so future planning (and a future knowledge-graph ingester) can read what was decided, what actually
shipped, and what failed. This build-up extends BDS-25 with three requirements surfaced by the user:
(1) capture the **harness + model** provenance in every learning; (2) make the learnings step a
**required, non-skippable** closing step in **all four** session-owning skills; (3) capture **PR
outcome** including **closed-without-merging as an explicit failure**.

## Scope

**In v1:**
- Two exact-match comment markers: `# ai-implement-build-up-learnings`, `# ai-implement-build-down-learnings`.
- One canonical comment per marker per issue, edited in place, on the parent/umbrella issue.
- Inlined build-up + build-down templates, each carrying a **provenance line** (harness + model).
- Build-down template carries an **Outcome taxonomy** that names `closed-unmerged (failure)`.
- A required closing step wired into `bd-build-up`, `bd-mega-build-up`, `bd-build-down`, `bd-super-build-down`.
- One shared reference doc: `docs/learnings-comments.md`, pointed to from each touched skill.
- Plugin version bump (0.7.0 → 0.8.0) + release note.

**Deferred:**
- Historical / cross-session PR-outcome reconciliation (querying closed PRs at orient). v1 is
  **session-only** capture — see Decisions → PR outcome.
- Any standalone "reconcile PR outcomes" mode.
- `bd-summit-push` / `bd-smoke-jumper` posting their own markers — they feed the build-down comment.
- A machine-readable schema / knowledge-graph ingester (the comment is the durable index; ingestion is later work).

**Out of scope:**
- Application code. This is entirely prose / skill-definition (`SKILL.md`) + one new doc.
- BDS-26 (multi-issue grouping awareness). Parked behind its two gates; edits the same four files, so
  it will be a **second manual pass** over these skills after BDS-25 lands. Not co-landed here.

## Decisions

- **Vehicle: manual, BDS-25 only, on `multi-issue-and-learnings`.** No AI-Implement labels; one
  human-reviewed PR to `testing`. No feature-node tree (no parallel pipeline pickup to design for).
  The refreshed BDS-25 body is the durable spec; this session implements it. BDS-26 is a later pass.
  *Rejected:* pipeline execution (would force BDS-25/BDS-26 sequencing + feature-node ceremony for a
  version bump, for ~5 prose files); co-landing BDS-26 now (it's gated on AII-219 being live).

- **Provenance capture: self-report + ask-if-unknown.** The agent running the skill writes a
  provenance line from what it knows (e.g. `Claude Code · Opus 4.8`). If it genuinely cannot determine
  its model, it asks the operator once rather than guessing or omitting. *Why:* these skills run inside
  an agent that usually knows its own identity; a hard "always ask" tax every run is worse, and a
  silently-omitted field defeats the provenance goal. *Rejected:* self-report-only (loses non-Claude
  accuracy), always-ask (prompt fatigue).
  - **Build-up** provenance = the single planning agent: `**Planned by:** <harness · model>`.
  - **Build-down** provenance = **two lines when they differ**: `**Driven by:** <harness · model>`
    (the agent running the build-down) and `**PRs implemented by:** <harness · model>` (the
    AI-Implement agent/model that wrote the PRs, *when known* — mark "unknown" if not).
    *Why two:* "planned by Opus, PRs written by GLM, driven by Opus" is exactly the kind of provenance
    a future reader needs; collapsing it hides which agent/model produced which outcome.
  - **`PRs implemented by` is NOT readable at build-down time today (verified).** The orchestrator
    knows the model internally (`AI-Implement` `src/pipeline/types.ts:49` `model?: string`;
    `implement.ts:69` default `claude-sonnet-4-6`) and has a models-and-providers surface, but the
    only thing it stamps on a PR is the literal `"Generated with AI-Implement"`
    (`src/pipeline/steps/push.ts:172`) — no model/harness/provider in the PR body, gap analysis,
    review comment, or commit trailers. Exposing it is tracked as **BDS-28** (orchestrator change:
    append `harness · model · provider` to the PR-body stamp). **BDS-25 does not block on BDS-28** —
    build-down writes `**PRs implemented by:** unknown (orchestrator does not emit yet — see BDS-28)`
    until BDS-28 lands + redeploys, after which the same line populates for real with **no skills
    change** (build-down already parses the PR body).

- **PR outcome: session-only capture, with a named failure state.** During a build-down, each PR the
  session **drives or observes** gets a terminal/current outcome recorded in the build-down learnings
  comment. Taxonomy: **`merged` | `closed-unmerged (failure)` | `open / never-landed` | `superseded`**.
  A `closed-unmerged` PR is recorded as a **failure** with a one-line *why it failed*. Detection uses
  the PR state the session already reads via GitHub MCP (`state=CLOSED` & `merged=false`).
  - **Accepted blind spot:** a PR closed-without-merging while **no** build-down session is running is
    **not** auto-captured (we chose not to reconcile PR history at orient). This is partially covered by
    BDS-25's existing signal — *a build-up comment with no build-down sibling = "planned but never
    landed."* The design doc and the skill text must **state this limitation explicitly** so it reads as
    a deliberate boundary, not an oversight. *Rejected:* orient+close reconciliation (more robust but
    more surface than wanted now); dedicated reconcile mode (deferred).

- **Which skills own a marker: the four session-owning skills only.** `bd-build-up` +
  `bd-mega-build-up` post/update `# ai-implement-build-up-learnings`; `bd-build-down` +
  `bd-super-build-down` post/update `# ai-implement-build-down-learnings`. `bd-summit-push`
  (sequencing) and `bd-smoke-jumper` (testing) run **within** a build-down and fold their findings into
  the build-down comment. *Why:* preserves one-canonical-comment-per-marker-per-issue; a smoke-jumper
  that posts its own marker would fragment the record. *Rejected:* smoke-jumper posts a third marker.

- **Required, not optional.** In each of the four skills the step is a hard closing step (a Red-Flag
  entry: "session concluded without posting/updating the learnings comment → not done"), so plain
  `bd-build-up` can't quietly skip what `bd-mega-build-up` does. *Why:* requirement (2) is about
  completeness — the compounding mechanism only works if it fires every time.

- **Placement & edit semantics** (carried from BDS-25, unchanged): one canonical comment per marker per
  issue, **edited in place** (edit history preserves the timeline), on the **parent/umbrella** issue;
  narrow per-task learnings may go on a child. Markers are **exact-match first lines**; never reuse
  `# ai-implement.yml` (opposite semantics — orchestrator config, stripped from the spec).

- **Cross-tracker:** both markers are plain comments; `save_comment` (Linear) and `addComment` (Jira)
  both exist, so the convention is identical on both providers. The doc states this once.

- **Distillation:** the comment holds the load-bearing decisions a future reader would be *surprised*
  by — not a second copy of the plan. Link out to the fuller in-repo plan doc for depth.

## Failure modes

- **Model unknown / non-Claude harness** → ask the operator once; never guess or silently omit.
- **PR closed with no session running** → accepted blind spot; leaned on absence-as-signal; documented.
- **Two skills racing the same comment** → one canonical comment, edited in place; the closing step
  reads-then-edits (never blind-creates a duplicate).
- **Marker typo / wrong marker** → exact-match rule + explicit "do not reuse `# ai-implement.yml`" note.
- **Learnings step skipped** → promoted to a Red Flag / required step in each skill.

## Rollout

- Manual single PR to `testing`. No migration, no flag, no backfill. Revert = revert the PR.
- Plugin `version` 0.7.0 → **0.8.0** (additive, backward-compatible) + release note. Without the bump,
  `/plugin update` serves stale skills (repo rule).

## Testing

- No automated tests in this repo (prose/skill definitions). Verification = self-review against the
  acceptance criteria + a read-through that every `ai-implement/feature`-style example and every
  learnings template renders correctly and the markers are exact-match. Optional real-world check:
  post one build-up learnings comment to a live issue and confirm it round-trips on Linear.

## Observability

- The markers themselves are the observability surface: `grep`/search for
  `# ai-implement-build-up-learnings` / `# ai-implement-build-down-learnings` across the tracker yields
  the full corpus. Absence of a build-down sibling is the "never landed" signal.

## Overlap & Reconciliation

- **BDS-25** — base issue; this build-up extends it (provenance, required-in-all-four, PR-outcome).
  Action: **refresh the body + ACs + templates** in Phase 4; keep as the single spec issue.
- **BDS-26** (multi-issue grouping awareness) — **Adjacent, high file-overlap** (same four `SKILL.md`
  + a shared doc + version bump). Action: **sequence, do not co-land.** BDS-25 lands first (manual,
  ungated); BDS-26 is a later manual pass that rebases on top. Flagged so the second pass expects to
  re-touch these files. No new issue.
- **AII-219** — Related only; the worked example (`# ai-implement-build-up-learnings` already on it).
  Action: cite as reference; no filing.

## Open Questions

- **Exact provenance-line wording / ordering** in the two templates — proposed in the plan; low-stakes,
  will finalize during drafting. Default: provenance line directly under `**Feature:**`.
- **Whether the build-down "never-landed" reconciliation** should be revisited once a knowledge-graph
  ingester exists (would upgrade the accepted blind spot). Default: leave deferred; revisit with BDS-26
  or a future learnings-ingester issue.
