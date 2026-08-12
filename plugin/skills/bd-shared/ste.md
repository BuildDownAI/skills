# Simplified Technical English (STE)

Shared writing-style reference for the BuildDown skills. When a skill says "STE", it means
this file. Two surfaces use it:

- **Tickets** — the title and the opening paragraph of every filed issue.
- **Decisions** — every question a skill asks the user to decide, in any phase.

**Why.** The people who read tickets and answer questions vary in technical depth and in
English fluency. STE keeps the decision visible: one idea per sentence, no idiom to decode,
no synonym to reconcile. The reader spends their attention on the trade-off, not on the prose.

STE here means the ASD-STE100 *grammar* rules plus the spirit of its dictionary — not full
dictionary compliance. An established technical term ("idempotency key", "feature branch",
"migration") is allowed when the grammar rules hold and the term is more precise than a
common word.

## Core rules

Apply every rule to every STE sentence:

1. **Active voice.** Name the actor. "The pipeline picks up the issue" — not "the issue is
   picked up."
2. **Present tense** where possible.
3. **One idea per sentence.** Split compound sentences.
4. **Keep sentences to 20 words or fewer** (25 for descriptive text).
5. **One word, one meaning — one meaning, one word.** Pick one term per concept and repeat
   it. An issue stays an "issue" — it does not become a "ticket", then a "task", then a "card".
6. **Prefer common words over jargon.** Use a simple verb: "Add", "Remove", "Change", "Show",
   "Make", "Use", "Keep", "Start", "Stop".
7. **Keep noun clusters to 3 words or fewer.** "The retry queue for webhooks" — not "the
   webhook delivery retry queue".
8. **State facts literally.** "This decision affects three issues" — not "this decision has a
   big blast radius". No idioms, no figures of speech.
9. **Explain each abbreviation at first use**, unless the project already defines it (PR,
   API, and the project's own names are fine).
10. **Terms of art are allowed.** A precise technical term beats a vague common one — keep
    the sentence around it simple.

More short sentences beat one dense sentence. When a rule forces a split, split — never
compress by dropping information.

## Ticket style — two audiences, in this order

1. **Title — STE.** One short statement of the work: a simple verb, active voice, noun
   clusters of 3 words or fewer, roughly 10 words.
   Example: `Add pagination to the employees API` — not
   `Employees API pagination support implementation`.
2. **Opening paragraph — STE.** The body starts with 2–4 plain sentences, before any heading,
   that say what the ticket is and why it exists. A human skimming the board must understand
   the ticket from this paragraph alone.
3. **Rest of the body — maximally legible to AI agents.** After the opening paragraph,
   optimize for a coding agent reading cold: exact file paths in backticks, complete code
   blocks instead of descriptions of code, explicit values instead of "appropriate" ones, the
   exact section headings the skill's body template names (they are parsed), consistent names
   for every type/function/route across sections, and no information that exists only behind
   a link.

## Decision style — questions to the user

Every time a skill asks the user to decide — a clarifying question, a grill question, a scope
cut, a filing choice, an approval gate — write the whole exchange in STE:

- **The question.** One decision per question. State it in one sentence where possible.
- **The options.** Name each option and what it does. Use parallel grammar across options.
- **The trade-off.** One sentence per cost or benefit. Name the concrete failure — "the
  cleanup PR fails in CI" — not a category like "there are operational risks".
- **The recommendation.** State it plainly. Give the reason in its own sentence.

Before/after examples:

| Instead of | Write |
|---|---|
| "Should we maybe consider whether the ingestion path could be made more robust against partial failures?" | "The import stops when one row fails. Do we skip bad rows and report them, or do we stop the import?" |
| "Are we OK with the potential double-charge scenario under concurrent submission?" | "If two users submit at the same time, the design charges the customer twice. Do we accept this, or do we add an idempotency key?" |
| "It might be worth thinking about the auth story here." | "Who can call this endpoint? I recommend: only signed-in team members." |

Check each question against the Core rules before you send it. Routine narration ("filing
issue 3 of 8…") is not a decision — plain style is fine there.
