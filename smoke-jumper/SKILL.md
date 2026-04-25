---
name: smoke-jumper
description: "Autonomous smoke-testing agent for PRs. Trigger this skill when the user says 'smoke-jump', 'smoke test', 'smoke-jumper', 'test this PR', 'test these PRs', 'verify the preview', 'does this PR actually work', or asks to validate a preview deploy before merge. Smoke-jumper parachutes onto one or more PRs, reads the gap analysis and issue context to figure out what to test, logs into the preview deploy, runs adaptive smoke tests (baseline health + PR-specific verification), posts results as a PR comment, and files tracker issues for any failures. It runs independently or in parallel with build-down, super-build-down, and summit-push — those skills can invoke it per-PR or consume its reports if already run."
---

# Smoke-Jumper Skill

A smoke-jumper is an autonomous agent that parachutes onto PRs, figures out what to test, and reports back. It offloads the smoke-testing bottleneck from build-down sessions so PRs can be verified independently of triage work.

**What makes smoke-jumper different from build-down's inline preview testing:**

- Build-down does quick inline smoke checks as part of PR triage. Smoke-jumper runs deeper, feature-aware tests.
- Build-down asks "does the page load?" Smoke-jumper asks "does the acceptance criteria actually hold?" — it reads the gap analysis, understands the workstream, and tests accordingly.
- Smoke-jumper posts autonomous PR comments with verdicts. Host skills (build-down, super-build-down) consume those verdicts as merge signals.

**Verdict-to-tier mapping (for host skills that consume smoke-jumper output):**

| Verdict | Meaning | Super-build-down action | Build-down action |
|---|---|---|---|
| 🟢 CLEAR TO MERGE | Boot + all tested profiles pass | Auto-merge (Tier 1) | Recommend merge |
| 🟡 data-caveat | Boot passes, caveats are data-only (empty states, mock data gaps) | Auto-merge with log (Tier 2) | Recommend merge, note caveat |
| 🟡 functional-caveat | Boot passes but a non-acceptance-criteria feature is broken | Escalate (Tier 3) | Recommend hold or agent fix |
| 🔴 DO NOT MERGE | Boot fails OR acceptance criteria feature broken | Escalate (Tier 3) | Hold, agent fix, or close |

This mapping is the contract between smoke-jumper and the host skills. Verdicts must be one of these four exactly.

---

## Configuration

- `{{TRACKER}}` — the issue tracker
- `{{REPO}}` — the GitHub repo, owner/name format
- `{{PREVIEW_HOST}}` — preview deploy URL pattern (e.g., `pr-{N}-{app}.{provider}.dev`)
- `{{IMPLEMENT_LABEL}}` — the label that triggers the AI coding agent pipeline
- `{{AUTH_PROVIDER}}` — the auth provider (e.g., Supabase Auth, Auth0, Clerk). Affects cookie/session handling in Phase 3.
- `{{INTERNAL_API_MCP}}` — optional MCP that allows direct API verification of the project's backend, more reliable than browser navigation
- The skill assumes a Workstream Profile Table (below) populated with the project's surfaces. Update per project.

---

## Environment and Pipeline Context

### Environment detection

Smoke-jumper is chat-primary — browser MCP is load-bearing. State at session start.

**Chat (primary and required):**
- Has: browser MCP (required), tracker MCP (required), GitHub MCP (recommended), internal API MCP (when available, for direct API verification)
- Use for: all phases
- If browser MCP is unavailable, smoke-jumper cannot run. Report back to the host skill "smoke-testing unavailable" and let the host downgrade its classification accordingly.

**Code-execution:**
- Rarely used for smoke-jumping — no browser.
- Used only if the test requires running the build command or a local script that browser MCP can't invoke.

**Opening declaration:** State the environment, target PRs, and invocation context (standalone / invoked from build-down / invoked from super-build-down — this determines the autonomy posture).

### Invocation context (determines autonomy)

Smoke-jumper behaves differently depending on who invoked it:

- **Standalone (user ran `smoke-jump ...` directly):** confirm batch scope with the user before starting. Human-assisted login is acceptable. Pause for input when needed.
- **Invoked from build-down:** run inline for the current PR, return verdict to build-down session. Human-assisted login acceptable via the host session's prompt. No separate confirmation needed.
- **Invoked from super-build-down (autonomous):** run for the target PR without confirmation. Do NOT ask for human-assisted login — if auth is required and no active session exists, return verdict `⚠️ auth-required` and let super-build-down handle it (downgrade to Tier 2 per its pattern).

### The gap analysis as primary assessment

Same as build-down: the AI coding agent's gap analysis comment is the primary document. Smoke-jumper's Phase 2 reads it first. The ✅ / ⚠️ / 🔧 structure drives which profiles to run and what to verify.

---

## Phase 1: Target Acquisition

Determine which PRs to smoke-test.

**Explicit:** the user names specific PR numbers → test those.

**Batch:** the user says "all passing PRs" or similar:
1. Use GitHub MCP `list_pull_requests` for `{{REPO}}`
2. Filter to PRs with passing CI checks
3. Standalone: present list and confirm. Invoked autonomously: proceed without confirmation.

**Auto-detect:** the user says "smoke-jump" with no args:
1. Tracker MCP `list_issues` with `state: "In Review"`
2. Cross-reference with open PRs via GitHub MCP
3. These are the PRs most likely to need smoke testing
4. Standalone: confirm the list. Autonomous: proceed.

### Check for existing reports first

Before running tests, check if a smoke-jumper report already exists on the PR:

- Read PR comments via GitHub MCP
- Look for a comment matching the smoke-jumper report format (`## 🔥 Smoke-Jumper Report`)
- If a report exists and is <24 hours old AND no new commits have landed since → consume the existing report, don't re-run
- If the report is stale (>24h) OR new commits since the report → re-run
- Note in Phase 5 whether this was a fresh run or a consumed cached report

### For each target PR, collect

- PR number and branch name
- Preview deploy URL: `{{PREVIEW_HOST}}` substituted with the PR number
- Associated tracker issue ID (from PR title or body)
- Changed files list (`get_pull_request_files`)

---

## Phase 2: Intelligence Gathering

Before testing, understand what this PR actually does.

### 2a. Read the gap analysis

Find the AI coding agent's comment. Extract:

- **✅ Implemented** — what was built (verify the load-bearing ones work)
- **⚠️ Gaps / Partial** — what might be broken or incomplete (most likely to fail tests)
- **🔧 Manual Steps** — anything requiring human intervention (not testable, note only)

### 2b. Read the tracker issue

Tracker MCP `get_issue` with relations included. Extract:

- **Acceptance criteria** — the definitive test checklist; these items anchor the 🔴 vs 🟡 verdict decision
- **Workstream** — determines which profile-specific tests apply (see 2d)
- **Dependencies** — if this depends on unmerged work, some features may not be testable (acceptable, document as caveat)

### 2c. Classify the changes

Based on files changed:

- **Frontend only** (components, hooks, pages) → UI Render profile
- **API route changes** → API Shape profile
- **Full stack** (both) → Flow profile
- **Migration only** → Boot test + verify affected tables via internal API MCP if available
- **Config/infra only** → Boot profile sufficient

### 2d. Determine test profile

Every PR gets **Boot + one or two specific profiles**. The Workstream Profile Table below should be customized per project — fill it with the project's actual surfaces.

| Profile | When | What to Test |
|---------|------|--------------|
| **Boot** | Every PR | Preview deploy loads, no 5xx errors, login works |
| **API Shape** | API route changes | Key endpoints return expected HTTP status and response structure |
| **UI Render** | Frontend changes | Target pages render, key components visible, no console errors |
| **Flow** | Full-stack features | Complete user workflow end-to-end |

**Workstream-specific profiles (project-specific — populate per project):**

| Workstream | Triggered By | What to Test |
|-----------|--------------|--------------|
| `{{WORKSTREAM_A}}` | Changes to surfaces matching this workstream | List specific render and behavior checks |
| `{{WORKSTREAM_B}}` | Changes to surfaces matching this workstream | List specific render and behavior checks |
| ... | ... | ... |

Examples of what workstream profiles look like (replace with project-specific entries):
- "Map view" profile → verify map renders, watch for z-index issues with overlays, check status markers, verify filters work
- "List view" profile → verify table renders, check sort/filter state, verify pagination
- "Form/config view" profile → verify form fields render, check validation, test save flow

---

## Phase 3: Authentication

The preview deploy requires login.

### 3a. Active browser session (preferred)

1. Navigate to the preview deploy
2. Check if the page loads a dashboard (already logged in) or redirects to login
3. If already logged in → proceed to Phase 4
4. If not → move to 3b

### 3b. Human-assisted login (context-dependent)

**Standalone invocation:** Notify the user: *"I need to log in to the preview deploy at {preview URL} to run smoke tests. Can you log in via the browser and let me know when you're ready?"* Wait for confirmation.

**Invoked from build-down:** Prompt via the host session — the user is already engaged. Same wait-for-confirmation pattern.

**Invoked from super-build-down (autonomous):** Do NOT prompt. Return verdict immediately:
```
⚠️ AUTH REQUIRED — PR #{N}
No active browser session for the preview deploy, and super-build-down is running
autonomously. Smoke test skipped. Recommend host downgrade this PR's classification
(Tier 1 candidates → Tier 2 with smoke-test-skipped note).
```
Super-build-down's Phase 3 already handles this case.

### 3c. Auth provider details

Per the project's `{{AUTH_PROVIDER}}`, sessions may not carry across different PR subdomains — check per PR. (Example: Supabase Auth uses chunked `sb-[project-ref]-auth-token` cookies that may need re-login on a different preview subdomain.)

---

## Phase 4: Test Execution

Run the profile determined in Phase 2d. Every PR gets Boot; additional profiles are additive.

### 4a. Boot Profile (every PR)

1. **Navigate to preview URL** — check for:
   - HTTP 200 (not 5xx)
   - Page content loads (not blank or infra error page)
2. **Login** — per Phase 3 outcome
3. **Post-login navigation:**
   - Dashboard or home page loads
   - Navigation sidebar renders with expected menu items
   - Use `read_console_messages` (errors only) to catch silent failures

**Boot failure = STOP.** Do not proceed to other profiles. Record the failure, post the PR comment with verdict 🔴, file the tracker issue.

### 4b. API Shape Profile

For PRs that touch API routes:

- **Preferred (when internal API MCP available):** Use direct API calls for structured verification. More reliable than browser navigation.
- **Fallback (browser MCP):** Navigate to the preview's API route directly and inspect response.

Verify:
- HTTP status (2xx for success endpoints, appropriate error codes for error cases)
- JSON response shape matches expected structure
- No 500 errors, NotImplementedError, or empty responses where data expected

### 4c. UI Render Profile

For PRs that touch frontend:

1. Navigate to the affected page(s) identified from changed files and acceptance criteria
2. Use `read_page` to verify target components render
3. Check for "undefined", "null", or error boundaries in the rendered output
4. Use `computer: screenshot` for visual verification when the page has complex layout
5. Use `read_console_messages` with errors only

### 4d. Flow Profile

For full-stack features:

1. Identify the flow from acceptance criteria
2. Walk through step by step (navigate, fill forms, click buttons)
3. Verify each step produces expected result
4. Check both UI feedback and (via internal API MCP or API Shape fallback) backend state change

### 4e. Workstream-Specific Profiles

Run these per the Workstream Profile Table in Phase 2d. They're project-specific — define them based on the surfaces the project has and the failure modes those surfaces are prone to.

---

## Phase 5: Results Reporting

### 5a. Verdict determination

Apply the verdict criteria from the top of this skill:

- **🟢 CLEAR TO MERGE** — Boot passes, all tested profiles pass or show only cosmetic issues
- **🟡 data-caveat** — Boot passes, caveats are demo data gaps, empty states for missing mock data, features depending on unmerged PRs
- **🟡 functional-caveat** — Boot passes but a feature (outside the acceptance criteria) is broken
- **🔴 DO NOT MERGE** — Boot fails, or a feature IN the acceptance criteria is broken

The difference between 🟡 data-caveat and 🟡 functional-caveat is load-bearing for super-build-down's Tier classification. Be precise.

### 5b. PR Comment

Post via GitHub MCP (`add_issue_comment`). Post autonomously — this is an informational artifact, not an action on the code.

```
## 🔥 Smoke-Jumper Report — PR #{number}

**Preview URL:** {preview URL}
**Tested:** {timestamp}
**Auth:** {active session / human-assisted / skipped-auth-required}
**Invocation:** {standalone / from build-down / from super-build-down}

### Boot
{✅ PASS | ❌ FAIL: {error details}}

### {Profile Name}
{✅ PASS | ⚠️ PARTIAL | ❌ FAIL}
{Details}

### Summary
**Verdict:** {🟢 CLEAR TO MERGE | 🟡 data-caveat | 🟡 functional-caveat | 🔴 DO NOT MERGE}

{One-sentence summary}

{For 🟡 — specify which caveat bucket and why}
```

**Never wrap the agent mention in backticks** in the report (same rule as build-down — protects mention detection).

### 5c. Tracker issues for failures

For each ❌ FAIL (whether 🔴 verdict or 🟡 functional-caveat with a specific broken feature):

- **Title:** `Smoke test failure: {description} (PR #{N})`
- **State:** `Todo` with `{{IMPLEMENT_LABEL}}` if the fix is well-scoped; `Backlog` if it needs planning
- **Labels:** `Bug`, plus workstream label
- **Priority:** Urgent if boot failure, High if acceptance-criteria feature broken, Medium otherwise
- **Dependency link:** Reference the source PR's issue as `relatedTo`

File autonomously. Do not ask permission — silent drop is not an option, and filing is safer than forgetting.

### 5d. Session summary (multi-PR sessions only)

If smoke-jumper ran on multiple PRs in one session, post a session summary as a tracker issue assigned to the architect (or the user, single-operator):

```
# Smoke-Jumper Session Summary — {date}

## PRs Tested: {count}
| PR | Issue | Verdict | Key Finding |

## Issues Filed: {count}
| Issue | PR | Severity | Description |

## Auth Notes
{How auth was handled, any PRs where auth was skipped}

## Patterns Observed
{Recurring issues across PRs — useful pipeline-health signal}

## Recommendations
{Merge order suggestions, blockers to address}
```

Single-PR invocations don't need a session summary — the PR comment is sufficient.

---

## Coordination with Host Skills

### Smoke-jumper ↔ Build-down

- Build-down can invoke smoke-jumper per-PR during triage
- If smoke-jumper has already run (<24h, no new commits), build-down consumes the existing report
- Build-down's verdict interpretation is less strict than super-build-down's — 🟡 functional-caveat can still recommend merge with the user's approval if the feature is out-of-scope for this PR

### Smoke-jumper ↔ Super-build-down

- Super-build-down invokes smoke-jumper mandatorily for every Tier 1 candidate
- Super-build-down strictly applies the verdict-to-tier mapping in the table at the top
- If smoke-jumper returns `⚠️ auth-required`, super-build-down downgrades the PR to Tier 2 with a skipped-smoke note
- If smoke-jumper is unavailable (browser MCP down), super-build-down downgrades all Tier 1 candidates to Tier 2 and proceeds

### Smoke-jumper ↔ Summit-push

- Summit-push predicts risks via static analysis; smoke-jumper verifies them at runtime
- If summit-push flagged a PR as high-risk in its manifest, smoke-jumper adds extra attention to those specific areas in Phase 4
- Summit-push Mode 2 (Mid-Push) can note "smoke-jumper verdict pending" for a PR and let the verdict determine merge sequencing

---

## Conventions

### PR comment conventions

- Never wrap the agent mention in backticks
- Always include the preview URL tested
- Keep verdicts consistent: 🟢 / 🟡 data-caveat / 🟡 functional-caveat / 🔴
- Include invocation context so host skills can parse correctly

### Test depth (time budget)

- Boot: ~30 seconds per PR. Non-negotiable — every PR gets Boot.
- API Shape: ~1-2 minutes per PR
- UI Render: ~1-2 minutes per PR
- Flow: ~3-5 minutes per PR
- **Total per PR: ~5-10 minutes max.** If a test is running long, stop and report a partial verdict with what's been checked.

### Common failure patterns

| Symptom | Likely Cause | Action |
|---|---|---|
| Preview returns 502/503 | Infra machine not started | Wait 30s, retry. If still down, note as infra issue (not code defect). |
| Login redirects in a loop | Auth provider misconfig on preview | Verdict ⚠️ auth-required. Let host skill handle. |
| Page loads but components blank | Frontend built but API errors | Check console errors AND API endpoints separately. Usually a 🔴. |
| Empty lists/tables | Demo data gap, not code bug | 🟡 data-caveat. |
| "Not found" on linked-detail pages | Mock data IDs don't exist in DB | 🟡 data-caveat — not a code defect. |
| Feature not showing | Depends on unmerged PR | 🟡 data-caveat with dependency note. Don't block merge. |
| Console errors on page load | Could be either — check severity | Investigate; if related to acceptance criteria → 🔴, else → 🟡 functional-caveat. |

---

## Key Principles

1. **Verdicts are a contract.** Host skills rely on the four-verdict table — 🟢, 🟡 data-caveat, 🟡 functional-caveat, 🔴. Be precise.
2. **The gap analysis is the primary document.** Read it first; it shapes what gets tested.
3. **Autonomy matches invocation context.** Standalone confirms. Build-down prompts. Super-build-down proceeds or returns auth-required.
4. **Re-use fresh reports.** Don't re-run a smoke test <24h old with no new commits.
5. **Boot is non-negotiable.** Every PR gets Boot; Boot failure stops the session for that PR.
6. **File failures autonomously.** Silence is never the default. If smoke-jumper found it, the tracker gets it.
7. **Time-box per PR.** ~5-10 minutes max. Partial verdicts beat stuck sessions.
