# Knowledge Graph Binding Contract

Canonical CLAUDE.md block format for integrating a project's knowledge graph with BuildDown skills.

## Knowledge graph (optional)
- kg.present:     true
- kg.repo:        <owner>/knowledge-graph-<project-slug>   # origin (owner/name)
- kg.path:        ../knowledge-graph-<project-slug>        # local checkout, relative to project root
- kg.branch:      knowledge-graph                          # branch to keep checked out
- kg.mcp_server:  <project-slug>-kg                        # MCP server name in .mcp.json
- kg.search_tool: mcp__<project-slug>-kg__kg_hybrid_search # the ONLY tool skills call

## Semantics

When `kg.present: false` or the entire `## Knowledge graph` block is absent from CLAUDE.md, KG-aware behavior degrades gracefully, but the shape of that degradation depends on how the step is invoked:

- **Incidental KG-aware steps** — a KG-aware step embedded inside another skill's flow (e.g. a future recon step that consults the graph as one input among several) is a **silent no-op**: no error, no warning, the rest of the skill proceeds unaffected. This keeps projects without a knowledge graph running unmodified through skills that only *optionally* touch the KG.
- **Skills invoked directly for the KG** — a skill the user runs specifically to work with the graph (`bd-kg-search`, `bd-kg-refresh`) instead responds with a clear, non-silent message — e.g. "This project has no KG bound — run bd-project-setup to add one." — and stops. Failing silently here would leave the user wondering why a KG-specific command did nothing.

## Tool usage

Skills **only** call `kg.search_tool` (hybrid-search) to query the knowledge graph. No other KG tools or internals are invoked by skill code. This keeps the contract minimal and the skill-to-KG coupling loose.

## Setup and maintenance

- `bd-project-setup` writes this block into a project's CLAUDE.md during onboarding.
- `bd-kg-refresh` keeps the local knowledge graph current by re-running the ingest — re-reading the source project's git history, tracker, and docs into the graph (it does not `git pull`; the ingest is what refreshes the content).
