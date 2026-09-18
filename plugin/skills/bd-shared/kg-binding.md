# Knowledge Graph Binding Contract

The KG is served by an **orchestrator's OAuth-protected `/mcp` endpoint** — the single source of
truth for every machine (AII-324). Skills never bind a local KG query server.

**Discovery:** The orchestrator connector prefix is discovered at session start via
`./session-start.md` step 1 (ToolSearch for `__get_project_binding`). No CLAUDE.md key is read
for the server name.

## Binding call — get_project_binding

When `kg.present: true` and the orchestrator MCP is in the session tool list, resolve the full
binding with one call:

```
mcp__<prefix>__get_project_binding(repo: "<owner>/<repo>")
```

where `<prefix>` is the orchestrator connector prefix resolved by `./session-start.md` step 1.

Response shape:

```json
{
  "repo": "<owner>/<repo>",
  "defaultBranch": "main",
  "tracker": {
    "kind": "linear",
    "team": "BDS"
  },
  "pickupLabel": "AI-Implement",
  "kg": {
    "present": true,
    "orchestratorUrl": "https://<app>.fly.dev",
    "sourceRepo": "<owner>/knowledge-graph-<project-slug>",
    "baseRepo": "<owner>/<primary-repo>",
    "searchTool": "kg_hybrid_search"
  }
}
```

`pickupLabel` is `null` when the tracker is not Linear. It is consumed by pickup-label resolution
(`./pickup-label.md`, rule 1), not by KG-aware search skills.

Resolve the hybrid-search tool as `mcp__<prefix>__<kg.searchTool>` from the response.

**Retired fields**: `kg.mcp_server`, `kg.search_tool`, `kg.orchestrator`, `kg.source_repo`,
`kg.repo`, `kg.path`, `kg.branch`, and the former transition-mode fields (namespaced `kg.`:
`local_mcp_server`, `local_search_tool`, `prefer` — retired by BDS-56). The local `kg-query`
CLI (`./.venv/bin/kg-query search --hybrid "<term>"`) is a checkout tool for iterating on
ingest — it is not a binding and is not configured here.

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

Skills **only** call the resolved hybrid-search tool to query the knowledge graph, with **one
sanctioned exception**: recon's staleness check reads the graph's age stamp via `kg_neighbors`
on the spine IRI (`./kg-recon.md` — that exact call, nothing more). No other KG tools or
internals are invoked by skill code. This keeps the contract minimal and the skill-to-KG
coupling loose.

## Setup and maintenance

- `bd-project-setup` (Phase K) writes the two-key block into a project's CLAUDE.md during
  onboarding and wires the remote MCP server entry.
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
