---
name: bd-system-questions
description: "Ask the orchestrator direct questions about the system: why a ticket isn't running, whether a pipeline is stuck, overall health, the project list, the runner mode, or the KG refresh status. Discovers the bound orchestrator MCP's tools at session start and routes questions by their descriptions — new capabilities are askable the day they ship. Trigger when the user says 'bd-system-questions', 'why isn't <ticket> running', 'why wasn't my ticket picked up', 'is the pipeline stuck', 'what's running right now', 'system health', 'orchestrator health', 'list the projects', 'what runner mode are we in', 'what is the KG refresh doing', or 'did the last refresh work'. No-op with a clear message if no orchestrator MCP is bound."
metadata:
  suite: builddown
---

# bd-system-questions Skill

Answer system questions from the orchestrator itself. This skill discovers the bound MCP
server's tools at session start and routes each question to the tool whose description best
answers it. Fixed sections 1–6 are priors — they accelerate routing for known patterns but
do not block unknown questions from reaching step 2.

## Binding

Read `CLAUDE.md` → `## Knowledge graph` block → `kg.mcp_server` (the orchestrator MCP
server, e.g. `orch-ai-implement-testing`). If no orchestrator server is bound, print:

> No orchestrator MCP bound — run bd-project-setup (Phase K).

and stop.

## Step 1 — Discover

At session start, use ToolSearch with the query `mcp__<server>__` (the bound server's
prefix) to list all tools the server exposes along with their descriptions.

Print exactly one line:

> orchestrator MCP exposes N tools

where N is the count returned. Keep the full list — tool name and description — for the
session. Never assume a tool exists because this skill names it; the discovery list is the
authority.

**If N = 0** (server bound but no tools returned — typically an auth error): tell the user
to re-authenticate via `/mcp` in an interactive session and stop. Do not fall through to
the prior sections.

## Step 2 — Route by description

For each user question:

1. Check the priors table (sections 1–6). A prior section that matches the question gives
   the primary tool and the fields to surface — use it directly.
2. If no prior matches, scan the discovery list. Pick the tool(s) whose description answers
   the question. When two tools fit, call the cheaper read first and the other only if the
   first leaves the question open. State which tool answered and why in one line.
3. If no tool description fits, apply the unanswerable rule (see Rules).

## Rules

**Write-guard.** A tool whose description implies a write — any of: create, update, delete,
trigger, set, pause, resume, or similar mutating verbs — is never called from this skill.
Route write-adjacent questions to the admin UI.

**Interpret, don't dump.** Answer the user's question in one or two sentences first; show
raw fields after, only where they help.

**Chain when the first answer points elsewhere** — e.g. question 1's "never dispatched"
leads to question 4's paused check. Two calls beat one guess.

**Composition.** When a question spans tools (e.g. "why is my refresh slow" → `get_kg_status`
+ `list_in_flight_jobs`), call each matching tool once and give one combined answer. Do not
dump two separate result blocks; synthesize into a single response that addresses the
question.

**Unanswerable questions.** When no tool description fits the question, respond with:

> no tool answers this; closest is `<tool>`, which would tell you `<what it answers>`

Never guess from memory of orchestrator internals.

**A question with no prior falls through to step 2** — the absence of a prior section does
not mean the question is unanswerable.

Works from any surface with the orchestrator MCP bound: Claude Code sessions (this binding),
or claude.ai chat with the connector added.

---

## Priors

The sections below are worked examples that accelerate routing. They do not constrain which
questions can be answered — any tool the discovery step finds is available to step 2.

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

### 6. "What is the KG refresh doing?" / "Did the last refresh work?"

Call `get_kg_status`. Surface in one line:

> stage: `<stage>` | served: `<servedAt>` | last ok: `<lastRefresh.ok>`

Then give `gate` and `detail` if `lastRefresh.ok` is false — these name the failing check
and its reason.

The five rail stages and their meanings:

| Stage | Meaning |
|---|---|
| `ingest-running` | Rail is cloning and ingesting |
| `staging` | Snapshot fetched; being staged, swapped, and verified |
| `serving` | Refresh complete; new snapshot promoted |
| `reverted` | Stamp or verify gate failed after swap; previous snapshot still serving |
| `failed` | Rail error before staging |

**When `stage` is terminal (`serving`, `reverted`, or `failed`):** look up the refresh PR
the rail opened on the KG source repo — its title is `kg-refresh: snapshot @ <servedAt>`.
If the PR has a comment whose first line is `# ai-implement-kg-refresh-learnings` (posted
by the rail when it detects an anomaly — present only when the rail flagged something),
surface the key findings from that comment. An uneventful refresh has no learnings comment;
skip if absent.

**If `get_kg_status` is not in the discovery list** (tool not yet live on this orchestrator),
fall through to the unanswerable rule.
