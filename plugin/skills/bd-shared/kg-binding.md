# Knowledge Graph Binding Contract

Canonical CLAUDE.md block format for integrating a project's knowledge graph with BuildDown skills.

The KG is served by an **orchestrator's OAuth-protected `/mcp` endpoint** — the single source of
truth for every machine (AII-324). Skills never bind a local KG query server.

## Knowledge graph (optional)
- kg.present:      true
- kg.orchestrator: https://<app>.fly.dev                       # orchestrator serving /mcp
- kg.mcp_server:   orch-<app-slug>                             # remote server name in .mcp.json — per-orchestrator (OAuth token ties to the name, BDS-22)
- kg.search_tool:  mcp__orch-<app-slug>__kg_hybrid_search      # the ONLY tool skills call
- kg.source_repo:  <owner>/knowledge-graph-<project-slug>      # ingest source; refresh = the trigger_kg_refresh MCP tool (admin role)

**Retired fields**: `kg.repo`, `kg.path`, `kg.branch`, and the former transition-mode fields (namespaced `kg.`: `local_mcp_server`, `local_search_tool`, `prefer` — retired by BDS-56). The local `kg-query` CLI (`./.venv/bin/kg-query search --hybrid "<term>"`) is a checkout tool for iterating on ingest — it is not a binding and is not configured here.

## Scope contract (rail-owned repos and teams, operator-owned docs roots)

The orchestrator's **project list is the KG's intended scope**: every repo the orchestrator
manages should be ingested, and every project's tracker team should be in the tracker config.
`sources.yml` in the KG source repo is the *materialized* scope. The rail's `kg-scope-reconcile`
step updates it automatically on every refresh — adding any repo or team that appears in the
orchestrator's project list but is missing from `sources.yml`. This is additive only: the rail
never removes an existing entry or overwrites its `path`, `docs_url`, `docs_sites`, or `tier`
values. Those fields are **operator-owned** — a removed entry's `path`/`docs_url`/`tier` stay
absent until the operator explicitly restores them. The Python ingest itself never calls the MCP:
config lives in git, MCP access lives in the session.

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
- `bd-kg-refresh` keeps the **orchestrator's** graph current: it triggers the refresh rail
  through the `trigger_kg_refresh` MCP tool (the rail clones, ingests, guards, and serves the
  updated graph). The laptop never pushes `snapshot/`. For local iteration on the ingest, use
  `bd-mega-kg-refresh` (forthcoming — see BDS-49).
- The graph stamps its own age at ingest (`dcterms:modified` on the spine IRI) — recon states
  "graph as of {date}" and flags staleness worth a refresh.

## Admin-only skills

A skill that calls a declared MCP write tool checks `get_session_identity` first and stops for
any role but the tool's declared role. Today the admin-only skills are `bd-kg-refresh` and
`bd-mega-kg-refresh`. Read-only skills never call a write tool.
