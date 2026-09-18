# Orchestrator Auth Health Check

Shared auth-health procedure for orchestrator-calling skills. Apply this procedure immediately after calling `mcp__<kg.mcp_server>__get_session_identity` — whether that call is for role-checking (admin-only skills) or for health-only (read-only skills).

**Warned-once invariant:** The expiry warning fires at most once per session. If a skill calls `get_session_identity` more than once, apply this procedure only at the first call.

## Precondition

The orchestrator MCP server name (`kg.mcp_server`) must already be resolved (from `get_project_binding` or the legacy CLAUDE.md block) before this procedure runs. The tool name is `mcp__<kg.mcp_server>__get_session_identity`.

## Expiry check

After receiving the `get_session_identity` response:

1. **If `refresh` is `null` or absent:** print exactly —
   > refresh expiry unknown

   Continue. Do not stop.

2. **If `refresh` is present and `refresh.expiresAt` is within 48 hours of now:** print exactly —
   > Your MCP sign-in expires \<when\>; re-authenticate via `/mcp` in an interactive session before a long run.

   where `<when>` is a human-readable relative expression (e.g. "in 6 hours" or "tomorrow at 14:32 UTC"). Continue. Do not stop.

3. **If `refresh.expiresAt` is more than 48 hours away:** no output. Continue normally.

## 401 recovery

If **any** orchestrator tool call in the skill returns a 401 or an `isError` result containing "requires re-authorization", "token expired", or similar auth-failure language:

1. Use `token.clientPath` from the `get_session_identity` result already in session context.

2. Print exactly one line:
   - If `token.clientPath` is `loopback` (desktop or CLI session):
     > Orchestrator MCP token expired — re-authenticate via `/mcp` in an interactive session and retry.
   - If `token.clientPath` is `connector` (claude.ai session):
     > Orchestrator MCP token expired — reconnect the connector in [claude.ai](https://claude.ai) settings and retry.
   - If `token.clientPath` is empty or absent (e.g. `get_session_identity` itself returned 401):
     > Orchestrator MCP token expired — re-authenticate via `/mcp` in an interactive session (desktop/CLI) or reconnect the connector in [claude.ai](https://claude.ai) settings and retry.

3. Stop the current step immediately. Do not retry the failed call. Do not continue to subsequent steps.

## Failure tolerance

- **`get_session_identity` itself returns 401:** apply the 401 recovery rule above (unknown path branch) and stop.
- **`get_session_identity` tool absent from session:** skip this procedure silently — do not print anything. (Admin-only skills check for tool presence before reaching this step and stop there; read-only skills treat an absent tool as a silent skip.)
- **Other error on `get_session_identity`:** print "auth health check failed: `<error>`; continuing" and proceed. The expiry warning is advisory; only a 401 stops the step.
