# Glossary

One name per concept. One concept per name. Decisions live in `docs/adr/`, not here.

## Project binding

The set of facts a skill needs about the project it runs in: the repo, its default branch, the
tracker and team, the pickup label, and the knowledge graph. The orchestrator answers it in
one call.

**Not to be confused with:** the legacy KG block, which is the fallback copy in `CLAUDE.md`.

## Pickup label

The Linear label that makes the orchestrator implement an issue. The orchestrator holds the
value; skills resolve it before they read or assign it.

**Not to be confused with:** the lifecycle labels the orchestrator sets itself
(`AI-Planning`, `AI-Working`, `Plan-Complete`, `Ready for Review`), and the Jira
`AI-Implement-Status` field, which is a field and not a label.

## Legacy KG block

The five-key `## Knowledge graph` block in `CLAUDE.md` that skills read before the project
binding existed. Read-only for one release, then retired.

**Not to be confused with:** the two keys that stay in `CLAUDE.md`, `kg.present` and
`kg.mcp_server`.

## Orchestrator MCP server name

The name of the orchestrator's remote server in `.mcp.json`. One name per orchestrator. The
sign-in token is bound to the name.

**Not to be confused with:** the orchestrator URL, which the project binding reports.

## Feature node

A parent issue that carries the pickup label and has labelled children. Its children land on
one feature branch; the branch's pull request into the base branch is the human review gate.

**Not to be confused with:** a planning parent from bd-high-plan, which is never labelled
during planning.

## Repo folder

A local checkout of a repository. Under the connector model, a repo folder carries no MCP
server entries and no binding blocks — the connectors supply the servers, and `get_project_binding`
supplies the binding at session start.

**Not to be confused with:** the orchestrator mapping, which is the orchestrator's record of
what a repo's binding is.

## Orchestrator mapping

The orchestrator's record of a repo's project binding: repo slug, default branch, tracker,
pickup label, and KG config. Returned by `get_project_binding`. Set once in the orchestrator's
admin UI; skills read it at session start.

**Not to be confused with:** the legacy `CLAUDE.md` binding blocks, which are retired by ADR 0002.

## Chat project

A claude.ai project that holds a skill bundle (via `repo: <owner>/<name>`) instead of a local
checkout. Chat projects use the same account-level connectors as CLI sessions and therefore gain
the same `get_project_binding` access without any per-project MCP configuration.

**Not to be confused with:** a Claude Code project (a local directory opened in the CLI or IDE).
