---
name: bd-kg-refresh
description: "Build or refresh a project's knowledge graph (KG) so semantic/hybrid search reflects the current code + tracker. Trigger when the user says 'bd-kg-refresh', 'refresh the KG', 'rebuild the knowledge graph', 're-ingest the KG', or after landing work that should be searchable. Ensures the KG repo's Python venv, runs the canonical ingest (which auto-builds the vector index), and reminds that the read-only MCP server reloads the graph only on a Claude Code restart. No-op with a clear message if this project has no KG bound (no `## Knowledge graph` block / kg.present:false)."
metadata:
  suite: builddown
---

# bd-kg-refresh Skill

Refresh a project's knowledge graph so semantic/hybrid search stays current with the codebase and tracker.

## Steps

1. **Read the binding.** Open `CLAUDE.md` and find the `## Knowledge graph` block. Parse `kg.present`, `kg.repo`, `kg.path`, and other keys (format: `docs/kg-binding.md` in the skills repo). If `kg.present` is `false` or the block is absent:
   - Print: "This project has no KG bound — run bd-project-setup to add one."
   - Stop.

2. **Ensure the venv.** Check if `<kg.path>/.venv` exists. If not:
   - `cd <kg.path>`
   - Prefer `python3.10` on PATH; if it isn't found, fall back to `python3` — e.g. `PY=python3.10; command -v "$PY" >/dev/null 2>&1 || PY=python3`.
   - `"$PY" -m venv .venv`
   - `./.venv/bin/pip install -r requirements.txt`
   - (Python 3.10+ is required for `mcp` and `fastembed` dependencies — verify the resolved interpreter meets that floor even after falling back to `python3`.)

3. **Run the ingest** from `<kg.path>`:
   - `./.venv/bin/python -m kg_ingest.cli --repo <code_repo.path from that repo's sources.yml> --tracker --secondary`
   - This rebuilds `out/graph.trig` and auto-builds the embeddings sidecar.
   - The tracker ingest uses the KG repo's own configured tracker credentials (this skill does not manage secrets).

4. **Report** the output:
   - Extract and print the quad count (triples in the graph), issue count, and vector count from the ingest logs.
   - Print whether `SHACL conforms` (the semantic validator).
   - If the run logs `embeddings SKIPPED` (fastembed not installed), surface that warning and note that semantic/hybrid search will be lexical-only until the dependency is fixed.

5. **Restart reminder.** Print: "The running KG MCP server loaded the graph at startup, so hybrid-search won't reflect this refresh until a Claude Code restart."

---

## Notes

- The binding format is canonical across all KG-aware skills (see `docs/kg-binding.md`).
- The ingest command is unified: it runs on both fresh clones and existing graphs, always rebuilding the index.
- A project without `kg.present: true` degrades gracefully, but not silently: this skill is invoked directly for the KG, so per `docs/kg-binding.md` it prints the "no KG bound" message in Step 1 and stops rather than skipping quietly. (The silent-no-op case applies only to KG-aware steps incidentally embedded inside other skills.)
