# Blast radius — the document and the rubric

Shared reference for `bd-blast-radius`, `bd-high-plan` (Phase 4), `bd-mega-build-up` (trust
boundaries), and `bd-build-down` (incident follow-up). A blast-radius document answers, for one
shared path, five questions with cited lines: who produces it, who carries it, who can see it,
who consumes it, and what one stray use destroys.

## When a path earns the document

Any one of these:

1. A credential, token, or secret that crosses a process or machine boundary.
2. A value that is consumed, deleted, or single-use, so a stray use is irreversible.
3. A shared table or file with more than one writer.
4. A callback or endpoint that accepts a bearer credential from a runtime the repo does not
   fully control (a runner, a hook, a test suite).

A path that meets none of these gets no document. Do not pad `docs/` with censuses of
harmless values.

## The section template

```markdown
## Credentials            (one row per credential or shared value)
| Name | Audience or scope | Minted / written | Carried by | Read by | Verified by | Consumed |

## Process boundary       (one row per spawned process class)
| Process | Environment builder | <credential class> | <credential class> | ... |

## Blast radius           (one row per credential)
| Credential | One stray use | What is lost | Where the symptom appears | Recovery |

## Rules                  (numbered; each names the test or hook that enforces it)

## The census: before you change this path   (checklist: producers, carriers, readers,
                                              verifiers, strippers, tests)

## Related                (issues, PRs, ADRs, the learning record; planned changes marked
                          "not landed" or "not scheduled")
```

Every cell that names code cites a path, and a line where the line matters (a verifier's
`consume` flag, a stripper's key list). A cell the author could not verify says "not verified"
in the cell. A failure row the author inferred says "inferred, not observed".

## Writing rules

- Prose in Simplified Technical English (`./ste.md`). Tables carry the facts; prose carries the
  consequence a reader must remember.
- Name the process that held the value, never the actor people assume held it. The incident
  that produced this rubric was blamed on "the agent"; the agent's process had the value
  stripped, and a repository test process under a pipeline step held it.
- Recovery is a fact, including "none for that run".
- The document is a subsystem reference: it is maintained, and a change to the path updates it
  in the same PR. It is not a historical record; the learning record under `docs/solutions/`
  is.

## Hooks in other skills

- **bd-high-plan, Phase 4 (security lens):** for each door a step adds or touches, cite the
  blast-radius section that covers it, or run `bd-blast-radius` before filing the parent. A
  door with no census is not settled.
- **bd-mega-build-up, trust boundaries:** the grill's trust-boundary questions are asked
  against the census, not against memory. No census, no settled boundary.
- **bd-build-down:** an escalation or a blocker whose cause is a credential or shared-state
  misuse runs `bd-blast-radius` before the session summary, and the summary links the page.
