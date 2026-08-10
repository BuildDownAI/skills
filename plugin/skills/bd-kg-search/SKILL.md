---
name: bd-kg-search
description: "Search this project's knowledge graph (KG) directly via hybrid search — the fast way to ask what past issues, PRs, decisions, and build-up/build-down learnings already exist, without running a full build-up/build-down session. Trigger when the user says 'bd-kg-search', 'kg search', 'search the KG for …', 'ask the knowledge graph', or asks whether the KG already knows about something. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
---

# bd-kg-search Skill

Search this project's knowledge graph directly via hybrid search. The KG is served by the
project's **orchestrator MCP** (`/mcp`, OAuth) — the single source of truth for every machine
(AII-324); there is no local graph to query.

## Steps

1. **Read the binding.** Open `CLAUDE.md` and find the `## Knowledge graph` block. Parse
   `kg.present` and other keys (format: `docs/kg-binding.md` in the skills repo). If
   `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop. No tool call.

2. **Run the search.** Take the user's query text and call **`kg.search_tool`** (the bound
   `mcp__orch-<app-slug>__kg_hybrid_search`) with `{query, limit: 10}`. Call **only** that tool
   — never other KG tools like `kg_provenance` (the one exception, spine-stamp staleness via
   `kg_neighbors`, belongs to recon — `docs/kg-recon.md` — not this skill).

3. **Render results,** ranked by `score`: for each hit show `title`, `type`, `score`,
   `matched_by`, a short `snippet`, and the `iri`. If `degraded: true`, note that the deployed
   sidecar is running lexical-only and suggest a `bd-kg-refresh` (its redeploy rebuilds
   embeddings). If zero results, say so plainly.

4. **Scope note.** Hybrid-search only — deeper graph walks exist but are out of scope here.
   Results always reflect the **deployed** graph: a completed `bd-kg-refresh` shows up on the
   next query with **no client restart** (the server is remote). If the tool errors with an
   auth failure, the OAuth token has expired (1-hour TTL) — re-authenticate via `/mcp` in an
   interactive session and retry.

---

## Notes

- The binding format is canonical across all KG-aware skills (see `docs/kg-binding.md`).
- A project without `kg.present: true` is a graceful no-op — no error, clear message.
- Legacy local bindings (`<slug>-kg` stdio servers) are retired — if one is still wired,
  point the operator at bd-project-setup Phase K to migrate.
