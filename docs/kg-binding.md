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

When `kg.present: false` or the entire `## Knowledge graph` block is absent from CLAUDE.md, every KG-aware skill step is a silent no-op — no error, no warning, just graceful degradation. This ensures that projects without a knowledge graph can still run skills without modification.

## Tool usage

Skills **only** call `kg.search_tool` (hybrid-search) to query the knowledge graph. No other KG tools or internals are invoked by skill code. This keeps the contract minimal and the skill-to-KG coupling loose.

## Setup and maintenance

- `bd-project-setup` writes this block into a project's CLAUDE.md during onboarding.
- `bd-kg-refresh` keeps the local knowledge graph current by pulling from the configured repo.
