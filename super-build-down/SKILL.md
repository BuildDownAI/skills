---
name: super-build-down
description: "Autonomous, lean-back build-down. Trigger this skill when the user says 'super-build-down', 'super build-down', 'autonomous build-down', 'lean-back build-down', 'just land everything', 'overnight build-down', or asks for a build-down that runs at speed without narration. Super-build-down is build-down's faster cousin — same autonomy defaults, same rules, but optimized for throughput: batch escalations, minimal narration, mandatory smoke-jumper dispatch, session-abort triggers for unattended runs. Use when there are many PRs to process, when the user won't be watching every step, or when speed matters more than step-by-step visibility."
---

# Super-Build-Down Skill

Super-build-down is build-down run at speed and scale. Same mission (fewer open PRs, cleaner board, no gaps left unfixed), same rules, same autonomy model — but tuned for throughput instead of interactive pace.

**The difference from build-down.** Build-down is already autonomous-by-default (post agent comments, merge clean PRs, file session summaries without asking). Super-build-down layers on:

1. **Batch escalations** — gather all pattern-break items and present once at the end, not inline as they appear
2. **Minimal narration** — log actions, don't explain each one; the session summary is the narrative
3. **Mandatory smoke-jumper** — every mergeable PR gets smoke-tested (build-down makes this optional)
4. **Session-abort triggers** — explicit conditions that halt an unattended run before it causes damage
5. **Throughput targets** — 10 PRs in under an hour is the benchmark

**When to use super-build-down over build-down:**
- 5+ PRs to process and most are routine
- End-of-day push or overnight session — the user won't be watching
- The user wants the board cleaned with minimal cognitive overhead
- The pipeline has been healthy recently (trust the defaults)

**When to use build-down instead:**
- 1-2 PRs, interactive review is faster
- PRs are complex, interconnected, or novel
- The user wants to review each PR for product intent
- Recent pipeline issues suggest distrust of the defaults

---

## Configuration

Same as build-down. The skill assumes the user has these set up:

- `{{TRACKER}}` — issue tracker (Linear, Jira, GitHub Issues)
- `{{REPO}}` — GitHub repo, owner/name format
- `{{PREVIEW_HOST}}` — preview deploy URL pattern
- `{{IMPLEMENT_LABEL}}` — label that triggers the AI coding agent pipeline
- `{{ARCHITECT_NAME}}` — human who owns risky changes (migrations, auth, infra). Optional.
- `{{BUILD_CMD}}` — verification command for typed code

---

## Environment and Pipeline Context

### Environment detection

Same as build-down. State at session start and adapt.

**Chat (primary for super-build-down):**
- Has: tracker MCP, GitHub MCP, browser MCP, project context
- Use for: orientation, triage, agent comments, merges, session summary
- Smoke-jumper runs sequentially in chat (no true parallel dispatch without subagents — it's sequential-but-automatic)

**Code-execution:**
- Has: bash, local filesystem, git
- Use for: local conflict resolution if agent loops, manual migration application (escalated out of session)
- Rarely the primary environment for super-build-down

**Code-reading agent:**
- Rarely used. If it's needed for something, that something is probably a pattern break that should escalate.

**Opening declaration at session start:** Environment, tool availability, PR count, target completion time.

### The AI coding agent pipeline

Pipeline is a running system. Agent-working state is expected, not alarming. Gap analysis is the primary assessment document (✅ Implemented / ⚠️ Gaps / 🔧 Manual Steps). See build-down's Environment and Pipeline Context section for full treatment — super-build-down inherits the same model.

---

## Phase 1: Orient (Fast)

Faster than build-down's orient because super-build-down trusts pipeline state and skips narration.

**Tracker board scan (one batch):**
- `list_issues`: states `In Progress`, `In Review`, and `Todo` with `{{IMPLEMENT_LABEL}}`

**PR scan (one batch via GitHub MCP):**
- `list_pull_requests` for `{{REPO}}`, state: open
- For each PR, batch: `get_pull_request`, `get_pull_request_status`, `get_pull_request_files`
- Read gap analysis comment from PR page

**What to capture per PR:**

- Issue ID (from branch name or title)
- Gap analysis: count of ⚠️ items, any 🔧 manual steps
- CI check status
- Mergeable state (clean / conflicted / behind)
- Migration presence (yes/no + filename)
- File count changed
- Age

**Orientation table (single print, no commentary):**

```
PR # | Issue | Gaps | Checks | Conflicts | Migration | Files | Age | Tier
```

The Tier column is filled in Phase 2. No other output in Phase 1 — save the narrative for the session summary.

### Summit-Push Risk Scan (automatic for 5+ PRs)

For 5+ open PRs, run summit-push Mode 2 automatically (not optional). Its risk report feeds Phase 2 classification directly. Don't ask permission — it's a read-only scan.

---

## Phase 2: Tier Classification

Every PR gets a tier. Tier drives action.

### Tier 1: Auto-merge

ALL of these must be true:
- ✅ CI checks passing (or only known transient infra failure)
- ✅ No merge conflicts
- ✅ Gap analysis: all ✅ Implemented, zero ⚠️ gaps
- ✅ Smoke-jumper returns 🟢 CLEAR TO MERGE
- ✅ No SQL migrations
- ✅ No overlap with other open PRs
- ✅ Not on pattern-break list (Phase 2d)

Additional confidence boosters (not required but speed the decision):
- PR touches ≤5 files
- PR is frontend-only
- PR age <3 days

**Action:** Smoke-jump, verify 🟢, merge, move issue to Done. Log one line.

### Tier 2: Auto-act

Clean enough to handle autonomously but has one manageable issue:

- ⚠️ Gap analysis has items that are agent-fixable (scoped, no product decision needed)
- ⚠️ Smoke-jumper returns 🟡 MERGE WITH CAVEATS (data-related only — demo data gaps, empty states)
- ⚠️ Clear-cut merge conflict (both sides added imports, both sides added config entries, no business logic overlap)

**Action:**
- For agent-fixable gaps: post the agent comment autonomously. Do not merge until the fix cycles through and the PR re-enters triage clean.
- For data-only 🟡: merge, log the caveat as out-of-scope.
- For clear-cut conflicts: post `git merge main` agent comment autonomously. Do not merge until resolved.

### Tier 3: Escalate (batch, not inline)

Escalation triggers (same pattern-break list as build-down):

1. Gap requires a product decision
2. Agent already failed on this specific gap (prior attempt in comment history)
3. Any SQL migration — additive, data, or destructive
4. Touches auth, security middleware, or auth provider config
5. Fix would modify >5 files or cross PR boundaries
6. PR age >5 days
7. Smoke-jumper returns 🔴 DO NOT MERGE
8. CI failing (not transient infra)
9. Merge conflict involves business logic
10. File overlap with another open PR (merge ordering decision)

**Action for super-build-down:** DO NOT present Tier 3 items as they appear. Collect them all. Present once at the end of Phase 4 as a batch.

---

## Phase 3: Smoke-Jumper Dispatch (Mandatory)

Super-build-down requires smoke-jumper. If browser MCP is unavailable, downgrade every Tier 1 to Tier 2 and note the skip in the summary — but do not skip the step entirely.

**Sequence (chat is sequential, not parallel):**

1. Prioritize PRs: Tier 1 candidates first (fastest to clear), then Tier 2, skip Tier 3 (they're escalating regardless)
2. Run smoke-jumper on each in order, using the existing smoke-jumper skill
3. Capture the verdict: 🟢 / 🟡 / 🔴
4. If smoke-jumper was already run on a PR (existing report in comments <24h old), consume it rather than re-running

**Smoke results feed Phase 2 classification:**
- 🟢 confirms Tier 1 → proceed to merge
- 🟡 data-only → Tier 2 action
- 🟡 functional → downgrade to Tier 3
- 🔴 → always Tier 3

---

## Phase 4: Autonomous Execution

Work PRs in tier order: Tier 1 first (fast wins), Tier 2 second (handle follow-ups), Tier 3 last (batched at end).

### 4a. Tier 1 — merge

1. Verify smoke result 🟢
2. Merge via GitHub MCP `merge_pull_request`, squash by default
3. Verify PR shows Merged
4. Update tracker issue to Done
5. Log one line: `✅ Auto-merged PR #{N} — {title}`
6. Continue — no commentary

### 4b. Tier 2 — act

For agent-fixable gaps:
1. Post agent comment via GitHub MCP
2. Log one line: `💬 Agent comment posted on PR #{N} for gap: {one-line}`
3. Do not merge — the PR will re-enter triage when the agent resolves and CI goes green

For clear-cut conflicts:
1. Post `git merge main` agent comment
2. Log one line: `💬 Conflict resolution agent comment posted on PR #{N}`
3. Do not merge

For data-only 🟡:
1. Merge (same as Tier 1)
2. Log: `✅ Auto-merged PR #{N} with data-caveat noted: {caveat}`
3. File follow-up issue only if the caveat describes net-new scope

### 4c. Post-merge sweep (after each merge)

Check remaining open PRs for new conflicts via `get_pull_request` mergeable state. Any PR that became conflicted gets re-classified in place.

### 4d. Follow-up filing (mid-session)

Super-build-down files follow-up issues same as build-down. Discovery of a scoped fix mid-session → new issue → `state: Todo` with `{{IMPLEMENT_LABEL}}`. Backlog only if the fix needs planning.

Do not drop gaps silently. If a gap is not agent-fixable and not escalatable, file it. Silence is never the default.

### 4e. Tier 3 — collect for batch

For each Tier 3 item encountered, add to a running list. Do not interrupt the flow to present.

Running list format (kept in working memory or a scratchpad file):

```
PR # | Pattern break trigger | Smoke verdict | My recommendation | Draft action
```

Present the full batch in Phase 5.

---

## Phase 5: Batch Escalation

After Tier 1 and Tier 2 work is complete, present Tier 3 items as a single batch.

### Batch format

```
🚨 Tier 3 batch — {count} PRs need a decision

PR #{N} — {title}
  Trigger: {pattern-break rule that hit}
  Smoke: {verdict or N/A}
  Recommendation: {merge / agent comment with {draft} / hold / close}
  Reason: {one sentence}

PR #{N} — {title}
  ...

Batch-respond options:
  "merge X, Y; hold Z; close W"
  "post agent comment on X with the draft; escalate Y to architect"
  "all merge except migrations"
  etc.
```

If the user responds, execute the batch instructions. If the user is unavailable (overnight run), log everything to the session summary and halt.

### Special case: migrations

Migration PRs always go to the architect, not the user, even in batch escalation. Separate them into their own section:

```
🔴 Migrations — architect's queue

PR #{N} — {title}
  Migration: {filename}
  Type: Additive / Data / Destructive
  Collision risk: {yes/no — other migrations open}
  SQL:
  {raw SQL inline}
```

Migrations stay in the session summary for the architect to apply manually. Do not ask the user to decide on migrations.

For single-operator setups (no architect): migrations still surface in this section but the user is the recipient. Same urgency, same SQL inline — just routed to the user instead.

---

## Phase 6: Queue Assessment

### 6a. Unblock downstream work

For each merged PR, check `blockedBy` on tracker issues. Any issue whose blockers are now all Done, and that has `{{IMPLEMENT_LABEL}}` → move to Todo. One batch update via tracker MCP.

### 6b. Pattern detection

If 2+ PRs escalated for the same reason, log the pattern. Examples:
- "3 PRs escalated for the same gap type: missing security context in new endpoints"
- "2 PRs escalated for conflicts with the same main-side PR"

Pattern logs go into the session summary "Observations" section and signal pipeline health issues worth addressing in a separate build-up.

### 6c. Next wave assessment

Quick check: are Todo issues that had blockers merged today ready to move? They were handled in 6a. Are there Backlog issues whose dependencies are now all Done? Flag them in the session summary — do not auto-promote. Wave promotion decisions are the user's.

---

## Phase 7: Session Summary (Autonomous Write)

Post as a tracker issue assigned to the architect (or to the user, single-operator). Same autonomy rule as build-down — this is informational, not an action, no approval gate.

**Title:** `Super Build-Down Summary — {Month Day}: {brief focus}`

**Tone:** Professional, factual. No alarm language. "Critical/urgent/blocker" reserved for literal P0.

**Migration-first structure** (matches build-down):

```markdown
# Super Build-Down Summary — {date}

## Migration Queue (action needed)
| File | PR | Tables | Type | Urgency | Status |
| {file} | #{N} | {tables} | Additive/Data/Destructive | 🟢/🟡/🔴 | Pending application |

{Raw SQL for 🔴 items inline}

## Session Stats
- PRs processed: {total}
- Auto-merged (Tier 1): {count}
- Auto-acted (Tier 2): {count}
- Escalated (Tier 3): {count}
- Smoke tests run: {count} ({🟢}/{🟡}/{🔴})
- Session duration: {min}
- Throughput: {PRs/hour}

## PRs Merged This Session
| PR | Issue | What it does | Smoke |

## Agent Comments Posted
| PR | Gap addressed | Posted at |

## Tier 3 Batch (pending decisions)
| PR | Trigger | Recommendation | Status |

## Issues Filed Mid-Session
| Issue | Source PR | State | Why filed |

## Manual Steps Surfaced
| Step | Source PR | Owner |

## Unblocked Work
| Issue | Was blocked by | Now in state |

## Board State After Session
- In Progress: {count}
- In Review: {count}
- Open PRs: {count}
- Todo (agent queue): {count}

## Observations / Patterns
{Pipeline health signals, recurring gap types, anything worth flagging}

## Recommendations for Next Session
{What to tackle next, blockers to address}
```

---

## Autonomy Guardrails

### Never auto-merge when

Same pattern-break list as Phase 2 Tier 3 (above), plus:
- PR modifies infrastructure config (deploy config, CI workflows, framework config)
- PR modifies auth/security (auth provider config, security policies, middleware)
- Smoke-jumper returned 🔴
- CI failing (not transient infra)
- PR open >5 days (aligned with build-down's threshold)

### Never auto-post agent comments when

1. Conflict involves business logic (not just imports/config)
2. Resolution is ambiguous
3. Same PR has received 2+ agent comments in this session (possible loop — escalate)
4. Gap requires a product decision

### Always log

- Every merge (auto), with PR #, issue, rationale
- Every agent comment posted
- Every Tier 3 collection
- Every smoke-jumper dispatch and result
- Every follow-up issue filed
- Every pattern observation

### Session-abort triggers (critical for unattended runs)

Halt the session immediately and post what you have to the summary when:

1. **3+ consecutive CI failures across different PRs** — main branch is likely broken. Do not keep merging.
2. **Auto-merge API call fails unexpectedly** — pause all merges, shift remaining PRs to Tier 3, finish with escalation batch.
3. **Smoke-jumper repeatedly returns 🔴 on PRs that should be clean** — something is wrong with the preview environment, not the PRs.
4. **The user explicitly says "stop" or "hold"** — pause all activity, present current state.
5. **More than 50% of PRs hit pattern-break triggers** — the session's scope is wrong for super-build-down; should have been build-down.

Abort means: finish writing the session summary (including what was completed and why it stopped), post it, exit. Do not keep trying.

---

## Conventions

### Merge conventions
- Always use GitHub MCP `merge_pull_request`
- Squash merge by default
- Verify merged status after each merge before proceeding

### Timing
- Target: <5 minutes per Tier 1 PR (including smoke-jump)
- Target: <10 minutes per Tier 2 PR
- Tier 3: batched, so 0 time per PR during execution; time spent at end
- Full session: <1 hour for 10 PRs

### Agent comment conventions

Same as build-down:
- Never wrap the agent mention in backticks
- Always instruct `git merge main` explicitly for conflict resolution
- Include `{{BUILD_CMD}}` as verification for typed-code changes
- Resolve `{ISSUE-ID}` placeholders to real IDs before posting

Super-build-down comments include a trailing marker so the architect can filter if needed:

```
[Posted by super-build-down — autonomous session {date}]
```

### Relationship to other skills

- **Super-build-down dispatches smoke-jumper** mandatorily. Existing reports <24h old are consumed rather than re-run.
- **Super-build-down uses summit-push Mode 2** automatically for 5+ PRs. Not optional, not asked.
- **Super-build-down does NOT run with build-down.** If the user wants to switch to interactive mode mid-session, the skill presents current state, writes the session summary so far, and hands off.

---

## Key Principles

1. **Throughput over narration.** Log, don't explain. The session summary is the narrative.
2. **Batch Tier 3, don't inline.** Pattern breaks collect; present once at end.
3. **Migrations always go to the architect, not the user.** Even in batch escalation. (Single-operator: still surface separately, just routed to the user.)
4. **Drive to standard.** Same as build-down — don't defer scoped gaps when the agent can fix them.
5. **Silence is never the default.** Every gap is fixed, escalated, or filed.
6. **Abort beats damage.** Session-abort triggers exist because unattended runs can cause harm. Honor them.
7. **Pattern-break list is identical to build-down.** This skill is build-down at speed, not with different rules.
