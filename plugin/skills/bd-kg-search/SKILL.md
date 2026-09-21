---
name: bd-kg-search
description: "Search this project's knowledge graph (KG) directly via hybrid search — the fast way to ask what past issues, PRs, decisions, and build-up/build-down learnings already exist, without running a full build-up/build-down session. Trigger when the user says 'bd-kg-search', 'kg search', 'search the KG for …', 'ask the knowledge graph', or asks whether the KG already knows about something. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
  client: any
  requires: [orchestrator]
---

# bd-kg-search Skill

Search this project's knowledge graph directly via hybrid search. The **orchestrator MCP**
(`/mcp`, OAuth) is the single source of truth (AII-324); `mcp__<prefix>__<kg.searchTool>`
(the resolved hybrid-search tool) is the only tool this skill calls.

## Steps

1. **Session start.** Run `../bd-shared/session-start.md`; its printed lines open the reply. This resolves the orchestrator
   connector prefix (`<prefix>`), the repo slug, and the full binding (including `kg`).
   If `kg.present` is `false` or absent from the binding:
   - Print: "This project has no KG bound."
   - Stop. No tool call.

2. **Resolve the target.** The resolved search tool (`mcp__<prefix>__<kg.searchTool>` from
   the session-start binding) is the single KG target.

   **Auth health check.** If `mcp__<prefix>__get_session_identity` is in the session's
   tool list, call it (health only — this step does not gate on role). Apply
   `../bd-shared/orchestrator-auth.md`; the 401 recovery applies to the search call in Step 3
   and to any other orchestrator call in this skill. If the tool is absent, skip this check.

   If the search tool is unavailable or errors (503 or other non-401 error), report it and stop.

3. **Run the search** with `{query, limit: 10}` on the resolved tool. Call **only** the
   hybrid-search tool — never other KG tools (the one exception, spine-stamp staleness via
   `kg_neighbors`, belongs to recon — `../bd-shared/kg-recon.md` — not this skill).
   **Split multi-key queries.** The exact-ID boost matches one issue key per query — a query
   with two keys ("AII-346 AII-340") surfaces neither. When the user's query contains more
   than one issue key, run one search per key, plus one combined search for any remaining
   prose, and merge the results per key in the render. Found live 2026-08-12.

4. **Announce the target, then render results.** After the session-start lines, print `KG: orchestrator (graph as of <date>)`. Then hits ranked by `score`: `title`, `type`, `score`, `matched_by`, a short
   `snippet`, the `iri`. **`DocSection` hits render their anchor URL prominently** (BDS-38):
   the IRI encodes `docpage/<url-encoded-page-url>#<anchor>` — decode the page URL, append
   the `#anchor`, and print it as the hit's first line (e.g.
   `https://docs.example.com/setup/sso#wire-the-orchestrator`) so the user can click
   straight to the passage. `DocPage` hits likewise render their decoded page URL.
   If `degraded: true`, note lexical-only and suggest `bd-kg-refresh` redeploy to rebuild
   embeddings. If zero results, say so plainly.

5. **Scope note.** Hybrid-search only — deeper graph walks are out of scope here. Results
   reflect the **deployed** orchestrator graph; a completed `bd-kg-refresh` appears with no
   client restart. On an orchestrator auth failure the recovery hint from
   `../bd-shared/orchestrator-auth.md` fires at Step 2 and stops the skill.

---

## Notes

- The binding format is canonical across all KG-aware skills (see `../bd-shared/kg-binding.md`).
- A project without `kg.present: true` is a graceful no-op — no error, clear message.
