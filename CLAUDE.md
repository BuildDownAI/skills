# Project configuration

This repo's skills (build-up, build-down, summit-push, etc.) help a human plan work — decomposing
objectives into issues and driving them. They reference external services through `{{PLACEHOLDER}}`
tokens. This file binds those placeholders to the concrete tools for **this** project.

## Issue tracker — Linear

- **tracker.kind:** `linear`
- **MCP server:** `linear` (project-scoped, defined in `.mcp.json`, endpoint `https://mcp.linear.app/mcp`)
- **Workspace:** `eudoxus` — bound at authentication time (run `/mcp` and authenticate the `linear` server; choose the Eudoxus workspace in the OAuth grant)
- **Team:** `BDS` — file/list/search issues against this team
- **Team URL:** https://linear.app/eudoxus/team/BDS/overview

When a skill resolves `{{TRACKER}}`, it means the `linear` MCP, Eudoxus workspace, **team BDS**.
New issues and projects created by build-up / mega-build-up go into team BDS unless told otherwise.

## AI-Implement label handoff — testing orchestrator

The skills don't run inside AI-Implement; they file issues that it later picks up. This binds that handoff.

- **`{{IMPLEMENT_LABEL}}`:** `AI-Implement` (the label a finished issue gets so the orchestrator implements it)
- **Pickup target:** AI-Implement **testing** instance (not production) — admin UI at
  `https://ai-implement-testing-orchestrator.fly.dev/admin#projects`
- **Team it polls:** `BDS` — so labeled BDS issues are safe to experiment with; they do not touch the
  production AI-Implement backlog (team AI-Implement / AII-*).

## GitHub repo — `{{REPO}}`

- **`{{REPO}}`:** `BuildDownAI/skills`
- **GitHub MCP:** `github` — add to `.mcp.json` if PR operations are needed (e.g. for build-down runs against this repo's own PRs)

## AI coding agent — `{{AGENT_MENTION}}`

- **`{{AGENT_MENTION}}`:** `/ai-implement` (comment trigger that re-runs Claude Code in gap-fill mode on a PR)
- **`{{CODING_AGENT}}`:** AI-Implement testing instance (same as the handoff target above)

## Plan documents — `{{PLAN_DIR}}`

- **`{{PLAN_DIR}}`:** `docs/superpowers/plans/`

## Build verification — `{{BUILD_CMD}}`

- **`{{BUILD_CMD}}`:** *(not applicable — this repo contains skill definitions and shell scripts only; no compile or test step)*

## Preview deployment — `{{PREVIEW_HOST}}` / `{{AUTH_PROVIDER}}`

- *(not applicable — this repo has no preview deployments; smoke-jumper is not used here)*
