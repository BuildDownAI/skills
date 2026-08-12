---
name: bd-kg-create
description: "BUILD a project's knowledge-graph (KG) repo from the BuildDownAI/bd-knowledge-graph-base template — the missing first step before bd-project-setup can bind it and bd-kg-refresh can build it. Trigger when the user says 'bd-kg-create', 'create a KG', 'build a knowledge graph repo', 'stand up a KG for this project', or when bd-project-setup's Phase K finds no KG repo and the user wants one. Creates the repo from the template (gh --template, private), clones it as a sibling, wires the upstream remote, fills sources.yml (namespace, code_repo, trackers), then hands off to bd-kg-refresh (first build) and bd-project-setup Phase K (MCP + CLAUDE.md binding). Closes with the KG learnings-loop step."
metadata:
  suite: builddown
---

# BD KG Create Skill

Builds a **new KG repo** for a project from the base template, then routes through
the existing rails (`bd-kg-refresh` to build, `bd-project-setup` Phase K to bind).
After this skill, the project has a working, queryable KG.

## Inputs (gather up front; ask only for what can't be derived)

| Input | Default |
|---|---|
| Project repo | the current project's `owner/name` |
| KG repo name | `knowledge-graph-<project-slug>` |
| Org | the project repo's owner |
| Namespace | `https://kg.<org>.dev/` (convention; confirm with the operator) |
| Tracker | from the project's `CLAUDE.md` (`tracker.kind` + team), if bound |
| Visibility | private |

## Steps

1. **Preflight.** If the project's `CLAUDE.md` already has `kg.present: true`, or
   `gh repo view <org>/<kg-name>` finds an existing repo, stop and point at
   `bd-project-setup` (Phase K binds existing KGs — never create a duplicate).

2. **Create from the template.**
   ```bash
   gh repo create <org>/<kg-name> --template BuildDownAI/bd-knowledge-graph-base --private
   gh repo clone <org>/<kg-name> ../<kg-name>
   git -C ../<kg-name> remote add upstream https://github.com/BuildDownAI/bd-knowledge-graph-base.git
   ```
   The sibling path `../<kg-name>` (relative to the project root) is the
   source-repo checkout convention `bd-kg-refresh` expects (the `kg.source_repo`
   binding names the origin). The `upstream` remote is how base improvements arrive
   later (`git fetch upstream && git merge upstream/main`) — template copies have
   no fork relationship, and forks of a public base would have to be public.
   Fallback when template access fails: clone the base directly, `git remote
   rename origin upstream`, create the new repo empty, add it as `origin`, push.

3. **Fill `sources.yml`** in the new clone — this is the KG's identity; set it
   once, up front:
   - `namespace:` the confirmed value (changing it later rewrites every IRI)
   - `code_repo:` the project's `slug` + relative `path` (e.g. `../<project>`)
   - `trackers:` the project's team(s), `tier: primary`
   - `self_ingest: true` (recommended: the KG should know its own internals)
   - optionally add `BuildDownAI/bd-knowledge-graph-base` under `secondary_repos`
     so base design knowledge is searchable from this KG
   Commit and push the configuration.

4. **Wire the orchestrator's sidecar build.** The KG serves from an orchestrator's
   `/mcp` (AII-324) — the orchestrator's image build must clone THIS repo as its
   sidecar source (see the orchestrator's `Dockerfile` KG clone step and its
   CLAUDE.md "KG sidecar" section; the build secret needs read access to the new
   repo). Without this leg the KG exists but nothing serves it.

5. **First build + deploy.** Invoke the **`bd-kg-refresh`** skill — its flow is
   ingest → snapshot commit → **orchestrator redeploy** → live verify, so a
   successful refresh ends with the graph queryable from `/mcp`. This skill never
   duplicates ingest or deploy logic.

6. **Bind.** Run **`bd-project-setup`'s Phase K**: registers the remote
   `orch-<app-slug>` MCP server (OAuth), pre-approves it, writes the
   `## Knowledge graph` block into the project's `CLAUDE.md` (format:
   `../bd-shared/kg-binding.md`), runs the K.5a redirect-URI preflight, and verifies with
   a real query.

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
