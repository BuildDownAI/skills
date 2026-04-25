---
name: build-down
description: "Run a build-down session — drive open PRs to merge. Trigger this skill when the user says 'build-down', 'let's do a build-down', 'drive PRs to merge', 'PR triage', or asks to review and merge open pull requests. A build-down is an active sprint-closure session — survey the issue tracker and open GitHub PRs, assess each one against its gap analysis, drive gaps to resolution autonomously via PR comments to the AI coding agent, merge clean PRs, file minimal new tracker issues only when blockers are discovered, and leave the board cleaner than it started. This skill assumes a workflow with an issue tracker (e.g., Linear MCP), GitHub MCP, browser automation MCP for preview testing, and an AI coding agent that opens PRs in response to issues."
---

# Build-Down Skill

A build-down drives open PRs to merge. Mission: fewer open PRs, cleaner tracker, no blockers left undocumented, no gaps left unfixed when they could be fixed in-session.

**Guiding principle — drive to standard.** If a gap is visible and a coding-agent comment can fix it in the existing PR, post the comment now. Don't defer real work to "future build-up" or "follow-up issue" when the fix is one comment away. The park-and-trash rule: if we're walking past it and can pick it up, we pick it up.

**Autonomy default.** This skill runs autonomously by default. Post coding-agent comments, merge clean PRs, file session summaries, and move issues between states without asking. Escalate to the user only for pattern breaks (defined below).

---

## Configuration

This skill assumes some setup the user has wired up. Names of services and roles vary — substitute as needed.

- `{{TRACKER}}` — the issue tracker (e.g., Linear, Jira, GitHub Issues). The skill assumes an MCP integration that supports `list_issues`, `get_issue`, `save_issue` (or equivalent create/update).
- `{{REPO}}` — the GitHub repo, owner/name format.
- `{{PREVIEW_HOST}}` — the preview deploy URL pattern, typically `pr-{N}-{app}.{provider}.dev` or similar.
- `{{AGENT_MENTION}}` — how the AI coding agent listens for follow-up requests on PRs (e.g., `@claude`, `@copilot`, an explicit command). The skill uses `@agent` as a placeholder — substitute the real mention.
- `{{ARCHITECT_NAME}}` — the human who owns risky changes (migrations, auth, infrastructure). Optional — single-operator setups skip the routing rules.
- `{{IMPLEMENT_LABEL}}` — the label on issues that triggers the AI coding agent pipeline (e.g., `ai-implement`, `agent-build`).
- `{{BUILD_CMD}}` — the verification command for type-checked code (e.g., `next build`, `tsc --noEmit`, `cargo check`).

The skill is written assuming an AI coding agent that opens PRs in response to labeled issues and posts a gap-analysis comment when the PR is ready for review. The pattern works with any agent that does this — the workflow is the contract, not the specific tool.

---

## Environment and Pipeline Context

### Environment detection

This skill runs in three environments with different capabilities. Detect which from available tools, state it at the start of the session, and adapt accordingly.

**Chat environment (web/mobile, e.g., claude.ai):**
- Has: tracker MCP, GitHub MCP (via connector), browser automation MCP (when extension active), project context, conversation memory, past-chat search
- Lacks: bash, local filesystem, git, ability to run build commands or apply migrations
- Use for: triage, sequencing, agent comments, merging via GitHub MCP, session summaries, filing issues
- Belay-on to a code-execution environment when: a conflict needs local resolution, a migration needs manual application, a test needs to run locally

**Code-execution environment (terminal, e.g., Claude Code):**
- Has: bash, local filesystem, git, can push commits, tracker MCP if configured
- Lacks: project memory across sessions, broad strategic context
- Use for: local conflict resolution, running build commands, applying migrations, testing fixes before push
- Belay-on to chat when: the session needs strategic context about a PR's history or product intent

**Code-reading agent (e.g., a desktop tool with deep filesystem access):**
- Has: deep codebase reading, grep across files
- Lacks: tracker MCP, GitHub MCP, project memory
- Use for: narrow code pattern searches when chat's read operations are too slow
- Most former code-reading-agent use cases are now better handled in chat with GitHub MCP

**Opening declaration:** At session start, state the environment and primary tools. Example: *"Running in chat. Tracker MCP + GitHub MCP available, will use browser MCP if PR UI interaction is needed."*

### The AI coding agent pipeline (running system, not manual workflow)

The pipeline runs continuously. Never treat pipeline state as a surprise.

- When an issue is in **Todo** with the `{{IMPLEMENT_LABEL}}` label → the agent picks it up within minutes
- Agent moves the issue to a working state (e.g., **In Progress** or a custom **Working** state) and opens a PR against a branch named for the issue
- When the PR is ready, agent moves the issue to **In Review** and posts a gap analysis comment (structure below)
- A working state is expected, not alarming. **In Review** means work is ready for triage.

If an issue you expected to act on is already in a working or In Review state, the pipeline beat you to it. Read the PR, don't re-file the work.

### The gap analysis document

Every PR opened by the AI coding agent should include a gap analysis comment with three sections (or equivalent — adapt to the agent in use):

- **✅ Implemented** — what the agent claims works
- **⚠️ Gaps / Partial Implementation** — where the agent fell short or punted
- **🔧 Manual Steps Required** — things the agent physically can't do (one-time infra setup, secret configuration, manual deploys)

This document is the primary PR assessment. Read it first, before the diff. Verify its claims against code only for load-bearing items (acceptance criteria, security, data integrity, migrations).

If the agent in use doesn't produce a structured gap analysis, build the equivalent assessment from the PR description and diff before triaging.

---

## Phase 1: Orient

Pull current state before assessing anything. Use tracker MCP and GitHub MCP in parallel.

**Tracker scan:**
- `list_issues` filtered by `state: "In Progress"`
- `list_issues` filtered by `state: "In Review"`
- `list_issues` filtered by `state: "Todo"` and label `{{IMPLEMENT_LABEL}}`
- Note any custom working state (pipeline is actively running)

**GitHub PR scan:**
Use GitHub MCP for structured PR data:
- `list_pull_requests` for `{{REPO}}`, state: open
- For each open PR, `get_pull_request` to capture title, branch, base, mergeable state, author
- `get_pull_request_status` for CI check state
- `get_pull_request_files` for diff summary
- Read comments via PR page to find the gap analysis (posted by the AI coding agent)

**Browser MCP supplement:** Use only when GitHub MCP data is incomplete — e.g., to visually confirm a conflict marker, read a threaded comment chain, or test a preview deploy URL.

**What to read per PR, in this order:**

1. PR title and linked issue ID (from the branch name or PR title)
2. `get_issue` on the linked tracker issue to capture acceptance criteria
3. Gap analysis comment (✅ / ⚠️ / 🔧 sections)
4. CI check status (passing/failing/pending)
5. Mergeable state (clean/conflicted/behind)
6. Diff summary — file count and which paths changed
7. For PRs with migrations: the migration filename and contents

Don't read the full diff at this stage. Full diff reads are for verification in Phase 2, not orientation.

**Present the orientation table:**

```
PR # | Issue | Gap Count | Checks | Conflicts | Migration | Files | Age
```

Flag any PR >5 days old — it's likely stale and needs a context check before normal triage.

---

## Phase 2: Gap-Analysis-Driven Triage

For each PR, work through its gap analysis section by section. The order matters: gaps before merge decisions.

### 2a. Process ⚠️ Gaps / Partial Implementation

For each gap item, classify:

**Agent-fixable (default — act autonomously):**
- Gap is a code-level fix (add a function, wire up a reporting call, add a test)
- Scope is contained to the existing PR's files
- No product decision required — the acceptance criteria or gap text tells you what to build
- Not on the pattern-break list (Phase 2d)

**Action:** Post an agent comment that specifies the fix. Use the template in Phase 3. Post without asking.

**Out of scope (file follow-up issue):**
- Gap describes work the original issue didn't require
- Gap is a net-new feature the agent surfaced as "would be nice"
- Gap requires a product decision

**Action:** Create a new tracker issue. If the fix is well-scoped and should be worked on soon: `state: Todo`, label `{{IMPLEMENT_LABEL}}`, full context in the body. If it needs planning or discussion: `state: Backlog` with a note about why it was deferred. Never drop a gap silently — either fix it or file it.

**Acceptable as-is (log only):**
- Gap is cosmetic or describes an edge case outside acceptance criteria
- Gap is explicitly scoped out by the issue body

**Action:** Note in session summary, do not act.

### 2b. Process 🔧 Manual Steps Required

Manual steps are by nature not agent-fixable — the agent surfaces them because a human needs to do them (one-time infra setup, secret configuration, dashboard changes).

- Do not treat manual steps as merge blockers — the code can merge and deploy; the manual step happens in parallel or after
- Log every manual step in the session summary under a "Manual Steps" section
- If the manual step is something the user would want visibility on before merge (e.g., a secret that must exist before the first cron run), flag it in the pre-merge summary

### 2c. Verify ✅ Implemented claims (load-bearing only)

The agent's self-report is usually accurate but not always. Verify specifically when the claim touches:

- Acceptance criteria from the tracker issue body (`get_issue` to retrieve)
- Security (auth, row-level security, credential handling)
- Data integrity (migrations, schema, deletion logic)
- Anything the user flagged in the original issue as load-bearing

For each verification, cross-reference against the actual diff (`get_pull_request_files` or read the specific file). If the claim doesn't hold:

- Post an agent comment requesting the correction (autonomous)
- Note the discrepancy in session summary — patterns of over-claiming are pipeline signal worth tracking

Do not verify every ✅ bullet. Cosmetic items, logging additions, minor helper functions don't need verification unless something looks off.

### 2d. Pattern-break escalation list

Escalate to the user (ask before acting) when ANY of these apply:

1. **Gap requires a product decision** — "should we show X or Y?" — the user decides
2. **Agent has already failed on this specific gap** in this PR (one prior attempt in the comment history)
3. **Any SQL migration** — additive, data-only, or destructive. The architect (if defined) owns migration application.
4. **Touches auth, row-level security, security middleware, or auth provider config** — never autonomous
5. **Fix would modify >5 files or cross PR boundaries**
6. **PR is >5 days old** — context may have shifted, check before driving

For escalations, present:

```
🚨 Escalation: PR #{N} — {title}

Pattern break: {which rule triggered}
Gap/issue: {description}
My recommendation: {what I'd do if autonomous}
Options: {merge now / agent comment with {draft} / file issue / hold / close}
```

### 2e. Migration handling (always escalated)

For any PR with a SQL migration:

1. Read the migration file(s) and summarize what they do
2. Classify:
   - 🟢 **Additive** — new columns/tables with defaults, indexes, backfill
   - 🟡 **Data-only** — UPDATE/INSERT, no schema change
   - 🔴 **Destructive** — DROP, RENAME, NOT NULL without default, constraint changes
3. Check if any other open PR touches the same tables — flag collision risk
4. Include the raw SQL in the escalation so the architect can review directly
5. Log in the migration queue (Phase 6) with urgency level

Never auto-merge a PR with a migration, even if everything else is clean. The architect's visibility on migration timing is non-negotiable. (For single-operator setups: still surface the migration explicitly, don't merge it silently.)

### 2f. Merge conflict handling

When a PR has a conflict:

**If the conflict is clear-cut (autonomous agent comment):**
- Both branches added imports → keep both
- Both branches added config entries → keep both
- Independent additions to the same file with no functional overlap

Post an agent comment (Phase 3 template) instructing `git merge main` and keeping both sets of changes. Do not merge until the agent resolves and re-verifies.

**If the conflict involves business logic (escalate):**
- Both branches modified the same function differently
- Conflict in a migration file
- Conflict in auth/security code
- Changes that would behave differently based on resolution choice

Escalate per Phase 2d with the conflict details and a resolution recommendation.

### 2g. Mock data awareness

PRs that show "No data" or "Not found" errors in preview usually indicate mock data gaps in the seed/fixture layer, not code defects. Check the issue's acceptance criteria:

- If real data wiring was required → agent comment to wire it
- If empty state is acceptable → note in summary, don't block merge

### 2h. Merge-sequencing analysis

Before merging anything, check for file overlap across open PRs:

- Via GitHub MCP: `get_pull_request_files` for each open PR, compare paths
- Via code-execution environment: `git diff --name-only origin/main...origin/{branch}` per branch, then `comm -12` on sorted outputs

If any two open PRs touch the same file:
- Flag in the triage table: "⚠️ Overlaps with PR #X on `{file}`"
- Recommend merge order (smaller/simpler first, or backend before frontend if there's a dependency)
- Pre-draft the agent conflict resolution comment for the second PR so it's ready when the conflict appears post-merge
- Never merge overlapping PRs simultaneously

Recommended merge order (when no overlap or dependencies dictate):

1. Smallest clean PRs first (fastest to verify, smallest blast radius)
2. Backend before frontend (when frontend depends on backend API)
3. PRs that unblock the most downstream work (check `blockedBy` on tracker issues)
4. Oldest among equals (don't let PRs go stale)

Phase 2h's ordering rules override any default "oldest first" instinct.

---

## Phase 3: Agent Comment Templates and Posting

### Template: single gap fix

```
@agent follow-up from gap analysis:

**Gap:** {quote the gap analysis bullet verbatim}

**Resolution:** {specific, testable instruction}
- {file path and what to change}
- {expected behavior after fix}

**Verification:**
- {specific behavioral check}
- `{{BUILD_CMD}}` passes

This should be a scoped change within this PR — no need to open a new branch.
```

### Template: merge conflict

```
@agent There is a merge conflict in `{file path}`. Please resolve by running `git merge main` and keeping both sets of changes:

- **From this branch ({ISSUE-ID}):** {what this branch added — be specific about functions, components, logic}
- **From main ({OTHER-ID}):** {what main added that conflicts}

These changes are complementary — {one sentence on why both should coexist}. Do not discard either set.

After resolving, verify: {one or two specific behavioral checks}, and `{{BUILD_CMD}}` passes.
```

### Template: multi-conflict

For PRs with multiple conflicts, use labeled sections (Conflict 1, Conflict 2, etc.) with specific resolution instructions for each. Be precise about function signatures and return types when both branches modify the same function.

### Resolving issue ID placeholders

Before posting, resolve every `{ISSUE-ID}` placeholder to the real issue ID:

- This PR's issue: from the PR title or branch name
- The main-side conflicting issue: check recent merge history via GitHub MCP `list_pull_requests` with state closed, find the PR that touched the same file, read its linked issue

If resolution is unclear, ask the user — don't leave literal `{ISSUE-ID}` in a posted comment.

### Posting rules

- **Never wrap the agent mention in backticks** — markdown rendering can prevent the agent from recognizing it
- **Always instruct `git merge main` explicitly** for conflict resolution — many coding agents default to forward-port, which leaves conflicts visible on GitHub
- **Include the build command as verification** for any typed-code change
- **Post autonomously** for agent-fixable gaps and clear-cut conflicts
- **Post via GitHub MCP** (`add_issue_comment` or PR comment equivalent) as the primary method
- **Browser MCP fallback** if GitHub MCP fails or the comment needs threading — use form input to type into the comment box, then ask for confirmation before clicking Comment

### After posting

- Note in session log: "Agent comment posted on PR #N for gap: {one-line summary}"
- Do not merge the PR yet — wait for the agent to resolve, then the PR re-enters triage when CI goes green

---

## Phase 4: Merge Execution

### Merge criteria (autonomous)

A PR is clean to merge when all of these are true:

- ✅ All ⚠️ Gaps are resolved (fixed, filed as follow-ups, or acknowledged as out of scope)
- ✅ CI checks passing (or a known transient infra failure is the only failure)
- ✅ No merge conflicts
- ✅ No SQL migrations (those escalate per 2e)
- ✅ No auth/security changes (those escalate per 2d)
- ✅ Verified ✅ Implemented claims hold up

Merge via GitHub MCP using squash merge as the default method. After merging:

- Verify the PR status shows merged
- Move the linked tracker issue to `Done`
- Check if the merge unblocks any `blockedBy` issues — update those to `Todo` if they have `{{IMPLEMENT_LABEL}}` and all blockers are now done

### Post-merge sweep

After each merge, re-evaluate remaining open PRs:

- Do any now have conflicts against the new main? (Check `get_pull_request` mergeable state)
- If so, post the pre-drafted agent conflict comment for each

### Transient infra failure handling

A timeout or infrastructure error on the preview deploy is transient, not a code issue. Recommendation in that case: re-run the deploy job, don't block merge. If three re-runs in a row fail, escalate — the infra provider may be degraded.

---

## Phase 5: Follow-up Issue Filing (when needed)

### When to file

File a new tracker issue when:

1. A gap is out of scope for the current PR but needs work soon (→ Todo + `{{IMPLEMENT_LABEL}}`)
2. A blocker is discovered during testing that needs planning (→ Backlog)
3. A pattern of failures points to a root cause needing architectural attention (→ Backlog, route to the architect)

### Filing context matters

The filing context determines the initial state:

- **Mid-session discovery, scoped fix:** `state: Todo`, labels include `{{IMPLEMENT_LABEL}}`, full context in body. The pipeline picks it up within minutes.
- **Mid-session discovery, needs planning:** `state: Backlog`, note in body why it was deferred from immediate pickup.
- **Out-of-scope gap from a PR:** `state: Todo` if it's a clean scoped fix, otherwise `Backlog`.
- **Architectural finding:** `state: Backlog`, assign to the architect, no `{{IMPLEMENT_LABEL}}`.

Default toward Todo + `{{IMPLEMENT_LABEL}}` when the work is scoped and deterministic. Backlog is for planning, not parking.

### What not to file

- Transient infra timeouts (retry instead)
- Mock data gaps already tracked in existing issues
- Minor visual polish not affecting functionality
- Anything that duplicates an existing open issue (check first)

### Issue body standard

```
## Problem / Context
{current state, why this issue exists, what triggered it}

## Task
{specifics — file paths, components, API shapes, schema if relevant}

## Acceptance Criteria
- [ ] {testable checks}
- [ ] `{{BUILD_CMD}}` passes (if typed code touched)

## Dependencies
Blocked by: {ISSUE-ID} (if any)

## Notes
{surfaced-from-PR #N, related architectural context, known gotchas}
```

---

## Phase 6: Session Summary

Post the session summary as a new tracker issue assigned to the architect (or the user, single-operator). This is an **autonomous write** — do not ask for approval. Summaries are informational artifacts, not actions.

**Title format:** `Session Summary — {Month Day}: {brief focus}`

**Tone:** Professional, factual. Describe what's broken without alarm language. Do not use "critical," "urgent," or "blocker" unless describing a literal P0.

### Structure (migrations first)

```markdown
# Session Summary — {date}

## Migration Queue (action needed)
| File | PR | Tables | Type | Urgency | Status |
|------|-----|--------|------|---------|--------|
| {file} | #{N} | {tables} | Additive/Data/Destructive | 🟢/🟡/🔴 | Pending application |

{For any 🔴, include the raw SQL inline so the architect can review and apply directly}

## PRs Merged This Session
| PR | Issue | What it does |

## PRs Worked But Not Merged
| PR | Issue | State | Why not merged |

## Agent Comments Posted
| PR | Gap addressed | Posted at |

## Issues Filed
| Issue | Source | State | Why filed |

## Manual Steps for {{ARCHITECT_NAME}} or User
| Step | Source PR | Owner |

## Unblocked Work
| Issue | Was blocked by | Now in state |

## Board State After Session
- In Progress: {count}
- In Review: {count}
- Open PRs: {count}
- Todo (agent queue): {count}

## Observations
{Patterns noticed — recurring gap types, pipeline health signals, anything worth flagging for next session}
```

---

## Key Principles (the non-negotiables)

1. **The PR branch belongs to the AI coding agent.** Never edit a PR branch directly. Never push commits to it. All changes go through agent comments. Exceptions: main-branch hotfixes unrelated to any open PR, and session summary issues (which aren't on any PR branch).

2. **Drive to standard now.** If a gap is scoped and the agent can fix it in-session, post the comment. Don't defer real work to "future build-up."

3. **Follow-up context determines state.** Discovery in build-down → Todo + `{{IMPLEMENT_LABEL}}` if scoped. Backlog only for planning.

4. **Autonomous by default, escalate only on pattern breaks.** See the Phase 2d list. Everything else, act.

5. **The gap analysis is the primary assessment document.** Read it first, verify load-bearing claims against the diff, act on each ⚠️ item explicitly.

6. **Reading is free; writing requires care.** Read PRs, diffs, comments liberally. Write operations (agent comments, merges, issue filings) are autonomous but logged. Escalations are the exception, not the default.

---

## Common Failure Patterns

| Symptom | Likely cause | Resolution |
|---|---|---|
| API error after merge ("Failed to fetch...") | Migration not applied — code references a column that doesn't exist | Apply the pending migration; 🔴 escalation next session |
| "Not found" errors on linked-detail pages | Mock data IDs don't exist in DB | Not a code defect; check acceptance criteria |
| Preview deploy timeout | Transient infra | Re-run deploy job |
| GitHub still shows conflicts after agent ran | Agent forward-ported instead of merging | Post new agent comment instructing `git merge main` |
| Gap analysis flags columns that exist | Agent didn't check current schema | Cross-reference the schema source of truth |
| Merging breaks a prod page | Code deployed before migration applied | The Phase 2e escalation exists to prevent this — the most common footgun |
| PR open >5 days with no activity | Likely stale | Check context before driving; may need rebase or close |

If a symptom doesn't clearly match a row, don't force-fit. Investigate and escalate.

---

## Conventions

**Tracker MCP patterns (assuming Linear-style):**
- `save_issue` handles both create and update (pass `id` to update)
- Label arrays replace rather than append — always pass the full desired label list
- `state: "Todo"` triggers agent pickup within minutes
- `state: "In Progress"` + PR attachment = agent is working

**Label conventions (adapt names to your tracker):**
- `{{IMPLEMENT_LABEL}}` — the AI coding agent should implement this
- `agent-working` — the AI coding agent is actively running (set by pipeline, don't set manually)
- `backend` — API, schema, or infrastructure work
- `frontend` — UI components, pages, styling
- `full-stack` — touches both

**Routing rules (when an architect role is defined):**
- `{{ARCHITECT_NAME}}` — schema migrations, security policies, infra, complex architecture
- AI coding agent pipeline — frontend convergence, UI fixes, well-defined backend tasks
- The user — product decisions, sequencing, pattern-break escalations

For single-operator setups: treat all "architect" callouts as escalations to the user, not a separate human.

**Migration context:**
- Migration files live wherever the project keeps them; reference the canonical path
- Verify whether deploy workflows auto-run migrations or require manual application; this affects merge-safety of migration PRs
- If migrations are manual, the architect (or user) applies them via the database provider's tooling
