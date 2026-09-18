# 0002. The orchestrator is a connector and projects carry no binding

**Status:** Accepted
**Date:** 2026-09-18

## Context

ADR 0001 (2026-09-17) established that `get_project_binding` resolves the project binding in one
call. But ADR 0001 still assumed that the orchestrator and tracker servers lived in the project's
`.mcp.json`, pre-approved in `.claude/settings.json`, and that `CLAUDE.md` held `kg.mcp_server`
and `kg.present` as residual per-project keys.

Verified 2026-09-18: claude.ai connectors "load automatically in the CLI when you sign in with
that account" (Claude Code MCP docs). A Claude Code session held the Linear connector (reconnected
to the `eudoxus` workspace) and an orchestrator connector alongside this repo's own `.mcp.json`
servers simultaneously. `get_project_binding` returned `tracker: { kind, team }`,
`pickupLabel`, `defaultBranch`, and `kg` — everything a skill needs to start. A repo folder
therefore needs no server entry, no pre-approval, and no binding block. The `kg.mcp_server` key is no longer needed: Claude Code stores an OAuth sign-in per endpoint,
not per server name, and skills find the connector by its tool suffix rather than by name. The `kg.present` key collapses into the orchestrator answer.

`bd-project-setup` wrote the per-project server entry, drove OAuth from inside the session, and
populated the binding blocks. With connectors handling server enrollment once at the account
level, every one of those duties is already covered at session start without any per-project
configuration.

BDS-22 ("consider a per-project tracker MCP name within a single workspace") is cancelled by this
decision: one tracker connector is bound to one workspace at a time. When a repo's orchestrator
mapping expects a different workspace, the session-start check names the workspace to reconnect to.

## Decision

The orchestrator and the tracker are provisioned as claude.ai connectors once per account, not
once per project. Projects carry no MCP server entries and no binding blocks.

Specifically:

- `bd-project-setup` is deleted. Its duties are served by the connector (server enrollment and
  auth) and by `get_project_binding` (binding resolution at session start).
- `.mcp.json` is deleted from this repo. There is nothing left to put in it.
- `enabledMcpjsonServers` is removed from `.claude/settings.json`.
- `## Issue tracker — Linear` and `## Knowledge graph (optional)` are removed from `CLAUDE.md`.
  These blocks held facts the connector and `get_project_binding` now supply.
- `kg.mcp_server` and `kg.present` in `CLAUDE.md` are retired; the orchestrator answer includes
  both.

The `## AI-Implement label handoff` block in `CLAUDE.md` is kept (minus its MCP server bullet)
as human context about this repo's specific pickup target and team.

Switching orchestrators: enable one connector and disable the other. Switching tracker workspaces:
reconnect the tracker connector to the target workspace. The session-start check names the
workspace if a repo's mapping expects a different one.

## Alternatives considered

- **Keep the per-project server entry for repos that need custom server names.** Rejected. The
  connector's server name is stable and account-wide; the scenario requiring a per-project name
  (BDS-22) is eliminated by the one-workspace-at-a-time rule.
- **Keep `kg.present` in `CLAUDE.md` as a cheap "no KG" signal.** Rejected. The orchestrator's
  `get_project_binding` returns `kg.present`; keeping a local copy reintroduces drift, the
  problem ADR 0001 solved.
- **Keep `bd-project-setup` as a lightweight validator.** Rejected. Its Phase K check printed the
  orchestrator's answer beside the two keys it wrote; without keys to write, the check is
  redundant with the session-start procedure (BDS-84).

## Consequences

- A fresh clone of any repo needs no setup step beyond signing into Claude Code with an account
  that holds the connectors. No `.mcp.json`, no pre-approval, no OAuth prompt inside the session.
- Skills that still say "run bd-project-setup" (bd-kg-refresh, bd-kg-search, bd-system-questions,
  bd-kg-create, `kg-binding.md`) are updated by BDS-84 (session-start procedure) to print a
  connector warning instead.
- Chat sessions (no `.mcp.json` access) gain the same server access as CLI sessions, because both
  use the account-level connector.
- One tracker connector is bound to one workspace at a time. Multi-workspace setups reconnect the
  connector, not the project file.
- AC #6 (operator check): with the Linear connector reconnected to `eudoxus` and the orchestrator
  connector enabled, a session in this repo with no `.mcp.json` must list a server exposing
  `get_project_binding` and a server exposing `save_issue`. This is a manual, post-merge gate;
  it must pass before BDS-84 merges.

## Related

- ADR 0001: establishes `get_project_binding` as the single resolver; 0002 extends it by retiring
  the two `CLAUDE.md` keys and the per-project server entry ADR 0001 still expected.
- BDS-80: parent planning story; architectural decision recorded there.
- BDS-84: session-start child; replaces the "run bd-project-setup" lines in remaining skills with
  connector warnings. Must not merge until the operator check (AC #6) is verified.
- BDS-82: chat bundle; adds the chat setup section to README alongside this PR's `### Setup`
  subsection.
- BDS-22: cancelled by this decision (one tracker connector, one workspace at a time).
- DOC-21: documents the `MCP_ALLOWED_REDIRECT_ORIGINS` prerequisite for claude.ai connector setup.
