#!/usr/bin/env bash
# Install BuildDown skills into a Claude Code skills directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="symlink"
TARGET_BASE="${HOME}/.claude"
SCOPE="user"
FORCE=0
DRY_RUN=0
ACTION="install"

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
  --dry-run            Print what would happen, change nothing.
  --uninstall          Remove this repo's skills from the target.
  -h, --help           Show this help.

Examples:
  ./install.sh
  ./install.sh --project ~/code/myrepo
  ./install.sh --copy --force
  ./install.sh --uninstall
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)        SCOPE="user"; TARGET_BASE="${HOME}/.claude"; shift ;;
    --project)     SCOPE="project"; TARGET_BASE="${2:?--project requires a path}/.claude"; shift 2 ;;
    --copy)        MODE="copy"; shift ;;
    --force)       FORCE=1; shift ;;
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

skill_names() {
  find "${SCRIPT_DIR}" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 \
    | xargs -0 -n1 dirname \
    | xargs -n1 basename \
    | sort
}

install_one() {
  local name="$1"
  local src="${SCRIPT_DIR}/${name}"
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
    echo "  mode:    ${MODE}"
    [[ $DRY_RUN -eq 1 ]] && echo "  dry-run: yes"
    echo

    run "mkdir -p \"${TARGET_DIR}\""
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
