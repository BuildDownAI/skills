---
name: bd-project-setup
description: "Wire this repo's BuildDown skills to concrete tools for a project — write the project-scoped MCP servers (.mcp.json), pre-approve them, drive each server's OAuth from inside the session, and bind the {{PLACEHOLDER}} tokens (tracker workspace/team, GitHub repo, AI-Implement label, build command, etc.) in CLAUDE.md. Trigger when the user says 'bd-project-setup', 'set up the skills', 'setup', 'wire up the relationships', 'configure the MCP servers', 'point Linear at this project', 'connect this repo to Linear/GitHub', or starts using these skills in a new project. Setup automates everything except the single in-browser OAuth approval, which is a hard boundary of OAuth."
---

# BD Project Setup Skill

Wires the BuildDown skills (build-up, summit-push, build-down, super-build-down, smoke-jumper, belay-on)
to the concrete tools for **one** project. Everything the skills reference is a `{{PLACEHOLDER}}`
token; setup turns those tokens into real servers and values.

**What setup can automate:** writing `.mcp.json`, pre-approving project MCP servers, **starting each
server's OAuth flow from inside the session** (the server's `authenticate` tool returns a link, and
`complete_authentication` finishes it), and writing the `CLAUDE.md` bindings.

**What setup cannot automate:** the in-browser approval itself. OAuth requires a human to open the link,
approve, and pick the workspace — there is no token until that happens. But the human never has to leave
the session to find an MCP panel; setup produces the link and consumes the callback.

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
| `{{ARCHITECT_NAME}}` | "Persona name for mega-build-up review?" | — |

## Phase 2 — Write `.mcp.json` (project-scoped servers)

Linear and GitHub both expose a single fixed remote endpoint each. The **workspace** is chosen at OAuth
time, not in the URL. Never put a `linear.app/<workspace>/...` web URL in the server `url`.

```json
{
  "mcpServers": {
    "linear": { "type": "http", "url": "https://mcp.linear.app/mcp" },
    "github": { "type": "http", "url": "https://api.githubcopilot.com/mcp/" }
  }
}
```

Only include servers the project actually uses. Validate it parses (`python3 -m json.tool .mcp.json`).

## Phase 3 — Pre-approve the servers (skip the trust prompt)

Project `.mcp.json` servers are untrusted until enabled. Add them to the **shared** `.claude/settings.json`
(committed, so teammates inherit the approval) so the interactive trust prompt never fires:

```json
{
  "enabledMcpjsonServers": ["linear", "github"]
}
```

Use the shared `settings.json` (not `settings.local.json`, which is gitignored and personal) so new joiners
get the approval. (`enableAllProjectMcpServers: true` trusts every server in `.mcp.json` at once.)

## Phase 4 — Write the `CLAUDE.md` bindings

Record the placeholder → value mapping at the project level so every skill resolves the same tools. At
minimum, the tracker workspace + **team** must be explicit, because issues get filed there.

```md
## Issue tracker — Linear
- tracker.kind: linear
- MCP server: `linear` (.mcp.json)
- Workspace: `eudoxus` (bound at OAuth time)
- Team: `BDS`  ← issues filed/listed/searched against this team
- Team URL: https://linear.app/eudoxus/team/BDS/overview
```

## Phase 5 — Authenticate each server (driven from the session)

Once a server is approved (Phase 3) but unauthenticated, it surfaces two auth tools — for Linear,
`mcp__linear__authenticate` and `mcp__linear__complete_authentication` (other servers follow the same
`mcp__<server>__authenticate` pattern). Drive the flow without sending the user to an MCP panel:

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
