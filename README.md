# BuildDown Skills

Claude Code skills that orchestrate the [AI-Implement](https://github.com/cpope/AI-Implement) pipeline from the human/PM side — planning issues, optimizing batches, driving PRs to merge, and smoke-testing previews.

AI-Implement turns a labeled Linear ticket into a PR. These skills handle everything around that: how the tickets get written, what order they go out in, how the resulting PRs get verified and landed, and how to leave the board cleaner than you found it.

---

## Why these skills

If you're using AI-Implement (or a similar ticket-to-PR pipeline), you'll quickly hit four recurring questions:

1. *"I have a design or objective — how do I turn it into well-scoped tickets the agent can one-shot?"*
2. *"I have a stack of planned tickets — what order should they go out in, and which ones will fail without more context?"*
3. *"I have a pile of open PRs from the agent — which ones merge, which need another pass, and which are blockers?"*
4. *"Did the preview actually work, or did the agent just make the diff look right?"*

Each skill in this repo answers one of those questions, with a consistent autonomy model and shared assumptions about your tooling (issue tracker MCP, GitHub MCP, browser automation MCP, AI coding agent that responds to PR comments).

---

## The skills

### `build-up` — plan a milestone's worth of issues

Turns a product objective, design handoff, or convergence plan into a sequenced, dependency-aware set of tracker issues ready for the AI coding agent. **Plan first, file second** — build-up always presents the proposed breakdown for your review before creating anything in the tracker.

Trigger: *"build-up"*, *"plan the issues"*, *"break this down into issues"*, *"convergence plan"*, *"build from this design"*.

### `summit-push` — strategize the batch before sending

Sits between build-up (planning) and build-down (landing). Takes a set of planned or filed issues and optimizes their sequencing, dependency graph, and issue-body quality for maximum one-shot success rate through the agent pipeline. Also runs pre-flight risk scans during build-down to anticipate architectural blindspots.

Trigger: *"summit-push"*, *"optimize the push"*, *"plan the assault"*, *"what order should we send these"*.

### `build-down` — drive open PRs to merge

An active sprint-closure session: survey the tracker and open PRs, assess each against its gap analysis, drive gaps to resolution autonomously via PR comments to the agent, merge clean PRs, file minimal follow-up issues only for real blockers. Runs autonomously by default; escalates only on pattern breaks.

Trigger: *"build-down"*, *"drive PRs to merge"*, *"PR triage"*.

### `super-build-down` — autonomous, lean-back build-down

Build-down's faster cousin. Same mission and rules, tuned for throughput: batch escalations (presented once at the end), minimal narration, mandatory smoke-jumper dispatch, explicit session-abort triggers for unattended runs. Use when you've got 5+ PRs and won't be watching every step.

Trigger: *"super-build-down"*, *"autonomous build-down"*, *"overnight build-down"*, *"just land everything"*.

### `smoke-jumper` — autonomous PR smoke-testing

Parachutes onto one or more PRs, reads the gap analysis to figure out what to test, logs into the preview deploy, runs adaptive smoke tests, posts a verdict comment, and files tracker issues for failures. Build-down does quick inline checks; smoke-jumper does the deeper feature-aware verification. Runs standalone or is dispatched per-PR by the build-down skills.

Trigger: *"smoke-jump"*, *"smoke test"*, *"test this PR"*, *"verify the preview"*.

### `belay-on` — formalize tool handoffs mid-session

A climbing term: *belay on* means the safety system is engaged and the climber can proceed. This skill formalizes pausing one tool (chat, CLI, code-execution) to gather information from another (code-reading agent, browser, etc.) and resuming cleanly when results come back. Each build skill anticipates belay-on points; this skill is what produces the handoff prompt and integrates the results.

Trigger: *"belay-on"*, *"hold while I check"*, *"sending to {tool}"*, *"back from recon"*.

---

## How they fit together

```
            ┌──────────┐
   design,  │ build-up │   plan reviewed,
 objective ─►          ├─► issues filed
            └──────────┘
                 │
                 ▼
          ┌─────────────┐
          │ summit-push │   sequence + harden
          │  (pre-push) │   issue bodies
          └─────────────┘
                 │
                 ▼  agent picks up issues, opens PRs
                 │
   ┌─────────────┴──────────────┐
   ▼                            ▼
┌────────────┐       ┌────────────────────┐
│ build-down │  or   │ super-build-down   │   triage + drive to merge
└────────────┘       └────────────────────┘
   │  dispatches per-PR        │ mandatory per-PR
   ▼                           ▼
            ┌──────────────┐
            │ smoke-jumper │   verdicts → merge signals
            └──────────────┘

  belay-on  ─── cross-cutting: pause/resume tool handoffs anywhere above
```

---

## Requirements

These skills assume a workflow with:

- **[Claude Code](https://docs.claude.com/en/docs/claude-code)** — the harness that loads and runs skills.
- **An issue tracker MCP** — Linear is the assumed default; substitute Jira / GitHub Issues if you have an equivalent MCP.
- **GitHub MCP** — for PR survey, comment posting, and merging.
- **Browser automation MCP** — for smoke-jumper and inline preview checks (Chrome DevTools MCP, Playwright MCP, etc.).
- **An AI coding agent that responds to PR comments** — [AI-Implement](https://github.com/cpope/AI-Implement) is the reference implementation; anything that opens a PR from a labeled ticket and re-runs from a `/ai-implement` (or equivalent) comment will work.

The skills are tooling-agnostic where possible — service names appear as `{{TRACKER}}`, `{{CODING_AGENT}}` etc. in the skill files. Substitute as needed.

---

## Installation

```bash
git clone https://github.com/cpope/BuildDownAI-skills.git
cd BuildDownAI-skills
./install.sh
```

By default this **symlinks** the skills into `~/.claude/skills/`, so a future `git pull` updates them instantly.

### Options

```
./install.sh                       # symlink into ~/.claude/skills (user-global)
./install.sh --project <path>      # install into <path>/.claude/skills (project-local)
./install.sh --copy                # copy files instead of symlinking
./install.sh --force               # overwrite existing skill dirs
./install.sh --dry-run             # show what would happen, change nothing
./install.sh --uninstall           # remove this repo's skills from the target
./install.sh -h | --help
```

### Manual install

If you'd rather not run the script, each skill is a self-contained directory under `skills/`. Copy or symlink whichever ones you want into `~/.claude/skills/` (or `<project>/.claude/skills/`):

```bash
ln -s "$PWD/build-down" ~/.claude/skills/build-down
ln -s "$PWD/build-up"   ~/.claude/skills/build-up
# ...etc
```

### Updating

If installed with symlinks (the default):

```bash
cd BuildDownAI-skills && git pull
```

If installed with `--copy`, re-run `./install.sh --copy --force` after pulling.

### Uninstalling

```bash
./install.sh --uninstall
```

This only removes skills whose names match this repo's `skills/*/` directories, and (in symlink mode) only if the symlink still points into this clone — it won't touch unrelated skills you've installed.

---

## License

Apache 2.0 — same as AI-Implement.
