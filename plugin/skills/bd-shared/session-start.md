# Session Start

Shared discovery-and-binding procedure. Run once at the start of every skill session that
needs the orchestrator. Stores session values (`prefix`, `team`, `defaultBranch`, `tracker`,
`pickupLabel`, `kg`) for all subsequent steps in the session.

Pattern anchor: `./pickup-label.md` (tool-presence check first, printed source line) and
`./kg-recon.md`.

## Step 1 — Discover the orchestrator connector

Use ToolSearch with the query `__get_project_binding`.

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

## Step 4 — Tracker connector check

For **`tracker.kind = linear`**:

Use ToolSearch for the suffix `__list_teams`.

- **None found — no connector at all:** print exactly —
  > No Linear connector is enabled in this session; this repo's orchestrator mapping expects team \<team\>. Add or enable it at claude.ai connectors.

  Stop for skills that write to the tracker. Read-only skills continue.

- **Exactly one found:** call `list_teams`. Check whether a team with key `tracker.team` is
  present.

  - **Not found — wrong workspace:** print exactly —
    > The Linear connector is signed into a workspace without team \<team\>; this repo's orchestrator mapping expects it. Reconnect the connector to that workspace.

    Stop for skills that write to the tracker. Read-only skills continue.

  - **Found:** print one line: `tracker: Linear team <tracker.team> ✓`

For **`tracker.kind = jira`**:

Use ToolSearch for the suffix `__list_projects` (Atlassian connector).

- **None found — no connector at all:** print exactly —
  > No Atlassian connector is enabled in this session; this repo's orchestrator mapping expects project \<team\>. Add or enable it at claude.ai connectors.

  Stop for skills that write to the tracker. Read-only skills continue.

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
