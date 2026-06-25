---
name: bd-project-setup
description: "Set up a new project to use the BuildDownAI skills and AI-Implement pipeline. Trigger this skill when the user says 'bd-project-setup', 'set up BuildDown', 'configure AI-Implement', 'set up this project for AI-Implement', 'wire up Linear and GitHub', or describes wanting to use the build-up/build-down workflow in a new repo. This skill walks through: checking prerequisites, installing the BuildDownAI skills, configuring the Linear and GitHub MCPs, writing the project's CLAUDE.md, and verifying the end-to-end pipeline connection."
---

# BD Project Setup Skill

This skill bootstraps a new project for the BuildDownAI workflow — Linear tracker, GitHub MCP, AI-Implement pipeline, and the build-up/build-down/smoke-jumper skill suite.

**Outcome:** by the end of a setup session the user has a working AI-Implement loop: file a labeled ticket → agent opens a PR → build-down drives it to merge.

---

## Prerequisites

Before running setup, confirm the user has:

1. **Claude Code** installed and running (`claude --version`)
2. **Linear workspace** with API access (`Settings → API → Personal API keys`)
3. **GitHub repo** the user owns or has admin access to
4. **AI-Implement** configured on the repo (GitHub App installed, workflow files committed)
5. **Node.js 18+** for npx-based MCP servers

If any prerequisite is missing, surface it and stop — setup can't proceed without it.

---

## Phase 1: Gather Config

Ask only the questions you can't infer. Resolve the rest from context.

**Required inputs:**

| Input | How to get it |
|---|---|
| `REPO` | `owner/name` of the GitHub repo to configure |
| `LINEAR_TEAM` | Team slug in Linear (visible in the URL: `linear.app/{workspace}/team/{slug}`) |
| `LINEAR_PROJECT` | Project name where issues will be filed (create if it doesn't exist) |
| `IMPLEMENT_LABEL` | The Linear label that triggers AI-Implement pickup (default: `AI-Implement`) |
| `BUILD_CMD` | Verification command for the repo (e.g., `npm run build`, `tsc --noEmit`, `pytest`) |

**Optional inputs (skip for single-operator setups):**

| Input | Purpose |
|---|---|
| `ARCHITECT_NAME` | Human who owns migrations, auth, and infra decisions |
| `PREVIEW_HOST` | Preview deploy URL pattern (e.g., `pr-{N}-{app}.fly.dev`) |
| `AGENT_MENTION` | How the coding agent listens for follow-up comments (default: `@claude`) |

If the user is setting up the BuildDownAI skills repo itself, use:
- `REPO`: `BuildDownAI/skills`
- `IMPLEMENT_LABEL`: `AI-Implement`
- `BUILD_CMD`: `echo "no build step"`

---

## Phase 2: MCP Configuration

### 2a. Write `.mcp.json`

Create `.mcp.json` in the project root:

```json
{
  "mcpServers": {
    "linear": {
      "command": "npx",
      "args": ["-y", "@linear/mcp-server"],
      "env": {
        "LINEAR_API_KEY": "${LINEAR_API_KEY}"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

Adapt to the user's environment:
- If they only have Linear (no GitHub MCP), omit the `github` block
- If they use a different Linear MCP package, substitute
- If they have browser automation MCP, add it here

### 2b. Write `.claude/settings.json`

Create `.claude/settings.json`:

```json
{
  "enabledMcpjsonServers": ["linear", "github"]
}
```

Adjust the array to match whichever servers are in `.mcp.json`.

### 2c. Update `.gitignore`

Add to `.gitignore` if not already present:

```
settings.local.json
```

`settings.local.json` holds secrets and machine-specific overrides — it must never be committed.

### 2d. Set the API key

Instruct the user to set `LINEAR_API_KEY` in their environment (`.zshrc`, `.bashrc`, or a `.env.local` that is gitignored):

```bash
export LINEAR_API_KEY="lin_api_..."
```

Or via Claude Code's environment: create `.claude/settings.local.json` (gitignored):

```json
{
  "env": {
    "LINEAR_API_KEY": "lin_api_...",
    "GITHUB_TOKEN": "ghp_..."
  }
}
```

---

## Phase 3: Install BuildDownAI Skills

If the BuildDownAI skills are not already installed:

```bash
git clone https://github.com/BuildDownAI/skills.git ~/builddown-skills
cd ~/builddown-skills
./install.sh
```

For project-local installation:

```bash
./install.sh --project /path/to/your/project
```

Verify installation:

```bash
ls ~/.claude/skills/
# should show: build-up  build-down  super-build-down  summit-push  smoke-jumper  belay-on
```

---

## Phase 4: Write the Project's CLAUDE.md

Write a `CLAUDE.md` at the project root. This is the primary context file Claude reads at session start.

**Minimum viable `CLAUDE.md`:**

```markdown
# {Project Name}

## Project Context

{1-2 sentences: what the project does, who uses it, why it exists.}

## BuildDownAI Configuration

- **Tracker:** Linear — team `{LINEAR_TEAM}`, project `{LINEAR_PROJECT}`
- **Repo:** {REPO}
- **AI-Implement label:** `{IMPLEMENT_LABEL}`
- **Build command:** `{BUILD_CMD}`
- **Preview deploys:** {PREVIEW_HOST or "not configured"}
- **Architect:** {ARCHITECT_NAME or "single-operator — escalate to user"}
- **Agent mention:** `{AGENT_MENTION}`

## Stack

{Key technologies: language, framework, database, test runner.}

## Conventions

{Important patterns to follow. E.g. "all DB access via the repository layer", "component tests co-located with components", "no new dependencies without discussion".}

## MCP Setup

- Linear MCP: configured in `.mcp.json`, enabled in `.claude/settings.json`
- GitHub MCP: {configured / not configured}
- API key: set via `LINEAR_API_KEY` env var or `.claude/settings.local.json` (gitignored)
```

Adapt sections based on what the user provided in Phase 1. Don't include sections that don't apply yet.

---

## Phase 5: Smoke Test the Connection

Walk the user through verifying the setup end-to-end.

### 5a. Verify Linear MCP

In Claude Code, run:

```
/mcp
```

Confirm `linear` appears in the list of active servers with status `connected`.

Then ask Claude to list issues:

> "List the 3 most recent issues in my Linear team."

If the list comes back — Linear MCP is working.

### 5b. Verify AI-Implement trigger

Create a test issue in Linear:
- Title: `[TEST] Hello AI-Implement`
- State: `Todo`
- Label: `{IMPLEMENT_LABEL}`
- Body: `Create a file called \`hello.txt\` in the repo root with the text "Hello from AI-Implement".`

Wait 2-3 minutes. Check the GitHub repo for an open PR. If a PR appears — the pipeline is live.

Close the test issue and PR without merging once confirmed.

### 5c. Verify skill loading

In a Claude Code session, trigger a build-up:

> "build-up"

Claude should respond with the build-up skill's opening declaration. If it does — skills are loaded.

---

## Phase 6: Handoff Summary

After setup completes, present a summary:

```
## BD Project Setup — Complete

**Repo:** {REPO}
**Linear team:** {LINEAR_TEAM} / project: {LINEAR_PROJECT}
**AI-Implement label:** {IMPLEMENT_LABEL}

**Files created:**
- `.mcp.json` — Linear{+ GitHub} MCP servers
- `.claude/settings.json` — enables MCP servers
- `CLAUDE.md` — project context for Claude sessions

**`.gitignore` updated:** `settings.local.json` excluded

**Skills installed:** {path — user-global or project-local}

**Pipeline status:** {verified working / not yet verified}

**Next step:** Run `build-up` to plan your first batch of issues.
```

If anything failed during smoke testing, include a **Troubleshooting** section with the specific failure and the most likely fix.

---

## Troubleshooting Reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `/mcp` shows `linear` as disconnected | `LINEAR_API_KEY` not set or wrong | Check `echo $LINEAR_API_KEY`; re-export from `.claude/settings.local.json` |
| AI-Implement doesn't pick up the test issue | Label name doesn't match the configured trigger | Check the AI-Implement GitHub App config for the exact label string |
| Skills not loading | Skills not installed or wrong path | Re-run `install.sh`; check `ls ~/.claude/skills/` |
| GitHub MCP not working | Token missing or insufficient scopes | Token needs `repo` scope; re-generate and update |
| `.mcp.json` parse error | JSON syntax error | Validate at jsonlint.com or `jq . .mcp.json` |

---

## Key Principles

1. **Don't skip the smoke test.** A passing smoke test is the only reliable signal that the end-to-end pipeline works. Setup that ends without verification is setup that might not work.
2. **`settings.local.json` is never committed.** It holds secrets. Verify it's in `.gitignore` before the session ends.
3. **`CLAUDE.md` is the source of truth for the project's workflow config.** Treat it like production config, not a README.
4. **One MCP per concern.** Don't combine Linear and GitHub in a custom server — use the official packages so upgrades are automatic.
5. **This skill is idempotent.** Re-running it on an already-configured project updates the config, doesn't duplicate it. Check for existing files before writing.
