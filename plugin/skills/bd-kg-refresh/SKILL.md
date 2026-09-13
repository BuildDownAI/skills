---
name: bd-kg-refresh
description: "Refresh a project's knowledge graph (KG) via the orchestrator's refresh rail (admin role). Preflights the orchestrator, reports scope from the rail's manifest reconcile, triggers the refresh rail through the orchestrator MCP (admin role), polls the five rail stages to serving, then verifies the deployed graph. For local ingest iteration, use bd-mega-kg-refresh. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
---

# bd-kg-refresh Skill

Refresh the **orchestrator's** knowledge graph via the rail. The rail clones the KG source repo,
runs the ingest, guards the result, and promotes it to serving — the laptop does not push a
snapshot. A refresh takes about 15 minutes on GitHub Actions.

## Steps

1. **Read the binding.** Open `CLAUDE.md` → `## Knowledge graph` block (format:
   `../bd-shared/kg-binding.md`). Parse `kg.present`, `kg.source_repo`, `kg.orchestrator`,
   `kg.search_tool`, `kg.mcp_server`. If `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop.

2. **Check your role.** Before any orchestrator call, confirm the session has admin access.
   - Use ToolSearch to check whether `mcp__<kg.mcp_server>__get_session_identity` is in the
     session's tool list. If the tool is absent:
     - Print: "This orchestrator has no `get_session_identity` tool; it predates the MCP write
       tier ([AII-381](https://linear.app/eudoxus/issue/AII-381/mcp-declared-write-list-with-a-role-per-tool-get-session-identity-and)).
       Update the orchestrator, then retry."
     - Stop.
   - Call `mcp__<kg.mcp_server>__get_session_identity`. Read `role` from the result. If `role`
     is not `admin`:
     - Print: "This skill needs an admin account on the orchestrator. Your MCP session is signed
       in as `<email>` with role `<role>`. Ask an admin to change your allowlist entry, or ask
       them to run the refresh."
     - Stop.

3. **Preflight.** Call `get_tenant_health` on the bound orchestrator MCP server
   (`mcp__<kg.mcp_server>__get_tenant_health`). Every row under `kgRefreshPreflight` must have
   `ok: true`. If any row fails:
   - Print: "Preflight failed: <row.repo> <row.grant> — <row.hint>"
   - Stop. Do not trigger the rail against a known-broken orchestrator.
   If `get_tenant_health` returns no `kgRefreshPreflight` rows (orchestrator predates AII-594),
   note "preflight rows absent — proceeding" and continue.
   Auth error → tell the user to re-authenticate via `/mcp` in an interactive session.

4. **Report scope.** The rail reconciles `sources.yml` automatically on every refresh —
   adding any repo or team from the orchestrator's project list that is not yet in the manifest.
   - Call `list_projects` on the bound orchestrator MCP
     (`mcp__<kg.mcp_server>__list_projects`) to obtain a project count. If `list_projects`
     is unreachable, note "project count unavailable" and continue — this report is
     informational, not a gate.
   - Print: "scope: N mapped projects; the rail adds missing repos and teams on this refresh
     (see the refresh PR's Scope section)."
   - **Base drift.** Check whether the derivative KG repo is behind the base template:
     1. If `get_tenant_health` returned a row with type `base:drift`, print that row directly
        and skip the remaining git steps below.
     2. Otherwise, read `base_repo:` from `sources.yml`. If the field is absent, use
        `https://github.com/BuildDownAI/bd-knowledge-graph-base.git` as the upstream URL
        and print "base_repo not set; using the base template". Skip the drift check only
        if the URL cannot be fetched (e.g., network error or auth failure).
     3. Ensure the `upstream` remote exists in the KG checkout: run
        `git remote get-url upstream`. If the remote is missing, add it:
        `git remote add upstream <base_repo>`.
     4. Run `git fetch origin` (to bring the derivative's remote refs current), then
        `git fetch upstream`.
     5. Determine the derivative's default branch: run
        `git remote show origin | grep 'HEAD branch'`; fall back to `main` if absent.
        Read the short SHA: `git rev-parse --short origin/<default-branch>` → `<SHA>`.
        Count commits the derivative is behind:
        `git rev-list origin/<default-branch>..upstream/main --count` → N.
        If N > 0, find the last merge date:
        `git log --merges --first-parent -1 --format=%cd origin/<default-branch>`
        (use "never merged" if no merge commit exists). Print:
        "derivative is N commits behind base (last merge <date>, origin/<default-branch> at <SHA>); run bd-mega-kg-refresh to merge"
        If N = 0, print: "derivative is current with base (origin/<default-branch> at <SHA>)".
     Advisory only — the refresh continues regardless of the result. Do not run
     `git merge upstream`, do not create a `kg-upstream/` branch, and do not open any PR
     in this sub-step.

5. **Trigger the rail.** Call `mcp__<kg.mcp_server>__trigger_kg_refresh` (no arguments).
   Read `status` from the result:
   - `202` — refresh accepted and running; proceed to Step 6.
   - `409` — a refresh is already running; proceed to Step 6 to poll the in-flight run;
     do not re-trigger.
   - `422` or any other refusal — the response body names the failing gate; state the gate
     and stop. Never re-trigger on a refusal; wait for the gate to clear before retrying
     from Step 3.
   - `isError` result containing `forbidden` — your role changed since Step 2; print:
     "This skill needs an admin account on the orchestrator. Your MCP session is signed in as
     `<email>` with role `<role>`. Ask an admin to change your allowlist entry, or ask them to
     run the refresh." and stop.

6. **Poll.** Every 60 seconds, check the rail status via
   `mcp__<kg.mcp_server>__get_kg_status`.

   Report the stage each minute. The five rail stages are:

   | Stage | Meaning |
   |---|---|
   | `ingest-running` | Rail is cloning and ingesting |
   | `staging` | Rail has fetched the pushed snapshot and is staging, swapping and verifying it locally (content guard already ran inside the runner before the push) |
   | `serving` | New snapshot promoted; refresh complete |
   | `reverted` | Stamp or verify gate failed after the swap; rail restored the previous snapshot, which is still serving |
   | `failed` | Rail error before staging |

   **Terminal conditions:**
   - `serving` with a `servedStamp` newer than before the trigger → proceed to Step 7.
   - `reverted` or `failed`:
     - Report `lastRefresh.gate` and `lastRefresh.detail`.
     - If `lastRefresh.detail` contains `KG_SNAPSHOT_TRACKER_REGRESSION` and you have **not**
       already accepted a new baseline in this session:
       1. Render `lastRefresh.partTable` as a markdown table with columns
          `part | before | after | delta` (delta = after − before; negative means shrink).
          If `lastRefresh.partTable` is absent, print the raw `lastRefresh.detail` and stop.
       2. Ask exactly one question in STE:
          > "The guard refused because `<part>` shrank from A to B lines. Is this shrink
          > expected from a change you know about (name it)? Yes: I re-trigger once with
          > accept-new-baseline, which records your name and the table in the refresh PR.
          > No: I stop."
       3. On **yes**: call `trigger_kg_refresh { acceptNewBaseline: true }`, mark the
          baseline as accepted for this session (never accept twice), and return to the
          top of the poll loop (Step 6).
       4. On **no**: stop.
     - If `lastRefresh.detail` contains `KG_SNAPSHOT_TRACKER_REGRESSION` and you have
       **already** accepted a new baseline in this session: print "Guard fired again after
       accept-new-baseline — stopping without re-triggering." and stop.
     - Otherwise: stop. Do not re-trigger; state the gate and let the operator decide next steps.

7. **Verify live.** Query the deployed graph through `kg.search_tool` and confirm:
   - A domain query returns non-empty, `degraded: false` results.
   - The graph's spine stamp (via `kg_neighbors` on the spine IRI — `../bd-shared/kg-recon.md`)
     equals `servedStamp` from Step 6.
   An unchanged stamp means the rail served the old snapshot — check `lastRefresh.gate` and
   `lastRefresh.detail` from the status response.

8. **Close — learnings loop (required check, usually a no-op).** Follow
   `../bd-shared/kg-learnings-loop.md`. In addition: find the refresh PR the rail opened
   (title: `kg-refresh: snapshot @ <stamp>`) and read two items from it:
   - **`### Scope` section (AII-607):** The rail writes a `### Scope` section listing any
     repos or teams it added to `sources.yml` on this run. Read it and include the delta as
     additional context for the learnings loop. If the Scope section is absent (rail predates
     AII-607), note its absence and proceed — this is not an error.
   - **`# ai-implement-kg-refresh-learnings` comment (AII-596):** If a comment with this
     exact marker is present (posted when the rail detects an anomaly), use it as additional
     input to the base-note decision alongside the ingest report. If absent (uneventful run or
     rail predates AII-596), proceed without it — this is normal.
   An uneventful refresh with no learnings comment files nothing. Advisory — never blocks.
   If a new baseline was accepted in this session (Step 6), include in the closing note:
   the part name, the before-lines count, the after-lines count, and the change the operator
   named when they accepted.

---

## Notes

- **Local iteration on the ingest** (interrogate the served graph, change the ingest config,
  hand the result to the rail) is `bd-mega-kg-refresh`, not this skill.
- The binding format is canonical across all KG-aware skills (see `../bd-shared/kg-binding.md`).
- This is an admin-only skill: it needs an allowlist entry with role admin on the orchestrator.
- `acceptNewBaseline` is the only sanctioned path past the `KG_SNAPSHOT_TRACKER_REGRESSION` guard; run `bd-mega-kg-refresh` (dry-run proof loop) before any refresh where a part shrink is expected.
