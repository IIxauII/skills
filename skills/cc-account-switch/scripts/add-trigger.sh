#!/usr/bin/env bash
# add-trigger.sh — append a guarded CLAUDE_CONFIG_DIR switch trigger to a shell
# rc file. Idempotent (marker-guarded). Backs up the rc file before editing.
#
# Usage:
#   add-trigger.sh --dir ~/.claude-work --strategy terminal  --match ghostty [--rc ~/.zshrc] [--label work]
#   add-trigger.sh --dir ~/.claude-work --strategy directory --match ~/work    [--rc ~/.zshrc] [--label work]
#   add-trigger.sh --dir ~/.claude-work --strategy alias      --name claude-work [--rc ~/.zshrc] [--label work]
#
#   --strategy  terminal | directory | alias
#   --match     terminal: $TERM_PROGRAM value (e.g. ghostty, iTerm.app, Apple_Terminal, vscode)
#               directory: path prefix (e.g. ~/work)
#   --name      alias: function name (default: claude-<label>)
#   --rc        rc file to append to. Default: autodetect (~/.zshrc or ~/.bashrc)
#   --label     identifier used in marker comments + default alias name. Default: work
#   --help
#
# NOTE: directory strategy emits the zsh (chpwd) form. For bash, see
# reference/triggers.md.
set -euo pipefail

DIR=""; STRATEGY=""; MATCH=""; NAME=""; RC=""; LABEL="work"

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --strategy) STRATEGY="${2:-}"; shift 2 ;;
    --match) MATCH="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --rc) RC="${2:-}"; shift 2 ;;
    --label) LABEL="${2:-}"; shift 2 ;;
    --help|-h) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

DIR="${DIR/#\~/$HOME}"
[ -n "$DIR" ] || { echo "error: --dir required" >&2; exit 2; }
[ -n "$STRATEGY" ] || { echo "error: --strategy required" >&2; exit 2; }

# Autodetect rc file.
if [ -z "$RC" ]; then
  if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
    RC="${ZDOTDIR:-$HOME}/.zshrc"
  else
    RC="$HOME/.bashrc"
  fi
fi
RC="${RC/#\~/$HOME}"
touch "$RC"

# $HOME-relative literal so the snippet stays portable inside the rc.
DIR_LITERAL="\$HOME${DIR#$HOME}"

START="# >>> cc-account-switch: ${STRATEGY} trigger (${LABEL}) >>>"
END="# <<< cc-account-switch: ${STRATEGY} trigger (${LABEL}) <<<"

if grep -qF "$START" "$RC"; then
  echo "trigger already present in $RC ($STRATEGY/$LABEL) — nothing to do."
  exit 0
fi

# Build the block into a temp file via plain heredoc redirects (no $(cat <<EOF),
# which breaks on bash 3.2 when the body contains braces).
BLOCKFILE="$(mktemp)"
trap 'rm -f "$BLOCKFILE"' EXIT

case "$STRATEGY" in
  terminal)
    [ -n "$MATCH" ] || { echo "error: terminal strategy needs --match (TERM_PROGRAM value)" >&2; exit 2; }
    cat > "$BLOCKFILE" <<EOF
$START
if [ "\$TERM_PROGRAM" = "$MATCH" ]; then
  export CLAUDE_CONFIG_DIR="$DIR_LITERAL"
fi
$END
EOF
    ;;
  directory)
    [ -n "$MATCH" ] || { echo "error: directory strategy needs --match (path prefix)" >&2; exit 2; }
    MATCH="${MATCH/#\~/$HOME}"
    MATCH_LITERAL="\$HOME${MATCH#$HOME}"
    cat > "$BLOCKFILE" <<EOF
$START
_cas_${LABEL}_dir="$MATCH_LITERAL"
_cas_${LABEL}_apply() {
  case "\$PWD/" in
    "\$_cas_${LABEL}_dir"/*) export CLAUDE_CONFIG_DIR="$DIR_LITERAL" ;;
    *) unset CLAUDE_CONFIG_DIR ;;
  esac
}
autoload -Uz add-zsh-hook 2>/dev/null && add-zsh-hook chpwd _cas_${LABEL}_apply
_cas_${LABEL}_apply
$END
EOF
    ;;
  alias)
    [ -n "$NAME" ] || NAME="claude-${LABEL}"
    cat > "$BLOCKFILE" <<EOF
$START
$NAME() { CLAUDE_CONFIG_DIR="$DIR_LITERAL" claude "\$@"; }
$END
EOF
    ;;
  *) echo "error: unknown strategy '$STRATEGY' (terminal|directory|alias)" >&2; exit 2 ;;
esac

cp "$RC" "$RC.bak"
printf '\n' >> "$RC"
cat "$BLOCKFILE" >> "$RC"

echo "appended $STRATEGY trigger to $RC:"
echo "----------------------------------------"
cat "$BLOCKFILE"
echo "----------------------------------------"
echo "Open a fresh shell to activate. Backup saved as $RC.bak"
