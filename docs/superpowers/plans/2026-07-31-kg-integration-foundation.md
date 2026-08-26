# KG Integration — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give a project an optional, read-only knowledge-graph (KG) connection the BuildDown skills can query via hybrid-search only — wiring it up (and bootstrapping it when missing) through `bd-project-setup`, plus two new skills (`bd-kg-refresh`, `bd-kg-search`).

**Architecture:** A project's KG is a separate sibling repo (`knowledge-graph-<slug>`) exposing a read-only stdio MCP server. `bd-project-setup` writes an optional `## Knowledge graph` block in CLAUDE.md (the whole skills↔KG interface), cloning the repo + registering the no-OAuth server + building the graph when those are missing. `bd-kg-refresh` owns venv + ingest (first build and refresh). `bd-kg-search` is a thin direct hybrid-search on-ramp. Every piece is a silent no-op when a project has no KG.

**Tech Stack:** Markdown skills (`plugin/skills/<name>/SKILL.md`, auto-discovered), JSON config (`.mcp.json`, `.claude/settings.json`), the KG repo's Python `kg_ingest`/`kg_query` (py3.10+, rdflib, fastembed). No executable code ships in this repo — validation is mechanical.

**Spec:** `docs/superpowers/specs/2026-07-31-kg-integration-foundation-design.md`

## Global Constraints

- **Hybrid-search only.** Skills call **only** `kg.search_tool` = `mcp__<slug>-kg__kg_hybrid_search`. Never call other KG tools (`kg_search`, `kg_neighbors`, `kg_provenance`, `kg_path`) or touch graph internals.
- **Graceful degradation.** `kg.present: false` (or the `## Knowledge graph` block absent) ⇒ every KG step is a **silent no-op** — no error, no prompt.
- **Server naming:** `<project-slug>-kg` (e.g. `ai-implement-kg`). Read-only **stdio** server, **no OAuth** (BDS-22's token-per-name trap does not apply). Pre-approve by adding the name to `enabledMcpjsonServers` in `.claude/settings.json`.
- **CLAUDE.md tokens (exact keys):** `kg.present`, `kg.repo`, `kg.path`, `kg.branch`, `kg.mcp_server`, `kg.search_tool`. Same server name across the `.mcp.json` entry, `enabledMcpjsonServers`, `kg.mcp_server`, and `kg.search_tool`.
- **KG venv/ingest:** Python **3.10+**; ingest command run from `kg.path` is `./.venv/bin/python -m kg_ingest.cli --repo <sources.yml code_repo.path> --tracker --secondary` (auto-embeds the vector sidecar).
- **Load-once caveat:** the MCP server loads the graph at startup, so after any build/refresh, a **Claude Code restart** is required before new results appear. Every relevant skill states this.
- **Validation is mechanical** (per BDS-2): YAML frontmatter parses, JSON examples pass `python3 -m json.tool`, required content greppable, plus a dry-run read-through. No unit tests.
- **Skill frontmatter shape (verbatim):** `name`, `description` (double-quoted, rich in trigger phrases), `metadata:\n  suite: builddown`.
- **New skills are auto-discovered** from `plugin/skills/<name>/SKILL.md` — no registry edit. Adding a new skill dir needs `/reload-plugins` or a Claude Code restart to appear live.

---

### Task 1: `docs/kg-binding.md` — the CLAUDE.md contract (single source of truth)

**Files:**
- Create: `docs/kg-binding.md`

**Interfaces:**
- Produces: the canonical `## Knowledge graph` CLAUDE.md block format, referenced by `bd-project-setup` (writes it), `bd-kg-search` (reads it), and later spec #2 skills.

- [ ] **Step 1: Write `docs/kg-binding.md`**

Content must include: (a) a one-line purpose; (b) the exact block, verbatim:

```md
## Knowledge graph (optional)
- kg.present:     true
- kg.repo:        <owner>/knowledge-graph-<project-slug>   # origin (owner/name)
- kg.path:        ../knowledge-graph-<project-slug>        # local checkout, relative to project root
- kg.branch:      knowledge-graph                          # branch to keep checked out
- kg.mcp_server:  <project-slug>-kg                        # MCP server name in .mcp.json
- kg.search_tool: mcp__<project-slug>-kg__kg_hybrid_search # the ONLY tool skills call
```

(c) semantics: `kg.present: false` or block-absent ⇒ every KG step is a silent no-op; (d) the rule that skills call **only** `kg.search_tool` (hybrid-search), never other KG tools; (e) a one-line pointer that `bd-project-setup` writes this block and `bd-kg-refresh` keeps the graph current.

- [ ] **Step 2: Verify content**

Run:
```bash
cd /Users/johnodwyer/gitRepos/skills
for t in kg.present kg.repo kg.path kg.branch kg.mcp_server kg.search_tool; do grep -q "$t" docs/kg-binding.md && echo "$t ok" || echo "MISSING $t"; done
grep -q "kg_hybrid_search" docs/kg-binding.md && echo "tool ok"
grep -qiE "no-op|silent" docs/kg-binding.md && echo "graceful documented"
```
Expected: all six tokens `ok`, `tool ok`, `graceful documented`.

- [ ] **Step 3: Commit**

```bash
git add docs/kg-binding.md
git commit -m "docs(kg): canonical CLAUDE.md knowledge-graph binding contract"
```

---

### Task 2: `bd-kg-refresh` skill (venv + ingest; first build & refresh)

**Files:**
- Create: `plugin/skills/bd-kg-refresh/SKILL.md`

**Interfaces:**
- Consumes: `kg.path` from the CLAUDE.md block (Task 1).
- Produces: an invocable skill `bd-kg-refresh` that `bd-project-setup` calls in its KG phase (Task 4).

- [ ] **Step 1: Write `plugin/skills/bd-kg-refresh/SKILL.md`**

Frontmatter (verbatim):
```md
---
name: bd-kg-refresh
description: "Build or refresh a project's knowledge graph (KG) so semantic/hybrid search reflects the current code + tracker. Trigger when the user says 'bd-kg-refresh', 'refresh the KG', 'rebuild the knowledge graph', 're-ingest the KG', or after landing work that should be searchable. Ensures the KG repo's Python venv, runs the canonical ingest (which auto-builds the vector index), and reminds that the read-only MCP server reloads the graph only on a Claude Code restart. No-op with a clear message if this project has no KG bound (no `## Knowledge graph` block / kg.present:false)."
metadata:
  suite: builddown
---
```

Body sections (numbered steps in the skill):
1. **Read the binding.** Read CLAUDE.md's `## Knowledge graph` block (format: `docs/kg-binding.md`). If `kg.present` is false or the block is absent → print "This project has no KG bound — run bd-project-setup to add one." and stop.
2. **Ensure the venv.** If `<kg.path>/.venv` is missing: `cd <kg.path> && python3.10 -m venv .venv && ./.venv/bin/pip install -r requirements.txt` (note: py3.10+ required for `mcp`/`fastembed`).
3. **Run the ingest** from `<kg.path>`: `./.venv/bin/python -m kg_ingest.cli --repo <code_repo.path from that repo's sources.yml> --tracker --secondary`. State that this rebuilds `out/graph.trig` and auto-builds the embeddings sidecar, and that the tracker ingest uses the KG repo's own configured tracker key (this skill does not manage secrets).
4. **Report** the printed quad/issue/vector counts and whether `SHACL conforms`. If the run logs `embeddings SKIPPED` (fastembed not installed), surface it and say semantic/hybrid search will be lexical-only until fixed.
5. **Restart reminder.** State that the running KG MCP server loaded the graph at startup, so hybrid-search won't reflect this refresh until a **Claude Code restart**.

- [ ] **Step 2: Verify frontmatter + content**

Run:
```bash
cd /Users/johnodwyer/gitRepos/skills
python3 -c "import yaml,sys; d=yaml.safe_load(open('plugin/skills/bd-kg-refresh/SKILL.md').read().split('---')[1]); assert d['name']=='bd-kg-refresh' and d['metadata']['suite']=='builddown'; print('frontmatter ok')"
grep -q "kg_ingest.cli --repo" plugin/skills/bd-kg-refresh/SKILL.md && echo "ingest cmd ok"
grep -qiE "restart" plugin/skills/bd-kg-refresh/SKILL.md && echo "restart reminder ok"
grep -qiE "no KG|kg.present" plugin/skills/bd-kg-refresh/SKILL.md && echo "graceful ok"
```
Expected: `frontmatter ok`, `ingest cmd ok`, `restart reminder ok`, `graceful ok`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/bd-kg-refresh/SKILL.md
git commit -m "feat(skill): bd-kg-refresh — build/refresh a project's KG (venv + ingest)"
```

---

### Task 3: `bd-kg-search` skill (direct hybrid-search on-ramp)

**Files:**
- Create: `plugin/skills/bd-kg-search/SKILL.md`

**Interfaces:**
- Consumes: `kg.present` and `kg.search_tool` from the CLAUDE.md block (Task 1).
- Produces: an invocable skill `bd-kg-search`.

- [ ] **Step 1: Write `plugin/skills/bd-kg-search/SKILL.md`**

Frontmatter (verbatim):
```md
---
name: bd-kg-search
description: "Search this project's knowledge graph (KG) directly via hybrid search — the fast way to ask what past issues, PRs, decisions, and build-up/build-down learnings already exist, without running a full build-up/build-down session. Trigger when the user says 'bd-kg-search', 'kg search', 'search the KG for …', 'ask the knowledge graph', or asks whether the KG already knows about something. No-op with a clear message if this project has no KG bound."
metadata:
  suite: builddown
---
```

Body sections (numbered steps in the skill):
1. **Read the binding.** Read CLAUDE.md's `## Knowledge graph` block (format: `docs/kg-binding.md`). If `kg.present` is false or absent → print "This project has no KG bound — run bd-project-setup to add one." and stop. No tool call.
2. **Run the search.** Take the user's query text and call **`kg.search_tool`** (the bound `mcp__<slug>__kg_hybrid_search`) with `{query, limit: 10}`. Call **only** that tool — never other KG tools.
3. **Render results,** ranked by `score`: for each hit show `title`, `type`, `score`, `matched_by`, a short `snippet`, and the `iri`. If `degraded: true`, note the vector index wasn't loaded and suggest `bd-kg-refresh` + a restart. If zero results, say so plainly.
4. **Scope note (in the skill):** hybrid-search only — deeper graph walks (neighbors/provenance) exist but are out of scope for this skill. If the user just refreshed, remind that a Claude Code restart is needed before new results appear.

- [ ] **Step 2: Verify frontmatter + content**

Run:
```bash
cd /Users/johnodwyer/gitRepos/skills
python3 -c "import yaml; d=yaml.safe_load(open('plugin/skills/bd-kg-search/SKILL.md').read().split('---')[1]); assert d['name']=='bd-kg-search' and d['metadata']['suite']=='builddown'; print('frontmatter ok')"
grep -q "kg.search_tool" plugin/skills/bd-kg-search/SKILL.md && echo "tool binding ok"
grep -qiE "no KG|kg.present" plugin/skills/bd-kg-search/SKILL.md && echo "graceful ok"
grep -qiE "degraded" plugin/skills/bd-kg-search/SKILL.md && echo "degraded handled"
```
Expected: `frontmatter ok`, `tool binding ok`, `graceful ok`, `degraded handled`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/bd-kg-search/SKILL.md
git commit -m "feat(skill): bd-kg-search — direct KG hybrid-search on-ramp"
```

---

### Task 4: `bd-project-setup` — new Knowledge-graph phase

**Files:**
- Modify: `plugin/skills/bd-project-setup/SKILL.md` (append a new phase after the tracker-wiring phases; do not disturb existing phases)

**Interfaces:**
- Consumes: `docs/kg-binding.md` (Task 1), the `bd-kg-refresh` skill (Task 2).
- Produces: the KG phase that writes the CLAUDE.md block + `.mcp.json` server + pre-approval.

- [ ] **Step 1: Add the "Phase K — Knowledge graph (optional)" section**

Insert a new phase mirroring the existing Phase 0 detect→classify→confirm style. It must contain these steps with this substance:

- **K.1 Detect.** Read the project CLAUDE.md for an existing `## Knowledge graph` block and `.mcp.json` for a `<slug>-kg` server. Classify: *bound & present* / *partially wired* / *not wired* / *deliberately absent*. Report; never clobber.
- **K.2 Decide.** Probe the convention origin `<project-owner>/knowledge-graph-<project-slug>` read-only (`gh repo view <owner>/knowledge-graph-<slug>`). Present the finding; ask the operator to confirm, override the slug, or declare "no KG" → write `kg.present: false` and END the phase.
- **K.3 Bootstrap missing pieces.** (a) if not cloned at `kg.path`: `git clone <origin> <kg.path> && git -C <kg.path> checkout <kg.branch>` (default `knowledge-graph`). (b) if no `<slug>-kg` server in `.mcp.json`: write this entry (absolute paths from `kg.path`):
  ```json
  "<project-slug>-kg": {
    "command": "<abs kg.path>/.venv/bin/python",
    "args": ["-m", "kg_query.server"],
    "cwd": "<abs kg.path>",
    "env": { "KG_BACKEND": "rdflib", "PYTHONPATH": "<abs kg.path>" }
  }
  ```
  and add `"<project-slug>-kg"` to `enabledMcpjsonServers` in `.claude/settings.json`. No OAuth flow.
- **K.4 Build.** Invoke the **`bd-kg-refresh`** skill so the graph + embeddings exist (setup does not duplicate ingest logic).
- **K.5 Bind.** Write/merge the `## Knowledge graph` block into CLAUDE.md per `docs/kg-binding.md`, merging (not clobbering) any existing values.
- **K.6 Restart note.** Tell the operator a Claude Code restart is required before the KG server serves the graph (load-once), same as the tracker "servers load at session start" note.

Also add a one-line entry for `## Knowledge graph` variables to Phase 0's CLAUDE.md-bindings detection table so re-runs detect it.

- [ ] **Step 2: Verify structure + JSON example**

Run:
```bash
cd /Users/johnodwyer/gitRepos/skills
F=plugin/skills/bd-project-setup/SKILL.md
python3 -c "import yaml; d=yaml.safe_load(open('$F').read().split('---')[1]); assert d['name']=='bd-project-setup'; print('frontmatter intact')"
for s in "K.1" "K.2" "K.3" "K.4" "K.5" "K.6"; do grep -q "$s" "$F" && echo "$s ok" || echo "MISSING $s"; done
grep -q "bd-kg-refresh" "$F" && echo "invokes refresh ok"
grep -q "knowledge-graph-" "$F" && echo "discovery convention ok"
grep -q "enabledMcpjsonServers" "$F" && echo "preapprove ok"
# Extract the fenced json server-entry example and validate it as an object:
python3 - <<'PY'
import re,json
t=open('plugin/skills/bd-project-setup/SKILL.md').read()
m=re.search(r'"[a-z0-9-]+-kg":\s*\{.*?\}\s*\}', t, re.S)
assert m, "no kg server json block found"
json.loads("{"+m.group(0)+"}"); print("server json valid")
PY
```
Expected: `frontmatter intact`, `K.1..K.6 ok`, `invokes refresh ok`, `discovery convention ok`, `preapprove ok`, `server json valid`.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/bd-project-setup/SKILL.md
git commit -m "feat(skill): bd-project-setup — optional Knowledge-graph phase (detect, bootstrap, bind)"
```

---

## Self-Review

**1. Spec coverage:**
- CLAUDE.md contract (spec Component 1) → Task 1. ✓
- `bd-project-setup` KG phase K.1–K.6 (Component 2) → Task 4. ✓
- `bd-kg-refresh` (Component 3) → Task 2. ✓
- KG MCP server entry + pre-approval (Component 4) → Task 4 Step 1 K.3. ✓
- `bd-kg-search` (Component 5) → Task 3. ✓
- Discovery convention → Task 4 K.2. ✓
- Graceful degradation → Tasks 1 (semantics), 2, 3 (no-op paths), 4 K.2 (kg.present:false). ✓
- Mechanical verification (BDS-2) → each task's Step 2. ✓
- Non-goals (recon, staleness-delta, KG-into-itself, BDS-32) → not in this plan by design. ✓

**2. Placeholder scan:** No "TBD"/"add error handling"/"similar to Task N". Frontmatter is verbatim; commands are concrete; the JSON entry is spelled out. ✓

**3. Type/name consistency:** `kg.search_tool` / `mcp__<slug>-kg__kg_hybrid_search`, server name `<slug>-kg`, and `bd-kg-refresh` / `bd-kg-search` are used identically across Tasks 1–4. ✓

## Operational note (not a task)

New skill directories are auto-discovered but appear live only after `/reload-plugins` or a Claude Code restart. To exercise `bd-kg-refresh` / `bd-kg-search` in-session after implementation, restart Claude Code once (the local skills repo is already the live plugin source).
