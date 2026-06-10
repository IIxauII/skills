#!/usr/bin/env bash
# remove-profile.sh — tear down a profile created by claude-account-switch.
# Reverses create-profile + add-trigger + install-statusline. Idempotent.
# Backs up every file it edits. Refuses to touch the primary (~/.claude) dir.
#
# Usage:
#   remove-profile.sh --dir ~/.claude-work [--rc ~/.zshrc] [--statusline ~/.claude/hooks/statusline.sh] \
#                     [--keychain-hash <hash>] [--keep-dir] [--yes] [--dry-run]
#
#   --dir            REQUIRED. Profile config dir to remove (e.g. ~/.claude-work).
#   --rc             Shell rc file to strip trigger blocks from. Default: autodetect (~/.zshrc or ~/.bashrc).
#   --statusline     Status-line script to strip the account-line block from.
#                    Default: ~/.claude/hooks/statusline.sh
#   --keychain-hash  macOS only: delete keychain service "Claude Code-credentials-<hash>"
#                    (full de-auth of that profile). See "finding the hash" in reference/mechanics.md.
#   --keep-dir       Do everything EXCEPT deleting the profile dir.
#   --yes            Required to actually delete the profile dir (guard against accidental data loss).
#                    Without it, the dir is kept and a warning is printed.
#   --dry-run        Print what would happen, change nothing.
#   --help
#
# What it removes:
#   1. Guarded blocks "# >>> claude-account-switch: ... >>>" from the rc file (triggers).
#   2. The "account line" guarded block from the status-line script.
#   3. The profile config dir (only with --yes) — this includes that account's
#      .claude.json, sessions, projects, history. Auth in the macOS keychain is
#      NOT removed unless --keychain-hash is given (orphaned creds are harmless).
#
# NOTE: only removes blocks added via the skill's marker comments. If you added
# the trigger or account line by hand (different comments), remove those manually.
set -euo pipefail

DIR=""; RC=""; STATUSLINE="$HOME/.claude/hooks/statusline.sh"
KC_HASH=""; KEEP_DIR=0; YES=0; DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --rc) RC="${2:-}"; shift 2 ;;
    --statusline) STATUSLINE="${2:-}"; shift 2 ;;
    --keychain-hash) KC_HASH="${2:-}"; shift 2 ;;
    --keep-dir) KEEP_DIR=1; shift ;;
    --yes) YES=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --help|-h) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

DIR="${DIR/#\~/$HOME}"
STATUSLINE="${STATUSLINE/#\~/$HOME}"
[ -n "$DIR" ] || { echo "error: --dir required" >&2; exit 2; }

# Safety: never remove the primary config dir.
PRIMARY="$(cd "$HOME/.claude" 2>/dev/null && pwd || echo "$HOME/.claude")"
DIRABS="$(cd "$DIR" 2>/dev/null && pwd || echo "$DIR")"
if [ "$DIRABS" = "$PRIMARY" ] || [ "$DIRABS" = "$HOME" ] || [ -z "$DIRABS" ]; then
  echo "error: refusing to remove primary/home dir ($DIRABS)" >&2; exit 1
fi

# Autodetect rc.
if [ -z "$RC" ]; then
  if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
    RC="${ZDOTDIR:-$HOME}/.zshrc"
  else
    RC="$HOME/.bashrc"
  fi
fi
RC="${RC/#\~/$HOME}"

run() { if [ "$DRY" = 1 ]; then echo "[dry-run] $*"; else eval "$*"; fi; }

# Strip guarded skill blocks from a file (range between >>> and <<< markers).
strip_blocks() {
  file="$1"; label="$2"
  [ -f "$file" ] || { echo "  $label: $file not found, skip"; return; }
  if ! grep -q '^# >>> claude-account-switch:' "$file"; then
    echo "  $label: no skill blocks in $file"; return
  fi
  if [ "$DRY" = 1 ]; then
    echo "[dry-run] would strip claude-account-switch blocks from $file"; return
  fi
  cp "$file" "$file.bak"
  tmp=$(mktemp)
  awk '
    /^# >>> claude-account-switch:/ {skip=1}
    !skip {print}
    /^# <<< claude-account-switch:/ {skip=0}
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "  $label: stripped blocks from $file (backup: $file.bak)"
}

echo "Removing profile: $DIR"
[ "$DRY" = 1 ] && echo "(dry run — no changes)"
echo

echo "1) shell rc trigger:"
strip_blocks "$RC" "rc"

echo "2) status-line account block:"
strip_blocks "$STATUSLINE" "statusline"

echo "3) keychain credential:"
if [ -n "$KC_HASH" ]; then
  if command -v security >/dev/null 2>&1; then
    run "security delete-generic-password -s 'Claude Code-credentials-$KC_HASH' >/dev/null 2>&1 && echo '  deleted keychain Claude Code-credentials-$KC_HASH' || echo '  keychain entry not found / already gone'"
  else
    echo "  'security' not available (non-macOS) — skip"
  fi
else
  echo "  skipped (no --keychain-hash). Orphaned creds are harmless; to fully de-auth,"
  echo "  run 'CLAUDE_CONFIG_DIR=$DIR claude' then '/logout' BEFORE deleting the dir,"
  echo "  or pass --keychain-hash (see reference/mechanics.md to find it)."
fi

echo "4) profile dir:"
if [ "$KEEP_DIR" = 1 ]; then
  echo "  --keep-dir set, leaving $DIR"
elif [ "$YES" = 1 ]; then
  run "rm -rf '$DIR' && echo '  deleted $DIR'"
else
  echo "  NOT deleted (pass --yes to confirm). This dir holds that account's"
  echo "  .claude.json, sessions, projects, history — deletion is permanent."
fi

echo
echo "done. Open a fresh shell to drop the trigger from the environment."
