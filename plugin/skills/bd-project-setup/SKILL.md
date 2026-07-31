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
> | A `CLAUDE.md` binding / tool parameter only | **team** (e.g. `BDS`) | **project / epic** (e.g. `PROJ`) |
> | Issue container | team | project + epic |
>
> **What varies per project — and where it lives:**
> - **Team / project** (the issue container): a `CLAUDE.md` binding only, passed as a tool *parameter*.
>   Different team → edit `CLAUDE.md`, nothing else; the server is unchanged.
> - **Workspace / site**: chosen at OAuth time and tied to the token. A single named server holds **one**
>   workspace/site's auth at a time.
>
> **Name the server after its workspace/site — not a generic `linear-server` — the moment more than one
> workspace is in play.** Claude Code ties a server's OAuth **token to the server name**, so every project
> that uses the name `linear-server` shares **one** token = **one** workspace. The failure this causes:
> a new project's `linear-server` comes up **already Connected** to whatever workspace that shared token
> holds (e.g. `acme`), and Linear's OAuth often **auto-completes to your default workspace** without
> showing a picker. The only way to put `linear-server` on a *different* workspace is to re-authenticate
> it — which **repoints every other project using that name**. That is a trap, not a fix.
>
> **Rule:**
> - **One Linear workspace ever** → `linear-server` is fine.
> - **More than one workspace** (or any doubt) → name each per workspace: **`linear-<workspace-slug>`**
>   (e.g. `linear-eudoxus`, `linear-acme`). Each gets its own token, so they coexist and never steal
>   each other's auth. Same for Jira sites: **`jira-<site-slug>`**.
>
> Whatever name a project binds, keep it identical across the `.mcp.json` entry, `enabledMcpjsonServers`,
> the `CLAUDE.md` binding, and the `mcp__<name>__*` tool calls. **Never repoint a shared-name server to
> "fix" a workspace** — give the new workspace its own name instead (see Step 0.2c).

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
| `## Knowledge graph` block | `kg.present`, `kg.repo`, `kg.path`, `kg.branch`, `kg.mcp_server`, `kg.search_tool` (see Phase K) |

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

### Step 0.2c — If a tracker is Connected, verify it's on THIS project's workspace/site

A Connected tracker server is **not** proof it's the right one — it may be authenticated to a different
workspace/site (and may have auto-completed there without a picker). Before binding anything:

1. **Check which workspace/site it holds.** Linear: call `mcp__<name>__list_teams` and see whether this
   project's target team is present. Jira: list projects/sites and check for the target project. Record
   the workspace/site the server is actually on.
2. **If it matches** the project's target → good, proceed.
3. **If it does NOT match** (e.g. server is on `acme`, project needs `eudoxus`) → **do not
   re-authenticate the shared server and do not propose removing the other workspace.** Re-auth repoints
   that name for *every* project using it. Instead, pick one of:

   | Situation | Action |
   |---|---|
   | Another project already has a server on the target workspace (found in Step 0.5) | Reuse **that** server's name/definition for this project; just authenticate it here if needed. |
   | No server exists yet for the target workspace | Define a **new, distinctly-named** server `linear-<target-workspace>` (e.g. `linear-eudoxus`) in Phase 2. Because the name is new and unauthenticated, its `authenticate` tool **is** exposed, so setup can drive first-time OAuth from the session — and the user picks the right workspace in the grant. |
   | You truly want to MOVE the shared server to the new workspace and nothing else uses it | Only then re-authenticate — and because a *Connected* server hides its `authenticate` tool, this goes through the interactive `/mcp` panel → select the server → **Reauthenticate** (see Phase 5). |

   Default to the **distinct name** path — it never disturbs an existing workspace's auth.

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

**Pick the server name by how many workspaces/sites you run** (see the intro callout + Step 0.2c):
use the bare `linear-server` / `jira-server` only if there will ever be **one** workspace/site of that
kind; otherwise name it after the workspace/site — `linear-<workspace>` / `jira-<site>` — so each gets
its own OAuth token and they never steal each other's auth.

**Linear project** (`tracker.kind: linear`) — single-workspace name shown; use `linear-<workspace>` if
you run more than one:

```json
{
  "mcpServers": {
    "linear-eudoxus": { "type": "http", "url": "https://mcp.linear.app/mcp" }
  }
}
```

**Jira project** (`tracker.kind: jira`):

```json
{
  "mcpServers": {
    "jira-<workspace>": { "type": "http", "url": "https://mcp.atlassian.com/v1/sse" }
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
- Site: `<your-workspace>` (<your-workspace>.atlassian.net — bound at OAuth time)
- Project / epic: `PROJ` / epic `PROJ-1234`  ← issues filed as children of this epic
- Browse URL: https://<your-workspace>.atlassian.net/browse/{KEY}
```

## Phase 5 — Authenticate each server (driven from the session)

Once a server is approved (Phase 3) but unauthenticated, it surfaces two auth tools —
`mcp__<server>__authenticate` and `mcp__<server>__complete_authentication` (e.g.
`mcp__linear-server__authenticate` / `mcp__jira-server__authenticate`). Drive the flow without sending the
user to an MCP panel:

1. **Start the flow.** Call `mcp__<server>__authenticate`. It returns an authorization URL.
2. **Hand the user the link.** Ask them to open it, approve, and **explicitly select the target workspace**
   (Linear, e.g. `eudoxus`) or **site** (Jira, e.g. `<your-workspace>.atlassian.net`) in the grant — Linear's
   consent page has a workspace switcher near the top. **Do not let it auto-complete to the default
   workspace** (a common cause of landing on the wrong one). If it does, that's the wrong-workspace case —
   handle it per Step 0.2c (give this workspace its own server name), not by repointing a shared server.
3. **Finish the flow.** Two outcomes:
   - The redirect page loads and auth completes automatically — the server's real tools appear. Done.
   - The redirect page shows a connection error (common when nothing is listening on the
     `http://localhost:<port>/callback` redirect). Ask the user to copy the **full URL from the browser
     address bar** and call `mcp__<server>__complete_authentication` with it as `callback_url`.
4. **Verify.** `claude mcp list` should show the server **Connected** (not Pending / Needs
   authentication). Confirm the right workspace/site by listing the container — Linear: `list_teams`,
   checking the target team is present; Jira: list projects / the target epic's children — before filing.
   If the wrong workspace/site shows up, go back to Step 0.2c — **don't** bind the project to it.

> **Re-authenticating an already-Connected server.** Once a server is Connected, its `authenticate` /
> `complete_authentication` tools are **no longer exposed**, so setup cannot re-drive OAuth from the
> session. Re-auth then goes through the interactive `/mcp` panel → select the server → **Reauthenticate**.
> Remember this **repoints that server name for every project using it** — only do it for a server you
> intend to move wholesale. To put a *different* workspace on a fresh project, prefer a new distinctly-named
> server (Step 0.2c), whose `authenticate` tool *is* exposed because it has never connected.

> Note: the in-browser approval is the one irreducible human step. Everything around it — starting the
> flow, presenting the link, consuming the callback, verifying — runs from inside the session.

---

## Phase K — Knowledge graph (optional)

Wires an **optional** per-project knowledge graph (KG) that KG-aware skills (e.g. `bd-kg-search`) query
via hybrid search. This phase never runs automatically as part of Phases 0–5 above — it is a distinct,
opt-in pass over the same detect → classify → confirm discipline as Phase 0. Skipping this phase entirely
leaves KG-aware skills as silent no-ops (`docs/kg-binding.md` — *Semantics*), so a project that never runs
Phase K is not "misconfigured," just KG-less.

### Step K.1 — Detect

Read the project `CLAUDE.md` for an existing `## Knowledge graph` block, and `.mcp.json` for a
`<project-slug>-kg` server entry. Classify the result — never clobber:

| State | Condition |
|---|---|
| **Bound & present** | `## Knowledge graph` block exists with `kg.present: true` **AND** the `<slug>-kg` server is in `.mcp.json` |
| **Partially wired** | One of the block or the server entry exists, but not both |
| **Not wired** | Neither the block nor the server entry exists |
| **Deliberately absent** | `## Knowledge graph` block exists with `kg.present: false` |

Report the classification to the user before doing anything else. If **Bound & present** or
**Deliberately absent**, confirm with the user before making any change — both are valid end states.

### Step K.2 — Decide

Probe the discovery convention `<project-owner>/knowledge-graph-<project-slug>` read-only:

```bash
gh repo view <project-owner>/knowledge-graph-<project-slug>
```

Present the finding (repo exists / not found) to the operator and ask them to:
- **Confirm** the probed owner/slug, or
- **Override** the slug (a different `knowledge-graph-<slug>` name or owner), or
- **Declare "no KG"** → write `kg.present: false` into the `## Knowledge graph` block (Step K.5's format)
  and **end this phase** here — do not proceed to K.3.

### Step K.3 — Bootstrap missing pieces

Only for the pieces Step K.1 found missing:

**(a) Clone, if not already checked out at `kg.path`:**

```bash
git clone <kg.repo origin> <kg.path>
git -C <kg.path> checkout <kg.branch>   # default: knowledge-graph
```

**(b) Write the MCP server entry, if no `<project-slug>-kg` server exists in `.mcp.json`** (all paths
absolute, derived from `kg.path`). Server name is `<project-slug>-kg` — e.g. for slug `acme`:

```json
"acme-kg": {
  "command": "/abs/path/to/kg.path/.venv/bin/python",
  "args": ["-m", "kg_query.server"],
  "cwd": "/abs/path/to/kg.path",
  "env": { "KG_BACKEND": "rdflib", "PYTHONPATH": "/abs/path/to/kg.path" }
}
```

Then add `"<project-slug>-kg"` to `enabledMcpjsonServers` in `.claude/settings.json` (same shared,
committed file as Phase 3) so the server is pre-approved. This server is **read-only stdio — no OAuth
flow** — there is no authenticate/complete_authentication step like Phase 5.

### Step K.4 — Build

Invoke the **`bd-kg-refresh`** skill so the graph and its embeddings exist (or are brought current).
Setup does not duplicate ingest logic — `bd-kg-refresh` owns the venv-provisioning and ingest run.

### Step K.5 — Bind

Write or merge the `## Knowledge graph` block into `CLAUDE.md`, per the canonical format in
`docs/kg-binding.md`. Merge into any existing block rather than overwriting it — preserve values the
user has already customized and only fill in what Steps K.1–K.4 newly established.

### Step K.6 — Restart note

Tell the operator: a Claude Code restart is required before the `<project-slug>-kg` MCP server serves
the graph — MCP servers load once at session start, so a newly-wired server (or a graph rebuilt by
`bd-kg-refresh`) isn't picked up by an already-running session until it restarts.

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
- **Feature-branch grouping (both trackers).** If a project will use AI-Implement parent/child
  *feature-branch grouping*, re-sync workflows so the target repo's `claude-implement.yml` accepts the
  `base_branch` input — un-synced repos 422 on grouped dispatch (the non-grouped path keeps working). This
  applies to **Linear and Jira** target repos alike; only designation differs (Linear label vs Jira
  `AI-Implement-Status` + Repo field). Full model: `docs/feature-branch-grouping.md`.
