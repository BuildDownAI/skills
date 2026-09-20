# 0003. Every skill declares its client and required tools

**Status:** Accepted
**Date:** 2026-09-18

## Context

As of 1.5.18, the fourteen BuildDown skills ship with no declaration of which client they
require or which MCP tools they depend on. A session that starts `bd-kg-create` in a chat
project gets as far as the `gh repo clone` step (Step 2) before failing with no bash shell.
A session that starts `bd-build-down` without the GitHub connector enabled gets as far as the
first `list_pull_requests` call before failing. Neither failure is caught early, and neither
prints a useful message.

`session-start.md` (introduced by BDS-84) runs at the top of every skill session. It already
discovers the orchestrator connector and validates the tracker workspace. It is the natural place
to enforce a pre-flight check for client type and required tools — the checks run before any
discovery and print a single, actionable stop line if the session cannot satisfy the skill's
requirements.

## Decision

We add `metadata.client` and `metadata.requires` (and optionally `metadata.claude-code-phases`
and `metadata.claude-code-reason`) to every skill's SKILL.md frontmatter, and enforce them in
`session-start.md` Step 0.

**Value set:**

- `client: any` — runs in both chat (claude.ai) and Claude Code; no client restriction.
- `client: claude-code` — requires Claude Code (bash, local filesystem). Chat sessions print the
  stop line and stop before Step 1.
- `claude-code-phases: [n, m, …]` — mixed skill: phases listed here require Claude Code. At the
  start of each listed phase the skill calls session-start step 0; chat sessions stop there.
- `claude-code-reason: "<one-line reason>"` — the reason printed in the stop line for `client:
  claude-code` or `claude-code-phases` skills.
- `requires: [orchestrator, tracker, github, browser]` — hard-stop tools. Only tools whose
  absence makes the skill non-functional are listed. Session-start step 0 checks each entry via
  ToolSearch and stops with a named message if the tool is absent.

**Skill inventory as of BDS-85 (2026-09-18):**

| Skill | `client` | `claude-code-phases` | `requires` |
|---|---|---|---|
| bd-belay-on | `any` | — | — |
| bd-build-down | `any` | — | `[tracker, github]` |
| bd-build-up | `any` | — | `[tracker]` |
| bd-high-plan | `any` | — | `[tracker]` |
| bd-kg-create | `claude-code` | — | `[github]` |
| bd-kg-refresh | `any` | — | `[orchestrator]` |
| bd-kg-search | `any` | — | `[orchestrator]` |
| bd-mega-build-up | `any` | — | `[tracker]` |
| bd-mega-kg-refresh | `any` | `[3, 4, 5]` | `[orchestrator, github]` |
| bd-smoke-jumper | `any` | — | `[tracker, github, browser]` |
| bd-summit-push | `any` | — | `[tracker]` |
| bd-super-build-down | `any` | — | `[tracker, github]` |
| bd-system-questions | `any` | — | `[orchestrator]` |

(bd-belay-on receives `client: any` and no requires — it is a handoff pattern that uses no
external tools of its own and does not run session-start.)

**Stop line formats (verbatim):**

- Client stop: `bd-<name> needs Claude Code: <claude-code-reason>. Open the repo folder in Claude Code and run it there.`
- Tool stop: `bd-<name> needs <tool> in this session; it is not enabled.`

**Where the check lives:** `session-start.md` Step 0 — before any orchestrator discovery (Step 1).
This means the stop fires before any MCP tool is called, giving the user a clear message
without a confusing tool error.

**Version line:** On success, after Step 3 binding resolves, session-start prints:
`builddown <version> · orchestrator <orchestratorUrl> · project <team>/<owner>/<repo>`
where `<version>` is read from `.claude-plugin/plugin.json` (the same file in the chat bundle).
In chat, this reflects the installed bundle version; in Claude Code on the repo, it reflects
the current file. The divergence is intentional and observable.

## Alternatives considered

- **Hardcode checks inside each skill** — rejected; the check would need to be maintained in
  thirteen places. A single location in session-start is the only one that stays in sync.
- **Warn instead of stop** — rejected; a warning that lets a chat session proceed into
  `bd-kg-create` produces a confusing bash-not-available error two steps later. Early stop is
  unambiguous.
- **Check only `client:`, not `requires:`** — rejected; `requires` catches tool-availability
  failures (e.g., GitHub connector not enabled) that `client` does not, and the stop messages
  are more actionable than a raw MCP error.

## Consequences

- Every new SKILL.md must declare `metadata.client` and `metadata.requires`. CONTRIBUTING.md
  and CLAUDE.md record this rule.
- A change that moves a step onto the shell, git, a checkout, or a browser must update the
  `client` or `requires` declaration in the same PR.
- The greps in the BDS-85 acceptance criteria serve as the regression check for any future PR.
- A stale chat bundle shows an older version number than Claude Code on the same day — this
  divergence is intentional (BDS-82 publishes the bundle on a release cadence, not on every
  commit).
