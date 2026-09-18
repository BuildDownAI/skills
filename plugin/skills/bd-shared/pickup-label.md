# Pickup-Label Resolution

Shared procedure for resolving the pipeline pickup label before every action that assigns it.
Called at session start by planning and landing skills.

## Resolution (rules 1–4)

**Rule 1 — Orchestrator (primary).** At session start, `./session-start.md` calls
`get_project_binding` and stores `pickupLabel` from the response. Read that stored session
value. Print once:

> `pickup label: <value> (label from orchestrator)`

**Rule 2 — Project binding (fallback).** If `get_project_binding` is absent from the tool list
or returns no `pickupLabel`, read `{{IMPLEMENT_LABEL}}` from the project binding:
- In a checkout session: the `{{IMPLEMENT_LABEL}}` binding in `CLAUDE.md`.
- In a chat session: the project instructions.

Store the value and print once:

> `pickup label: <value> (label from project binding)`

If no binding exists (no `CLAUDE.md` or no `{{IMPLEMENT_LABEL}}` line), use the orchestrator
default `AI-Implement` and print once:

> `pickup label: AI-Implement (label from default)`

**Rule 3 — Re-resolve before assignment.** Re-resolve the pickup label immediately before every
action that assigns it to an issue (rule 1 → 2, including the no-binding sub-case, in order). Read-only scans and status
checks use the session value resolved at session start — no extra call needed.

**Rule 4 — Use verbatim.** Use the resolved value exactly as returned. Never change its case,
spelling, or whitespace.

## Jira carve-out (rule 5)

On Jira, the pickup signal is the `AI-Implement-Status` **field**, not a label. The field name
`AI-Implement-Status` is defined in the orchestrator mapping; skills do not resolve it
dynamically. Rules 1–4 do not apply on Jira — see the Jira adapter's **Pickup trigger**
section (`trackers/jira.md`).
