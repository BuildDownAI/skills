---
name: bd-kg-search
description: "Search this project's knowledge graph (KG) directly via hybrid search — the fast way to ask what past issues, PRs, decisions, and build-up/build-down learnings already exist, without running a full build-up/build-down session. Trigger when the user says 'bd-kg-search', 'kg search', 'search the KG for …', 'ask the knowledge graph', or asks whether the KG already knows about something. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
---

# bd-kg-search Skill

Search this project's knowledge graph directly via hybrid search.

## Steps

1. **Read the binding.** Open `CLAUDE.md` and find the `## Knowledge graph` block. Parse `kg.present` and other keys (format: `docs/kg-binding.md` in the skills repo). If `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop. No tool call.

2. **Run the search.** Take the user's query text and call **`kg.search_tool`** (the bound `mcp__<slug>-kg__kg_hybrid_search`) with `{query, limit: 10}`. Call **only** that tool — never other KG tools like `kg_neighbors` or `kg_provenance`.

3. **Render results,** ranked by `score`: for each hit show `title`, `type`, `score`, `matched_by`, a short `snippet`, and the `iri`. If `degraded: true`, note that the vector index wasn't loaded and suggest running `bd-kg-refresh` + a Claude Code restart. If zero results, say so plainly.

4. **Scope note.** Hybrid-search only — deeper graph walks (neighbors/provenance) exist but are out of scope for this skill. If the user just refreshed, remind that a Claude Code restart is needed before new results appear.

---

## Notes

- The binding format is canonical across all KG-aware skills (see `docs/kg-binding.md`).
- A project without `kg.present: true` is a graceful no-op — no error, clear message.
