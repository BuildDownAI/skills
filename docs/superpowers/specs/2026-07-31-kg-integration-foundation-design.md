# Design spec: KG integration — foundation (bd-project-setup KG phase + bd-kg-refresh)

**Status:** approved design · **Date:** 2026-07-31

This is **spec #1 of 2** for wiring the BuildDown skills to a per-project knowledge
graph (KG), **hybrid-search only**. Spec #1 is the *foundation*: the CLAUDE.md
binding contract, a KG phase in `bd-project-setup`, and a new `bd-kg-refresh`
skill. **Spec #2** (separate) adds the advisory recon step + staleness-delta to
the four session-owning skills — out of scope here.

Everything degrades gracefully: a project with no KG is fully supported and
untouched.

## Goal

Give a project an optional, read-only KG connection that the skills can later
query, and make the connection real when it's missing — clone the KG repo from
its origin, register its MCP server, build the graph — without a human leaving
the session.

## The KG, in one paragraph

A project's KG is a **separate sibling repo** (`knowledge-graph-<project-slug>`)
containing an rdflib graph built by `kg_ingest` from the project's git history +
tracker + docs. It exposes a **read-only stdio MCP server** (`python -m
kg_query.server`) whose only surface the skills use is **`kg_hybrid_search`**.
The server has **no OAuth** — it's a local process Claude Code launches on demand
— so wiring it is simpler than the tracker server (contrast BDS-22's
token-per-name naming trap, which does not apply here).

## Component 1 — the CLAUDE.md binding contract

`bd-project-setup` writes an optional block. This is the **entire interface**
between skills and the KG; skills read these values and never touch graph
internals.

```md
## Knowledge graph (optional)
- kg.present:     true
- kg.repo:        BuildDownAI/knowledge-graph-<project-slug>   # origin (owner/name)
- kg.path:        ../knowledge-graph-<project-slug>            # local checkout (rel. to project root)
- kg.branch:      knowledge-graph                              # branch to keep checked out
- kg.mcp_server:  <project-slug>-kg                            # MCP server name in .mcp.json
- kg.search_tool: mcp__<project-slug>-kg__kg_hybrid_search     # the ONLY tool skills call
```

- `kg.present: false` (or the block absent) ⇒ every KG-aware skill step is a
  **silent no-op**. No errors, no prompts.
- `kg.path` is relative to the project root; the sibling-directory default keeps
  the KG next to the project clone.
- `kg.search_tool` is derived from `kg.mcp_server` but bound explicitly so skills
  never string-build tool names.

## Component 2 — `bd-project-setup`: a new "Knowledge graph" phase

A new phase (after the tracker wiring), structured like the existing **Phase 0
detect → classify → confirm** pattern (per BDS-9 — never clobber an existing
setup).

**Step K.1 — Detect.** Read the project `CLAUDE.md` for an existing
`## Knowledge graph` block and `.mcp.json` for a `<slug>-kg` server. Classify:
*bound & present* / *partially wired* / *not wired* / *deliberately absent*.

**Step K.2 — Decide whether the project has a KG.** Probe by convention: does
`<same-owner>/knowledge-graph-<project-slug>` exist on the remote (`gh repo view`,
read-only)? Present the finding and ask the operator to confirm, override the
slug, or declare "no KG" → bind `kg.present: false` and end the phase. Never
assume; always confirm (BDS-9 gate).

**Step K.3 — Bootstrap what's missing** (the operator-confirmed "get it locally"
requirement):
1. **Repo not cloned at `kg.path`** → `git clone <origin> <kg.path>` and
   `git checkout <kg.branch>` (default `knowledge-graph`).
2. **MCP server not in `.mcp.json`** → write the read-only entry (Component 4)
   and pre-approve it (add `<slug>-kg` to `enabledMcpjsonServers` in
   `.claude/settings.json`). No OAuth flow.

**Step K.4 — Build.** Invoke **`bd-kg-refresh`** (Component 3) so the graph and
embeddings exist and the server can actually answer. Setup does not duplicate
ingest logic.

**Step K.5 — Bind.** Write/merge the `## Knowledge graph` block (Component 1)
into `CLAUDE.md`, merging (not clobbering) any existing values.

**Step K.6 — Note the restart.** Tell the operator: the MCP server loads the
graph once at startup, so a **Claude Code restart** is needed before
`kg_hybrid_search` is live (and after any future refresh). This is the same
"MCP servers load at session start" caveat the setup skill already documents for
the tracker.

The whole phase is skippable: if the operator says the project has no KG, K.3–K.5
are skipped and only `kg.present: false` is written.

## Component 3 — new `bd-kg-refresh` skill

A new `bd-*` skill **in this repo** (`plugin/skills/bd-kg-refresh/SKILL.md`). One
skill, used for both the first build and every later refresh.

**Inputs:** `kg.path` (from CLAUDE.md). The project path to ingest is **not**
re-derived by this skill — it is already bound inside the KG repo's own
`sources.yml` (`code_repo.path`, e.g. `../AI-Implement`), which the KG uses as the
source of truth for what it ingests. **Behavior:**
1. Ensure the venv: if `<kg.path>/.venv` is missing, create it with Python 3.10+
   and `pip install -r requirements.txt` (the `mcp`/`fastembed` deps need 3.10+).
2. Run the canonical ingest from `kg.path`, passing the project path resolved from
   that repo's `sources.yml`:
   `./.venv/bin/python -m kg_ingest.cli --repo <sources.yml code_repo.path> --tracker --secondary`
   (auto-embeds — rebuilds `out/graph.trig` **and** the vector sidecar).
   The tracker ingest needs the KG's configured tracker key/credentials as the KG
   repo already documents; this skill does not manage those secrets.
3. Report: quad/issue/vector counts and `SHACL conforms`.
4. **Remind:** the running MCP server won't serve the new graph until a Claude
   Code **restart** (load-once).

Trigger phrases: "bd-kg-refresh", "refresh the KG", "rebuild the knowledge graph",
"re-ingest". Frontmatter + numbered-steps match the other bd-* skills.

**"Running" needs no second skill:** the query surface is a stdio MCP server
Claude Code launches on demand — there is no daemon to start — so build + refresh
is the only recurring operation.

## Component 4 — the KG MCP server entry (written by bd-project-setup)

Parameterized from `kg.path` (`$KG` below), matching the reference
`ai-implement-kg` entry:

```json
"<project-slug>-kg": {
  "command": "$KG/.venv/bin/python",
  "args": ["-m", "kg_query.server"],
  "cwd": "$KG",
  "env": { "KG_BACKEND": "rdflib", "PYTHONPATH": "$KG" }
}
```

Absolute paths (resolved from `kg.path`). Pre-approved via
`enabledMcpjsonServers`. Read-only: exposes `kg_hybrid_search` (and the other
read tools) — no write tools, no auth.

## Discovery convention

KG origin defaults to `<project-owner>/knowledge-graph-<project-slug>` (e.g.
`BuildDownAI/AI-Implement` → `BuildDownAI/knowledge-graph-ai-implement`). Probed,
never assumed; the operator confirms or overrides in Step K.2.

## Graceful degradation (first-class)

- No KG for a project → `kg.present: false`; nothing else is written; no skill is
  affected.
- KG repo unreachable / clone fails → report and stop the phase (leave the
  project un-bound), never half-write the block.
- fastembed absent in the KG venv → the ingest already skips embeddings
  gracefully (documented in the KG repo); `bd-kg-refresh` surfaces the warning.

## Testing / verification (mechanical — per BDS-2)

No executable code ships (markdown skills + JSON). Validation is:
- `python3 -m json.tool .mcp.json` and `python3 -m json.tool .claude/settings.json`
  exit 0 after Step K.3.
- The written `<slug>-kg` server name is identical across the `.mcp.json` entry,
  `enabledMcpjsonServers`, `kg.mcp_server`, and `kg.search_tool`.
- `bd-kg-refresh/SKILL.md` has valid frontmatter (name/description) and follows
  the repo's skill structure.
- **Dry-run acceptance:** on a project with no KG, running `bd-project-setup`'s KG
  phase writes exactly `kg.present: false` and changes nothing else. On a project
  whose KG repo exists remotely but isn't cloned, the phase clones it, writes +
  pre-approves the server, runs `bd-kg-refresh` to a conforming graph, and binds
  the block — then instructs a restart.

## Non-goals (explicit)

- **The recon step** (skills querying the KG in Orient) — that's **spec #2**.
- **Staleness-delta** (detect KG age + what's new at tracker/PR ingest points) —
  spec #2.
- **Ingesting the KG repo into the KG itself** — deferred; revisit after this
  feature set ships.
- **BDS-32** structured/versioned learning payloads — a future enhancement; the
  loop works with today's first-line marker format.
- Managing the KG's own tracker credentials — owned by the KG repo, not this skill.
