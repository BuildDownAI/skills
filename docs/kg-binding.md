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

**Retired fields** (pre-AII-324 local bindings — migrate on sight via bd-project-setup Phase K):
`kg.repo`, `kg.path`, `kg.branch`, and stdio `<project-slug>-kg` server entries.

## Semantics

When `kg.present: false` or the entire `## Knowledge graph` block is absent from CLAUDE.md, KG-aware behavior degrades gracefully, but the shape of that degradation depends on how the step is invoked:

- **Incidental KG-aware steps** — a KG-aware step embedded inside another skill's flow (e.g. a future recon step that consults the graph as one input among several) is a **silent no-op**: no error, no warning, the rest of the skill proceeds unaffected. This keeps projects without a knowledge graph running unmodified through skills that only *optionally* touch the KG.
- **Skills invoked directly for the KG** — a skill the user runs specifically to work with the graph (`bd-kg-search`, `bd-kg-refresh`) instead responds with a clear, non-silent message — e.g. "This project has no KG bound — run bd-project-setup to add one." — and stops. Failing silently here would leave the user wondering why a KG-specific command did nothing.

## Tool usage

Skills **only** call `kg.search_tool` (hybrid-search) to query the knowledge graph, with **one
sanctioned exception**: recon's staleness check reads the graph's age stamp via `kg_neighbors`
on the spine IRI (`docs/kg-recon.md` — that exact call, nothing more). No other KG tools or
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
