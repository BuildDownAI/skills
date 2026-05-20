---
name: project-triage
description: "Audit an existing tracker project, ground each non-Done issue against the current code, classify them, and propose a write plan that closes silently-shipped work, refreshes stale issue bodies, sequences blocked work, and updates the project description. Trigger this skill when the user says 'triage this project', 'audit this project', 'project triage', 'clean up the project', 'this project is a mess', 'where are we on X project', 'review the issue tracker', or asks to assess and clean up an existing tracker project after a migration, a long period of inactivity, or any time the open-issue list has drifted out of sync with what actually shipped. Project-triage is the sibling of build-up (creation) and build-down (PR-side closure) — it operates on the issue tracker itself, against the code reality of an existing repo, and ALWAYS stops for human approval before any writes."
---

# Project Triage Skill

A grounded sweep across an existing project's issues. Reads issue bodies, compares each against the current state of the repo, classifies into a six-bucket rubric, and presents a write plan that the operator approves before anything mutates.

The most common reason to run this is after a tracker migration (e.g., GitHub Issues → Linear) where parent issues stayed open even after the substantive work landed via PRs, leaving a project full of "done-tombstones" — issues whose literal acceptance criterion is already met on `main` / `testing` / the canonical branch, but the tracker never reflected the close. Other reasons: a project that's been sitting for months with no activity, a project where labels and project state contradict the actual code, or just routine cleanup before kicking off the next phase of work.

## Configuration

- `{{TRACKER}}` — the issue tracker (e.g., Linear, Jira, GitHub Issues). The skill assumes an MCP that supports `list_projects`, `get_project`, `save_project`, `list_issues`, `get_issue`, `save_issue`, `save_comment`, and (optionally) `save_document`.
- `{{REPO}}` — the GitHub repo issues are grounded against, in `owner/name` form.
- `{{BASE_BRANCH}}` — the canonical branch issue bodies should be checked against (e.g., `main`, `testing`, `develop`). This is where "the code reality" lives.
- `{{IMPLEMENT_LABEL}}` — optional. If the project uses an AI-coding-agent label (e.g., `AI-Implement`), name it here so the skill can preserve / restore it correctly on issues that get retained or refreshed.

## When NOT to use

- **Fresh project planning** — use `build-up` (fast) or `mega-build-up` (adversarial design review). Triage operates on issues that already exist.
- **Daily PR triage / drive PRs to merge** — use `build-down` or `super-build-down`. Triage doesn't touch open PRs.
- **Single-issue investigation** — overkill. Just read the one issue and answer the question.
- **A project < 10 issues** — the manual sweep is fast enough that the structured workflow adds more overhead than value. Just read them all and decide.

## Environment requirements

**Chat environment (web/mobile or local Claude Code):**
- Has: tracker MCP, GitHub MCP / `gh` CLI, project context, conversation memory.
- Use for: pulling project state, reading issue bodies, drafting the inventory, presenting the report, and (after approval) executing the writes.

**Code-reading environment (local Claude Code or a code-execution subagent):**
- Has: local filesystem, bash, grep, `git show`, ability to read repo files on `{{BASE_BRANCH}}`.
- Use for: grounding each issue's acceptance criterion against the current code — i.e., is the symbol/file/line the issue points at already in its desired state?

If only chat is available, the grounding pass degrades to "did anything on the branch get merged that mentions this symbol?" via GitHub MCP — still useful but weaker. Prefer running this skill from a local Claude Code session inside a fresh checkout of `{{REPO}}`.

## Classification rubric

Every non-Done issue gets exactly one of these:

| Class | Definition | Default action |
|---|---|---|
| `still-relevant` | Work hasn't landed; body is clear and actionable. | Leave alone. Optionally re-prioritize. |
| `done-tombstone` | The literal acceptance criterion is already met on `{{BASE_BRANCH}}` — the work shipped but the tracker never closed the parent. | Close as Done with a comment citing the evidence (line numbers, commit hashes, config flags). |
| `superseded` | Replaced by another issue (newer plan, scope change) or a merged PR with a different number. | Close with a link to the successor. |
| `body-needs-update` | Still relevant but the body has stale line numbers, dead file paths, or vague acceptance. | Refresh the body against current code; preserve the substantive ask. |
| `split` | Umbrella-shaped — encodes multiple deliverables that should be sequenced separately. If children already exist as separate issues, consider closing the umbrella as a tombstone. | Either split into child issues or fold into the existing children's parent-of relation. |
| `gap-found` | While reading, you noticed a missing follow-up the project needs. | File a new issue (after approval). Don't sneak it in as a fix to an existing one. |

**Hard rule:** do NOT silently invent a 7th class. If a real-world hit doesn't fit cleanly, surface that in the report and ask the operator which class to put it in.

Also do a **Done-issue spot-check**: pick 5 random Done issues and verify they're correctly classified. This catches migration errors (e.g., issues marked Done in the tracker because of a migration mapping but where the work never actually landed). If the random sample finds any mis-classification, expand the sample.

## Phase 1: Snapshot (read-only, ~30s)

The 4-question summary, presented before anything else.

1. **Pull project metadata** via `get_project` (include members + resources). Capture: name, state, lead, target date, priority, current description, attached documents.
2. **List all issues** via `list_issues` with project filter. Capture: counts by state, label distribution, last-updated timestamps.
3. **Compute the top-theme synthesis** (2 sentences max): what's this project mostly about right now, based on the actual issue titles? Avoid using the description's self-description; the audit hasn't ratified it yet.
4. **Flag obvious mismatches:** stale counts in the description, no lead, no target date, no documents attached, labels missing.

Output of Phase 1 is a single paragraph the operator can quote. It IS the read-only status check — a user who only wanted that can stop here.

## Phase 2: Audit (the work, parallelizable)

For every non-Done issue:

1. **Read the body.** Extract: file paths, symbols (functions, classes, fields, config keys), line numbers, referenced PR / commit / issue IDs.
2. **Ground against `{{BASE_BRANCH}}`.** For each reference: `git show origin/{{BASE_BRANCH}}:<path>` and grep for the symbol(s). Has the named change landed? Is the symbol at the cited line? Are the cited line numbers still accurate?
3. **Classify** into one of the six classes. Cite specific evidence in the justification — line numbers, commit SHAs, config flag values. Avoid "looks done" — name the file and line.
4. **Note dependencies between Todo issues** that surface during reading. If issue A's body says "blocked by B," capture that.

**Parallelize** by spawning a code-reading subagent that does the per-issue grounding in batches of 5–10. The subagent reads the bodies you've already pulled, does the grep/git-show work, and returns a structured inventory. This keeps the main session's context lean and avoids re-reading the same files for every issue.

Spot-check 5 random Done issues with the same grounding method to catch migration errors.

Cap: if Phase 2 has spent more than ~5 min per issue on grounding (excluding tool latency), the project is too big for a single-pass triage — break it into per-area passes and run the skill again on each.

## Phase 3: Triage inventory (the report)

A single markdown document with this structure:

```
# {{PROJECT_NAME}} — Triage Audit (YYYY-MM-DD)

## Snapshot
[Phase 1 output, 4-question summary]

## Triage classifications
[Per-issue: id, title, class, 2-4 sentence justification with evidence]

## Done-issue spot-check
[5/5 confirmed-done OR list of mis-classified found]

## Cross-cutting findings
[Patterns across multiple issues, gaps suggested, project-level recommendations]

## Summary counts
- done-tombstone: N (list IDs)
- still-relevant: N
- body-needs-update: N
- superseded: N
- split: N
- gap-found: N (these will become new issues, not actions on existing ones)
```

The inventory IS the deliverable of the read-only phase. Present it whole, then go to Phase 4.

## Phase 4: Approval gate (STOP)

This is a hard stop. After presenting the inventory, list the **specific write actions** the skill recommends, grouped:

1. **Closes** — each done-tombstone and superseded issue, with the closing comment text.
2. **Body refreshes** — each `body-needs-update`, with the proposed new body (or just the diff if it's a small change).
3. **Cross-link comments** — for issues with Phase-N dependencies surfaced during audit (don't auto-block; use a comment to flag).
4. **Priority / label changes** — only if explicitly warranted by audit findings (e.g., a safety guard discovered to be Low when it should be Medium).
5. **New issues** (`gap-found`) — proposed title + body, marked as separate writes.
6. **Project-level updates** — description rewrite (full proposed text), target date, lead, attached document.

For each, the user can: approve all, decline specific ones, or change the proposed text. Wait for explicit "go" or a specified subset before executing Phase 5. Do NOT execute any write in Phase 4.

If the user pushes back on a classification, redo the audit for that issue with the corrected lens — don't argue from the original report.

## Phase 5: Execute writes (after approval)

Apply the approved actions. Order:

1. **Closes first** (the most decisive cleanup; reduces the noise floor for subsequent reads).
2. **Body refreshes + priority changes** (no state transitions; safe to do anywhere).
3. **Cross-link comments** (additive; safe).
4. **New issues** (filed AFTER closes so the tracker view stays clean during execution).
5. **Project description rewrite** — do this LAST so it reflects the post-write state, not the pre-write state.
6. **Attached document** (optional) — saves the audit summary as a permanent project artifact.

Pace writes ~200ms apart to stay under tracker rate limits. If a write fails, log it and continue — surface the failure list at the end rather than aborting the whole pass.

After Phase 5, post a 2-line summary: "N writes executed, M failed (if any). Project now X Done / Y Todo."

## Conventions

**Grounding-against-code patterns** (assuming git + GitHub):

- Always `git fetch origin {{BASE_BRANCH}}` before reading. Local working tree may be on a feature branch.
- Use `git show origin/{{BASE_BRANCH}}:<path>` to read file content at the tip of the canonical branch — NOT the working-tree copy.
- Line numbers drift constantly. If an issue body cites `:712-713` and the symbol is now at `:811-812`, that's `body-needs-update`, NOT `done-tombstone`. Don't conflate the two.
- For symbol-not-found: distinguish "renamed" (look for git log mentioning the old name) from "never existed" (search blame history). The first is `body-needs-update`; the second is a flag for the operator.

**Tracker MCP patterns** (assuming Linear-style; adapt to your tracker):

- `save_issue` handles both create and update — pass `id` to update an existing issue.
- Label arrays replace, not append — always pass the full desired label list when changing labels.
- `state: "Todo"` + `{{IMPLEMENT_LABEL}}` (if set) triggers AI-Implement-style pickup within minutes; only use that state for the small set of issues you actually want the agent to grab next.
- `state: "Backlog"` is for issues with unmet dependencies, not a general default.

**Closing-comment shape** (use this template for done-tombstones):

```
**Closed YYYY-MM-DD as done-tombstone** via project triage audit.

<2-4 sentence root-cause-was-X explanation>

Verified on `origin/{{BASE_BRANCH}}`:
- <citation 1 with file:line>
- <citation 2 with commit SHA or config flag value>

<Optional: forward-looking note about what to do if the symptom recurs>
```

The shape matters: future-you (or another operator running this skill in 6 months) wants the evidence cited, not your reasoning compressed into "looks done."

**Project description rewrite shape:**

- Open with one sentence stating what the project does (NOT how it's tracked).
- Add a `## Status (YYYY-MM-DD)` section with the post-triage counts and a 2-3 sentence current-state synthesis.
- Enumerate the post-triage backlog explicitly (each open issue gets a one-line description).
- Footer with migration provenance if applicable.

**Stop-before-writes pattern:** every project-triage invocation MUST surface the write plan and pause for explicit user approval. The skill never auto-merges its own audit. This is the safety contract — the operator may catch one mis-classification per audit and that's the entire point of the gate.

## Why this skill exists (and where it slots into the BuildDownAI lineup)

The BuildDownAI skill set covers planning (`build-up`, `mega-build-up`), pre-flight (`summit-push`), execution (AI-coding agent), and PR-side closure (`build-down`, `super-build-down`, `smoke-jumper`). The gap was the **tracker side** of an existing project that's drifted out of sync with code.

Project-triage fills it:

```
  build-up / mega-build-up   →   summit-push   →   [AI-Implement label]   →   build-down / super-build-down
       (creation)                 (sequencing)         (execution)                  (PR closure)

                                    ↑                                                       ↓
                                    │                                                       │
                                    └─────────────  project-triage  ─────────────────────┘
                                                  (drift correction)
```

Run project-triage between phases of work, after a migration, or whenever the tracker view stops matching reality. Output feeds back into build-up (gap-found issues) and build-down (cleaner PR queue).

## Triggers (canonical phrasing)

The description block already lists these for the harness, but for reference:

- "triage this project"
- "audit this project"
- "project triage"
- "clean up the project"
- "this project is a mess"
- "where are we on {project name}"
- "review the issue tracker for {project}"
- "what's actually still relevant in {project}"

If the user mentions any of these AND names (or scope-limits) a specific project, run this skill. If they're asking a generic "where are we" with no project name, start with Phase 1 (Snapshot) of every active project they mention — or ask which project.
