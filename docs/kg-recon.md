# Knowledge Graph Recon

Shared recon procedure for the four session-owning skills (`bd-build-up`, `bd-mega-build-up`, `bd-build-down`, `bd-super-build-down`). After these skills post learnings to the tracker, the recon step here reads them back and closes the loop. When a project has a knowledge graph bound, recon orients the operator with relevant prior decisions and gaps.

## Guard

Read the project's CLAUDE.md for a `## Knowledge graph` block (format: `docs/kg-binding.md`). If `kg.present` is false or the block is absent, **skip silently — no output, no warning**. (This is an incidental step, one input among many; projects without a graph proceed unaffected.)

When the block is present and `kg.present: true`, continue to the query step.

## Query

Derive **1–3 short queries** from the work at hand — e.g. the objective's key nouns, or an issue key + title + gap topics from its gap analysis. These queries are brief and direct (2–4 words), surfacing the core concept(s) the operator needs orientation on.

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

Both `stat` forms yield epoch seconds; convert to an ISO timestamp for the queries below with `date -u -r <epoch> +%Y-%m-%dT%H:%M:%SZ` (macOS) or `date -u -d @<epoch> +%Y-%m-%dT%H:%M:%SZ` (Linux).

Compare to now and **always note the age in one line** — e.g., "KG last built 4 hours ago" or "KG is fresh (2 hours old)".

**If the KG is older than 24 hours**, list what the KG is blind to at its standard ingest points. The threshold is hour-granular, so use an ISO timestamp, not a bare date, in both queries:

- Tracker issues **updated** since the build time — query the project's bound tracker MCP (Linear "updated after `<ISO timestamp>`", Jira likewise) and report the count.
- PRs **merged** since — `gh pr list --state merged --search "merged:>=<YYYY-MM-DDTHH:MM:SSZ>" --limit 20` — and report the count.

Present the gap explicitly ("KG last built `<age>` ago; since then `N` issues changed, `M` PRs merged — treat results as missing these") and nudge the operator to run `bd-kg-refresh` for fresh results.

**If the KG is fresher than 24 hours**, skip these delta queries — stay fast. A recent build is good enough; no need to dig into tracker history.

## Failure tolerance

Any error — tool unavailable, degraded response, empty index, tracker or `gh` hiccup — generates **one-line note** and **proceeds**. Recon is advisory, never blocking.

- Missing tool → "KG search unavailable (tool error); proceeding without orientation."
- Degraded index → "KG vector index not loaded (results lexical-only); run `bd-kg-refresh` and restart Claude Code for full hybrid search."
- Empty index → "KG index empty; no prior learnings to draw on."
- Stale graph file → "Could not stat graph.trig; KG staleness unknown."
- Tracker query fails → "Tracker unavailable; staleness gap unknown."

The session continues unaffected.
