---
name: bd-kg-refresh
description: "Refresh a project's knowledge graph (KG) so hybrid search reflects the current code + tracker. The KG is served by the orchestrator's /mcp — REFRESH = REDEPLOY: run the ingest locally in the KG source repo, commit the snapshot parts, redeploy the orchestrator (the image build re-materializes graph + embeddings), then verify the deployed graph's age stamp changed. Trigger when the user says 'bd-kg-refresh', 'refresh the KG', 'rebuild the knowledge graph', 're-ingest the KG', or after landing work that should be searchable. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
---

# bd-kg-refresh Skill

Refresh the **orchestrator's** knowledge graph. There is no local graph to refresh — the
deployed sidecar is the single source of truth (AII-324), and it only changes when a new image
is built from a committed snapshot. **The redeploy IS the refresh**; the deploy log is the
refresh audit trail.

```
ingest (local, KG source repo) → commit snapshot parts → redeploy orchestrator → verify live
```

## Steps

1. **Read the binding.** Open `CLAUDE.md` → `## Knowledge graph` block (format:
   `../bd-shared/kg-binding.md`). Parse `kg.present`, `kg.source_repo`, `kg.orchestrator`,
   `kg.search_tool`. If `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop.

2. **Ensure the source-repo checkout.** The ingest runs locally in a clone of
   `kg.source_repo` (convention: a sibling directory of the project). Clone it if absent.
   Ensure its venv: prefer `python3.10`, fall back to `python3`
   (`PY=python3.10; command -v "$PY" >/dev/null 2>&1 || PY=python3`), then
   `"$PY" -m venv .venv && ./.venv/bin/pip install -r requirements.txt` if `.venv` is missing.

2b. **Reconcile scope with the orchestrator (BDS-36).** The orchestrator's project list is
   the KG's scope authority; `sources.yml` is the materialized copy. Before the ingest:
   - Call `list_projects` on the bound orchestrator MCP server (the same server as
     `kg.search_tool` — the diagnostics tools ride it).
   - **Diff repos:** every project repo must appear in `sources.yml` (as `code_repo` or a
     `secondary_repos` entry). For each missing repo: clone it as a sibling directory, add
     the entry, and **ask the operator for its docs URL** ("What is the published docs root
     for <repo>? Skip if none."). Record the answer as `docs_url:`; a skip leaves the key
     absent, and later refreshes ask again while it stays absent.
   - **Diff teams:** every project `teamKey` must appear under `trackers:`. Add missing
     teams at `tier: secondary`.
   - Commit the reconciled `sources.yml` before ingesting, and **announce the delta**
     plainly: "orchestrator manages N projects; sources covered M; added <repos/teams>".
     No delta → one line: "scope in sync (N projects)".
   - Failure-tolerant: MCP unreachable or unauthenticated → announce it and proceed with
     the existing config; the reconcile is a convergence step, not a gate.

3. **Run the ingest** from the source-repo checkout:
   - `./.venv/bin/python -m kg_ingest.cli --repo <code_repo.path from sources.yml> --tracker --secondary`
   - Rebuilds `out/graph.trig` + embeddings locally and — the part that matters for the
     deploy — rewrites the **committed snapshot parts** (`snapshot/parts/*.nt`), including the
     graph **age stamp** (`dcterms:modified` on the spine IRI, written at ingest).
   - Tracker credentials come from the KG repo's own configuration; this skill does not
     manage secrets.

4. **Report the ingest**: quad count, issue/vector counts, `SHACL conforms`, and the
   `graph age stamp` line (this run's date — the value the live verify checks for in Step 7).
   Surface an `embeddings SKIPPED` warning if fastembed wasn't available.

5. **Commit + push the snapshot** to the source repo's default branch:
   - `git add snapshot/ && git commit -m "kg-refresh: snapshot @ <date> (<N> quads)" && git push`
   - Data-refresh commits go straight to the default branch — the snapshot is generated
     output, not reviewed code. The orchestrator's image build clones this branch.

6. **Redeploy the orchestrator.** Standard path (AI-Implement ≥ AII-357): trigger a
   **self-deploy** — `POST <orchestrator>/api/deploy` with an admin session token; the
   orchestrator builds its own next image, minting the KG build secret internally
   (`202 {"deploying": <sha>}` = started; `409` = one already running). Fallback for an
   image that predates self-deploy: the manual command in the orchestrator repo's
   `docs/deployment.md` — `fly deploy --remote-only --no-cache --build-secret kg_token=…
   --build-arg SOURCE_COMMIT/REPO/BRANCH … --app <app>` (all three stamps, or the resulting
   image cannot self-deploy). Never a plain `fly deploy` — it ships a sidecar-less image
   (`/mcp` → 503).
   **Sequencing rule:** confirm the snapshot push LANDED (`git log origin/<default>`)
   *before* triggering the deploy — chaining push and deploy in one command lets the remote
   builder clone the pre-push tree, and Step 7's unchanged stamp is how you find out.

7. **Verify live (boots ≠ serves).** Query the deployed graph through `kg.search_tool` and
   confirm:
   - a domain query returns non-empty, `degraded: false` results, and
   - the graph's **age stamp equals Step 3's date** (recon reads it via `kg_neighbors` on the
     spine IRI — `../bd-shared/kg-recon.md`). An unchanged stamp means the deploy served the OLD
     snapshot. Two known causes, both benign: the push hadn't landed when the build cloned
     (Step 6's sequencing rule), or **remote-builder git-cache lag** — a `--depth 1` clone
     issued moments after a push can be served from the builder's cache and miss it (seen
     live 2026-08-18: self-deploy v111 built the old snapshot; v112, minutes later, was
     correct). Either way: wait a few minutes, re-trigger Step 6, re-verify. Don't chase a
     bug that isn't there. Note a self-deploy `409 deploy-in-progress` can outlast the
     release by several minutes — poll, don't assume it's stuck.
   No client restart is needed — the server is remote; new results appear on the next query.

8. **Close — learnings loop (required check, usually a no-op).** Follow
   `../bd-shared/kg-learnings-loop.md`: if this refresh surfaced a base-relevant pattern (ingest
   failure class, classifier miss, portability gap, deploy-path gap), file the sanitized
   learning PR into `BuildDownAI/bd-knowledge-graph-base` `testing`. An uneventful refresh
   files nothing. Advisory — never blocks.

---

## Notes

- **One refresh feeds both targets** (transition mode): Step 3's ingest rebuilds the LOCAL
  graph (`out/graph.trig` + embeddings in the source-repo checkout) immediately — a bound
  local stdio server serves it after a Claude Code restart. Steps 5–6 carry the same data to
  the orchestrator. The refresh remains orchestrator-first: the deployed graph is the source
  of truth, the local copy a development convenience.
- The binding format is canonical across all KG-aware skills (see `../bd-shared/kg-binding.md`).
- Deploy rights are required for Step 6 — an operator without them stops after Step 5 and
  hands the deploy to someone who has them (the committed snapshot makes the refresh
  deterministic for whoever deploys).
- The ingest command is unified: fresh clones and existing checkouts run the same command.
- A project without `kg.present: true` degrades gracefully, but not silently: this skill is
  invoked directly for the KG, so it prints the "no KG bound" message and stops.
