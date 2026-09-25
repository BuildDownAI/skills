# Project configuration

The orchestrator and the tracker are claude.ai connectors; the skills resolve this repo's binding from `get_project_binding` at session start.

This repo's skills (bd-build-up, bd-build-down, bd-summit-push, etc.) help a human plan work — decomposing
objectives into issues and driving them. They reference external services through `{{PLACEHOLDER}}`
tokens. This file binds those placeholders to the concrete tools for **this** project.

## AI-Implement label handoff — testing orchestrator

The skills don't run inside AI-Implement; they file issues that it later picks up. This binds that handoff.

- **`{{IMPLEMENT_LABEL}}`:** `AI-Implement` (the label a finished issue gets so the orchestrator implements it; the orchestrator's value wins when the orchestrator MCP is bound)
- **Pickup target:** AI-Implement **testing** instance (not production) — admin UI at
  `https://ai-implement-testing-orchestrator.fly.dev/admin#projects`
- **Team it polls:** `BDS` — so labeled BDS issues are safe to experiment with; they do not touch the
  production AI-Implement backlog (team AI-Implement / AII-*).
- **Feature-branch grouping behaviour** the skills must respect (parent/child feature nodes, child PRs into
  `ai-implement/feature/<key>`, internal roll-ups vs the top-of-tree human-gate PR): see
  `plugin/skills/bd-shared/feature-branch-grouping.md`.

## GitHub repo — `{{REPO}}`

- **`{{REPO}}`:** `BuildDownAI/skills`
- **GitHub MCP:** `github` — add to `.mcp.json` if PR operations are needed (e.g. for bd-build-down runs against this repo's own PRs)

## AI coding agent — `{{AGENT_MENTION}}`

- **`{{AGENT_MENTION}}`:** `/ai-implement` (comment trigger that re-runs Claude Code in gap-fill mode on a PR)
- **`{{CODING_AGENT}}`:** AI-Implement testing instance (same as the handoff target above)

## Decision records — `{{ADR_DIR}}`

- **`{{ADR_DIR}}`:** `docs/adr/` — bd-mega-build-up's grill writes ADRs here, and terminology
  into a root `CONTEXT.md`. These are committed; they are canonical reference, not session
  working notes. (The old `{{PLAN_DIR}}` binding retired with the implementation-plan phase.)

## Skill authoring rule

Every new or changed `SKILL.md` must declare `metadata.client` and `metadata.requires` in its frontmatter and call `../bd-shared/session-start.md` first; a change that moves a step onto the shell, git, a local checkout, or a browser must update the declaration in the same PR (see `docs/adr/0003-every-skill-declares-its-client-and-required-tools.md`). A `description` never contains `<` or `>`; the claude.ai plugin upload rejects it.

## Build verification — `{{BUILD_CMD}}`

- **`{{BUILD_CMD}}`:** *(not applicable — this repo contains skill definitions and shell scripts only; no compile or test step)*

## Preview deployment — `{{PREVIEW_HOST}}` / `{{AUTH_PROVIDER}}`

- *(not applicable — this repo has no preview deployments; bd-smoke-jumper is not used here)*

## Releasing

`testing` and `main` have different jobs. Keep the branch-specific rules below separate.

### On `testing` — where every change lands

- **Any change to `plugin/skills/**` (or other shipped plugin content) must change `version` in
  [`plugin/.claude-plugin/plugin.json`](plugin/.claude-plugin/plugin.json) and in `plugin/skills/bd-shared/VERSION` in the *same* PR.** The plugin
  `version` is the only signal that tells `/plugin update` to pull new content.
- **Compute the new version from `main`, not from the previous `testing` value.** Read `main`'s
  version first (a shallow clone needs the fetch):
  `git fetch origin main --depth=1 && git show origin/main:plugin/.claude-plugin/plugin.json`
  1. **Release target, set once per cycle.** If `testing` still carries `main`'s version, set the
     target: `main` + `0.1.0` for additive or backward-compatible work, `main` + `1.0.0` for a
     breaking change. This happens **once** between releases, however many PRs land. A later
     breaking PR may raise a minor target to the major target (`1.5.x` → `2.0.0`); nothing raises
     the same level twice.
  2. **Patch per PR.** Every later PR that changes shipped content adds `0.0.1`. A PR that touches
     no shipped content leaves the version alone.

  Worked example: `main` is `1.4.0`. The first content PR sets `1.5.0`; the next two set `1.5.1`
  and `1.5.2`; the release is tagged `v1.5.2`. `testing` never reaches `1.6.0` before a release.
- `.claude-plugin/marketplace.json` uses `./plugin` on this branch; it should not be edited on `testing`.

### On `main` — where releases live

- No direct commits: changes arrive by merging `testing`, except for catalog repoint PRs.
- `.claude-plugin/marketplace.json` has two entries. `builddown` pins `git-subdir` `ref` to the release tag. `builddown-dev` uses `ref: testing`.
- Keep the URL explicit: `https://github.com/BuildDownAI/skills.git`.

### Cutting a release

1. Merge `testing` → `main` with a merge commit (no extra version bump commit).
2. Create/push annotated tag `vX.Y.Z`, where `X.Y.Z` is the version `testing` carries at merge time. Publish the GitHub release from that tag.
3. Repoint `main` catalog `ref` to that tag in a `main`-only PR. Change only the `builddown` entry's `ref`; leave `builddown-dev` unchanged.

After merges between `testing` and `main`, verify the catalog file still matches the branch's required mode.
