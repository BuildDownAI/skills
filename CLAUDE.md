# Project configuration

This repo's skills (bd-build-up, bd-build-down, bd-summit-push, etc.) help a human plan work — decomposing
objectives into issues and driving them. They reference external services through `{{PLACEHOLDER}}`
tokens. This file binds those placeholders to the concrete tools for **this** project.

## Issue tracker — Linear

- **MCP server:** `linear` (project-scoped, defined in `.mcp.json`, endpoint `https://mcp.linear.app/mcp`)
- **Workspace:** `eudoxus` — bound at authentication time (run `/mcp` and authenticate the `linear` server; choose the Eudoxus workspace in the OAuth grant)
- **Team:** `BDS` — file/list/search issues against this team
- **Team URL:** https://linear.app/eudoxus/team/BDS/overview

When a skill resolves `{{TRACKER}}`, it means the `linear` MCP, Eudoxus workspace, **team BDS**.
New issues and projects created by bd-build-up / bd-mega-build-up go into team BDS unless told otherwise.

## AI-Implement label handoff — testing orchestrator

The skills don't run inside AI-Implement; they file issues that it later picks up. This binds that handoff.

- **`{{IMPLEMENT_LABEL}}`:** `AI-Implement` (the label a finished issue gets so the orchestrator implements it)
- **Pickup target:** AI-Implement **testing** instance (not production) — admin UI at
  `https://ai-implement-testing-orchestrator.fly.dev/admin#projects`
- **Team it polls:** `BDS` — so labeled BDS issues are safe to experiment with; they do not touch the
  production AI-Implement backlog (team AI-Implement / AII-*).

<!-- TODO (next pass): bind the remaining placeholders at project level —
     {{REPO}} (GitHub MCP), {{PREVIEW_HOST}}, {{CODING_AGENT}}/{{AGENT_MENTION}},
     {{BUILD_CMD}}, {{PLAN_DIR}}, {{AUTH_PROVIDER}}. -->
