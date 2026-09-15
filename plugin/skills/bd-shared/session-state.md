# Session state file

A landing session (bd-build-down, bd-super-build-down) keeps its queue in **one file on disk**,
rewritten at every state change. The file is the session's source of truth for progress: the
harness plan tool, the terminal statusline, and the tracker status comment are all renderers of it,
never the other way round.

Why a file: it is the only mechanism that works identically in Claude Code and Codex, it survives
context compaction and a killed terminal, and it lets a session resume — or move to a different
harness — without re-orienting from scratch. The transcript is not persistent; this is.

## Path

`.bd/session.md` at the root of the repo the session is driving (the checkout of `{{REPO}}`, or the
current working directory when the session is not run from a checkout). One session per repo at a
time.

The directory is local working state, not a deliverable. **Add `.bd/` to the project's `.gitignore`**
the first time a session creates it (an autonomous write; say so in one line). Never commit it and
never include it in a PR.

## Shape

Two parts, in this order: a header block of `key: value` lines, then one queue table. Nothing else.
Keep both machine-readable — the statusline script parses them with `awk`, and a resuming session
reads them before anything else.

```markdown
# bd-session
skill: bd-build-down
phase: 4 merge
started: 2026-09-11T14:02Z
updated: 2026-09-11T14:40Z
repo: acme/webapp
tracker: linear
harness: Claude Code · Opus 4.8
parent: BDS-80

| PR | Issue | Tier | State | Last action |
|---|---|---|---|---|
| #412 | BDS-88 | 1 | merged | 14:31 verified merge, issue → Done |
| #415 | BDS-91 | 2 | awaiting-agent | 14:40 posted /ai-implement for gap: empty-state copy |
| #418 | BDS-93 | 3 | escalated | 14:38 smoke 🔴 login redirect loop |
| #420 | BDS-94 | — | queued | |
```

Header keys:

| Key | Value |
|---|---|
| `skill` | `bd-build-down` or `bd-super-build-down` |
| `phase` | the running skill's phase number and one word from its title (bd-build-down: `1 orient` … `6 summary`; bd-super-build-down: `1 orient` … `7 summary`), or `closed` |
| `started` / `updated` | ISO 8601 UTC, minute precision. `updated` changes on every write |
| `repo` | `{{REPO}}` |
| `tracker` | `linear` or `jira` |
| `harness` | the harness and model driving the session, same value the learnings comment records under `Driven by` |
| `parent` | the parent/umbrella issue key when the queue is a feature-node tree; omit otherwise |
| `aborted` | bd-super-build-down only: the session-abort trigger that halted the run, in one line; omit otherwise. Left with an open `phase` so the next session's resume check surfaces it |

Queue columns:

- **PR** — `#N`, or `—` for a queued issue with no PR yet.
- **Issue** — the tracker key.
- **Tier** — bd-super-build-down's 1/2/3; bd-build-down writes `—`.
- **State** — one word from the vocabulary below. No synonyms, no free text; the count in the
  statusline depends on it.
- **Last action** — `HH:MM` and one short clause. The most recent thing that happened to this PR,
  not a history. History lives in the transcript and the learnings comment.

### State vocabulary

| State | Meaning |
|---|---|
| `queued` | in the session's scope, not yet looked at |
| `triaging` | gap analysis and diff being assessed |
| `awaiting-agent` | coding-agent comment posted, waiting on a new head |
| `awaiting-ci` | new head landed, checks running |
| `smoke-testing` | bd-smoke-jumper dispatched, no verdict yet |
| `merge-ready` | all merge criteria met, merge not yet executed |
| `merged` | merged and verified, issue moved to Done |
| `escalated` | pattern break — waiting on the user (bd-super-build-down: collected for the batch) |
| `blocked` | cannot proceed this session for a reason outside the PR (migration gate, infra, auth) |
| `closed-unmerged` | closed without merging — a failure, reason in Last action |
| `superseded` | replaced by another PR or issue |

`merged`, `closed-unmerged`, and `superseded` are terminal. Everything else is open.

## When to write

Rewrite the whole file (it is small) at each of these points. Do not batch writes; the value of the
file is that it is current when the terminal is not.

1. **Session start**, end of Phase 1 — header plus every PR from the orientation table as `queued`.
2. **Every per-PR state change** — a comment posted, a merge verified, a smoke verdict received, a
   pattern break found, a PR closed. One PR per write is fine.
3. **Every phase boundary** — update `phase`.
4. **Session close** — set `phase: closed` after the learnings comment is posted. The file stays so
   the next session can see what the last one left open.

If the harness is a Claude Code hook or statusline consumer, it reads the file; you never need to
print the queue to the terminal for it. Log lines to the user stay as the skills define them.

## Resume

**Before Phase 1**, check for an existing `.bd/session.md`:

- **Absent, or `phase: closed`** — start fresh. Overwrite at the end of Phase 1.
- **Open phase** — a prior session did not close. Present its header and its open rows in one short
  block, then ask one question: *resume this session, or start over?* Resume means: re-read live
  state (PR heads, CI, tracker status) for each open row before acting on it — the file records what
  the last session *did*, not what is true now — and keep the same `started`. Start over means:
  overwrite. Do not silently do either.

A session moving between harnesses (Claude Code to Codex, or a bd-belay-on handoff) resumes the same
way. The file is the handoff.

## Renderers

The file is the truth; these show it. Each is optional and none replaces a write to the file.

- **Harness plan tool.** If the harness has an in-session plan or todo tool (Claude Code's task
  list, Codex's plan), mirror the queue into it at the same write points — one item per open PR,
  named `#N state`. Display only: it does not persist past the session.
- **Claude Code statusline.** `../bd-shared/tools/bd-statusline.sh` reads the file for the current
  directory and prints one line — skill, phase, merged-of-total, open-state counts, last update.
  Install once per machine in `~/.claude/settings.json`:

  ```json
  { "statusLine": { "type": "command", "command": "bash /path/to/bd-shared/tools/bd-statusline.sh" } }
  ```

  `install.sh` puts the script at `~/.claude/skills/bd-shared/tools/bd-statusline.sh`; a marketplace
  install puts it under the plugin cache — `find ~/.claude -name bd-statusline.sh` locates it. With no
  session file in the current directory the script prints the model and directory, so it is safe as
  the only statusline. Codex has no statusline; there, the plan tool and the file itself are the
  display.
- **Tracker status comment.** When the queue has a `parent`, keep one comment on that issue whose
  first line is `# bd-session-status`, edited in place at every phase boundary and every terminal
  state change (not every write). Body: the header block and the queue table, verbatim. This is what
  someone away from the terminal sees. It is a separate comment from
  `# ai-implement-build-down-learnings` (`./learnings-comments.md`) — status is live and disposable,
  learnings are distilled and durable. Delete or leave the status comment at close; do not fold it
  into the learnings comment.

## Relationship to the session summary and learnings

The Phase 6 session summary and the closing learnings comment are written **from** this file: every
row's terminal state maps onto the learnings outcome taxonomy (`merged`, `closed-unmerged (failure)`,
`open / never-landed` for any non-terminal state, `superseded`). If a row is missing from the file, it
is missing from the summary — which is the check that the file was kept.
