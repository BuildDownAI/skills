---
name: belay-on
description: "Pause-and-recon pattern for multi-tool sessions. Trigger this skill when the user says 'belay-on', 'belay on', 'hold while I check', 'sending to {tool}', 'need code eyes on this', 'back from recon', 'here are the results', or when a session hits a question that can't be answered from the current tool's perspective and needs dispatching to another tool (chat→code-reading agent, chat→code-execution, code-execution→code-reading, etc). Belay-on formalizes the handoff between tools with different capabilities — it generates targeted recon prompts when pausing, and integrates recon results when resuming. Use any time a session needs to pause for information that requires a different tool's perspective."
---

# Belay-On Skill

A climbing term: "belay on" means the safety system is engaged and the climber can proceed. In the workflow, it means: **I'm pausing this session to gather information from a tool with a different perspective, and I'll resume when results come back.**

Belay-on formalizes a pattern the build skills (build-down, build-up, summit-push, super-build-down) already anticipate. Each declares its environment at session start and notes when to belay-on. This skill is what actually produces the handoff.

**When belay-on does not apply:**

- **Fully autonomous sessions** (super-build-down, overnight runs). If the session can't pause and wait for a human to relay results from another tool, belay-on is the wrong pattern. Escalate to the host skill's pattern-break list instead.
- **Within-environment questions.** If the information is reachable from the current tool, no belay-on — just answer.

---

## Tool Perspective Map

Each tool in the workflow has capability and blind spots. This is the reference that drives belay-on targeting.

| Tool | Strengths | Blind Spots |
|---|---|---|
| **Chat environment** (e.g., claude.ai) | Tracker MCP, GitHub MCP, browser MCP, project context, conversation memory, cross-session recall | No bash, no local filesystem, can't run code or tests, can't directly verify file contents against a local repo |
| **Code-execution environment** (e.g., Claude Code, terminal) | Bash, local filesystem, git, can push commits, can run build commands and tests, tracker MCP if configured | No project memory across sessions, thinner strategic context, no cross-session recall |
| **Code-reading agent** (e.g., desktop tool with deep filesystem access) | Deep codebase reading, grep across many files, pattern tracing across files faster than chat's reads | No tracker MCP, no GitHub MCP, no project memory, can't file or modify anything external |
| **Browser MCP (in chat)** | Sees the running app, clicks through UI, reads rendered pages, tests preview deploys | Surface-level only, can't read source code, can't query databases directly |

Most chat sessions have browser MCP available as a sub-capability — it's not a separate environment, it's a tool chat uses. The belay-on targets are the code-execution environment and the code-reading agent; browser MCP is usually invoked in-session from chat.

**Code-reading agent's residual role:** Most of what dedicated code-reading agents used to do is now better handled by chat + GitHub MCP. Belay-on to a code-reading agent only when chat's read operations are too slow for the question (e.g., grep across 50+ files) or when the pattern requires reading file contents chat can't access.

---

## Two Modes

### Mode 1: Dispatch ("I need eyes elsewhere")

Triggered when:

- The user explicitly says "belay-on," "sending to {tool}," "need code eyes on this," or equivalent
- A host build skill identifies an assumption that needs cross-tool validation. Specific triggers:
  - **Summit-push** confidence score ≤3 due to unverifiable codebase assumption → belay-on to a code-reading agent or code-execution
  - **Build-up** orient phase needs to read prototype or production codebase → belay-on to a code-reading agent
  - **Build-down** agent conflict resolution has looped twice → belay-on to code-execution for manual resolution
  - **Build-down** a PR's diff behavior can't be verified from GitHub MCP alone → belay-on to browser MCP preview test (usually in-session, not a full belay)
  - **Code-execution session** needs strategic context about a PR's product intent → belay-on to chat

**What the skill does:**

1. **Identify the perspective gap.** What specifically can't be answered from here? State it in one sentence.
2. **Identify the target tool.** Which of chat / code-execution / code-reading agent can answer it? If the question requires multiple, split into multiple recon prompts.
3. **Generate the recon prompt.** Write a self-contained markdown file tailored to the target tool's capabilities (templates below).
4. **Save and present the prompt.** Write to `/mnt/user-data/outputs/recon-{target}-{topic}.md` and use `present_files` so the user can download or copy.
5. **Mark the session as paused.** Post the pause marker (format below). State what we're waiting on and where to resume.

### Mode 2: Integrate ("results are back")

Triggered when:

- The user pastes recon results into the session
- The user says "back from recon," "here are the results," or equivalent
- The user uploads screenshots or text from another tool

**What the skill does:**

1. **Parse the incoming results against the original recon questions.** Match answers to numbered questions — if something is missing, say so before proceeding.
2. **Update the session's understanding.** Fill the gaps that triggered the dispatch.
3. **Revise any assessments that were uncertain.** Confidence scores, merge recommendations, issue body drafts — all get updated against the new facts.
4. **Resume the interrupted workflow.** Host skill continues from its recorded resume point.

---

## Recon Prompt Templates

### Universal structure

```markdown
# {Target Tool} Recon: {Topic}

## Context
{What session is running, what we're doing, why we paused. 2-3 sentences.}

## What We Know Already
{Findings so far — don't make the target tool redo work. Include file paths, issue IDs, PR numbers, whatever's relevant.}

## What I Need You To Investigate

### 1. {Specific question}
{Details, file paths, what to look for}

### 2. {Specific question}
...

(3-7 questions max — bounded investigation, not an audit.)

## Output Format
{Exactly what to bring back — code snippets, yes/no answers, file contents, screenshots.}

## This Feeds Back Into
{Which session resumes, what decision the results unblock.}
```

### Target-specific guidance

**For a code-reading agent (code reading / pattern grep):**
- Reference specific file paths to examine
- Ask for code snippets, not summaries
- Request grep/search results for specific patterns ("find all places we call `get_widget`")
- Ask about data flow: "where does X get set? what calls Y?"
- Don't ask about tracker state, PR metadata, or GitHub status — code-reading agents can't see those

**Example question for a code-reading agent:**
> 1. Open `src/app/widgets/[id]/page.tsx`. Does the component still use the `useThing` hook imported from `@/hooks/use-thing`? If so, paste lines 1-30 of the file. If the hook has been replaced with something else, identify the replacement.

**For code-execution (code + execution):**
- Everything a code-reading agent gets, plus:
- "Run this command and report the output"
- "Check if this test passes"
- "What does the build command say about this file?"
- "Stage these changes on a new branch and push"
- Don't ask about strategic context or past-session history

**Example question for code-execution:**
> 1. On branch `{ISSUE-ID}/some-feature`, run `git merge main`. If there are conflicts, paste the conflict markers for each file. If the merge succeeds cleanly, run the build command and report the result.

**For browser MCP (UI verification — usually in-session, not a full belay):**
- Provide specific URLs (production or preview)
- Describe what to look for on each page
- Ask for screenshots or `read_page` extractions of specific states
- Don't ask about code internals or database state

**For chat (strategic context — when code-execution or code-reading is calling back):**
- Ask about tracker issue state, dependencies, blockers
- Ask about product decisions, priorities, sequencing
- Ask about memory/history from past sessions
- Don't ask about code internals

### Quality bar

- **Self-contained.** The target tool should not need clarifying questions to start.
- **Specific.** File paths, not "look around the codebase." Exact commands, not "check if it works."
- **Bounded.** 3-7 questions. Anything more should be split into multiple recon prompts.
- **Actionable.** Results directly unblock a decision in the paused session.

---

## Pause and Resume Markers

### On dispatch

Post this marker in the conversation when sending off a recon:

```
⏸️ BELAY-ON: Dispatched to {Chat | Code-execution | Code-reading agent}
   Waiting for: {1-line summary of what we need}
   Resume point: {where to pick up when results arrive — skill name + phase}
   Prompt artifact: {filename in /mnt/user-data/outputs/}
```

Do not continue the host skill's workflow past this point. Wait for the user to return with results.

### On resume

Post this marker when the user returns with recon results:

```
▶️ RESUME: Results from {Chat | Code-execution | Code-reading agent}
   Gaps filled: {what we learned}
   Revised assessments: {what changed vs. pre-belay state}
   Continuing: {what we do next — skill name + phase}
```

Then continue the host skill's workflow from the recorded resume point.

### Timeout behavior

If the user hasn't returned within the span of a single session and appears to have moved on:

- Do not assume results. The uncertainty that triggered the belay is still unresolved.
- If the host skill can proceed with the uncertainty flagged (e.g., summit-push marks the issue as 3/5 confidence and continues), do that.
- If the host skill cannot proceed, summarize what's pending and stop. The user will resume when they return.

---

## Integration with Host Skills

### Summit-push → belay-on

Summit-push rates issues 1-5. A score of 3 or below often means "I can't verify the codebase assumption this issue description is making." Belay-on to a code-reading agent with specific questions about the assumption.

Example dispatch:
> "{ISSUE-ID} scored 3/5 — the issue assumes `some-component.tsx` still has phase routing. Can't verify from here. Dispatching recon to code-reading agent."

### Build-up → belay-on

Build-up Phase 1 orient often needs to read prototype or production codebase to write accurate issue descriptions. In chat, belay-on to a code-reading agent for the read.

Example dispatch:
> "Need the exact database query pattern for the relevant predictions before I can write {ISSUE-ID}. Dispatching recon to code-reading agent."

### Build-down → belay-on

Build-down mostly self-contains in chat (tracker MCP + GitHub MCP covers most needs). Belay-on fires when:

- The agent has failed twice on the same conflict — dispatch to code-execution for manual resolution
- A PR's behavior needs to be verified in the preview, and browser MCP in-session isn't enough — dispatch to smoke-jumper or code-execution for deeper testing
- A migration needs manual application — dispatch to code-execution

### Build-down in code-execution → belay-on

If a code-execution session needs strategic context about a PR's product intent or history, dispatch to chat.

Example dispatch (from code-execution):
> "Before I resolve this conflict manually, I need the product-intent context for why PR #447 took this approach. Dispatching to chat."

### Super-build-down does NOT use belay-on

Super-build-down is designed to run autonomously. If it hits a condition that would warrant a belay, that's a pattern break — it goes to the Tier 3 batch escalation instead. Do not dispatch recon prompts from a super-build-down session.

---

## Conventions

- Recon prompts are always produced as markdown files in `/mnt/user-data/outputs/`
- Prompts destined for chat (when code-execution or code-reading agent is calling back) use the same chat-capability vocabulary
- When dispatching to browser MCP, use current production/preview URLs — confirm these are still correct if in doubt
- Project-specific path conventions apply for code-execution and code-reading prompts working in a particular repo
- If the user says "belay-on" without specifying a target tool, infer from the question type:
  - Code content questions → code-reading agent (read-only) or code-execution (if write needed)
  - "Does this actually work?" → browser MCP (in-session if possible) or code-execution
  - "Can you fix this?" → code-execution
  - Strategic/planning questions → chat
- Belay-on is general-purpose. The build-system examples in this skill illustrate the pattern; other contexts can use the same skill with different host-skill integrations.

---

## Key Principles

1. **Belay-on formalizes a handoff, not a workaround.** It exists because tools have real capability differences — not because any single tool is broken.
2. **Pause, don't guess.** If the host skill needs information it can't get, dispatch a recon. Don't proceed with speculation.
3. **Bounded investigation.** 3-7 questions per recon. Bigger asks get split.
4. **Specific beats open-ended.** File paths, exact commands, concrete output formats. No "look around."
5. **The dispatch is complete before waiting.** Save the prompt file, present it, post the pause marker — then stop. Don't keep working.
6. **Not for autonomous runs.** Super-build-down and overnight sessions escalate instead of belay.
7. **Tool perspectives are capability, not preference.** Route based on what the tool can see, not on what feels familiar.
