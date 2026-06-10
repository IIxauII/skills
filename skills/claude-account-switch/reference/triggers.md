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
- Ghostty / iTerm / Apple Terminal / VS Code → `$TERM_PROGRAM`
  (`ghostty`, `iTerm.app`, `Apple_Terminal`, `vscode`)
- Windows Terminal → `$env:WT_SESSION` (presence)

**zsh/bash** (`~/.zshrc` or `~/.bashrc`):
```bash
# >>> claude-account-switch: terminal trigger (work) >>>
if [ "$TERM_PROGRAM" = "ghostty" ]; then
  export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
fi
# <<< claude-account-switch: terminal trigger (work) <<<
```

**PowerShell** (`$PROFILE`):
```powershell
# >>> claude-account-switch: terminal trigger (work) >>>
if ($env:WT_SESSION) { $env:CLAUDE_CONFIG_DIR = "$HOME\.claude-work" }
# <<< claude-account-switch: terminal trigger (work) <<<
```

---

## 2. Directory-based

Account follows a path subtree. Works in any terminal.

**zsh** — `chpwd` hook (`~/.zshrc`):
```bash
# >>> claude-account-switch: directory trigger (work) >>>
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
# <<< claude-account-switch: directory trigger (work) <<<
```

**bash** — `PROMPT_COMMAND` (`~/.bashrc`):
```bash
# >>> claude-account-switch: directory trigger (work) >>>
_cas_apply_profile() {
  case "$PWD/" in
    "$HOME/work"/*) export CLAUDE_CONFIG_DIR="$HOME/.claude-work" ;;
    *) unset CLAUDE_CONFIG_DIR ;;
  esac
}
case "$PROMPT_COMMAND" in *_cas_apply_profile*) ;; *) PROMPT_COMMAND="_cas_apply_profile;${PROMPT_COMMAND}" ;; esac
# <<< claude-account-switch: directory trigger (work) <<<
```

**PowerShell** — prompt function hook (`$PROFILE`):
```powershell
# >>> claude-account-switch: directory trigger (work) >>>
$function:prompt = {
  if ($PWD.Path -like "$HOME\work*") { $env:CLAUDE_CONFIG_DIR = "$HOME\.claude-work" }
  else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
  "PS $($PWD.Path)> "
}
# <<< claude-account-switch: directory trigger (work) <<<
```
(If a custom prompt already exists, merge the env logic into it instead.)

---

## 3. Alias / wrapper

Explicit, zero magic, most portable. You type `claude-work` for the work
account, `claude` for the default.

**zsh/bash**:
```bash
# >>> claude-account-switch: alias trigger (work) >>>
claude-work() { CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude "$@"; }
# <<< claude-account-switch: alias trigger (work) <<<
```

**PowerShell**:
```powershell
# >>> claude-account-switch: alias trigger (work) >>>
function claude-work { $env:CLAUDE_CONFIG_DIR = "$HOME\.claude-work"; claude @args }
# <<< claude-account-switch: alias trigger (work) <<<
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
