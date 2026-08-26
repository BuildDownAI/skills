---
name: bd-system-questions
description: "Ask the orchestrator direct questions about the system: why a ticket isn't running, whether a pipeline is stuck, overall health, the project list, the runner mode. Trigger when the user says 'bd-system-questions', 'why isn't <ticket> running', 'why wasn't my ticket picked up', 'is the pipeline stuck', 'what's running right now', 'system health', 'orchestrator health', 'list the projects', or 'what runner mode are we in'. Uses the orchestrator MCP's read-only diagnostics tools. No-op with a clear message if no orchestrator MCP is bound."
metadata:
  suite: builddown
---

# bd-system-questions Skill

Answer system questions from the orchestrator itself. The orchestrator MCP serves five
read-only diagnostics tools next to the KG tools, on the same server and the same sign-in.
This skill maps plain questions to the right tool and interprets the answer.

## Binding

Read `CLAUDE.md` → `## Knowledge graph` block → `kg.mcp_server` (the orchestrator MCP server,
e.g. `orch-ai-implement-testing`). The diagnostics tools ride that server:
`mcp__<server>__get_issue_dispatch_status`, `get_tenant_health`, `list_in_flight_jobs`,
`list_projects`, `get_runner_mode`. If no orchestrator server is bound, print: "No orchestrator
MCP bound — run bd-project-setup (Phase K)." and stop. On an auth error, tell the user to
re-authenticate via `/mcp` in an interactive session (rare — tokens refresh automatically).

## The questions, and how to answer them

### 1. "Given ticket ID X, why isn't it running?"

Call `get_issue_dispatch_status(identifier: "X")`. Interpret, in order:

| Answer shape | Meaning | Tell the user |
|---|---|---|
| `inFlight: true` | It IS running | The phase and elapsed time; long elapsed on `implementation` is usually a big issue, not a stall — check the run before assuming |
| `dedupEntry` present | Dedup holds it | Dedup has NO time window — the entry clears only on failure, terminal reconcile, or manual delete. A completed prior run means the ticket already shipped |
| Last dispatch `completed / success` + `prUrl` | It already ran | Give the PR link; the ticket likely needs a new issue, not a re-run |
| Last dispatch failed | It failed | Give the conclusion; the orchestrator retries per its rules or the issue was parked |
| `recentDispatches: []` | Never dispatched | Check the pickup preconditions: label present? state Todo? project paused? capacity full? Use question 4 for the project row. **All green and still nothing?** Check the orchestrator's tracker visibility: its Linear app actor must be a MEMBER of the issue's team — new teams don't include the app automatically, and the poll silently sees nothing there (found live 2026-08-14: KGB-1, all preconditions green, app not in the team). The orchestrator cannot diagnose its own blindness — verify by minting an app-actor token and listing teams |

### 2. "Is anything stuck? What's running right now?"

Call `list_in_flight_jobs`. Empty list = nothing runs. For each job report identifier, repo,
phase, and elapsed seconds. Flag any job whose elapsed time is far past the project's job
timeout as stuck-candidate, and check it with question 1.

### 3. "How healthy is the system?"

Call `get_tenant_health`. Report the four numbers in one line: runner mode (and its source),
in-flight jobs, pending gap-fills, project count. A non-`default` runner mode means the
failover lever is pulled — say so plainly.

### 4. "What projects are on this orchestrator?"

Call `list_projects`. Report one row per mapping: team key, repo, execution mode, provider,
paused state, capacity cap. Flag paused projects — a paused project answers many "why isn't
my ticket running" questions by itself.

### 5. "What runner mode are we in?"

Call `get_runner_mode`. Report mode and source. Source `env` means the UI switch has no
effect until the env var is unset — say so.

## Rules

- **Read-only.** These tools change nothing. Admin actions (add a project, set the mode) go
  through the admin UI until the Admin write tier ships (AII-381, blocked by AII-340).
- **Interpret, don't dump.** Answer the user's question in one or two sentences first; show
  the raw fields after, only where they help.
- **Chain when the first answer points elsewhere** — e.g. question 1's "never dispatched"
  leads to question 4's paused check. Two calls beat one guess.
- Works from any surface with the orchestrator MCP bound: Claude Code sessions (this binding),
  or claude.ai chat with the connector added.
