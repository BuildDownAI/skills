---
name: bd-mega-kg-refresh
description: "Local, interactive KG refresh: interrogate the served graph, propose and test ingest changes with the user, open a PR on the KG repo with manifest/ingest changes, then hand off to bd-kg-refresh (the rail) to produce the snapshot. Trigger when the user says 'bd-mega-kg-refresh', 'change the ingest', 'why is X not in the KG', or 'interactive KG refresh'. Use plain bd-kg-refresh when local iteration is not needed."
metadata:
  suite: builddown
---

# bd-mega-kg-refresh Skill

Local, interactive KG refresh running in the KG source checkout. Reads the served graph,
proposes ingest changes with the user one decision at a time, proves them locally, opens a PR
on the KG repo with only manifest/ingest changes, then hands off to the rail (bd-kg-refresh)
to produce and serve the snapshot.

**One rule above all:** the laptop never pushes `snapshot/`. The only pushes this skill makes
are manifest/ingest changes on a `kg-ingest/*` branch through a PR.

## Steps

### Phase 1 — Bind and orient

1. **Read the binding.** Open `CLAUDE.md` → `## Knowledge graph` block (format:
   `../bd-shared/kg-binding.md`). Parse all fields:

   | Field | Required for this skill | Notes |
   |---|---|---|
   | `kg.present` | required | Stop with "This project has no KG bound" if `false` or absent |
   | `kg.source_repo` | required | The KG source repo (`owner/name`) |
   | `kg.orchestrator` | required | Orchestrator URL for the rail handoff |
   | `kg.mcp_server` | required | Remote orchestrator MCP server name |
   | `kg.search_tool` | required | Orchestrator hybrid-search tool |

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

3. **Establish the KG source checkout.** This skill runs in the KG source checkout. Confirm
   the working directory contains `sources.yml` and the Python ingest package. If the checkout
   does not exist locally:
   - Clone: `gh repo clone <kg.source_repo> <local-path>`
   - Set up the venv and install dependencies:
     ```bash
     cd <local-path>
     ./setup.sh
     ```
   - Announce: "KG checkout ready at `<local-path>`."

4. **Orient.** Read `sources.yml` — list every `code_repo`, `secondary_repos` entry, `docs_sites`,
   classifier rules, and namespace. State counts: "N sources, M docs sites, classifier has K
   rules." This is the baseline for Phase 3 decisions.

5. **Check upstream base drift.** Determine how far the derivative has drifted from the base
   template before touching the manifest.

   a. **Resolve the base URL.** Read `sources.yml` for a `base_repo:` field. If present, use
      that value. Otherwise fall back to `https://github.com/BuildDownAI/bd-knowledge-graph-base.git`.

   b. **Ensure the remote exists (idempotent):**
      ```bash
      git remote get-url upstream 2>/dev/null || git remote add upstream <base-url>
      ```

   c. **Fetch:**
      ```bash
      git fetch upstream
      ```

   d. **Count drift:**
      ```bash
      git rev-list --count HEAD..upstream/main
      ```

   e. **Announce:**
      - If N = 0: "Derivative is current with base — no upstream commits to merge."
      - If N > 0: "Derivative is **N commits behind base.**"

      When N > 0, run `git log --oneline HEAD..upstream/main` and group commits by path prefix:

      | Bucket | Path prefix |
      |---|---|
      | Learnings | `learnings/` |
      | Ingest | `kg_ingest/` |
      | Query / serve | `kg_query/` |
      | Ontology and shapes | `ontology/`, `shapes/` |
      | Docs | `docs/`, `README` |
      | Other | *(everything else)* |

      Omit any bucket with no commits. If no commits fall into a recognised bucket, show the
      full raw `--oneline` log. This grouped summary is carried forward to Q0 in Phase 3 and
      to the PR body when the merge is accepted.

---

### Phase 2 — Interrogate the served graph

Goal: understand what the graph currently contains and what is missing, stale, or wrong.

1. **Read the spine stamp.** Call `kg_neighbors` on the spine IRI (as defined in
   `../bd-shared/kg-recon.md`) via `mcp__<kg.mcp_server>__kg_neighbors`. Record the
   `dcterms:modified` stamp and per-part triple counts. Announce:
   "Served graph as of `<stamp>`. Parts: `<counts>`."

2. **Run 3–5 hybrid searches.** Derive search terms from:
   - The user's named topics (ask: "What concepts or recent tracker activity should I search
     for?"), or
   - Recent tracker or PR activity from `mcp__<kg.mcp_server>__list_projects`.

   For each search: call `mcp__<kg.mcp_server>__<kg.search_tool>` (i.e., `kg.search_tool` =
   `mcp__<kg.mcp_server>__kg_hybrid_search`) with the term. Record what was found and what
   was absent.

3. **Produce a gap table.** Synthesize the searches and spine inspection into one table:

   | Source | Expected | Found |
   |---|---|---|
   | `<repo or docs site>` | `<what should be there>` | `<what the graph returned>` |

   Include every source in `sources.yml`. Mark each as: ✓ present, ⚠ stale or thin,
   ✗ absent. Add a "not in sources.yml" row for any topic the user names that has no source entry.
   Mark any repo or team that appears in the orchestrator's project list but not in `sources.yml`
   as "rail will add" — the rail's reconcile step handles those automatically.

---

### Phase 3 — Propose ingest changes with the user

Work through the gap table from Phase 2. Gather the facts (read `sources.yml`, the ingest code,
the served graph) first — each question gives the user a single decision.

Format each question exactly:

```
❓ **Q{n}** — **{Decision title}**: {Question in STE. One decision. Name each option and what
it does. State each trade-off as a concrete outcome, not a category.}

➡️ {Recommended answer, stated plainly, with the reason in its own sentence.}
```

Facts are the skill's job — read the code and the manifest before each question. Never ask the
user something the code already answers.

**Decision domains — one question per domain that the gap table flags:**

❓ **Q0** — **Upstream base merge**: The base template has N new commits since this derivative's
last merge (see Phase 1 drift summary). Should those changes be merged now before adjusting the
ingest manifest?

**Options:**
- **Merge now** — creates branch `kg-upstream/<YYYY-MM-DD>`, merges `upstream/main`, runs the
  Phase 4 fast loop and proof loop, then opens a `kg-upstream` PR before continuing to Q3.
- **Skip** — proceed directly to Q3; the upstream drift remains unaddressed this session.

➡️ Merge now when N > 0 — base changes may include accepted learnings, classifier updates, KGB
marker list changes, or ingest improvements that affect this refresh. Skip only when N = 0 or
you explicitly defer to a later session.

**On yes — upstream merge flow:**

1. Create the branch from the derivative's current default branch:
   ```bash
   git checkout -b kg-upstream/<YYYY-MM-DD>
   ```

2. Merge:
   ```bash
   git merge upstream/main
   ```

3. **If there are conflicts:** Run `git status` to list every conflicting file. Stop with:
   > "Merge conflicts in: `<file-list>`. Resolve these by hand, then run
   > `git merge --continue`. **Never resolve `sources.yml` or `snapshot/` conflicts by taking
   > the upstream version** — `sources.yml` encodes this derivative's scope and must not be
   > overwritten with the base template's example project; `snapshot/` is the rail's output
   > and must never be staged."
   Do not auto-resolve any conflict.

4. **On clean merge:** Run the full Phase 4 fast loop and then the proof loop on the
   `kg-upstream/<YYYY-MM-DD>` branch exactly as described in Phase 4. `snapshot/` is never
   staged at any point.

5. **Open the upstream PR** (Phase 5 flow, adapted for this branch):
   - Capture the short SHA of `upstream/main`:
     ```bash
     git rev-parse --short upstream/main
     ```
   - Stage only the files the merge changed — never `snapshot/`:
     ```bash
     git add <merged files — never snapshot/>
     # NEVER: git add snapshot/
     # NEVER: git add .
     ```
   - Commit and push:
     ```bash
     git commit -m "kg-upstream: merge base <short-sha> (<N> commits)"
     git push -u origin kg-upstream/<YYYY-MM-DD>
     ```
   - Open PR:
     ```bash
     gh pr create --repo <kg.source_repo> \
       --base <default-branch> \
       --title "kg-upstream: merge base <short-sha> (<N> commits)" \
       --body "<grouped base-change summary from Phase 1 drift analysis>"
     ```
   - Post the learnings comment on the PR:
     ```
     # ai-implement-kg-refresh-learnings

     **What changed:** Merged N commits from upstream base template (<short-sha>).
     **Why:** <grouped summary of base changes: learnings, ingest, classifier, ontology, docs>
     **What the user rejected:** n/a (upstream merge)
     ```

6. **Wait for merge.** Announce the PR URL, then say:
   > "Merge the `kg-upstream/<YYYY-MM-DD>` PR, then confirm here. After it merges, run
   > `git pull` on the default branch so Q3–Q5 decisions are based on the post-merge state."
   Do not continue to Q3 until the user confirms the upstream PR is merged.

**On no / skip:** Proceed directly to Q3 with no further reference to the upstream merge in
this session.

---

❓ **Q3** — **Docs sites**: For each repo that lacks a `docs_url` but has published docs, should
a docs site entry be added? Versioned docs sites need `documents_branch:` to pin which area
the ingest targets.

➡️ Add docs sites for repos with published docs; skip repos with only inline README docs.

---

❓ **Q4** — **Classifier rules**: Does the gap table show learning or decision content being
missed or mis-classified? Should classifier rules be added, tightened, or broadened?

➡️ Tighten rules that produce noise; broaden rules that miss content the user names as
important. Read the classifier code before recommending specifics.

---

❓ **Q5** — **Namespace**: Is the KG namespace in `sources.yml` still correct for the project's
current identifier scheme? A namespace change requires re-minting all IRIs — propose only if
the existing namespace is actively wrong.

➡️ Keep the existing namespace unless the user confirms that IRI stability is not a concern.

---

After all decisions are settled, summarize the agreed changes: "I will make these changes to
`sources.yml` and related files: `<list>`. Proceeding to Phase 4."

---

### Phase 4 — Test locally

Two loops, in order. The proof loop is the gate before Phase 5.

#### Fast loop — iterate quickly

Goal: verify that the manifest changes produce a graph that answers the Phase 2 gaps.

1. Apply the agreed changes to `sources.yml` and any classifier/ingest config files.

2. Run the ingest — this rebuilds `out/graph.trig` and the vector index in one pass:
   ```bash
   cd <kg checkout>
   ./setup.sh --tracker --secondary
   ```
   Check that `out/graph.trig` is non-empty.

3. Query the rebuilt local graph using the checkout's CLI:
   ```bash
   ./.venv/bin/kg-query search --hybrid "<term>"
   ```
   Run one query per Phase 2 search term. For the spine-stamp lookup use:
   ```bash
   ./.venv/bin/kg-query --neighbors <iri>
   ```
   Confirm that gaps marked ✗ or ⚠ are now ✓.

4. **Repeat** the fast loop for each round of changes until the gap table is clean. Do not
   proceed to the proof loop while any expected source is still ✗ in the local graph.

#### Proof loop — the PR gate

Goal: prove the changes pass the harness dry-run before opening a PR.

1. **Obtain `td.json`.** `td.json` is the request body of `POST /api/runner/kg-tracker-data`
   for one team — the tracker data the rail uses as ingest input. Until AII-597 ships an admin
   export route (`GET /api/kg/tracker-data?team=<key>`), ask an orchestrator admin to provide
   the file. Do not invent or synthesize a substitute.

2. Run the harness dry-run from the AI-Implement project root:
   ```bash
   npm run dev:run -- --phase kg-refresh --workspace <kg checkout> --tracker-data td.json
   ```
   This runs the clone, secondary, ingest steps and the snapshot guard in dry-run — it does
   **not** write to `snapshot/`.

3. Inspect the guard table in the dry-run output. It must be **clean** (no rows marked
   failed or degraded) before Phase 5 runs. If any guard row fails:
   - Read the failure detail.
   - Return to the fast loop to address the root cause.
   - Re-run the proof loop.

**The proof loop guard table must be clean. Do not open a PR until it is.**

---

### Phase 5 — PR the change

Branch, commit only the manifest/ingest changes, open the PR, post the learnings comment.

1. **Branch.** In the KG source checkout:
   ```bash
   git checkout -b kg-ingest/<date>-<slug>
   ```
   where `<date>` is `YYYY-MM-DD` (today) and `<slug>` is a 2–4 word kebab-case summary of
   the changes (e.g. `add-acme-docs-site`, `fix-classifier-decision-rule`).

2. **Stage by path — never snapshot/.** Add only the files the agreed changes touch:
   ```bash
   git add sources.yml
   git add <any changed classifier or ingest config files>
   # NEVER: git add snapshot/  — never stage anything under snapshot/
   # NEVER: git add .          — never glob-add the working tree
   ```
   If `git status` shows any changes under `snapshot/`, do not stage them. They must not
   appear in the PR. This is a hard rule: `snapshot/` is the rail's output, never the
   laptop's commit.

3. **Commit and push:**
   ```bash
   git commit -m "kg-ingest: <short description of changes>"
   git push -u origin kg-ingest/<date>-<slug>
   ```

4. **Open the PR** against the KG repo's default branch:
   ```bash
   gh pr create --repo <kg.source_repo> \
     --base <default-branch> \
     --title "kg-ingest: <short description>" \
     --body "<summary of what changed and why, referencing the Phase 2 gap table>"
   ```

5. **Post the learnings comment** on the PR:
   ```
   # ai-implement-kg-refresh-learnings

   **What changed:** <list of manifest/ingest changes made>
   **Why:** <root cause from the gap table — what was missing, stale, or mis-classified>
   **What the user rejected:** <any Phase 3 option the user declined, with their reason>
   ```
   The marker `# ai-implement-kg-refresh-learnings` must be the exact first line of this
   comment. This is the marker that `../bd-shared/kg-learnings-loop.md` reads back in Phase 7.

6. Announce the PR URL and ask the user to review and merge it.

---

### Phase 6 — Hand off to bd-kg-refresh

Wait for the user to confirm the ingest PR is merged. Do not trigger the rail before the PR
merges — the rail clones the KG source repo and will pick up merged changes only.

1. **Wait for merge.** Ask: "Tell me when the `kg-ingest/<date>-<slug>` PR is merged and I
   will continue." Do not poll GitHub; wait for the user's confirmation.

2. **Run bd-kg-refresh.** After the user confirms, invoke bd-kg-refresh. It will:
   - Preflight the orchestrator.
   - Report scope (the rail adds any missing repos or teams automatically).
   - Trigger the rail through the `trigger_kg_refresh` MCP tool.
   - Poll the five rail stages to serving.
   - Verify the live graph.

3. **Report the served stamp.** After bd-kg-refresh completes, read the `servedStamp` it
   reports. Announce: "Rail complete. Served graph as of `<stamp>`."
   - If `mcp__<kg.mcp_server>__get_kg_status` is available (AII-595), use it to confirm the
     stamp. If it is not available, the stamp from bd-kg-refresh's poll output is sufficient.

---

### Phase 7 — Learnings loop

Follow `../bd-shared/kg-learnings-loop.md`.

The upstream base merge (`kg-upstream/<date>` PR) is not a derivative learning; nothing is
filed to the base-note for it.

**Additional inputs:** After bd-kg-refresh completes, find the refresh PR the rail opened
(title: `kg-refresh: snapshot @ <stamp>`) and read two items from it:

1. **`### Scope` section (AII-607):** The rail writes a `### Scope` section into the refresh
   PR listing any repos or teams it added to `sources.yml` on this run. Read it and include the
   delta as additional context for the learnings loop. If the Scope section is absent (rail
   predates AII-607), note its absence and proceed — this is not an error.

2. **`# ai-implement-kg-refresh-learnings` comment (AII-596):** If a comment with this exact
   marker is present on that PR, read it and use it as additional input to the base-note
   decision alongside the ingest report from Phase 5. If no such comment is present (uneventful
   run or rail predates AII-596), proceed without it — this is normal, not an error.

An uneventful refresh with no learnings comment and no base-relevant patterns files nothing.
This step is advisory and never blocks.

---

## Notes

- **The laptop never pushes `snapshot/`.** The only pushes this skill makes are
  `sources.yml`, classifier rules, docs-site entries, and namespace changes on a
  `kg-ingest/<date>-<slug>` branch through a PR. The rail (bd-kg-refresh) produces the
  snapshot.
- **bd-kg-refresh** handles the orchestrator rail (preflight, trigger, poll, verify). This
  skill owns the ingest iteration; bd-kg-refresh owns the snapshot production.
- The binding format is canonical across all KG-aware skills (see `../bd-shared/kg-binding.md`).
- Phase 4's proof-loop command must be run from the AI-Implement project root (the directory
  containing `package.json` with the `dev:run` script), not from the KG checkout.
- Admin-only skill, same rule as bd-kg-refresh.
