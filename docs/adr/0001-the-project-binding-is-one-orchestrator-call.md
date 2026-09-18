# 0001. The project binding is one orchestrator call

**Status:** Accepted
**Superseded in part by:** 0002 (the two `CLAUDE.md` keys and the per-project server entry that this ADR still expected to be present are retired)
**Date:** 2026-09-17

## Context

Every KG-aware skill read its binding from a `## Knowledge graph` block in the project's
`CLAUDE.md`: five `kg.*` keys that `bd-project-setup` Phase K wrote by hand. The orchestrator
already held every one of those values. Copies drifted. A skill with a stale `kg.search_tool`
had no path when the tool was absent from its session (BDS-67). The pickup label had the same
shape: a literal in sixteen skill files, while the orchestrator held it as a settings row an
admin can change (AI-Implement ADR 022).

The orchestrator's `/mcp` door now serves two read tools that answer these questions
directly: `get_project_binding` (AI-Implement AII-715) returns the project's repo, default
branch, tracker, effective pickup label, and the KG binding; `get_session_identity`
(AII-714) returns the caller's role and the expiry of the access and refresh tokens. The
question was how much of the binding stays in `CLAUDE.md`, and what a skill does when the
tools are not there.

## Decision

We resolve the project binding with one call, `mcp__<kg.mcp_server>__get_project_binding`,
passed the repo slug. `CLAUDE.md` keeps two keys only:

- `kg.mcp_server` — the remote server name in `.mcp.json`. This is a client-side fact: the
  OAuth token is bound to the server name (BDS-22), so no orchestrator answer can supply it.
- `kg.present` — lets a project declare "no KG" without a call, and keeps the silent-skip
  rule for KG recon.

The answer's shape is the orchestrator's contract (`docs/mcp-server.md` in AI-Implement):
`repo`, `defaultBranch`, `tracker: { kind, team }`, `pickupLabel` (`null` when the tracker is
not Linear), and `kg: { present, orchestratorUrl, sourceRepo, baseRepo, searchTool }`. Skills
resolve the search tool as `mcp__<kg.mcp_server>__<kg.searchTool>`.

The pickup label comes from the same call. The orchestrator's value wins. The
`{{IMPLEMENT_LABEL}}` line in `CLAUDE.md` is the fallback, then the default `AI-Implement`
(`plugin/skills/bd-shared/pickup-label.md`).

The tool-presence check comes before the call. When `get_project_binding` is absent from the
session's tool list, a skill reads the legacy five-key block, prints "legacy binding", and
continues. Both shapes are documented for one release.

Admin-only skills read auth health from `get_session_identity`. When the refresh token
expires within 48 hours the skill says so before a long run. When any orchestrator call
answers 401, the skill prints one recovery line for the caller's client path and stops the
step (`plugin/skills/bd-shared/orchestrator-auth.md`).

## Alternatives considered

- **Keep the five-key block as the source of truth.** Rejected. Two copies of one value
  drift, and the drift is silent until a skill fails. Observed: `kg.search_tool` named a tool
  the session did not have (BDS-67).
- **Keep nothing in `CLAUDE.md`; discover the server by scanning `.mcp.json`.** Rejected. A
  checkout can bind more than one orchestrator server, and a chat session has no
  `.mcp.json`. The server name is the key the OAuth token hangs on, so it has to be stated.
- **Per-project KG fields in the mapping.** Rejected. The KG is one graph per orchestrator.
  `get_project_binding` reports orchestrator-wide KG config on purpose, so the skills side
  must not model a per-project graph.
- **Call the tool at every step.** Rejected. Read-only scans use the value resolved at
  session start; a skill re-resolves only before an action that assigns or writes. Same rule
  as `pickup-label.md` rule 3.
- **Fail when the tool is absent.** Rejected. A cached tool list, a chat session with no
  orchestrator connector, and an orchestrator that predates the tool all look the same from
  inside a skill. Fallback with a printed source line is the safe shape (BDS-67 pattern).

## Consequences

- One source of truth. A new orchestrator field reaches the skills without a `CLAUDE.md`
  edit in every project.
- `bd-project-setup` Phase K becomes a check that prints the orchestrator's answer beside the
  two keys it writes, not a writer of five keys.
- Every skill prints where its binding and its pickup label came from, once per session.
- A session whose tool list was cached without the tool uses legacy values without knowing
  the orchestrator has newer ones. The printed source line is the only signal.
- Live acceptance checks need an authenticated orchestrator session. A session whose token
  has expired cannot verify them; it gets the 401 recovery line instead.
- Follow-on work: BDS-70 (contract and Phase K), BDS-71 (the KG-aware skills), BDS-73
  (auth health), BDS-74 (clone steps named). After one release the legacy block is retired
  in a separate issue.
