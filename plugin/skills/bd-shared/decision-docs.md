# Decision docs — ADRs and the glossary

Shared reference for the grill phases. The grill produces **durable repo documents**, not a
throwaway plan. An ADR and a glossary entry outlive the session, the tracker issue, and the
person who ran the build-up. The next build-up reads them, and so does any coding agent
working in that part of the codebase.

Write them **as decisions land**, inside the grill. Do not batch them to the end — a batched
doc gets written from memory and loses the alternatives that made the decision interesting.

## Where they live

ADRs go in `{{ADR_DIR}}`, which defaults to `docs/adr/`. The glossary is a root `CONTEXT.md`.

```
/
├── CONTEXT.md              ← the glossary
└── docs/adr/
    ├── 0001-event-sourced-orders.md
    └── 0002-postgres-for-write-model.md
```

If a `CONTEXT-MAP.md` sits at the repo root, the repo has several bounded contexts and the map
says where each one's `CONTEXT.md` and `docs/adr/` live. Write into the context that owns the
work; system-wide decisions go in the root `docs/adr/`.

Create files lazily. No `CONTEXT.md` until the first term is worth pinning. No `docs/adr/`
until the first decision earns an ADR.

These **are** committed to the code repo. They are canonical reference, unlike the working
notes a session generates.

## When a decision earns an ADR

Offer one only when all three hold:

1. **Hard to reverse** — changing your mind later costs real work.
2. **Surprising without context** — a future reader will ask "why did they do it this way?"
3. **A real trade-off** — there were genuine alternatives, and you picked one for stated
   reasons.

Miss any one of the three and skip the ADR. Most grill decisions do not earn one. A decision
that fails the test still belongs in the issue body's `## Notes` and in the build-up learnings
comment — it just does not become a permanent repo document.

### ADR format

```markdown
# {NNNN}. {Decision, as a short statement}

**Status:** Accepted
**Date:** {YYYY-MM-DD}

## Context

The forces at play, in 1–2 paragraphs. What made this a question at all.

## Decision

What we chose, in the active voice. "We store audit events in the existing `events` table."

## Alternatives considered

- **{Alternative}** — why we rejected it, naming the concrete cost.

## Consequences

What becomes easier, and what becomes harder. Name the follow-on work this creates.
```

Number ADRs sequentially from the highest existing number. Never renumber an existing ADR.

## The glossary

`CONTEXT.md` is a glossary and nothing else. It is free of implementation detail. It is not a
spec, a scratchpad, or a home for decisions — those are ADRs.

Sharpen terms during the grill, and write each one down the moment it resolves:

- **Challenge a conflicting term.** When the user's usage contradicts the glossary, say so.
  *"Your glossary defines cancellation as X. You seem to mean Y. Which is it?"*
- **Sharpen a fuzzy term.** Propose a precise canonical name. *"You say account. Do you mean
  the Customer or the User? Those are different things."*
- **Check the term against the code.** When the user states how something works, verify it. A
  contradiction is worth surfacing immediately.

One name per concept, and one concept per name. That is the same rule STE applies to
sentences, applied to the domain — see [`ste.md`](./ste.md).

### Glossary entry format

```markdown
## {Term}

{One or two sentences defining it, in the domain's language, with no implementation detail.}

**Not to be confused with:** {the neighbouring term it is most often conflated with}
```
