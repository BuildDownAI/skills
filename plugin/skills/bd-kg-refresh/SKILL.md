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
   `docs/kg-binding.md`). Parse `kg.present`, `kg.source_repo`, `kg.orchestrator`,
   `kg.search_tool`. If `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop.

2. **Ensure the source-repo checkout.** The ingest runs locally in a clone of
   `kg.source_repo` (convention: a sibling directory of the project). Clone it if absent.
   Ensure its venv: prefer `python3.10`, fall back to `python3`
   (`PY=python3.10; command -v "$PY" >/dev/null 2>&1 || PY=python3`), then
   `"$PY" -m venv .venv && ./.venv/bin/pip install -r requirements.txt` if `.venv` is missing.

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

6. **Redeploy the orchestrator** — from the orchestrator repo's checkout, run its deploy
   wrapper (AI-Implement: `./scripts/deploy-orchestrator.sh [app]`). Never a plain
   `fly deploy` — it ships a sidecar-less image (`/mcp` → 503). The wrapper passes the build
   secret + `--no-cache` and fails loudly if `/mcp` doesn't answer 401 after the deploy.

7. **Verify live (boots ≠ serves).** Query the deployed graph through `kg.search_tool` and
   confirm:
   - a domain query returns non-empty, `degraded: false` results, and
   - the graph's **age stamp equals Step 3's date** (recon reads it via `kg_neighbors` on the
     spine IRI — `docs/kg-recon.md`). An unchanged stamp means the deploy served the OLD
     snapshot (push didn't land, or the build cloned before the push) — re-run Step 6.
   No client restart is needed — the server is remote; new results appear on the next query.

8. **Close — learnings loop (required check, usually a no-op).** Follow
   `docs/kg-learnings-loop.md`: if this refresh surfaced a base-relevant pattern (ingest
   failure class, classifier miss, portability gap, deploy-path gap), file the sanitized
   learning PR into `BuildDownAI/bd-knowledge-graph-base` `testing`. An uneventful refresh
   files nothing. Advisory — never blocks.

---

## Notes

- The binding format is canonical across all KG-aware skills (see `docs/kg-binding.md`).
- Deploy rights are required for Step 6 — an operator without them stops after Step 5 and
  hands the deploy to someone who has them (the committed snapshot makes the refresh
  deterministic for whoever deploys).
- The ingest command is unified: fresh clones and existing checkouts run the same command.
- A project without `kg.present: true` degrades gracefully, but not silently: this skill is
  invoked directly for the KG, so it prints the "no KG bound" message and stops.
