# Trigger strategies

How `CLAUDE_CONFIG_DIR` gets set for the non-default account. Pick any one (or
combine). All snippets are guarded with marker comments so `add-trigger` can
insert/remove them idempotently. `DIR` below = the profile config dir, e.g.
`$HOME/.claude-work`.

Trade-off summary:

| Strategy | Auto? | Portable | Hijack risk | Best for |
|---|---|---|---|---|
| terminal | yes | medium | **high** (whole terminal) | dedicating one terminal app to an account |
| directory | yes | medium | low | account follows a project tree |
| alias | no | **high** | none | explicit control, any OS |
| per-project `.env` | yes | high (needs direnv) | low | a repo always = one account |

---

## 1. Terminal-based

Bind "this terminal app = this account". **Caveat:** every session in that
terminal becomes the account — keep another terminal for the other account.

Detect the terminal via an env var the emulator sets:
- Ghostty / iTerm / Apple Terminal / VS Code / WezTerm → `$TERM_PROGRAM`
  (`ghostty`, `iTerm.app`, `Apple_Terminal`, `vscode`, `WezTerm`)
- Windows Terminal → `$env:WT_SESSION` (presence)

**Detection limits:** kitty does not set `$TERM_PROGRAM` (it sets
`$KITTY_WINDOW_ID` — match on that instead) and alacritty sets no marker
variable at all. tmux rewrites `$TERM_PROGRAM` to `tmux`, so the trigger
will not fire inside tmux even when the outer terminal matches. For
tmux/alacritty setups, prefer the directory or alias strategy.

**zsh/bash** (`~/.zshrc` or `~/.bashrc`):
```bash
# >>> cc-account-switch: terminal trigger (work) >>>
if [ "$TERM_PROGRAM" = "ghostty" ]; then
  export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
fi
# <<< cc-account-switch: terminal trigger (work) <<<
```

**PowerShell** (`$PROFILE`):
```powershell
# >>> cc-account-switch: terminal trigger (work) >>>
if ($env:WT_SESSION) { $env:CLAUDE_CONFIG_DIR = "$HOME\.claude-work" }
# <<< cc-account-switch: terminal trigger (work) <<<
```

---

## 2. Directory-based

Account follows a path subtree. Works in any terminal.

**zsh** — `chpwd` hook (`~/.zshrc`):
```bash
# >>> cc-account-switch: directory trigger (work) >>>
_cas_work_dir="$HOME/work"
_cas_apply_profile() {
  case "$PWD/" in
    "$_cas_work_dir"/*) export CLAUDE_CONFIG_DIR="$HOME/.claude-work" ;;
    *) unset CLAUDE_CONFIG_DIR ;;
  esac
}
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _cas_apply_profile
_cas_apply_profile   # run for the initial dir
# <<< cc-account-switch: directory trigger (work) <<<
```

**bash** — `PROMPT_COMMAND` (`~/.bashrc`):
```bash
# >>> cc-account-switch: directory trigger (work) >>>
_cas_apply_profile() {
  case "$PWD/" in
    "$HOME/work"/*) export CLAUDE_CONFIG_DIR="$HOME/.claude-work" ;;
    *) unset CLAUDE_CONFIG_DIR ;;
  esac
}
case "$PROMPT_COMMAND" in *_cas_apply_profile*) ;; *) PROMPT_COMMAND="_cas_apply_profile;${PROMPT_COMMAND}" ;; esac
# <<< cc-account-switch: directory trigger (work) <<<
```

**PowerShell** — prompt function hook (`$PROFILE`):
```powershell
# >>> cc-account-switch: directory trigger (work) >>>
$function:prompt = {
  if ($PWD.Path -like "$HOME\work*") { $env:CLAUDE_CONFIG_DIR = "$HOME\.claude-work" }
  else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
  "PS $($PWD.Path)> "
}
# <<< cc-account-switch: directory trigger (work) <<<
```
(If a custom prompt already exists, merge the env logic into it instead.)

---

## 3. Alias / wrapper

Explicit, zero magic, most portable. You type `claude-work` for the work
account, `claude` for the default.

**zsh/bash**:
```bash
# >>> cc-account-switch: alias trigger (work) >>>
claude-work() { CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude "$@"; }
# <<< cc-account-switch: alias trigger (work) <<<
```

**PowerShell**:
```powershell
# >>> cc-account-switch: alias trigger (work) >>>
function claude-work { $env:CLAUDE_CONFIG_DIR = "$HOME\.claude-work"; claude @args }
# <<< cc-account-switch: alias trigger (work) <<<
```

---

## 4. Per-project `.env` (direnv)

A repo pins itself to an account. Requires [direnv](https://direnv.net)
(`brew install direnv` / package manager) hooked into the shell.

In the repo root, `.envrc`:
```bash
export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
```
Then `direnv allow`. Leaving the dir auto-unsets it. Add `.envrc` to the repo's
`.gitignore` if the path is personal.
