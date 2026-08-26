# Design spec: KG recon in the session-owning skills (spec #2)

**Status:** approved design (core) · **Date:** 2026-07-31

**Spec #2 of 2** for the KG↔skills integration. Spec #1 (merged/PR'd) built the
foundation: the CLAUDE.md `## Knowledge graph` binding, `bd-project-setup`'s KG
phase, and the `bd-kg-refresh` / `bd-kg-search` skills. Spec #2 makes the four
**session-owning skills** *consult* the KG during orientation — **hybrid-search
only**, **advisory and non-blocking**, and **silently skipped** when a project has
no KG. Depends on spec #1 (the `kg.*` binding + `kg.search_tool`).

## Goal

Before a session-owning skill plans or triages, it should ask the KG what the team
already learned/decided about this work — so we stop re-solving solved problems —
and know how stale that answer is.

## Scope: the four session-owning skills

`bd-build-up`, `bd-mega-build-up` (planning side) and `bd-build-down`,
`bd-super-build-down` (landing side) — the same four that already *post*
build-up/build-down learnings. This closes the loop: the skills that **write**
learnings are the ones that **read** them.

## Core decisions (already agreed)

- **Advisory, non-blocking.** Recon informs; it never gates. It cites prior
  learnings where they change a plan or gap decision, but does not require it.
- **Query as-is.** Recon searches the existing graph; it never triggers a rebuild
  (a full ingest is slow and the MCP server is load-once — a mid-session rebuild
  wouldn't even be seen without a restart). Refresh stays a deliberate
  `bd-kg-refresh` step.
- **Named, explicit step** (per **BDS-29**: a mandatory step got skipped when it
  lived in prose — naming it as its own step is what makes it happen). Even
  advisory, recon is a titled Orient step, not a buried sentence.
- **Silent skip when no KG.** This is an *incidental* step inside another skill,
  so `kg.present:false`/absent ⇒ skip with no output (matches
  `docs/kg-binding.md`'s incidental-step semantics — the opposite of the
  directly-invoked `bd-kg-*` skills, which announce).

## Component 1 — `docs/kg-recon.md` (the shared procedure, single source)

Mirrors the existing `docs/learnings-comments.md` pattern: one canonical file the
four skills reference, so the recon procedure is defined once. It contains:

1. **Guard.** Read CLAUDE.md's `## Knowledge graph` block. If `kg.present` is
   false/absent → skip silently (no output).
2. **Query.** Derive **1–3** short queries from the work in hand (see per-skill
   inputs) and call **`kg.search_tool`** (`kg_hybrid_search`), `limit: 8`.
   Hybrid-search **only** — never other KG tools.
3. **Use the results.** Surface the top relevant learnings/decisions/issues to the
   operator as orientation context. Where a hit changes a plan choice or a gap
   call, cite it (e.g. "prior learning AII-259 says … so …"). Advisory — no
   mandatory-citation checklist.
4. **Staleness-delta** (lean): `stat` `<kg.path>/out/graph.trig` for the KG's
   last-build time. Always note the age in one line. **If** the KG is older than
   **24h**, compute what it's blind to at the standard ingest points — issues
   updated since that time (via the project's tracker MCP) and PRs merged since
   (via `gh pr list --search "merged:>=<date>"`) — and list them so recon results
   are read knowing the gap, then nudge `bd-kg-refresh`. Fresh KG (<24h) → skip
   the delta queries entirely (stay fast). Never blocks.
5. **Failure tolerance.** Any error (tool unavailable, empty index/`degraded`,
   tracker/`gh` hiccup) → note it in one line and proceed. Recon never aborts the
   host skill.

## Component 2 — the recon step in each of the four skills

A short, titled step in each skill's **Phase 1: Orient**, referencing
`docs/kg-recon.md` for the procedure (not restating it). Placement + per-skill
query inputs:

| Skill | Where | Query inputs (1–3) |
|---|---|---|
| `bd-build-up` | Phase 1 Orient, right after "Clarifying questions (all modes)", before the mode-specific orient | the objective/milestone in the user's words + its key nouns |
| `bd-mega-build-up` | Phase 1 Orient, same position | same as build-up (objective + key nouns) |
| `bd-build-down` | Phase 1 Orient, before gap-analysis triage | the PR's linked issue key + title + the gap topics from its gap-analysis |
| `bd-super-build-down` | Phase 1 Orient (Fast) — one line folded into its orientation table, kept minimal | the PR's issue key + title |

`bd-super-build-down` is the lean-back/fast variant, so its recon is deliberately
minimal (a single hybrid-search on the issue, no separate narration) — it still
runs, just quietly.

## Data flow

```
Orient → [kg.present?] —no→ skip silently
                        —yes→ kg_hybrid_search(1–3 queries) → surface top hits (cite where decisive)
                              → stat graph.trig mtime → note age; if >24h: tracker "issues since" + gh "PRs since" → list gap + nudge refresh
       → continue the skill's normal Orient/planning/triage
```

## Non-goals

- **No changes to spec #1** (the binding, `bd-project-setup`, `bd-kg-refresh`,
  `bd-kg-search`).
- **No auto-refresh** — query as-is; refresh stays operator-driven.
- **No mandatory citation / gating** — advisory only.
- **No deeper graph walks** — hybrid-search only (neighbors/provenance stay out).
- **Not the other skills** — `bd-summit-push`, `bd-smoke-jumper`, `bd-belay-on`,
  `bd-project-setup` are out of scope (summit-push could get recon later; flagged,
  not built).

## Testing / verification (mechanical, per the repo)

- `docs/kg-recon.md` exists and contains: the guard, the hybrid-search-only rule,
  the 1–3 query derivation, the staleness-delta (graph.trig mtime + tracker/`gh`),
  and the silent-skip semantics.
- Each of the four skills' `SKILL.md`: frontmatter still parses; a **titled** KG
  recon step is present in Phase 1 Orient; it references `docs/kg-recon.md`; it
  states the silent skip; it calls **only** `kg.search_tool` (no other KG tool
  named).
- Dry-run read-through: with `kg.present:false`, the recon step is a clean no-op;
  with a KG bound, it runs the search + (if stale) the delta, all non-blocking.

## Open calls for review

1. **Staleness threshold = 24h** for running the delta queries (fresh KG skips
   them). Reasonable, or prefer always-run / a different cutoff?
2. **`bd-super-build-down`** recon kept minimal (single quiet search). Good, or
   skip recon entirely in the fast variant?
