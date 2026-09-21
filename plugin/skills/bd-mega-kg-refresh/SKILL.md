---
name: bd-mega-kg-refresh
description: "Local, interactive KG refresh: interrogate the served graph, propose and test ingest changes with the user, open a PR on the KG repo with manifest/ingest changes, then hand off to bd-kg-refresh (the rail) to produce the snapshot. Trigger when the user says 'bd-mega-kg-refresh', 'change the ingest', 'why is X not in the KG', or 'interactive KG refresh'. Use plain bd-kg-refresh when local iteration is not needed."
metadata:
  suite: builddown
  client: any
  claude-code-phases: [3, 4, 5]
  claude-code-reason: "phases 3–5 edit and push the KG repo from a local checkout"
  requires: [orchestrator, github]
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

1. **Session start.** Run `../bd-shared/session-start.md`; its printed lines open the reply. This resolves the orchestrator
   connector prefix (`<prefix>`), the repo slug, and the full binding (including `kg`).
   Stop with "This project has no KG bound." if `kg.present` is `false` or absent.

   Fields resolved for this skill:

   | Field | Source | Notes |
   |---|---|---|
   | `<prefix>` | session-start step 1 | Orchestrator connector prefix for all `mcp__<prefix>__*` calls |
   | `kg.present` | binding (step 3) | Stop if `false` or absent |
   | `orchestratorUrl` | binding (step 3) `kg` | Orchestrator URL for the rail handoff |
   | `kg.sourceRepo` | binding (step 3) | The KG source repo (`owner/name`) |
   | `mcp__<prefix>__<kg.searchTool>` | prefix + binding `kg.searchTool` | Orchestrator hybrid-search tool (the resolved composite name) |

2. **Check your role.** Before any orchestrator call, confirm the session has admin access.
   - Use ToolSearch to check whether `mcp__<prefix>__get_session_identity` is in the
     session's tool list. If the tool is absent:
     - Print: "This orchestrator has no `get_session_identity` tool; it predates the MCP write
       tier ([AII-381](https://linear.app/eudoxus/issue/AII-381/mcp-declared-write-list-with-a-role-per-tool-get-session-identity-and)).
       Update the orchestrator, then retry."
     - Stop.
   - Call `mcp__<prefix>__get_session_identity`. Apply `../bd-shared/orchestrator-auth.md`
     (expiry warning; 401 recovery applies to every subsequent orchestrator call in this skill,
     across all phases).
     Read `role` from the result. If `role` is not `admin`:
     - Print: "This skill needs an admin account on the orchestrator. Your MCP session is signed
       in as `<email>` with role `<role>`. Ask an admin to change your allowlist entry, or ask
       them to run the refresh."
     - Stop.

3. **Establish the KG source checkout.** This skill runs in the KG source checkout. Confirm
   the working directory contains `sources.yml` and the Python ingest package. If the checkout
   does not exist locally:
   - Clone: `gh repo clone <sourceRepo> <local-path>`
   - Set up the venv and install dependencies:
     ```bash
     cd <local-path>
     ./setup.sh
     ```
   - Announce: "KG checkout ready at `<local-path>`."

4. **Orient.** Read `sources.yml` — list every `code_repo`, `secondary_repos` entry, `docs_sites`,
   classifier rules, and namespace. State counts: "N sources, M docs sites, classifier has K
   rules." This is the baseline for Phase 3 decisions.

5. **Check upstream base drift.** Call `mcp__<prefix>__get_tenant_health` and read the
   `base:drift` row to determine how far the derivative has drifted from the base template.

   1. If `get_tenant_health` returns a row with type `base:drift`, print the row's value and
      its `hint` field (when present). Carry the drift count forward to Q0 in Phase 3.
   2. If no `base:drift` row is present, print: "base drift unknown — this orchestrator
      predates [AII-598](https://linear.app/eudoxus/issue/AII-598/kg-refresh-preflight-advisory-basedrift-row-how-far-the-kg-repo-is);
      upgrade the orchestrator to obtain the `base:drift` advisory row." and continue.

   Advisory only — the drift count is used by Q0 in Phase 3 to decide whether to offer the
   upstream merge flow. Do not run `git merge upstream`, do not create a `kg-upstream/` branch,
   and do not open any PR in this step.

---

### Phase 2 — Interrogate the served graph

Goal: understand what the graph currently contains and what is missing, stale, or wrong.

1. **Read the spine stamp.** Call `kg_neighbors` on the spine IRI (as defined in
   `../bd-shared/kg-recon.md`) via `mcp__<prefix>__kg_neighbors`. Record the
   `dcterms:modified` stamp and per-part triple counts. Announce:
   "Served graph as of `<stamp>`. Parts: `<counts>`."

2. **Run 3–5 hybrid searches.** Derive search terms from:
   - The user's named topics (ask: "What concepts or recent tracker activity should I search
     for?"), or
   - Recent tracker or PR activity from `mcp__<prefix>__list_projects`.

   For each search: call `mcp__<prefix>__<searchTool>` (the resolved search tool from
   Step 1) with the term. Record what was found and what was absent.

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

**Needs clone: this phase edits and pushes the KG repo.** Run `../bd-shared/session-start.md` step 0 — if in a chat session, it prints the needs-Claude-Code line and stops.

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
last merge (N comes from the Phase 1 Step 5 drift count). Should those changes be merged now
before adjusting the ingest manifest?

**Options:**
- **Merge now** — resolves the base URL, fetches upstream, produces a grouped commit summary,
  creates branch `kg-upstream/<YYYY-MM-DD>`, merges `upstream/main`, runs the Phase 4 fast loop
  and proof loop, then opens a `kg-upstream` PR before continuing to Q3.
- **Skip** — proceed directly to Q3; the upstream drift remains unaddressed this session.

➡️ Merge now when N > 0 — base changes may include accepted learnings, classifier updates, KGB
marker list changes, or ingest improvements that affect this refresh. Skip only when N = 0 or
you explicitly defer to a later session.

**On yes — upstream merge flow:**

1. **Resolve the base URL, set up the upstream remote, and fetch.** Read `sources.yml` for a
   `base_repo:` field. If present, use that value; otherwise fall back to
   `https://github.com/BuildDownAI/bd-knowledge-graph-base.git`. Ensure the remote exists
   (idempotent) and fetch:
   ```bash
   git remote get-url upstream 2>/dev/null || git remote add upstream <base-url>
   git fetch upstream
   ```
   Then run `git log --oneline HEAD..upstream/main` and group commits by path prefix.
   *(Note: `upstream/main` is the hardcoded base target; [BDS-54](https://linear.app/eudoxus/issue/BDS-54/bd-kg-refresh-and-bd-mega-kg-refresh-track-the-base-branch-from) will replace it with the value from `sources.yml base_repo.branch`.)*

   | Bucket | Path prefix |
   |---|---|
   | Learnings | `learnings/` |
   | Ingest | `kg_ingest/` |
   | Query / serve | `kg_query/` |
   | Ontology and shapes | `ontology/`, `shapes/` |
   | Docs | `docs/`, `README` |
   | Other | *(everything else)* |

   Omit any bucket with no commits. If no commits fall into a recognised bucket, show the full
   raw `--oneline` log. This grouped summary is used in the PR body (step 6 below).

2. Create the branch from the derivative's current default branch:
   ```bash
   git checkout -b kg-upstream/<YYYY-MM-DD>
   ```

3. Merge:
   ```bash
   git merge upstream/main
   ```

4. **If there are conflicts:** Run `git status` to list every conflicting file. Stop with:
   > "Merge conflicts in: `<file-list>`. Resolve these by hand, then run
   > `git merge --continue`. **Never resolve `sources.yml` or `snapshot/` conflicts by taking
   > the upstream version** — `sources.yml` encodes this derivative's scope and must not be
   > overwritten with the base template's example project; `snapshot/` is the rail's output
   > and must never be staged."
   Do not auto-resolve any conflict.

5. **On clean merge:** Run the full Phase 4 fast loop and then the proof loop on the
   `kg-upstream/<YYYY-MM-DD>` branch exactly as described in Phase 4. `snapshot/` is never
   staged at any point.

6. **Open the upstream PR** (Phase 5 flow, adapted for this branch):
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
   - Open PR (body must include the `### Guard table` section from the Phase 4 dry-run):
     ```bash
     gh pr create --repo <sourceRepo> \
       --base <default-branch> \
       --title "kg-upstream: merge base <short-sha> (<N> commits)" \
       --body "$(cat <<'EOF'
     <grouped base-change summary from step 1 above>

     ### Guard table

     <paste lastRefresh.partTable verbatim from the Phase 4 dry-run>

     **Verdict:** <passed | refused | current | failed — and if refused, which part and whether the delta predicted it>
EOF
     )"
     ```
     The Phase 4 gate rule applies here exactly as for the ingest PR: the dry-run verdict must
     be `passed`, **or** `refused` only on a part the settled Snapshot delta predicted. A
     `refused` row the delta did not predict sends the session back to the fast loop before this
     PR is opened.
   - Post the learnings comment on the PR:
     ```
     # ai-implement-kg-refresh-learnings

     **What changed:** Merged N commits from upstream base template (<short-sha>).
     **Why:** <grouped summary of base changes: learnings, ingest, classifier, ontology, docs>
     **What the user rejected:** n/a (upstream merge)
     **Guard table:** <verdict>; accept-new-baseline needed: yes/no
     ```

7. **Wait for merge.** Announce the PR URL, then say:
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

**Needs clone: this phase edits and pushes the KG repo.** Run `../bd-shared/session-start.md` step 0 — if in a chat session, it prints the needs-Claude-Code line and stops.

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

Goal: prove the changes pass the rail's own dry-run before opening a PR.

1. **Push the working branch.** Push the current branch (`kg-upstream/<date>` or
   `kg-ingest/<date>-<slug>`) to origin:
   ```bash
   git push -u origin <branch>
   ```

2. **Trigger the dry-run.**

   > **No `ref` parameter.** `trigger_kg_refresh` accepts `dryRun` and `acceptNewBaseline`
   > only (checked against the live schema 2026-09-21). The rail dry-run runs the KG repo's
   > default branch and cannot prove an unmerged branch. AII-633 landed the branch proof as a
   > PR-triggered required check on the KG repo, not as a `ref` argument. For the proof loop on
   > an unmerged branch, use the offline harness path below and say so under `### Guard table`
   > in the PR body; use the rail dry-run to prove the default branch after merge.

   Call:
   ```
   mcp__<prefix>__trigger_kg_refresh { dryRun: true }
   ```
   The dry-run runs the same job as a live refresh but does **not** write to `snapshot/`.
   Record the time of this call as the trigger time.

3. **Poll to a terminal state.** Call `mcp__<prefix>__get_kg_status` every 60 s.
   Stop when all three conditions hold:
   - `running === false`
   - `lastRefresh.dryRun === true`
   - `lastRefresh.at` is later than the trigger time

4. **Read the verdict and Guard table.** From `get_kg_status`, read:
   - `lastRefresh.ok` — `true` for guard passed or graph-is-current; `false` for refused or failed.
   - `lastRefresh.detail` — the detail string; derive the verdict:
     - `passed` — detail starts with `dry-run: guard passed`
     - `refused` — detail starts with `dry-run: guard refused`
     - `current` — detail is `dry-run: graph is current — no new data to check` (ok: true, benign)
     - `failed` — anything else (runner failed before the guard; read `detail` for the reason)
   - `lastRefresh.partTable` — array of `{ part, prev, new }` (absent when the run failed before
     the guard); paste verbatim under `### Guard table` in the PR body.

   Apply the gate rule below.

**Gate rule — Guard table:** The verdict (derived from `lastRefresh.detail`) must be `passed` or
`current`, **or** `refused` only on a part that the settled Snapshot delta (agreed in Phase 3)
predicted would shrink or change. A `failed` verdict is not a guard result — read `lastRefresh.detail`
for the reason and return to the fast loop.
Paste `lastRefresh.partTable` verbatim under `### Guard table` in the PR body.
A `refused` row on a part the delta did **not** predict sends the session back to the fast loop.
Do not open a PR until the gate rule is satisfied.

> **Without network (offline alternative):** If the orchestrator MCP is unreachable, use the
> local harness instead. Obtain `td.json` (the request body of
> `POST /api/runner/kg-tracker-data` for one team — ask an orchestrator admin to export it; do
> not invent or synthesise a substitute). Run from the AI-Implement project root:
> ```bash
> npm run dev:run -- --phase kg-refresh --workspace <kg checkout> --tracker-data td.json
> ```
> This runs the same guard check locally. Inspect the guard table in the output and apply the
> same gate rule. The harness path does not require pushing the branch first.

---

### Phase 5 — PR the change

**Needs clone: this phase edits and pushes the KG repo.** Run `../bd-shared/session-start.md` step 0 — if in a chat session, it prints the needs-Claude-Code line and stops.

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

4. **Open the PR** against the KG repo's default branch (body must include the `### Guard table`
   section from the Phase 4 dry-run):
   ```bash
   gh pr create --repo <sourceRepo> \
     --base <default-branch> \
     --title "kg-ingest: <short description>" \
     --body "$(cat <<'EOF'
   <summary of what changed and why, referencing the Phase 2 gap table>

   ### Guard table

   <paste lastRefresh.partTable verbatim from the Phase 4 dry-run>

   **Verdict:** <passed | refused | current | failed — and if refused, which part and whether the delta predicted it>
EOF
   )"
   ```

   The gate rule from Phase 4 applies: the dry-run verdict must be `passed`, **or** `refused` only on a part the settled Snapshot delta predicted. A `refused` row the delta did not predict sends the session back to the fast loop before this PR is opened.

5. **Post the learnings comment** on the PR:
   ```
   # ai-implement-kg-refresh-learnings

   **What changed:** <list of manifest/ingest changes made>
   **Why:** <root cause from the gap table — what was missing, stale, or mis-classified>
   **What the user rejected:** <any Phase 3 option the user declined, with their reason>
   **Guard table:** <verdict>; accept-new-baseline needed: yes/no
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

   If the Phase 4 Guard table recorded a `refused` row on a predicted tracker-file shrink, state
   this finding when invoking bd-kg-refresh: e.g. "The Phase 4 dry-run Guard table showed a
   refused row for part `<part>` — this was a predicted tracker-file shrink." bd-kg-refresh's
   regression branch (a BDS child issue) offers the accept-new-baseline flow for this case.

3. **Report the served stamp.** After bd-kg-refresh completes, read the `servedStamp` it
   reports. Announce: "Rail complete. Served graph as of `<stamp>`."
   - If `mcp__<prefix>__get_kg_status` is available (AII-595), use it to confirm the
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
- Phase 4's offline harness (`npm run dev:run`) must be run from the AI-Implement project root
  (the directory containing `package.json` with the `dev:run` script), not from the KG checkout.
  The primary network path (MCP dry-run) has no such constraint.
- Admin-only skill, same rule as bd-kg-refresh.
