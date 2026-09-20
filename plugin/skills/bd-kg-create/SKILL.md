---
name: bd-kg-create
description: "BUILD a project's knowledge-graph (KG) repo from the BuildDownAI/bd-knowledge-graph-base template — the first step before bd-kg-refresh can build it. Trigger when the user says 'bd-kg-create', 'create a KG', 'build a knowledge graph repo', 'stand up a KG for this project', or when no KG repo exists yet. Creates the repo from the template (gh --template, private), clones it as a sibling, wires the upstream remote, fills sources.yml (namespace, code_repo, trackers), then hands off to bd-kg-refresh (first build) and verifies with session-start. Closes with the KG learnings-loop step."
metadata:
  suite: builddown
  client: claude-code
  claude-code-reason: "clones and edits the KG repo (Step 2 onwards require a local checkout)"
  requires: [github]
---

# BD KG Create Skill

Builds a **new KG repo** for a project from the base template, then routes through
the existing rails (`bd-kg-refresh` to build and verify).
After this skill, the project has a working, queryable KG.

**Needs clone: this skill clones the KG repo and edits it locally (Step 2 and beyond require the checkout).**

## Inputs (gather up front; ask only for what can't be derived)

| Input | Default |
|---|---|
| Project repo | the current project's `owner/name` |
| KG repo name | `knowledge-graph-<project-slug>` |
| Org | the project repo's owner |
| Namespace | `https://kg.<org>.dev/` (convention; confirm with the operator) |
| Tracker | from the project's `CLAUDE.md` (`tracker.kind` + team), if bound |
| Docs URL | two-part ask (BDS-38): (a) "What is the published docs root for this project? Skip if none." (b) for a versioned site (stable/latest areas): "Which docs version/area documents the branch this KG ingests?" — the answer selects the crawl root and is recorded as `documents_branch:` |
| Orchestrator | the orchestrator URL — the app whose projects define scope (confirmed by `get_project_binding` after Step 6 binds it) |
| Visibility | private |

## Steps

1. **Preflight.** If `kg repo view <org>/<kg-name>` finds an existing repo, or if running
   `../bd-shared/session-start.md` returns `kg.present: true` in the binding (i.e. a KG is
   already bound for this project), stop — never create a duplicate (use bd-kg-refresh to
   rebuild an existing KG).

2. **Create from the template.**
   ```bash
   gh repo create <org>/<kg-name> --template BuildDownAI/bd-knowledge-graph-base --private
   gh repo clone <org>/<kg-name> ../<kg-name>
   git -C ../<kg-name> remote add upstream https://github.com/BuildDownAI/bd-knowledge-graph-base.git
   ```
   The sibling path `../<kg-name>` (relative to the project root) is the
   source-repo checkout convention `bd-kg-refresh` expects (the `sourceRepo` binding
   from `get_project_binding` names the origin). The `upstream` remote is how base improvements arrive
   later (`git fetch upstream && git merge upstream/main`) — template copies have
   no fork relationship, and forks of a public base would have to be public.
   Fallback when template access fails: clone the base directly, `git remote
   rename origin upstream`, create the new repo empty, add it as `origin`, push.

3. **Fill `sources.yml`** in the new clone — this is the KG's identity; set it
   once, up front:
   - `namespace:` the confirmed value (changing it later rewrites every IRI)
   - `code_repo:` the project's `slug` + relative `path` (e.g. `../<project>`) +
     `docs_url:` (the collected docs root, when the project has one)
   - `docs_sites:` (when a docs root was given) one entry per site — `url:` (the
     version-area root from the two-part ask), `repo:` (the project slug),
     `documents_branch:` (when versioned) — this is what makes the first refresh
     **crawl** the docs into DocSite/DocPage/DocSection section cards, not just
     stamp a pointer (base how-to: the base repo's `docs/design/docs-sites.md`)
   - `orchestrator:` the app URL — its project list defines this KG's intended
     scope; bd-kg-refresh's reconcile step keeps `sources.yml` converged to it
   - `trackers:` the project's team(s), `tier: primary`
   - `self_ingest: true` (recommended: the KG should know its own internals)
   - optionally add `BuildDownAI/bd-knowledge-graph-base` under `secondary_repos`
     so base design knowledge is searchable from this KG
   Commit and push the configuration.

4. **Wire the orchestrator's server side.** Five ordered sub-steps — 4a and 4b must be
   done before Step 5; 4c–4e describe the sequencing rules and verification criteria
   that Step 5's bd-kg-refresh invocation must satisfy. Do not compress or reorder.

   **4a. GitHub App installation.** The orchestrator's GitHub App must have `contents: read`
   access to the new KG repo before the image build runs — skipping this produces a 422 at
   deploy time. Locate the App ID from the orchestrator's Fly secrets (`GITHUB_APP_ID`) or
   its deployment docs. Navigate to GitHub → the KG repo's org → Settings →
   Third-party Access → GitHub Apps → Configure the orchestrator's App → add the new KG repo
   to the selected-repositories list. If the KG repo's org differs from the orchestrator's
   org, install the App on the KG repo's org first.

   **4b. Set `KG_SOURCE_REPO`.** Point the orchestrator at the new repo:
   ```bash
   fly secrets set KG_SOURCE_REPO=<owner>/<kg-repo-name> --app <orchestrator-app>
   ```
   Set this explicitly — never rely on the default (`BuildDownAI/knowledge-graph-ai-implement`).
   Even before AII-436 removes that default, omitting this causes the orchestrator to silently
   serve the wrong graph after every deploy.

   **4c. Snapshot before deploy (sequencing rule).** Step 5's ingest must commit and push
   the snapshot to the KG repo's default branch **before** triggering the deploy — the image
   build clones that branch, and a deploy against an empty or stale branch serves an empty
   graph with no build error. After Steps 4a and 4b, resolve the orchestrator connector prefix
   via ToolSearch with the query `get_tenant_health`, taking the tool whose name ends in `__get_tenant_health` (session-start has not yet run for a brand-new
   project with no binding — resolve the prefix directly here). Call
   `mcp__<prefix>__get_tenant_health` and confirm the `kgRefreshPreflight` rows show
   `ok: true` for the new repo's GitHub App access row and the `KG_SOURCE_REPO` row — this
   confirms the orchestrator can see the new repo before triggering the deploy (stronger gate
   than a local `git log`). If any preflight row fails, stop and resolve the issue before
   Step 5. If `get_tenant_health` returns no `kgRefreshPreflight` rows (orchestrator predates
   AII-594), note "preflight rows absent — proceeding" and continue. Chaining push and deploy
   in one command lets the remote builder clone the pre-push tree; 4e's unchanged stamp is how
   you find out.

   **4d. The bake deploy.** Step 5 triggers one orchestrator deploy after 4a–4c complete.
   This deploy bakes the KG namespace from `sources.yml` into the image; the namespace cannot
   change at runtime.

   > **Graph-switch-requires-deploy rule.** The refresh rail (`POST /api/kg/refresh`) updates
   > content within the already-baked graph only — re-ingest and re-embed on the same
   > `sources.yml`. It does **not** switch which graph is served. Switching graphs — a
   > different namespace, `sources.yml`, or `KG_SOURCE_REPO` — always requires a new deploy.
   > Deploy-free `POST /api/kg/refresh` applies only to updating the already-baked graph.

   **4e. Real-query verification.** A 401 at `/mcp` or a healthy boot proves nothing about
   graph content. **The signature failure mode is empty-but-healthy:** `degraded: false` with
   zero results — the sidecar booted successfully but ingested the wrong or empty snapshot.
   Step 5 verifies:
   - `kg_hybrid_search` with a domain term returns non-empty, `degraded: false` results, and
   - the graph's **age stamp equals Step 5's ingest stamp** (recon reads it via `kg_neighbors`
     on the spine IRI — `../bd-shared/kg-recon.md`). An unchanged stamp means the deploy served
     the OLD snapshot.

5. **First build + deploy.** Invoke the **`bd-kg-refresh`** skill — its flow is
   ingest → snapshot commit → **orchestrator redeploy** → live verify, so a
   successful refresh ends with the graph queryable from `/mcp`. This skill never
   duplicates ingest or deploy logic.

6. **Verify binding.** Run `../bd-shared/session-start.md`. The orchestrator connector
   (discovered via ToolSearch with the query `get_project_binding`) must now return `kg.present:
   true` for this project's repo slug. If the orchestrator connector is not yet enabled in
   this session, add or enable it at claude.ai connectors, then re-run session-start to
   confirm the binding resolves. Verify with a live search (`mcp__<prefix>__<kg.searchTool>`)
   that the graph is queryable and non-empty.

7. **Close — learnings loop (required check, usually a no-op).** Follow
   `../bd-shared/kg-learnings-loop.md`: if this create surfaced a base-relevant pattern
   (template gap, portability issue, ingest failure), file the sanitized learning
   PR into the base's `testing`. An uneventful create files nothing.

## Notes

- One KG per project repo; the KG is a **sibling repo**, never a subdirectory.
- Never put business data in the base or in learning PRs (sanitization rule in
  the base's `CONTRIBUTING.md`).
- Related: `bd-kg-refresh` (rebuild), `bd-kg-search` (query), `../bd-shared/kg-recon.md`
  (how session skills consult the KG).
