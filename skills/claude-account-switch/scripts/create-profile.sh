#!/usr/bin/env bash
# create-profile.sh — create an additional Claude Code account profile dir and
# symlink the shared config into it. Idempotent. Never touches the source dir.
#
# Usage:
#   create-profile.sh --dir ~/.claude-work [--from ~/.claude] [--share "a b c"]
#
#   --dir    REQUIRED. Config dir for the new profile (the CLAUDE_CONFIG_DIR value).
#   --from   Source/primary config dir to symlink shared items from. Default: ~/.claude
#   --share  Space-separated items to symlink. Default share-set below.
#   --help   Show this help.
set -euo pipefail

FROM="$HOME/.claude"
DIR=""
SHARE_DEFAULT="settings.json skills commands hooks plugins CLAUDE.md .mcp.json mcp-servers"
SHARE="$SHARE_DEFAULT"

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)   DIR="${2:-}"; shift 2 ;;
    --from)  FROM="${2:-}"; shift 2 ;;
    --share) SHARE="${2:-}"; shift 2 ;;
    --help|-h)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Expand leading ~ if passed literally.
DIR="${DIR/#\~/$HOME}"
FROM="${FROM/#\~/$HOME}"

[ -n "$DIR" ] || { echo "error: --dir is required" >&2; exit 2; }
[ -d "$FROM" ] || { echo "error: source dir not found: $FROM" >&2; exit 1; }

# Guard: refuse to clobber the primary dir.
if [ "$(cd "$DIR" 2>/dev/null && pwd || echo "$DIR")" = "$(cd "$FROM" && pwd)" ]; then
  echo "error: --dir must differ from --from ($FROM)" >&2; exit 1
fi

mkdir -p "$DIR"
echo "profile dir: $DIR"
echo "source:      $FROM"
echo "symlinking shared items:"

for item in $SHARE; do
  src="$FROM/$item"
  dst="$DIR/$item"
  if [ -e "$src" ]; then
    ln -sfn "$src" "$dst"
    echo "  linked  $item"
  else
    echo "  skip    $item (not in source)"
  fi
done

echo
echo "done. Items NOT shared (kept per-account): .claude.json, projects/, history.jsonl, sessions/, tasks/, telemetry/, caches"
echo "Next: set CLAUDE_CONFIG_DIR=$DIR (via a trigger), open a fresh shell, run 'claude' then '/login'."
