---
name: bd-shared
description: "Shared procedures and reference files that every other BuildDown skill reads by relative path (session-start.md, pickup-label.md, kg-recon.md, the tracker adapters, and the rest). This is not a skill a person runs. It carries a SKILL.md only so that claude.ai loads this folder next to the other skills; without one, chat sessions cannot read the shared files. If invoked directly, say that and stop."
metadata:
  suite: builddown
  client: any
  requires: []
---

# bd-shared

This folder is a library, not a skill. Every other BuildDown skill points at it with
`../bd-shared/<file>.md`. The index of files and who reads them is `README.md` in this folder.

If a person invokes `bd-shared` directly, print one line:

> bd-shared holds shared procedures for the other BuildDown skills; run one of those instead.

Then stop.
