#!/usr/bin/env bash
# =====================================================================
# uninstall.sh — remove everything install.sh added.
#
# Removes ONLY the skills/commands/agents that this combo ships (by name),
# from every harness path, plus the `bughunter` CLI symlink. It will NOT
# touch unrelated skills you had before (e.g. pre-existing Hermes skills).
#
#   ./uninstall.sh            # remove from all harnesses + the CLI
#   ./uninstall.sh --dry-run  # show what WOULD be removed, change nothing
# =====================================================================
set -uo pipefail
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

# names this combo ships
SKILLS=$(ls "$REPO_DIR/skills" 2>/dev/null)
CMDS=$(ls "$REPO_DIR/commands"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -v '^README.md$')
AGENTS=$(ls "$REPO_DIR/agents"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -v '^README.md$')

rm_path() {  # $1 = file/dir to remove
  [ -e "$1" ] || return 0
  if [ "$DRY" = 1 ]; then echo "  would remove: $1"; else rm -rf "$1"; echo "  removed: $1"; fi
}

remove_from() {  # $1 = harness root
  local root="$1"
  [ -d "$root" ] || return 0
  echo "Cleaning $root"
  for s in $SKILLS;  do rm_path "$root/skills/$s"; done
  for c in $CMDS;    do rm_path "$root/commands/$c"; done
  for a in $AGENTS;  do rm_path "$root/agents/$a"; done
}

echo "Uninstalling BugHunter Combo$([ "$DRY" = 1 ] && echo ' (dry-run)')"
echo ""

remove_from "$HOME/.claude"
remove_from "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
remove_from "$HOME/.agents"
remove_from "$HOME/.hermes"

# standalone CLI symlink
echo "CLI:"
for cand in /usr/local/bin/bughunter "$HOME/.local/bin/bughunter"; do
  if [ -L "$cand" ] || [ -f "$cand" ]; then
    if [ "$DRY" = 1 ]; then echo "  would remove: $cand"
    else
      rm -f "$cand" 2>/dev/null || sudo rm -f "$cand" 2>/dev/null || echo "  ⚠ could not remove $cand (try: sudo rm -f $cand)"
      [ -e "$cand" ] || echo "  removed: $cand"
    fi
  fi
done

echo ""
echo "✓ Uninstall complete$([ "$DRY" = 1 ] && echo ' (dry-run — nothing changed)')"
echo "  Backups (if any) remain under ~/.claude/install-backups/"
echo "  The repo folder itself is untouched — delete it manually if you want."
