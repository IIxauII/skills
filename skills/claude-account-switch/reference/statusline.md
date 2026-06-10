# Status line — show the active account

Goal: every prompt shows which account the session is using, so you never act
in the wrong one. The email is **not** in the status-line stdin payload, so we
read it from the active `.claude.json`, resolved via `CLAUDE_CONFIG_DIR`.

## The account line (POSIX shell)

Self-contained, color-coded, prints one line (no trailing newline by itself —
the caller adds `\n` if it wants multiline):

```bash
# Resolve the active account's .claude.json (CLAUDE_CONFIG_DIR wins, else home).
if [ -n "$CLAUDE_CONFIG_DIR" ]; then
  acct_json="$CLAUDE_CONFIG_DIR/.claude.json"
else
  acct_json="$HOME/.claude.json"
fi
email=$(jq -r '.oauthAccount.emailAddress // empty' "$acct_json" 2>/dev/null)
if [ -n "$email" ]; then
  # Color + tag by which profile dir is active. Adjust the case patterns to taste.
  case "$CLAUDE_CONFIG_DIR" in
    *work*|*business*) color=208; tag="biz" ;;      # orange
    "")                color=245; tag="personal" ;; # grey (default account)
    *)                 color=39;  tag="alt" ;;       # blue
  esac
  printf '\033[38;5;%dm[%s] %s\033[0m' "$color" "$tag" "$email"
fi
```

Requires `jq`. Without it, degrade silently (print nothing).

## Multiline status line

Officially supported: each line your command prints stdout becomes a separate
status row. Put the account on its own top line, the rest below:

```bash
printf '%s\n' "<account line>"   # line 1
printf '%s'   "<your existing segments>"  # line 2 (no trailing newline)
```

## Three install modes (what `install-statusline.sh` does)

The installer inspects `settings.json` → `statusLine`:

1. **No status line yet** → writes a fresh `statusline.sh` that prints just the
   account line, and points `settings.json` `statusLine.command` at it.
2. **Existing status line is a script file** → backs it up (`.bak`), inserts a
   guarded account-line block right after `INPUT=$(cat)` (or after the shebang),
   so the account shows as the first line. Idempotent via markers.
3. **Existing status line is an inline command** → cannot safely edit; prints
   the snippet and instructions for the user to merge manually.

Marker comments used for idempotent injection:
```
# >>> claude-account-switch: account line >>>
...
# <<< claude-account-switch: account line <<<
```

## PowerShell account line

```powershell
$cfg = if ($env:CLAUDE_CONFIG_DIR) { Join-Path $env:CLAUDE_CONFIG_DIR ".claude.json" } else { Join-Path $HOME ".claude.json" }
if (Test-Path $cfg) {
  $email = (Get-Content $cfg -Raw | ConvertFrom-Json).oauthAccount.emailAddress
  if ($email) {
    $tag = if ($env:CLAUDE_CONFIG_DIR -match 'work|business') { 'biz' } elseif (-not $env:CLAUDE_CONFIG_DIR) { 'personal' } else { 'alt' }
    Write-Output "[$tag] $email"
  }
}
```
(Windows terminals vary in ANSI color support; the PowerShell version omits
color codes by default.)

## Note on shared settings.json

If `settings.json` is symlinked across accounts (recommended), there is **one**
status-line script serving all of them — which is exactly why it must resolve
the email dynamically from `CLAUDE_CONFIG_DIR` rather than hard-coding it. A
hard-coded email is the #1 reported status-line mistake (issue #16793).
