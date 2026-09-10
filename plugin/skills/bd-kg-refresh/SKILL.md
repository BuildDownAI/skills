---
name: bd-kg-refresh
description: "Refresh a project's knowledge graph (KG) via the orchestrator's refresh rail. Preflights the orchestrator, reports scope from the rail's manifest reconcile, triggers POST /api/kg/refresh, polls the five rail stages to serving, then verifies the deployed graph. For local ingest iteration, use bd-mega-kg-refresh. No-op with a clear message if this project has no KG bound."
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

2. **Preflight.** Call `get_tenant_health` on the bound orchestrator MCP server
   (`mcp__<kg.mcp_server>__get_tenant_health`). Every row under `kgRefreshPreflight` must have
   `ok: true`. If any row fails:
   - Print: "Preflight failed: <row.repo> <row.grant> — <row.hint>"
   - Stop. Do not trigger the rail against a known-broken orchestrator.
   If `get_tenant_health` returns no `kgRefreshPreflight` rows (orchestrator predates AII-594),
   note "preflight rows absent — proceeding" and continue.
   Auth error → tell the user to re-authenticate via `/mcp` in an interactive session.

3. **Report scope.** The rail reconciles `sources.yml` automatically on every refresh —
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
     4. Run `git fetch upstream`.
     5. Count commits the derivative is behind: `git rev-list HEAD..upstream/main --count`
        → N. If N > 0, find the last merge date:
        `git log --merges --first-parent -1 --format=%cd HEAD`
        (use "never merged" if no merge commit exists). Print:
        "derivative is N commits behind base (last merge <date>); run bd-mega-kg-refresh to merge"
        If N = 0, print: "derivative is current with base".
     Advisory only — the refresh continues regardless of the result. Do not run
     `git merge upstream`, do not create a `kg-upstream/` branch, and do not open any PR
     in this sub-step.

4. **Trigger the rail.** Send `POST <kg.orchestrator>/api/kg/refresh` with an admin session
   token. Handle each response:
   - `202` — refresh accepted and running; proceed to Step 5.
   - `409` — a refresh is already running; proceed to Step 5 to poll the in-flight run;
     do not re-trigger.
   - Refusal — the response body names the failing preflight row or the deploy hold; state
     the gate and stop. Never re-trigger on a refusal; wait for the gate to clear before
     retrying from Step 2.

5. **Poll.** Every 60 seconds, check the rail status:
   - **Preferred (when available — AII-595):** `mcp__<kg.mcp_server>__get_kg_status`
   - **Current default:** `GET <kg.orchestrator>/api/kg/status` with an admin session token.

   Report the stage each minute. The five rail stages are:

   | Stage | Meaning |
   |---|---|
   | `ingest-running` | Rail is cloning and ingesting |
   | `staging` | Rail has fetched the pushed snapshot and is staging, swapping and verifying it locally (content guard already ran inside the runner before the push) |
   | `serving` | New snapshot promoted; refresh complete |
   | `reverted` | Stamp or verify gate failed after the swap; rail restored the previous snapshot, which is still serving |
   | `failed` | Rail error before staging |

   **Terminal conditions:**
   - `serving` with a `servedStamp` newer than before the trigger → proceed to Step 6.
   - `reverted` or `failed` → report `lastRefresh.gate` and `lastRefresh.detail`; stop.
     Do not re-trigger; state the gate and let the operator decide next steps.

6. **Verify live.** Query the deployed graph through `kg.search_tool` and confirm:
   - A domain query returns non-empty, `degraded: false` results.
   - The graph's spine stamp (via `kg_neighbors` on the spine IRI — `../bd-shared/kg-recon.md`)
     equals `servedStamp` from Step 5.
   An unchanged stamp means the rail served the old snapshot — check `lastRefresh.gate` and
   `lastRefresh.detail` from the status response.

7. **Close — learnings loop (required check, usually a no-op).** Follow
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

---

## Notes

- **Local iteration on the ingest** (interrogate the served graph, change the ingest config,
  hand the result to the rail) is `bd-mega-kg-refresh`, not this skill.
- The binding format is canonical across all KG-aware skills (see `../bd-shared/kg-binding.md`).
- An admin session token is required to trigger and poll the rail — an operator without one
  stops after Step 3 and hands the trigger to someone who has it.
