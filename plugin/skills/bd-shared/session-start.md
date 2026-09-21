# Session Start

Shared discovery-and-binding procedure. Run once at the start of every skill session that
needs the orchestrator. Stores session values (`prefix`, `team`, `defaultBranch`, `tracker`,
`pickupLabel`, `kg`) for all subsequent steps in the session.

**Read this file before acting; do not run it from memory.** Every "print" in this file is a
line the user sees. The printed lines open the reply, in step order, before any other output
from the calling skill. A skill's own first line (an opening declaration, a `KG:` line, a
table) comes after them. A step that says "stop" ends the reply after its line.

Pattern anchor: `./pickup-label.md` (tool-presence check first, printed source line) and
`./kg-recon.md`.

## Step 0 — Client and tool check

Before any discovery, read the calling skill's `metadata.client`, `metadata.claude-code-phases`,
`metadata.claude-code-reason`, and `metadata.requires` from its frontmatter.

**Client check (chat sessions):**

Determine whether the session is running in **chat** (claude.ai — no bash, no local filesystem)
or **Claude Code** (terminal, bash available).

- **`client: claude-code`** and session is chat — print exactly:
  > bd-\<name\> needs Claude Code: \<claude-code-reason\>. Open the repo folder in Claude Code and run it there.

  Stop. No further steps run.

- **`claude-code-phases` is set** and this invocation is at the start of one of those listed
  phases (i.e., session-start is being called from within a listed phase) and session is chat
  — print exactly the same line (using `claude-code-reason`) and stop. No further steps run.

**Required-tool check:**

For each entry in the calling skill's `requires` list, check whether the tool is available in
this session:

| `requires` entry | Availability check |
|---|---|
| `orchestrator` | ToolSearch with the query `get_project_binding` returns at least one tool whose name ends in `__get_project_binding` |
| `tracker` | ToolSearch with the query `list_teams` (Linear) or `list_projects` (Jira) returns at least one tool whose name ends in that suffix, outside the orchestrator prefix |
| `github` | ToolSearch for `get_pull_request` returns at least one result |
| `browser` | ToolSearch for a page navigation tool (`navigate`, `read_page`) returns at least one result |

If a required entry is absent, print exactly:
  > bd-\<name\> needs \<tool\> in this session; it is not enabled.

Stop. No further steps run.

All checks pass — continue to Step 1.

## Step 1 — Discover the orchestrator connector

Use ToolSearch with the query `get_project_binding`. Write the query without leading
underscores; a query that starts with `__` matches nothing. Count the tools whose name ends in
`__get_project_binding`.

- **None found:** print exactly —
  > No orchestrator connector is enabled in this session. Add or enable one at claude.ai connectors.

  Stop for skills that need the orchestrator. bd-belay-on does not require the orchestrator and
  may continue past this line.

- **Two or more found:** print exactly —
  > Two orchestrator connectors are enabled; disable one.

  Stop. (In a Claude Code session with `.mcp.json`, "disable one" means removing one entry
  from the file.)

- **Exactly one found:** its prefix is the orchestrator server name for this session. Store as
  `<prefix>`. Every subsequent `mcp__<prefix>__*` call in this session uses it.

  Print one line: `orchestrator: <prefix>`

## Step 2 — Repo slug

Resolve `<owner>/<repo>`:

- **Claude Code:** run `git remote get-url origin` and parse to `<owner>/<repo>` (strip
  protocol, host, and `.git` suffix; e.g. `https://github.com/BuildDownAI/skills.git` →
  `BuildDownAI/skills`).
- **Chat (claude.ai):** read the `repo:` line from the project instructions
  (format: `repo: <owner>/<repo>`, e.g. `repo: BuildDownAI/skills`).
- **Neither available:** ask once: "What is this project's GitHub repo slug (owner/name)?"

Store the resolved slug for this session.

## Step 3 — Binding

Call `mcp__<prefix>__get_project_binding(repo: "<owner>/<repo>")`.

- **`isError` containing "No project mapping found":** print exactly —
  > orchestrator \<orchestratorUrl\> has no project for \<owner\>/\<repo\>; read-only skills continue, skills that file issues stop.

  where `<orchestratorUrl>` comes from the error response when present (omit the token if
  absent). Read-only skills continue; planning and issue-filing skills stop here.

- **Success:** store `team`, `defaultBranch`, `tracker`, `pickupLabel`, and `kg` for the
  session. Print one line:
  `binding: <owner>/<repo> → team <tracker.team> (<tracker.kind>)`

  Then read `version` from the loaded plugin's own `.claude-plugin/plugin.json` (the plugin
  directory this skill file lives in; in a checkout of the skills repo that is
  `plugin/.claude-plugin/plugin.json`). In a chat session that file is not mounted; read
  `../bd-shared/VERSION` instead (one line, written into the chat bundle by the release
  workflow). If neither is readable, print `version unknown` in its place. Print:
  `builddown <version> · orchestrator <orchestratorUrl> · project <team>/<owner>/<repo>`
  where `<orchestratorUrl>` is `kg.orchestratorUrl` from the binding response, `<team>` is
  `tracker.team`, and `<owner>/<repo>` is the slug from Step 2. Example:
  `builddown 1.5.23 · orchestrator https://ai-implement-testing-orchestrator.fly.dev · project BDS/BuildDownAI/skills`

## Step 4 — Tracker connector check

For **`tracker.kind = linear`**:

Use ToolSearch with the query `list_teams`. Count the tools whose name ends in `__list_teams`.

- **None found — no connector at all:** print exactly —
  > No Linear connector is enabled in this session; this repo's orchestrator mapping expects team \<team\>. Add or enable it at claude.ai connectors.

  Stop for skills that write to the tracker. Read-only skills continue.

- **Two or more found:** print exactly —
  > Two Linear connectors are enabled; disable one.

  Stop. (A repo that still carries a Linear entry in `.mcp.json` next to the connector is the
  usual cause; remove the entry.)

- **Exactly one found:** its prefix is `<tracker-prefix>`. Call
  `mcp__<tracker-prefix>__get_team(query: "<tracker.team>")`. `list_teams` returns team names,
  not keys, so it cannot answer this check.

  - **Empty or error answer — wrong workspace:** print exactly —
    > The Linear connector is signed into a workspace without team \<team\>; this repo's orchestrator mapping expects it. Reconnect the connector to that workspace.

    Stop for skills that write to the tracker. Read-only skills continue.

  - **Found:** print one line: `tracker: Linear team <tracker.team> ✓`

For **`tracker.kind = jira`**:

Use ToolSearch with the query `list_projects`. Count the tools whose name ends in
`__list_projects` and whose prefix is not `<prefix>` from Step 1; the orchestrator has its own
`list_projects`, which does not count.

- **None found — no connector at all:** print exactly —
  > No Atlassian connector is enabled in this session; this repo's orchestrator mapping expects project \<team\>. Add or enable it at claude.ai connectors.

  Stop for skills that write to the tracker. Read-only skills continue.

- **Two or more found:** print exactly —
  > Two Atlassian connectors are enabled; disable one.

  Stop.

- **Exactly one found:** call `list_projects`. Check whether a project with key `tracker.team`
  is present.

  - **Not found — wrong workspace:** print exactly —
    > The Atlassian connector is signed into a workspace without project \<team\>; this repo's orchestrator mapping expects it. Reconnect the connector to that workspace.

    Stop for skills that write to the tracker. Read-only skills continue.

  - **Found:** print one line: `tracker: Jira project <tracker.team> ✓`

## Step 5 — Downstream hand-off

The session values from steps 1–4 serve as the source for:

- **`./pickup-label.md`** (rule 1): reads `pickupLabel` from the binding stored in step 3;
  no second `get_project_binding` call needed.
- **`./kg-recon.md`**: guard on `kg.present` from the step-3 binding; search tool is
  `mcp__<prefix>__<kg.searchTool>`.
- **`./orchestrator-auth.md`**: precondition is `<prefix>` from step 1.

## Step 6 — Per-repo facts

The following facts are not yet carried by the binding (AII-731 adds them as a fast follow;
once it ships, read them from the step-3 response first, falling back to `CLAUDE.md` only for
values the binding does not carry):

- `{{BUILD_CMD}}` — build/type-check command
- `{{PREVIEW_HOST}}` — preview deploy URL pattern
- `{{AUTH_PROVIDER}}` — auth provider name
- `{{ARCHITECT_NAME}}` — human who owns risky changes
- `{{AGENT_MENTION}}` — comment trigger for the AI coding agent

Read each from the repo's `CLAUDE.md` when present. If a fact is absent from `CLAUDE.md` and
the calling skill requires it:

- **Claude Code:** ask once per session and offer to append the resolved value to `CLAUDE.md`.
- **Chat:** ask once per session.
