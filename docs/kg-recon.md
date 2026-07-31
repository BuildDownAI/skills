# Knowledge Graph Recon

Shared recon procedure for the four session-owning skills (`bd-build-up`, `bd-mega-build-up`, `bd-build-down`, `bd-super-build-down`). After these skills post learnings to the tracker, the recon step here reads them back and closes the loop. When a project has a knowledge graph bound, recon orients the operator with relevant prior decisions and gaps.

## Guard

Read the project's CLAUDE.md for a `## Knowledge graph` block. If `kg.present` is false or the block is absent, **skip silently — no output, no warning**. (This is an incidental step, one input among many; projects without a graph proceed unaffected.)

When the block is present and `kg.present: true`, continue to the query step.

## Query

Derive **1–3 short queries** from the work at hand — the issue being decomposed or implemented, the gap being closed, the tests being verified. These queries are brief and direct (2–4 words), surfacing the core concept(s) the operator needs orientation on.

Call **`kg.search_tool`** (and only `kg.search_tool` — hybrid-search only) with `{query, limit: 8}`. Repeat for each derived query if multiple are needed.

## Use the results

Surface the top relevant learnings, decisions, and prior issues from the graph hits as **orientation context**. Where a hit changes a plan choice or closes a gap, cite it inline — e.g., "prior learning AII-259 says … so …" — to anchor the connection.

**Advisory, not required.** If nothing in the hits is relevant to the work at hand, say so in one line and move on. Do not force citations when the KG has no signal.

## Staleness-delta

Get the KG's last-build time from the graph file:

```bash
stat -f %m "<kg.path>/out/graph.trig"  # macOS
stat -c %Y "<kg.path>/out/graph.trig"  # Linux
```

Compare to now and **always note the age in one line** — e.g., "KG last built 4 hours ago" or "KG is fresh (2 hours old)".

**If the KG is older than 24 hours**, list what the KG is blind to at its standard ingest points:

- Tracker issues **updated** since the build time — query the project's bound tracker MCP (Linear "updated after `<YYYY-MM-DD>`", Jira likewise) and report the count.
- PRs **merged** since — `gh pr list --state merged --search "merged:>=<YYYY-MM-DD>" --limit 20` — and report the count.

Present the gap explicitly ("KG last built `<age>` ago; since then `N` issues changed, `M` PRs merged — treat results as missing these") and nudge the operator to run `bd-kg-refresh` for fresh results.

**If the KG is fresher than 24 hours**, skip these delta queries — stay fast. A recent build is good enough; no need to dig into tracker history.

## Failure tolerance

Any error — tool unavailable, empty index, tracker or `gh` hiccup — generates **one-line note** and **proceeds**. Recon is advisory, never blocking.

- Missing tool → "KG search unavailable (tool error); proceeding without orientation."
- Empty index → "KG index empty; no prior learnings to draw on."
- Stale graph file → "Could not stat graph.trig; KG staleness unknown."
- Tracker query fails → "Tracker unavailable; staleness gap unknown."

The session continues unaffected.
