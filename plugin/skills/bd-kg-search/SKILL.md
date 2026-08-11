---
name: bd-kg-search
description: "Search this project's knowledge graph (KG) directly via hybrid search — the fast way to ask what past issues, PRs, decisions, and build-up/build-down learnings already exist, without running a full build-up/build-down session. Trigger when the user says 'bd-kg-search', 'kg search', 'search the KG for …', 'ask the knowledge graph', or asks whether the KG already knows about something. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
---

# bd-kg-search Skill

Search this project's knowledge graph directly via hybrid search. The **orchestrator MCP**
(`/mcp`, OAuth) is the single source of truth (AII-324); during the transition a project may
ALSO bind a local server, and this skill resolves between them per `docs/kg-binding.md`
*Dual-target resolution* — always telling the user which graph answered.

## Steps

1. **Read the binding.** Open `CLAUDE.md` and find the `## Knowledge graph` block. Parse
   `kg.present`, the orchestrator fields, and the optional `kg.local_*` + `kg.prefer` fields
   (format: `docs/kg-binding.md`). If `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop. No tool call.

2. **Resolve the target** per the binding doc's dual-target rule: try `kg.prefer`'s search
   tool first (default: the orchestrator's `kg.search_tool`); if it is unavailable or errors
   and the other target is bound, fall back to it.

3. **Run the search** with `{query, limit: 10}` on the resolved tool. Call **only** the
   hybrid-search tool — never other KG tools (the one exception, spine-stamp staleness via
   `kg_neighbors`, belongs to recon — `docs/kg-recon.md` — not this skill).

4. **Announce the target, then render results.** First line is the announce from the binding
   doc (e.g. `KG: orchestrator` / `KG: LOCAL FALLBACK — orchestrator unavailable (token
   expired)`). Then hits ranked by `score`: `title`, `type`, `score`, `matched_by`, a short
   `snippet`, the `iri`. If `degraded: true`, note lexical-only and the fix for the target
   that served (orchestrator → `bd-kg-refresh` redeploy rebuilds embeddings; local → re-run
   the ingest/embed and restart Claude Code). If zero results, say so plainly.

5. **Scope note.** Hybrid-search only — deeper graph walks are out of scope here. Freshness
   differs by target: orchestrator results reflect the **deployed** graph (a completed
   `bd-kg-refresh` appears with no client restart); local results reflect the last local
   ingest **as of session start** (the stdio server loads at startup — restart to pick up a
   newer local graph). An orchestrator auth failure means the 1-hour token expired —
   re-authenticate via `/mcp` in an interactive session (with refresh tokens live, this
   should be rare).

---

## Notes

- The binding format is canonical across all KG-aware skills (see `docs/kg-binding.md`).
- A project without `kg.present: true` is a graceful no-op — no error, clear message.
- A local stdio server named by `kg.local_mcp_server` is the supported transition binding.
  An UNNAMED legacy stdio binding should be recorded (or removed) via bd-project-setup
  Phase K so resolution and announcements work.
