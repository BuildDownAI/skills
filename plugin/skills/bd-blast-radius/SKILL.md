---
name: bd-blast-radius
description: "Document the blast radius of one shared path — a credential, a token, a callback, or a shared table — from the knowledge graph and the code: who produces it, who carries it, which processes can see it, who consumes it, and what one stray use destroys. Writes the result into the repo's docs/ as a subsystem reference section, so the next change to that path starts from a census instead of an incident. Trigger when the user says 'bd-blast-radius', 'blast radius', 'document the blast radius of X', 'who can see this credential', after an incident whose cause is a credential or shared-state misuse, or from bd-high-plan Phase 4 and the bd-mega-build-up trust-boundaries branch when a step touches such a path."
metadata:
  suite: builddown
---

# bd-blast-radius Skill

One shared path, one document section. The output is a repository reference page (or a section
of one) that a person and the knowledge graph (KG) both read. Template and rubric:
[`../bd-shared/blast-radius.md`](../bd-shared/blast-radius.md).

**Cardinal rule: cite the line, not the belief.** Every producer, carrier, reader, verifier, and
stripper is a file path with a line, verified in the checkout. A row that cannot be cited is
marked "not verified" in the document, never guessed.

Write prose in Simplified Technical English — [`../bd-shared/ste.md`](../bd-shared/ste.md).

## When to use

- After an incident whose root cause is a credential, a token, a callback, or a shared table
  reaching a process that should not hold it, or being consumed by the wrong caller.
- Before a plan step that adds, moves, or scopes such a path (bd-high-plan Phase 4 names the
  door; this skill documents the room behind it).
- When a subsystem reference in `docs/` names a credential without saying who can see it.

Do not use it for a change with no shared state and no credential. The census would be empty.

## Steps

1. **Name the path.** One credential, token, callback, or table per run of this skill. Write
   its name exactly as the code spells it. If the user names a subsystem, list the paths in it
   and ask which one, or run once per path.

2. **KG recon.** Follow [`../bd-shared/kg-recon.md`](../bd-shared/kg-recon.md): search for the
   path's name, its incidents, its decisions, and any existing `docs/` page. Announce the
   target. Prior incidents become rows in the blast-radius table; prior decisions become the
   Related list. Silent skip when no KG is bound.

3. **Census by grep.** In the checkout, find and cite:
   - **Producers** — where the value is minted, created, or written first.
   - **Carriers** — every dispatch path, environment, envelope, input, or file that moves it.
   - **Readers** — every module that reads it, including tests.
   - **Verifiers and consumers** — every check, and whether the check destroys the value
     (`consume`, delete, single-use).
   - **Strippers and boundaries** — every place the value is removed from a child environment,
     and which processes use which builder.

4. **Process-boundary table.** One row per process class the runtime spawns. One column per
   credential class. Each cell says present or stripped, with the builder that decides it.

5. **Failure walk.** For each credential, answer four questions in one table row: one stray use
   does what; what is lost; where the symptom appears (usually another subsystem); how it is
   recovered. Cite the incident if one exists. Mark inferred rows "inferred, not observed".

6. **Rules and the census checklist.** Write the rules the incident or the plan established,
   with the test or hook that enforces each. Write the census as a checklist the next change
   runs before it edits the path.

7. **Write it where it lives.**
   - A new subsystem reference page under `docs/` when none covers the path, with a row in
     `docs/README.md` and the reference link in the repo's `CLAUDE.md` subsystem index.
   - A `## Blast radius` section in the existing reference page when one covers the path.
   - When an incident triggered the run: the learning record under `docs/solutions/` (if the
     repo keeps one) links to the new section, and the section links back.
   - A rule that is hard to reverse, surprising, and a real trade-off earns an ADR — apply the
     test in [`../bd-shared/decision-docs.md`](../bd-shared/decision-docs.md).
   - Flow diagrams in mermaid, validated before commit, if the repo's docs rule says so.

8. **Deliver.** One PR, docs only, against the development branch. When the run was driven
   from an issue, add the outcome to that issue's learnings comment
   ([`../bd-shared/learnings-comments.md`](../bd-shared/learnings-comments.md)). Then run
   `bd-kg-refresh` if the operator wants the page searchable before the next scheduled refresh.

## Red flags

- **A row with a module name and no line.** → Not verified. Cite it or mark it.
- **"The agent did it."** → Find the process that held the value. The model process is often
  the one that could not.
- **A blast-radius table with one row.** → The path has more than one credential class, or
  the failure walk stopped early. Walk the carriers again.
- **Rules with no enforcing test named.** → File the test as an issue or name the gap in the
  document. A rule nobody can run is a wish.
- **The page written from memory of the incident.** → The census is grep output. Run it.

## Related skills

- **bd-high-plan** — Phase 4 names the doors; this skill documents the room behind each one.
- **bd-mega-build-up** — the trust-boundaries branch of the grill cites or produces this document.
- **bd-build-down** — an incident with a credential or shared-state cause runs this before the
  session summary.
- **bd-kg-search / bd-kg-refresh** — the recon in, the refresh out.
