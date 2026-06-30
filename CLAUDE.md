# Project configuration

This repo's skills (bd-build-up, bd-build-down, bd-summit-push, etc.) help a human plan work — decomposing
objectives into issues and driving them. They reference external services through `{{PLACEHOLDER}}`
tokens. This file binds those placeholders to the concrete tools for **this** project.

## Issue tracker — Linear

- **tracker.kind:** `linear`
- **MCP server:** `linear-eudoxus` — this repo's own project-scoped server (`.mcp.json`), endpoint `https://mcp.linear.app/mcp`, pre-approved in `.claude/settings.json`. Named per workspace (not a generic `linear-server`) so its OAuth token stays distinct from other Linear workspaces (e.g. oolidata) and they never steal each other's auth. The `builddown` plugin bundles no MCP servers; this server is for developing the skills repo itself and is not shipped to plugin users.
- **Workspace:** `eudoxus` — bound at authentication time (run `/mcp` and authenticate the `linear-eudoxus` server; choose the Eudoxus workspace in the OAuth grant)
- **Team:** `BDS` — file/list/search issues against this team
- **Team URL:** https://linear.app/eudoxus/team/BDS/overview

When a skill resolves `{{TRACKER}}`, it means the `linear-eudoxus` MCP, Eudoxus workspace, **team BDS**.
New issues and projects created by bd-build-up / bd-mega-build-up go into team BDS unless told otherwise.

## AI-Implement label handoff — testing orchestrator

The skills don't run inside AI-Implement; they file issues that it later picks up. This binds that handoff.

- **`{{IMPLEMENT_LABEL}}`:** `AI-Implement` (the label a finished issue gets so the orchestrator implements it)
- **Pickup target:** AI-Implement **testing** instance (not production) — admin UI at
  `https://ai-implement-testing-orchestrator.fly.dev/admin#projects`
- **Team it polls:** `BDS` — so labeled BDS issues are safe to experiment with; they do not touch the
  production AI-Implement backlog (team AI-Implement / AII-*).
- **Feature-branch grouping behaviour** the skills must respect (parent/child feature nodes, child PRs into
  `ai-implement/feature/<key>`, internal roll-ups vs the top-of-tree human-gate PR): see
  `docs/feature-branch-grouping.md`.

## GitHub repo — `{{REPO}}`

- **`{{REPO}}`:** `BuildDownAI/skills`
- **GitHub MCP:** `github` — add to `.mcp.json` if PR operations are needed (e.g. for bd-build-down runs against this repo's own PRs)

## AI coding agent — `{{AGENT_MENTION}}`

- **`{{AGENT_MENTION}}`:** `/ai-implement` (comment trigger that re-runs Claude Code in gap-fill mode on a PR)
- **`{{CODING_AGENT}}`:** AI-Implement testing instance (same as the handoff target above)

## Plan documents — `{{PLAN_DIR}}`

- **`{{PLAN_DIR}}`:** `docs/superpowers/plans/`

## Build verification — `{{BUILD_CMD}}`

- **`{{BUILD_CMD}}`:** *(not applicable — this repo contains skill definitions and shell scripts only; no compile or test step)*

## Preview deployment — `{{PREVIEW_HOST}}` / `{{AUTH_PROVIDER}}`

- *(not applicable — this repo has no preview deployments; bd-smoke-jumper is not used here)*

## Releasing — ⚠️ bump the plugin version on every skill change

> **Reminder:** the plugin **`version`** is the *only* signal that tells `/plugin update` (and the
> marketplace) to pull new content. `marketplace.json` carries no version — it just sources `./plugin`.

- **Any change to `plugin/skills/**` (or other shipped plugin content) must bump `version` in
  [`plugin/.claude-plugin/plugin.json`](plugin/.claude-plugin/plugin.json) in the *same* PR.** Skip it and
  installs keep serving the stale skills.
- **Minor** (`0.x.0`) for additive / backward-compatible changes; **patch** (`0.0.x`) for fixes and wording.
- Current: **`0.6.0`**.
