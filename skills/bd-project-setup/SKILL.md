---
name: bd-project-setup
description: "Wire this repo's BuildDown skills to concrete tools for a project — bind the {{PLACEHOLDER}} tokens (tracker workspace/team, GitHub repo, AI-Implement label, build command, etc.) in CLAUDE.md, pre-approve the MCP servers, and drive each server's OAuth from inside the session. The builddown plugin already bundles the tracker server (linear-server), so setup usually does NOT need to write .mcp.json — it only authors .mcp.json for servers the plugin doesn't ship (e.g. github, or a non-default tracker). Trigger when the user says 'bd-project-setup', 'set up the skills', 'setup', 'wire up the relationships', 'configure the MCP servers', 'point Linear at this project', 'connect this repo to Linear/GitHub', or starts using these skills in a new project. Setup automates everything except the single in-browser OAuth approval, which is a hard boundary of OAuth."
metadata:
  suite: builddown
---

# BD Project Setup Skill

Wires the BuildDown skills (bd-build-up, bd-summit-push, bd-build-down, bd-super-build-down, bd-smoke-jumper, bd-belay-on)
to the concrete tools for **one** project. Everything the skills reference is a `{{PLACEHOLDER}}`
token; setup turns those tokens into real servers and values.

**What setup can automate:** pre-approving MCP servers, **starting each server's OAuth flow from inside
the session** (the server's `authenticate` tool returns a link, and `complete_authentication` finishes
it), and writing the `CLAUDE.md` bindings. It writes `.mcp.json` only when a needed server isn't already
provided by the plugin.

> **The plugin bundles the tracker server.** When these skills are installed via the `builddown`
> plugin, the plugin ships its own `.mcp.json` declaring **`linear-server`** (Linear at
> `https://mcp.linear.app/mcp`). That server travels with the plugin into every project, so for a
> Linear project you usually do **not** write a project-scoped `.mcp.json` — you just authenticate
> `linear-server` and record the workspace/team binding.
>
> **What actually varies per project — and where it lives:**
> - **Team** (e.g. `BDS`): a `CLAUDE.md` binding only, passed as a tool *parameter*. Different team →
>   edit `CLAUDE.md`, nothing else. The server is unchanged.
> - **Workspace**: chosen at OAuth time and tied to the token. A single named server holds **one**
>   workspace's auth at a time.
>
> So the bundled `linear-server` is genuinely shared across every project **that lives in the same
> Linear workspace** (only their `CLAUDE.md` team binding differs). A project in a **different
> workspace** cannot share it — author a project-scoped server with a **distinct name**
> (e.g. `linear-<workspace-slug>`), pre-approve it, bind `{{TRACKER}}` to it in that project's
> `CLAUDE.md`, and authenticate it to that workspace. **Do not reuse the name `linear-server` for a
> second workspace** — it collides with the bundled server. Also author a project `.mcp.json` for
> servers the plugin doesn't ship (e.g. `github`) or a non-Linear tracker.
>
> Whatever name a project binds, keep it identical across that server's `.mcp.json` entry,
> `enabledMcpjsonServers`, the `CLAUDE.md` binding, and the `mcp__<name>__*` tool calls. The bundled
> default is **`linear-server`**; additional workspaces get their own distinct names.

**What setup cannot automate:** the in-browser approval itself. OAuth requires a human to open the link,
approve, and pick the workspace — there is no token until that happens. But the human never has to leave
the session to find an MCP panel; setup produces the link and consumes the callback.

---

## Phase 0 — Detect existing setup

Before gathering any input or writing any files, read the project's current state. Use the Read
tool directly on each path; never infer from memory.

### Step 0.1 — Check for a local `.mcp.json`

Read **both** locations (either may exist):

1. `<project-root>/.mcp.json`
2. `<project-root>/.claude/.mcp.json`

For each location that exists, note the path and list every entry in `mcpServers`. If neither exists,
record: *no local `.mcp.json` found*.

### Step 0.2 — Check for `CLAUDE.md` bindings

Read `<project-root>/CLAUDE.md`. Look for the following variables (names may appear as headings,
bullet keys, or inline text):

| Variable | What to look for |
|---|---|
| `tracker.kind` | `linear` or `jira` |
| Tracker workspace | workspace name bound to the MCP server |
| Tracker team | team short-code (e.g. `BDS`) |
| `{{IMPLEMENT_LABEL}}` | label the coding-agent pickup trigger |
| `enabledMcpjsonServers` / server-approval state | whether servers are pre-approved in `.claude/settings.json` |

If `CLAUDE.md` is absent or contains none of these, record: *no CLAUDE.md bindings found*.

### Step 0.2b — Check for already-connected / already-permissioned tracker servers

A tracker can already be reachable even when this project has no local `.mcp.json` — e.g. via a
**global connector** or a server configured in another scope. Writing a fresh `linear` server in that
case creates a *duplicate* (and often a name mismatch that defeats the Phase 3 pre-approval). Check
before assuming "Not configured":

1. **Connected servers.** Run `claude mcp list` (Bash). Note every server already shown **Connected**,
   and whether any is a tracker (name contains `linear`, `jira`, `atlassian`, or its tools are
   `mcp__<name>__list_teams`-style). If a tracker is already Connected, record its **server name**.
2. **Permissioned server names.** Read `.claude/settings.json`, `.claude/settings.local.json`, and
   `~/.claude/settings.json`. Collect:
   - `enabledMcpjsonServers` entries
   - any `permissions.allow` entry of the form `mcp__<name>__*` — the `<name>` is an
     already-approved server name (e.g. `linear-server`, not necessarily `linear`).

   Record the existing tracker server name(s). **In Phase 2, reuse the existing name rather than
   hardcoding `linear`** — a `.mcp.json` server whose name doesn't match the already-permissioned
   `mcp__<name>__*` won't inherit that approval and will re-trigger the trust prompt.

> If a tracker is **already Connected** (step 1) and the project has no local `.mcp.json`, do **not**
> silently treat it as "Not configured." Surface it: *"A `<name>` tracker server is already connected
> (global/other scope). Want a project-scoped `.mcp.json` twin anyway, or rely on the existing
> connection?"* Only write a project-scoped server if the user wants the binding committed to the repo.

### Step 0.3 — Classify the local setup

Based on Steps 0.1 and 0.2, classify the project into one of three states:

| State | Condition |
|---|---|
| **Fully configured** | `.mcp.json` present with at least one tracker server entry **AND** all five CLAUDE.md variables bound |
| **Partially configured** | One of `.mcp.json` or CLAUDE.md bindings present but not both |
| **Not configured** | Neither `.mcp.json` nor CLAUDE.md bindings found |

### Step 0.4 — Report findings and ask what to do next

**If Fully configured:** Report the current parameters in a table:

```
Current setup detected:
  tracker.kind          : <value>
  Workspace             : <value>
  Team                  : <value>
  {{IMPLEMENT_LABEL}}   : <value>
  Server approval state : <enabled/not enabled>
  .mcp.json location    : <path>
```

Then ask: **"This project is already configured. Re-run setup to update the bindings, or keep
the current setup as-is?"** Wait for the user to choose one of:
- **Re-run** → proceed to Phase 1 (gather fresh values; phases 1–5 will merge, not clobber)
- **Keep** → stop here; do not modify any files

**If Partially configured:** Report what was found and what is missing, e.g.:

```
Partial setup detected:
  .mcp.json found at  : <path>
  CLAUDE.md bindings  : MISSING
```

Then ask: **"Setup is incomplete. Complete the missing wiring, or start over from scratch?"** Wait:
- **Complete** → proceed to Phase 1 (skip steps for what already exists)
- **Start over** → proceed to Phase 1 (treat as Not configured)

**If Not configured:** Skip to Step 0.5 to check for reusable servers from other projects.

### Step 0.5 — Scan for cross-project MCP servers (Not configured path only)

> **Trust boundary:** Read local config files only. Never copy auth tokens. Surface server names and
> command strings for a human decision — credential values must always be redacted.

Read `~/.claude.json`. If the file is absent or has no `projects` key, record *no other projects
found* and skip to Phase 1.

Otherwise, iterate over every entry in `projects[*].mcpServers`. For each MCP server entry, check
whether it is a tracker candidate using these heuristics (any match qualifies):

- Server `name` contains `linear`, `jira`, or `atlassian` (case-insensitive)
- `command` or `args` contain `@linear/mcp`, `mcp-linear`, `jira`, or `atlassian`
- `env` keys include `LINEAR_API_KEY`, `JIRA_*`, or `ATLASSIAN_*`

Build a numbered list of candidates. For each candidate, show:

| Field | Display |
|---|---|
| # | Sequential number |
| Name | Server `name`, or the `command` string if `name` is absent |
| Type / command | `type` + `url` for remote servers; `command` + `args` for local servers |
| Env keys | Key names only — values shown as `[redacted]` |
| Source project | Absolute path of the project where the entry was found |

> **Note:** On shared or multi-user machines, even env var *names* can hint at credential existence.
> Only surface these details to the project owner in a private session.

If one or more candidates are found, show the table and ask:

**"Found tracker MCP servers in other projects (listed above). Pick one to use as a template for
this project's `.mcp.json`, or configure from scratch?"**

Wait for the user to choose:
- **Use server N** → carry the server's `name`, `type`/`url` or `command`/`args` forward to Phase 2
  as pre-filled values. Do **not** carry env var values or auth tokens — the user must re-authenticate.
- **Configure from scratch** → proceed to Phase 1 with no pre-filled values

If no candidates are found, proceed to Phase 1 with a note: *no existing tracker MCP servers found
in other projects; configuring from scratch*.

---

## Phase 1 — Gather the bindings

Ask the user (or read from an existing `CLAUDE.md`) for the values. Only `{{TRACKER}}` is required to
start; the rest can be filled in later as the project needs them.

| Placeholder | Question | Example |
|---|---|---|
| `tracker.kind` | "Linear or Jira?" | `linear` (default) |
| `{{TRACKER}}` workspace + team | "Which Linear workspace and team?" | workspace `eudoxus`, team `BDS` |
| `{{REPO}}` | "Which GitHub repo do PRs land in?" | `org/product-repo` |
| `{{IMPLEMENT_LABEL}}` | "What label does the coding agent pick up?" | `AI-Implement` |
| `{{AGENT_MENTION}}` | "What PR-comment mention re-triggers the agent?" | `/ai-implement` |
| `{{PREVIEW_HOST}}` | "Where do preview deploys live?" | `https://pr-{n}.preview.app` |
| `{{AUTH_PROVIDER}}` | "How do you log into previews?" | Google SSO |
| `{{BUILD_CMD}}` | "Build/verify command?" | `npm run build && npm test` |
| `{{PLAN_DIR}}` | "Where do plan drafts go?" | `docs/plans/` (default) |
| `{{ARCHITECT_NAME}}` | "Persona name for bd-mega-build-up review?" | — |

## Phase 2 — `.mcp.json` (only for servers the plugin doesn't bundle)

**Skip this phase for the tracker on a Linear project in your default workspace** — the `builddown`
plugin already ships `linear-server`. Run it only to:
- add a server the plugin doesn't bundle (`github`),
- point at a **non-Linear tracker**, or
- point at a **different Linear workspace** than the bundled `linear-server`'s auth.

Linear and GitHub both expose a single fixed remote endpoint each. The **workspace** is chosen at OAuth
time, not in the URL. Never put a `linear.app/<workspace>/...` web URL in the server `url`.

```json
{
  "mcpServers": {
    "github": { "type": "http", "url": "https://api.githubcopilot.com/mcp/" }
  }
}
```

**Different-workspace tracker.** A single named server holds one workspace's OAuth, so a project in a
*second* workspace needs its own server under a **distinct name** — `linear-<workspace-slug>`, never
`linear-server` (that collides with the bundled server). Bind `{{TRACKER}}` to this name in the
project's `CLAUDE.md`:

```json
{ "mcpServers": { "linear-acme": { "type": "http", "url": "https://mcp.linear.app/mcp" } } }
```

Only write a bare `linear-server` here if the plugin is **not** installed in this project (no bundled
server exists to collide with). Validate the file parses (`python3 -m json.tool .mcp.json`).

> **Reuse the existing server name (from Step 0.2b).** If a tracker is already permissioned under a name
> in `permissions.allow` (e.g. `mcp__linear-acme__*`) or already Connected, use **that** name as the
> `mcpServers` key — don't introduce a second name for the same workspace. A mismatch means the server
> won't inherit the existing approval and the Phase 3 pre-approval and Phase 5 OAuth will target the
> wrong name. Keep the key identical across `.mcp.json`, `enabledMcpjsonServers`, the `CLAUDE.md`
> binding, and the `mcp__<name>__*` tool calls. The bundled default is **`linear-server`**; each
> additional workspace gets its own distinct name.

## Phase 3 — Pre-approve the servers (skip the trust prompt)

Project `.mcp.json` servers are untrusted until enabled. Add them to the **shared** `.claude/settings.json`
(committed, so teammates inherit the approval) so the interactive trust prompt never fires:

```json
{
  "enabledMcpjsonServers": ["linear-server", "github"]
}
```

List every server the project relies on, **including the plugin-bundled `linear-server`** — pre-approving
it here means the bundled tracker never triggers a trust prompt in this project. Use the shared
`settings.json` (not `settings.local.json`, which is gitignored and personal) so new joiners get the
approval. (`enableAllProjectMcpServers: true` trusts every server in `.mcp.json` at once.)

## Phase 4 — Write the `CLAUDE.md` bindings

Record the placeholder → value mapping at the project level so every skill resolves the same tools. At
minimum, the tracker workspace + **team** must be explicit, because issues get filed there.

```md
## Issue tracker — Linear
- tracker.kind: linear
- MCP server: `linear-server` (bundled by the builddown plugin; pre-approved in .claude/settings.json)
- Workspace: `eudoxus` (bound at OAuth time)
- Team: `BDS`  ← issues filed/listed/searched against this team
- Team URL: https://linear.app/eudoxus/team/BDS/overview
```

## Phase 5 — Authenticate each server (driven from the session)

Once a server is approved (Phase 3) but unauthenticated, it surfaces two auth tools — for the bundled
Linear server, `mcp__linear-server__authenticate` and `mcp__linear-server__complete_authentication`
(other servers follow the same `mcp__<server>__authenticate` pattern). Drive the flow without sending the
user to an MCP panel:

1. **Start the flow.** Call `mcp__<server>__authenticate`. It returns an authorization URL.
2. **Hand the user the link.** Ask them to open it, approve, and — for Linear — **select the target
   workspace** (e.g. `eudoxus`) in the grant.
3. **Finish the flow.** Two outcomes:
   - The redirect page loads and auth completes automatically — the server's real tools appear. Done.
   - The redirect page shows a connection error (common when nothing is listening on the
     `http://localhost:<port>/callback` redirect). Ask the user to copy the **full URL from the browser
     address bar** and call `mcp__<server>__complete_authentication` with it as `callback_url`.
4. **Verify.** `claude mcp list` should show the server **Connected** (not Pending / Needs
   authentication). Confirm the workspace by listing teams (`list_teams`) and checking the target team is
   present.

> Note: the in-browser approval is the one irreducible human step. Everything around it — starting the
> flow, presenting the link, consuming the callback, verifying — runs from inside the session.

---

## Notes

- `.mcp.json` is safe to commit — endpoints are non-secret and OAuth tokens are stored separately. Only
  gitignore it if a project wants per-developer server choices.
- Re-running setup is safe: it merges into existing config rather than clobbering it.
- For a different Linear workspace later, re-authenticate the server and pick the new workspace — the URL
  never changes.
