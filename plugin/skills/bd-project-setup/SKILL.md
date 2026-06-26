---
name: bd-project-setup
description: "Wire this repo's BuildDown skills to concrete tools for a project — write exactly ONE tracker MCP server (.mcp.json) for the project's tracker.kind (Linear OR Jira, never both), pre-approve it, drive its OAuth from inside the session, and bind the {{PLACEHOLDER}} tokens (tracker workspace/team, GitHub repo, AI-Implement label, build command, etc.) in CLAUDE.md. The builddown plugin ships skills only — it bundles no MCP servers — so every project provisions its own tracker here. Trigger when the user says 'bd-project-setup', 'set up the skills', 'setup', 'wire up the relationships', 'configure the MCP servers', 'point Linear at this project', 'connect this repo to Linear/Jira/GitHub', or starts using these skills in a new project. Setup automates everything except the single in-browser OAuth approval, which is a hard boundary of OAuth."
metadata:
  suite: builddown
---

# BD Project Setup Skill

Wires the BuildDown skills (bd-build-up, bd-summit-push, bd-build-down, bd-super-build-down, bd-smoke-jumper, bd-belay-on)
to the concrete tools for **one** project. Everything the skills reference is a `{{PLACEHOLDER}}`
token; setup turns those tokens into real servers and values.

**What setup can automate:** writing the project's `.mcp.json`, pre-approving its servers, **starting each
server's OAuth flow from inside the session** (the server's `authenticate` tool returns a link, and
`complete_authentication` finishes it), and writing the `CLAUDE.md` bindings.

> **One tracker per project — Linear XOR Jira.** The `builddown` plugin ships **skills only**; it bundles
> **no** MCP servers. So each project declares its own tracker in its own `.mcp.json`, and a project has
> **exactly one** tracker server, chosen by `tracker.kind`:
>
> | `tracker.kind` | Server name | Endpoint |
> |---|---|---|
> | `linear` | `linear-server` | `https://mcp.linear.app/mcp` |
> | `jira` | `jira-server` | Atlassian remote MCP (confirm the current URL/transport from Atlassian's docs) |
>
> Never put both in one project. The two trackers are exact analogs — everything below applies to each:
>
> | Concept | Linear | Jira |
> |---|---|---|
> | Chosen at OAuth time (one per server token) | **workspace** | **site** (`<site>.atlassian.net`) |
> | A `CLAUDE.md` binding / tool parameter only | **team** (e.g. `BDS`) | **project / epic** (e.g. `BAC`) |
> | Issue container | team | project + epic |
>
> **What varies per project — and where it lives:**
> - **Team / project** (the issue container): a `CLAUDE.md` binding only, passed as a tool *parameter*.
>   Different team → edit `CLAUDE.md`, nothing else; the server is unchanged.
> - **Workspace / site**: chosen at OAuth time and tied to the token. A single named server holds **one**
>   workspace/site's auth at a time.
>
> Because there's no shared/bundled server, project `.mcp.json` files are independent — two projects in
> the **same** workspace/site can both use the canonical name (`linear-server` / `jira-server`). If you
> operate **multiple** workspaces or sites of the same tracker kind and want zero ambiguity in auth, give
> each a **distinct name** (`linear-<workspace-slug>` / `jira-<site-slug>`). Whatever name a project binds,
> keep it identical across the `.mcp.json` entry, `enabledMcpjsonServers`, the `CLAUDE.md` binding, and the
> `mcp__<name>__*` tool calls.

**What setup cannot automate:** the in-browser approval itself. OAuth requires a human to open the link,
approve, and pick the workspace/site — there is no token until that happens. But the human never has to
leave the session to find an MCP panel; setup produces the link and consumes the callback.

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

## Phase 2 — Write `.mcp.json` (one tracker server, by `tracker.kind`)

Write **exactly one** tracker server, matching `tracker.kind`. Each tracker exposes a single fixed remote
endpoint; the workspace/site is chosen at OAuth time, never in the URL (never put a
`linear.app/<workspace>/...` or `<site>.atlassian.net` web URL in `url`).

**Linear project** (`tracker.kind: linear`):

```json
{
  "mcpServers": {
    "linear-server": { "type": "http", "url": "https://mcp.linear.app/mcp" }
  }
}
```

**Jira project** (`tracker.kind: jira`):

```json
{
  "mcpServers": {
    "jira-server": { "type": "http", "url": "https://mcp.atlassian.com/v1/sse" }
  }
}
```

> Confirm the current Atlassian remote-MCP URL and transport (`http` vs `sse`) against Atlassian's docs
> before committing — the tracker adapters discover Jira tool names at runtime, but the server URL must be
> right. Do **not** add a Linear server to a Jira project or vice versa: one tracker per project.

Add `github` **only if** the project needs GitHub MCP operations (it is not a tracker, so it doesn't
break the one-tracker rule):

```json
{ "mcpServers": { "github": { "type": "http", "url": "https://api.githubcopilot.com/mcp/" } } }
```

Include only the servers the project actually uses. Validate it parses (`python3 -m json.tool .mcp.json`).

> **Reuse an already-permissioned name (from Step 0.2b).** If this project already has the tracker
> permissioned under a name in `permissions.allow` (e.g. `mcp__linear-server__*`) or already Connected,
> use **that** name as the `mcpServers` key rather than introducing a second one — a mismatch means the
> server won't inherit the existing approval and Phase 3/Phase 5 will target the wrong name. Keep the key
> identical across `.mcp.json`, `enabledMcpjsonServers`, the `CLAUDE.md` binding, and the `mcp__<name>__*`
> tool calls. Canonical names: **`linear-server`** / **`jira-server`**; for multiple workspaces/sites of
> the same kind, use distinct `linear-<slug>` / `jira-<slug>` names.

## Phase 3 — Pre-approve the servers (skip the trust prompt)

Project `.mcp.json` servers are untrusted until enabled. Add them to the **shared** `.claude/settings.json`
(committed, so teammates inherit the approval) so the interactive trust prompt never fires:

```json
{
  "enabledMcpjsonServers": ["linear-server", "github"]
}
```

List exactly the servers in this project's `.mcp.json` — the one tracker (`linear-server` **or**
`jira-server`) plus `github` if used. Use the shared `settings.json` (not `settings.local.json`, which is
gitignored and personal) so new joiners get the approval. (`enableAllProjectMcpServers: true` trusts every
server in `.mcp.json` at once.)

## Phase 4 — Write the `CLAUDE.md` bindings

Record the placeholder → value mapping at the project level so every skill resolves the same tools. At
minimum, the tracker workspace + **team** must be explicit, because issues get filed there.

**Linear:**

```md
## Issue tracker — Linear
- tracker.kind: linear
- MCP server: `linear-server` (project .mcp.json; pre-approved in .claude/settings.json)
- Workspace: `eudoxus` (bound at OAuth time)
- Team: `BDS`  ← issues filed/listed/searched against this team
- Team URL: https://linear.app/eudoxus/team/BDS/overview
```

**Jira** (same shape; site replaces workspace, project/epic replaces team):

```md
## Issue tracker — Jira
- tracker.kind: jira
- MCP server: `jira-server` (project .mcp.json; pre-approved in .claude/settings.json)
- Site: `cloudshare` (cloudshare.atlassian.net — bound at OAuth time)
- Project / epic: `BAC` / epic `BAC-23858`  ← issues filed as children of this epic
- Browse URL: https://cloudshare.atlassian.net/browse/{KEY}
```

## Phase 5 — Authenticate each server (driven from the session)

Once a server is approved (Phase 3) but unauthenticated, it surfaces two auth tools —
`mcp__<server>__authenticate` and `mcp__<server>__complete_authentication` (e.g.
`mcp__linear-server__authenticate` / `mcp__jira-server__authenticate`). Drive the flow without sending the
user to an MCP panel:

1. **Start the flow.** Call `mcp__<server>__authenticate`. It returns an authorization URL.
2. **Hand the user the link.** Ask them to open it, approve, and **select the target workspace** (Linear,
   e.g. `eudoxus`) or **site** (Jira, e.g. `cloudshare.atlassian.net`) in the grant.
3. **Finish the flow.** Two outcomes:
   - The redirect page loads and auth completes automatically — the server's real tools appear. Done.
   - The redirect page shows a connection error (common when nothing is listening on the
     `http://localhost:<port>/callback` redirect). Ask the user to copy the **full URL from the browser
     address bar** and call `mcp__<server>__complete_authentication` with it as `callback_url`.
4. **Verify.** `claude mcp list` should show the server **Connected** (not Pending / Needs
   authentication). Confirm the right workspace/site by listing the container — Linear: `list_teams`,
   checking the target team is present; Jira: list projects / the target epic's children — before filing.

> Note: the in-browser approval is the one irreducible human step. Everything around it — starting the
> flow, presenting the link, consuming the callback, verifying — runs from inside the session.

---

## Notes

- The `builddown` plugin bundles **no** MCP servers — it ships skills only. Every project provisions its
  own one tracker here, so a Linear project never carries a Jira server and vice versa.
- `.mcp.json` is safe to commit — endpoints are non-secret and OAuth tokens are stored separately. Only
  gitignore it if a project wants per-developer server choices.
- Re-running setup is safe: it merges into existing config rather than clobbering it.
- For a different workspace/site later, re-authenticate the same server and pick the new one — the URL
  never changes. (Switching `tracker.kind` between Linear and Jira means replacing the one tracker server,
  not adding a second.)
