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

### `bd-project-setup` — wire a project's tools and bindings

Runs once per project to configure everything the other skills need: writes `.mcp.json` with the project's MCP servers, pre-approves them so the trust prompt never fires, drives each server's OAuth flow from inside the session, and writes the `{{PLACEHOLDER}}` → value bindings into `CLAUDE.md` (tracker workspace/team, GitHub repo, build command, etc.). The rest of the skills read those bindings — you only run setup once.

The plugin ships **skills only** — it bundles no MCP servers. So each project provisions **exactly one** tracker server, chosen by `tracker.kind`: `linear-server` for a Linear project or `jira-server` for a Jira project, never both. (GitHub is added per project only where needed.)

Trigger: *"bd-project-setup"*, *"set up the skills"*, *"wire up the relationships"*, *"configure the MCP servers"*, *"point Linear at this project"*.

### `bd-build-up` — plan a milestone's worth of issues

Turns a product objective, design handoff, or convergence plan into a sequenced, dependency-aware set of tracker issues ready for the AI coding agent. **Plan first, file second** — bd-build-up always presents the proposed breakdown for your review before creating anything in the tracker.

Trigger: *"bd-build-up"*, *"plan the issues"*, *"break this down into issues"*, *"convergence plan"*, *"build from this design"*.

### `bd-summit-push` — strategize the batch before sending

Sits between bd-build-up (planning) and bd-build-down (landing). Takes a set of planned or filed issues and optimizes their sequencing, dependency graph, and issue-body quality for maximum one-shot success rate through the agent pipeline. Also runs pre-flight risk scans during bd-build-down to anticipate architectural blindspots.

Trigger: *"bd-summit-push"*, *"optimize the push"*, *"plan the assault"*, *"what order should we send these"*.

### `bd-build-down` — drive open PRs to merge

An active sprint-closure session: survey the tracker and open PRs, assess each against its gap analysis, drive gaps to resolution autonomously via PR comments to the agent, merge clean PRs, file minimal follow-up issues only for real blockers. Runs autonomously by default; escalates only on pattern breaks.

Trigger: *"bd-build-down"*, *"drive PRs to merge"*, *"PR triage"*.

### `bd-super-build-down` — autonomous, lean-back bd-build-down

bd-build-down's faster cousin. Same mission and rules, tuned for throughput: batch escalations (presented once at the end), minimal narration, mandatory bd-smoke-jumper dispatch, explicit session-abort triggers for unattended runs. Use when you've got 5+ PRs and won't be watching every step.

Trigger: *"bd-super-build-down"*, *"autonomous bd-build-down"*, *"overnight bd-build-down"*, *"just land everything"*.

### `bd-smoke-jumper` — autonomous PR smoke-testing

Parachutes onto one or more PRs, reads the gap analysis to figure out what to test, logs into the preview deploy, runs adaptive smoke tests, posts a verdict comment, and files tracker issues for failures. bd-build-down does quick inline checks; bd-smoke-jumper does the deeper feature-aware verification. Runs standalone or is dispatched per-PR by the bd-build-down skills.

Trigger: *"smoke-jump"*, *"smoke test"*, *"test this PR"*, *"verify the preview"*.

### `bd-mega-build-up` — deep bd-build-up with adversarial grilling and plan documents

bd-build-up's heavier cousin. Same AI-Implement pipeline awareness and issue-shape discipline, but adds an adversarial design-review phase (senior-engineer pushback before any issues get filed), a detailed implementation plan with exact file paths, and design + plan documents attached to the tracker project/epic so they travel with the work. Supports both Linear and Jira via swappable tracker adapters (`trackers/linear.md`, `trackers/jira.md`).

Use bd-mega-build-up when scope is non-trivial (≥ 8 issues, multi-system, schema changes, or new architecture) or when the plan needs to live as documentation. Use plain `bd-build-up` for smaller, well-trodden work.

Trigger: *"bd-mega-build-up"*, *"deep bd-build-up"*, *"grill me on this"*, *"thorough bd-build-up"*, *"I want the senior eng review"*.

### `bd-belay-on` — formalize tool handoffs mid-session

A climbing term: *belay on* means the safety system is engaged and the climber can proceed. This skill formalizes pausing one tool (chat, CLI, code-execution) to gather information from another (code-reading agent, browser, etc.) and resuming cleanly when results come back. Each build skill anticipates bd-belay-on points; this skill is what produces the handoff prompt and integrates the results.

Trigger: *"bd-belay-on"*, *"hold while I check"*, *"sending to {tool}"*, *"back from recon"*.

---

## How they fit together

```
        ┌──────────────────┐
  once  │ bd-project-setup │  write .mcp.json, CLAUDE.md bindings,
  per   │                  │  OAuth each MCP server from inside the session
 project└──────────────────┘
                 │ bindings in place
                 ▼
   ┌─────────────┴──────────────────┐
   ▼                                ▼
┌──────────┐              ┌──────────────────┐
│ bd-build-up │◄─ design,    │ bd-mega-build-up    │◄─ design,  adversarial grilling
│          │   objective  │                  │   objective + written plan docs
└──────────┘              └──────────────────┘
     │                              │
     └──────────────┬───────────────┘
                    │ plan reviewed, issues filed
                    ▼
┌─────────────┐
│ bd-summit-push │   sequence + harden issue bodies
│  (pre-push) │
└─────────────┘
     │
     ▼  agent picks up issues, opens PRs
     │
┌────┴──────────────────────────┐
▼                               ▼
┌────────────┐       ┌────────────────────┐
│ bd-build-down │  or   │ bd-super-build-down   │   triage + drive to merge
└────────────┘       └────────────────────┘
  │  dispatches per-PR          │ mandatory per-PR
  ▼                             ▼
           ┌──────────────┐
           │ bd-smoke-jumper │   verdicts → merge signals
           └──────────────┘

  bd-belay-on  ─── cross-cutting: pause/resume tool handoffs anywhere above
```

**Feature-branch grouping awareness (Linear only).** When AI-Implement parent/child *feature-branch
grouping* is in play, a labelled parent with labelled children becomes a feature node: children PR into
its `ai-implement/feature/<key>` branch, and the tree rolls up to one human-reviewed `feature → base` PR.
`bd-build-up`, `bd-mega-build-up`, `bd-summit-push`, `bd-build-down`, `bd-super-build-down`, and
`bd-smoke-jumper` are grouping-aware. Full model: [`docs/feature-branch-grouping.md`](docs/feature-branch-grouping.md).

---

## Requirements

These skills assume a workflow with:

- **[Claude Code](https://docs.claude.com/en/docs/claude-code)** — the harness that loads and runs skills.
- **An issue tracker MCP** — Linear is the assumed default; substitute Jira / GitHub Issues if you have an equivalent MCP.
- **GitHub MCP** — for PR survey, comment posting, and merging.
- **Browser automation MCP** — for bd-smoke-jumper and inline preview checks (Chrome DevTools MCP, Playwright MCP, etc.).
- **An AI coding agent that responds to PR comments** — [AI-Implement](https://github.com/cpope/AI-Implement) is the reference implementation; anything that opens a PR from a labeled ticket and re-runs from a `/ai-implement` (or equivalent) comment will work.

The skills are tooling-agnostic where possible — service names appear as `{{TRACKER}}`, `{{CODING_AGENT}}` etc. in the skill files. Substitute as needed.

---

## Installation

This repo is also a **Claude Code plugin marketplace**, so the simplest install is:

```
/plugin marketplace add BuildDownAI/skills
/plugin install builddown@builddown
```

That tracks the repo's default branch and is managed by `/plugin` (update with `/plugin marketplace update builddown`). To install from a specific branch or tag, append `@ref` (GitHub shorthand) or `#ref` (full git URL):

```
/plugin marketplace add BuildDownAI/skills@ai-implement/feature/bds-1
/plugin install builddown@builddown
```

### Versions and channels

Which channel you're on depends on how you installed:

| How you installed | What you get |
|---|---|
| `/plugin marketplace add BuildDownAI/skills` (no ref) | **Stable** — pinned to the latest release tag |
| `/plugin marketplace add BuildDownAI/skills@testing` | **Dev** — tracks `testing`, updates as work lands |
| `./install.sh --from-git <url>@v1.0.0` | Whatever tag you pin |
| `./install.sh` from a checkout, or manual copy | Whatever that checkout contains — unversioned |

**Stable** only changes when a new version ships. **Dev** follows `testing` and can change at any time,
including in ways that haven't been through a release. Check which version you have with
`/plugin list --enabled`.

#### Moving between channels

Your channel is recorded **on your machine** when you first run `marketplace add`. Releases in this repo
cannot move you — switching is something you do locally.

To move from dev to stable:

```
/plugin marketplace remove builddown
/plugin marketplace add BuildDownAI/skills
/plugin install builddown@builddown
```

Reverse the middle line (`BuildDownAI/skills@testing`) to go the other way.

> **Removing a marketplace uninstalls the plugins installed from it.** The third line is not optional —
> without it you'll have no skills installed.

### Script install (symlink / copy)

If you'd rather not use the plugin system:

```bash
git clone https://github.com/BuildDownAI/skills.git builddown-skills
cd builddown-skills
./install.sh
```

By default this **symlinks** the skills into `~/.claude/skills/`, so a future `git pull` updates them instantly.

After installing, open a Claude Code session in the repo you want to use these skills with and run `bd-project-setup`. Setup writes `.mcp.json`, pre-approves the MCP servers, drives OAuth authentication from inside the session, and records all `{{PLACEHOLDER}}` bindings in `CLAUDE.md`. You only need to do this once per project; the other skills read those bindings automatically.

### Options

```
./install.sh                       # symlink into ~/.claude/skills (user-global)
./install.sh --project <path>      # install into <path>/.claude/skills (project-local)
./install.sh --copy                # copy files instead of symlinking
./install.sh --force               # overwrite existing skill dirs
./install.sh --prune               # remove stale/renamed BuildDown skills no longer in source
./install.sh --from-git <url>      # install from a managed clone (accepts <url>@<ref>)
./install.sh --ref <ref> --update  # pin/refresh the managed clone to a branch/tag/SHA
./install.sh --dry-run             # show what would happen, change nothing
./install.sh --uninstall           # remove this repo's skills from the target
./install.sh -h | --help
```

### Install from GitHub (managed clone)

`--from-git` clones (or refreshes) into a managed source dir at `~/.claude/_sources/builddown` and
installs from there, so your install never rides a random working copy on a dev branch:

```bash
# Latest default branch, refreshed on each run
curl -fsSL https://raw.githubusercontent.com/BuildDownAI/skills/main/install.sh | bash -s -- \
  --from-git https://github.com/BuildDownAI/skills.git --update

# Pin to a specific branch/tag/SHA (e.g. to test a feature branch)
./install.sh --from-git https://github.com/BuildDownAI/skills.git@ai-implement/feature/bds-1 --update
```

To re-point a managed install at a different ref later, re-run with the new `@<ref>` (or `--ref`) and
`--update`. Add `--prune` to drop any skills that were renamed or removed between refs.

### Stale-install cleanup

Every BuildDown `SKILL.md` carries `metadata.suite: builddown` in its frontmatter. On install, the
script reports any **marked** skill in the target that's no longer in the current source (e.g. an
old un-prefixed `build-down` left behind after the `bd-` rename) and, with `--prune`, removes it.
Skills without the marker are never touched.

### Manual install

If you'd rather not run the script, each skill is a self-contained directory under `plugin/skills/`. Copy or symlink whichever ones you want into `~/.claude/skills/` (or `<project>/.claude/skills/`):

```bash
ln -s "$PWD/plugin/skills/bd-build-down" ~/.claude/skills/bd-build-down
ln -s "$PWD/plugin/skills/bd-build-up"   ~/.claude/skills/bd-build-up
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
