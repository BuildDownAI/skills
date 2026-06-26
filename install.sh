#!/usr/bin/env bash
# Install BuildDown skills into a Claude Code skills directory.
set -euo pipefail

# Every BuildDown SKILL.md carries `metadata.suite: builddown` in its
# frontmatter. That marker is what lets --prune tell *our* installed skills
# apart from anyone else's, independent of the bd- name prefix.
SUITE_MARKER="builddown"

# Managed source checkout used by --from-git, so installs don't ride a random
# working copy on a dev branch.
SRC_HOME="${HOME}/.claude/_sources/builddown"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="symlink"
TARGET_BASE="${HOME}/.claude"
SCOPE="user"
FORCE=0
DRY_RUN=0
PRUNE=0
ACTION="install"
FROM_GIT=""
GIT_REF=""
UPDATE=0

usage() {
  cat <<EOF
Install BuildDown skills into a Claude Code skills directory.

Usage:
  ./install.sh [options]

Options:
  --user               Install into ~/.claude/skills (default).
  --project <path>     Install into <path>/.claude/skills.
  --copy               Copy files instead of symlinking (default: symlink).
  --force              Overwrite existing skill directories at the target.
  --prune              Remove installed BuildDown skills (by suite marker) that
                       are no longer in the source — clears stale/renamed skills.
  --from-git <url>     Install from a managed clone instead of this directory.
                       Accepts <url>@<ref> to pin a branch/tag/SHA. The clone
                       lives in ${SRC_HOME}.
  --ref <ref>          Branch/tag/SHA for --from-git (alternative to <url>@<ref>).
  --update             With --from-git, fetch + reset the managed clone to <ref>
                       before installing.
  --dry-run            Print what would happen, change nothing.
  --uninstall          Remove this repo's skills from the target.
  -h, --help           Show this help.

Examples:
  ./install.sh
  ./install.sh --project ~/code/myrepo
  ./install.sh --copy --force
  ./install.sh --prune
  ./install.sh --from-git https://github.com/BuildDownAI/skills.git --update
  ./install.sh --from-git https://github.com/BuildDownAI/skills.git@ai-implement/feature/bds-1 --update
  ./install.sh --uninstall
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)        SCOPE="user"; TARGET_BASE="${HOME}/.claude"; shift ;;
    --project)     SCOPE="project"; TARGET_BASE="${2:?--project requires a path}/.claude"; shift 2 ;;
    --copy)        MODE="copy"; shift ;;
    --force)       FORCE=1; shift ;;
    --prune)       PRUNE=1; shift ;;
    --from-git)    FROM_GIT="${2:?--from-git requires a url}"; shift 2 ;;
    --ref)         GIT_REF="${2:?--ref requires a value}"; shift 2 ;;
    --update)      UPDATE=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --uninstall)   ACTION="uninstall"; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

TARGET_DIR="${TARGET_BASE}/skills"

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

# Resolve --from-git into a managed clone, then point SCRIPT_DIR at it. Supports
# <url>@<ref> (ref also settable via --ref). With --update, fetch + hard-reset
# the clone to the ref so the install reflects the remote, not a stale local copy.
resolve_from_git() {
  [[ -z "$FROM_GIT" ]] && return 0

  local url="$FROM_GIT"
  local ref="$GIT_REF"
  # Split a trailing @<ref>, but keep scp-style git@host: and :// intact.
  if [[ "$url" == *"@"* ]]; then
    local tail="${url##*@}"
    local head="${url%@*}"
    # Only treat the suffix as a ref if the head still looks like a full URL.
    if [[ "$head" == *://* || "$head" == *: ]]; then
      url="$head"
      [[ -z "$ref" ]] && ref="$tail"
    fi
  fi

  echo "Source: managed clone for --from-git"
  echo "  url:   ${url}"
  echo "  ref:   ${ref:-<default branch>}"
  echo "  path:  ${SRC_HOME}"
  echo

  if [[ ! -d "${SRC_HOME}/.git" ]]; then
    run "mkdir -p \"$(dirname "${SRC_HOME}")\""
    run "git clone \"${url}\" \"${SRC_HOME}\""
  elif [[ $UPDATE -eq 1 ]]; then
    run "git -C \"${SRC_HOME}\" remote set-url origin \"${url}\""
    run "git -C \"${SRC_HOME}\" fetch origin"
  fi

  if [[ -n "$ref" ]]; then
    run "git -C \"${SRC_HOME}\" checkout \"${ref}\""
    [[ $UPDATE -eq 1 ]] && run "git -C \"${SRC_HOME}\" reset --hard \"origin/${ref}\" 2>/dev/null || git -C \"${SRC_HOME}\" reset --hard \"${ref}\""
  elif [[ $UPDATE -eq 1 ]]; then
    run "git -C \"${SRC_HOME}\" pull --ff-only"
  fi

  if [[ $DRY_RUN -eq 0 ]]; then
    SCRIPT_DIR="${SRC_HOME}"
  fi
  echo
}

skill_names() {
  find "${SCRIPT_DIR}/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 \
    | xargs -0 -n1 dirname \
    | xargs -n1 basename \
    | sort
}

# True if the given SKILL.md belongs to the BuildDown suite (carries the marker).
is_suite_skill() {
  local skill_md="$1"
  [[ -f "$skill_md" ]] && grep -qE "^[[:space:]]*suite:[[:space:]]*${SUITE_MARKER}[[:space:]]*$" "$skill_md"
}

# Scan the target for installed BuildDown skills (by marker) that are NOT in the
# current source. Those are stale or renamed (e.g. build-down left behind after
# the bd- rename). Warn always; remove only when --prune is set.
prune_stale() {
  local source_names="$1"
  [[ ! -d "$TARGET_DIR" ]] && return 0

  local found_stale=0
  local dst name skill_md
  for dst in "${TARGET_DIR}"/*; do
    [[ -e "$dst" || -L "$dst" ]] || continue
    name="$(basename "$dst")"
    # A symlink may point at a now-renamed/removed dir; resolve via -L target too.
    skill_md="${dst}/SKILL.md"
    is_suite_skill "$skill_md" || continue
    if ! grep -qxF "$name" <<< "$source_names"; then
      found_stale=1
      if [[ $PRUNE -eq 1 ]]; then
        run "rm -rf \"$dst\""
        echo "  prune $name (BuildDown skill not in current source)"
      else
        echo "  stale $name (BuildDown skill not in current source; re-run with --prune to remove)"
      fi
    fi
  done
  [[ $found_stale -eq 1 ]] && echo
  return 0
}

install_one() {
  local name="$1"
  local src="${SCRIPT_DIR}/skills/${name}"
  local dst="${TARGET_DIR}/${name}"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ $FORCE -eq 1 ]]; then
      run "rm -rf \"$dst\""
    else
      echo "  skip  $name (already exists; use --force to overwrite)"
      return 0
    fi
  fi

  if [[ "$MODE" == "symlink" ]]; then
    run "ln -s \"$src\" \"$dst\""
    echo "  link  $name -> $src"
  else
    run "cp -R \"$src\" \"$dst\""
    echo "  copy  $name"
  fi
}

uninstall_one() {
  local name="$1"
  local dst="${TARGET_DIR}/${name}"

  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    echo "  skip  $name (not installed)"
    return 0
  fi

  if [[ -L "$dst" ]]; then
    local link_target
    link_target="$(readlink "$dst")"
    case "$link_target" in
      "${SCRIPT_DIR}"/*|"${SCRIPT_DIR}")
        run "rm \"$dst\""
        echo "  unlink $name"
        ;;
      *)
        echo "  skip  $name (symlink points elsewhere: $link_target)"
        ;;
    esac
    return 0
  fi

  if [[ $FORCE -eq 1 ]]; then
    run "rm -rf \"$dst\""
    echo "  remove $name (--force on copied install)"
  else
    echo "  skip  $name (copied install; re-run with --force to remove)"
  fi
}

main() {
  resolve_from_git

  local names
  names="$(skill_names)"
  if [[ -z "$names" ]]; then
    echo "No skills found under ${SCRIPT_DIR}/" >&2
    exit 1
  fi

  if [[ "$ACTION" == "install" ]]; then
    echo "Installing BuildDown skills"
    echo "  scope:   ${SCOPE}"
    echo "  target:  ${TARGET_DIR}"
    echo "  source:  ${SCRIPT_DIR}"
    echo "  mode:    ${MODE}"
    [[ $DRY_RUN -eq 1 ]] && echo "  dry-run: yes"
    echo

    run "mkdir -p \"${TARGET_DIR}\""
    prune_stale "$names"
    while IFS= read -r name; do install_one "$name"; done <<< "$names"
    echo
    echo "Done. Restart Claude Code (or run /skills) to pick up changes."
  else
    echo "Uninstalling BuildDown skills from ${TARGET_DIR}"
    [[ $DRY_RUN -eq 1 ]] && echo "  dry-run: yes"
    echo
    while IFS= read -r name; do uninstall_one "$name"; done <<< "$names"
    echo
    echo "Done."
  fi
}

main
