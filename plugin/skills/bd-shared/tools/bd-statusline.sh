#!/usr/bin/env bash
# Claude Code statusline renderer for the BuildDown session state file.
#
# Reads the statusline JSON Claude Code pipes on stdin, finds `.bd/session.md`
# in the session's working directory (contract: ../session-state.md), and
# prints one line:
#
#   bd-build-down · 4 merge · 3/7 merged · 1 awaiting-agent · 1 escalated · 14:40Z
#
# With no session file it prints the model and directory, so it is safe to
# install as the only statusline. Dependencies: bash, awk, sed — no jq, no
# python, because this runs on every prompt redraw.
#
# Install (once per machine), in ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "bash /path/to/bd-statusline.sh" } }
set -u

input="$(cat)"

# Pull a top-level or nested string value out of the statusline JSON without jq.
json_str() {
  printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1
}

dir="$(json_str current_dir)"
[ -z "$dir" ] && dir="$(json_str cwd)"
[ -z "$dir" ] && dir="$PWD"
model="$(json_str display_name)"

file="$dir/.bd/session.md"

if [ ! -f "$file" ]; then
  printf '%s%s\n' "${model:+$model · }" "${dir/#$HOME/"~"}"
  exit 0
fi

awk '
  # Header: `key: value` lines before the table.
  /^skill:/   { sub(/^skill:[ \t]*/, "");   skill = $0; next }
  /^phase:/   { sub(/^phase:[ \t]*/, "");   phase = $0; next }
  /^updated:/ { sub(/^updated:[ \t]*/, ""); updated = $0; next }

  # Queue rows: | PR | Issue | Tier | State | Last action |
  /^\|/ {
    n = split($0, c, "|")
    if (n < 6) next
    state = c[5]; gsub(/^[ \t]+|[ \t]+$/, "", state)
    if (state == "State" || state ~ /^-+$/) next
    total++
    if (state == "merged") { merged++; next }
    if (state == "closed-unmerged" || state == "superseded") { failed++; next }
    open[state]++
  }

  END {
    line = (skill != "" ? skill : "bd-session")
    if (phase != "") line = line " · " phase
    if (total > 0) line = line " · " merged+0 "/" total " merged"
    if (failed > 0) line = line " · " failed " closed"
    # Fixed order so the line is stable as counts change.
    split("escalated blocked awaiting-agent awaiting-ci smoke-testing merge-ready triaging queued", order, " ")
    for (i = 1; i <= 8; i++) {
      s = order[i]
      if (s in open) line = line " · " open[s] " " s
    }
    if (updated != "") {
      t = updated; sub(/^[^T]*T/, "", t)      # keep HH:MMZ
      line = line " · " t
    }
    print line
  }
' "$file"
