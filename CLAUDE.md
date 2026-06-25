# BuildDownAI Skills — eudoxus/BDS

## Project Context

This is the BuildDownAI skills repository — a collection of Claude Code skills that orchestrate the [AI-Implement](https://github.com/BuildDownAI/AI-Implement) pipeline from the human/PM side. Skills handle planning issues, optimizing batches, driving PRs to merge, and smoke-testing previews.

The `eudoxus/BDS` Linear project tracks development of the skills repo itself.

## BuildDownAI Configuration

- **Tracker:** Linear — project `BDS`
- **Repo:** `BuildDownAI/skills`
- **AI-Implement label:** `AI-Implement`
- **Build command:** `echo "no build step"` (this repo is markdown-only)
- **Preview deploys:** not applicable
- **Architect:** single-operator — escalate to user
- **Agent mention:** `@claude`

## Stack

- Markdown skill files (no compiled code)
- Bash install script
- Linear MCP for issue tracking
- AI-Implement pipeline for issue-to-PR automation

## Conventions

- Each skill lives in its own directory (`skill-name/SKILL.md`)
- Skill files use YAML frontmatter with `name` and `description` fields
- The `description` field drives trigger matching — write it as a comprehensive set of trigger phrases
- No new dependencies without good reason — skills are markdown, keep them that way
- Follow the phase/principle structure established by `build-down` and `build-up`

## MCP Setup

- Linear MCP: configured in `.mcp.json`, enabled in `.claude/settings.json`
- API key: set via `LINEAR_API_KEY` env var or `.claude/settings.local.json` (gitignored)

## Skills in This Repo

| Skill | Purpose |
|---|---|
| `build-up` | Plan and file a milestone's worth of tracker issues |
| `mega-build-up` | Deep build-up with adversarial design review and a written plan document |
| `summit-push` | Optimize sequencing and issue quality before sending to the agent |
| `build-down` | Drive open PRs to merge |
| `super-build-down` | Autonomous, lean-back build-down for large PR batches |
| `smoke-jumper` | Autonomous PR smoke-testing against preview deploys |
| `belay-on` | Formalize tool handoffs mid-session |
| `bd-project-setup` | Bootstrap a new project for the BuildDownAI workflow |
