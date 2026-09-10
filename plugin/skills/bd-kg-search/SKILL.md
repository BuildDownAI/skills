---
name: bd-kg-search
description: "Search this project's knowledge graph (KG) directly via hybrid search — the fast way to ask what past issues, PRs, decisions, and build-up/build-down learnings already exist, without running a full build-up/build-down session. Trigger when the user says 'bd-kg-search', 'kg search', 'search the KG for …', 'ask the knowledge graph', or asks whether the KG already knows about something. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
---

# bd-kg-search Skill

Search this project's knowledge graph directly via hybrid search. The **orchestrator MCP**
(`/mcp`, OAuth) is the single source of truth (AII-324); `kg.search_tool` is the only tool
this skill calls.

## Steps

1. **Read the binding.** Open `CLAUDE.md` and find the `## Knowledge graph` block. Parse
   `kg.present` and the orchestrator fields (format: `../bd-shared/kg-binding.md`).
   If `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop. No tool call.

2. **Resolve the target.** Call the orchestrator's `kg.search_tool` — the single KG target.
   If the tool is unavailable or errors (token expired, 503), report it and stop.

3. **Run the search** with `{query, limit: 10}` on the resolved tool. Call **only** the
   hybrid-search tool — never other KG tools (the one exception, spine-stamp staleness via
   `kg_neighbors`, belongs to recon — `../bd-shared/kg-recon.md` — not this skill).
   **Split multi-key queries.** The exact-ID boost matches one issue key per query — a query
   with two keys ("AII-346 AII-340") surfaces neither. When the user's query contains more
   than one issue key, run one search per key, plus one combined search for any remaining
   prose, and merge the results per key in the render. Found live 2026-08-12.

4. **Announce the target, then render results.** First line: `KG: orchestrator (graph as of <date>)`. Then hits ranked by `score`: `title`, `type`, `score`, `matched_by`, a short
   `snippet`, the `iri`. **`DocSection` hits render their anchor URL prominently** (BDS-38):
   the IRI encodes `docpage/<url-encoded-page-url>#<anchor>` — decode the page URL, append
   the `#anchor`, and print it as the hit's first line (e.g.
   `https://docs.example.com/setup/sso#wire-the-orchestrator`) so the user can click
   straight to the passage. `DocPage` hits likewise render their decoded page URL.
   If `degraded: true`, note lexical-only and suggest `bd-kg-refresh` redeploy to rebuild
   embeddings. If zero results, say so plainly.

5. **Scope note.** Hybrid-search only — deeper graph walks are out of scope here. Results
   reflect the **deployed** orchestrator graph; a completed `bd-kg-refresh` appears with no
   client restart. An orchestrator auth failure means the 1-hour token expired —
   re-authenticate via `/mcp` in an interactive session (with refresh tokens live, this
   should be rare).

---

## Notes

- The binding format is canonical across all KG-aware skills (see `../bd-shared/kg-binding.md`).
- A project without `kg.present: true` is a graceful no-op — no error, clear message.
