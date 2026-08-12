# Knowledge Graph Binding Contract

Canonical CLAUDE.md block format for integrating a project's knowledge graph with BuildDown skills.

The KG is served by an **orchestrator's OAuth-protected `/mcp` endpoint** — the single source of
truth for every machine (AII-324). Skills never bind a local KG query server.

## Knowledge graph (optional)
- kg.present:      true
- kg.orchestrator: https://<app>.fly.dev                       # orchestrator serving /mcp
- kg.mcp_server:   orch-<app-slug>                             # remote server name in .mcp.json — per-orchestrator (OAuth token ties to the name, BDS-22)
- kg.search_tool:  mcp__orch-<app-slug>__kg_hybrid_search      # the ONLY tool skills call
- kg.source_repo:  <owner>/knowledge-graph-<project-slug>      # ingest source; refresh = ingest → commit snapshot → redeploy
- kg.local_mcp_server:  <project-slug>-kg                          # OPTIONAL (transition/dev): local stdio server name
- kg.local_search_tool: mcp__<project-slug>-kg__kg_hybrid_search   # OPTIONAL: its hybrid-search tool
- kg.prefer:       orchestrator                                # orchestrator (default) | local — which target skills try first

**Retired fields**: `kg.repo`, `kg.path`, `kg.branch`. A local stdio server is NOT retired when
named by `kg.local_mcp_server` — that is the supported **transition binding** (below). An
*unnamed* stdio entry is legacy; bd-project-setup Phase K records or removes it.

## Dual-target resolution (transition mode)

During the local→orchestrator transition a project may bind BOTH targets. Every KG-aware step
resolves them the same way:

1. **Try `kg.prefer` first** (default `orchestrator`). Its search tool is the primary.
2. **Fall back to the other target** only if the preferred tool is unavailable or errors
   (server unauthenticated / token expired / 503 / not loaded) AND the other is bound.
3. **Always announce the target that served the query — one line, every time:**
   - `KG: orchestrator (graph as of <date>)`
   - `KG: local (kg.prefer=local; graph as of <date>)`
   - `KG: LOCAL FALLBACK — orchestrator unavailable (<reason>); local graph may drift from the shared source of truth`
   The user must never wonder which graph answered.
4. **Orchestrator-only capabilities never fall back.** Anything the local server does not serve
   (e.g. the orchestrator diagnostics tools) is orchestrator-required: if it is unavailable,
   say so — `"requires the orchestrator MCP — re-authenticate /mcp (or fix the deploy) to use
   this"` — and skip that step; do not silently substitute local data.
5. The two graphs can differ in freshness (local: rebuilt by any ingest, served after a Claude
   Code restart; orchestrator: rebuilt by snapshot commit + redeploy). The age stamp
   (`dcterms:modified` on the spine IRI) is readable on both — cite the served target's stamp.

## Semantics

When `kg.present: false` or the entire `## Knowledge graph` block is absent from CLAUDE.md, KG-aware behavior degrades gracefully, but the shape of that degradation depends on how the step is invoked:

- **Incidental KG-aware steps** — a KG-aware step embedded inside another skill's flow (e.g. a future recon step that consults the graph as one input among several) is a **silent no-op**: no error, no warning, the rest of the skill proceeds unaffected. This keeps projects without a knowledge graph running unmodified through skills that only *optionally* touch the KG.
- **Skills invoked directly for the KG** — a skill the user runs specifically to work with the graph (`bd-kg-search`, `bd-kg-refresh`) instead responds with a clear, non-silent message — e.g. "This project has no KG bound — run bd-project-setup to add one." — and stops. Failing silently here would leave the user wondering why a KG-specific command did nothing.

## Tool usage

Skills **only** call `kg.search_tool` (hybrid-search) to query the knowledge graph, with **one
sanctioned exception**: recon's staleness check reads the graph's age stamp via `kg_neighbors`
on the spine IRI (`./kg-recon.md` — that exact call, nothing more). No other KG tools or
internals are invoked by skill code. This keeps the contract minimal and the skill-to-KG
coupling loose.

## Setup and maintenance

- `bd-project-setup` (Phase K) writes this block into a project's CLAUDE.md during onboarding and
  wires the remote MCP server entry.
- `bd-kg-refresh` keeps the **orchestrator's** graph current: re-run the ingest in `kg.source_repo`,
  commit the snapshot parts, redeploy the orchestrator (the image build re-materializes graph +
  embeddings). There is no live reload — the redeploy *is* the refresh.
- The graph stamps its own age at ingest (`dcterms:modified` on the spine IRI) — recon states
  "graph as of {date}" and flags staleness worth a refresh.
