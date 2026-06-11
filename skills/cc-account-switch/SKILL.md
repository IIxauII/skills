---
name: cc-account-switch
description: Set up and manage multiple Claude Code accounts (e.g. personal + business) on one machine using CLAUDE_CONFIG_DIR — fully isolated auth with shared settings/skills/hooks via symlinks, an auto-switch trigger (terminal / directory / alias / per-project .env), and a status line that shows the active account email. Cross-platform (macOS, Linux, Windows). Use when the user wants to run two accounts side by side, switch accounts without logging out, dedicate a terminal/dir to a work account, or show which account a session is billing against.
---

# Claude Code multi-account switcher

Run multiple Claude Code accounts on one machine, fully isolated, with shared
config and an automatic switch trigger. Built on `CLAUDE_CONFIG_DIR` — the one
official lever. No third-party tool required; this skill reproduces the
best-practice pattern (cf. `clausona`, `ccstatusline`).

## Core idea (read first)

`CLAUDE_CONFIG_DIR` points Claude Code at a different config directory. Each
directory gets **independent auth** (macOS: a per-dir keychain entry
`Claude Code-credentials-<hash>`; Linux/Windows: its own `.credentials.json`)
and its own `.claude.json`, history, and sessions. Both accounts stay logged
in forever — no `/logout` churn.

To avoid maintaining two copies of settings/skills/hooks, **symlink the shared
parts** from the primary config dir into each new profile dir. Keep auth and
session state separate.

Full mechanics + the per-OS auth model + the `~/.claude.json` home-global trap:
→ `reference/mechanics.md` (read before running anything on Windows).

## Decision flow

1. **Detect environment** — OS (`uname` / `$OS`) and shell (`$SHELL`, or
   PowerShell). Picks script + snippet dialect.
2. **Name the profile + pick its config dir.** Convention: `~/.claude-work`,
   `~/.claude-personal`, etc. The *primary* account keeps the default
   `~/.claude` — never modify or relocate it.
3. **Choose the share-set** — what to symlink from primary into the profile.
   Default below; confirm with the user.
4. **Create the profile** → `scripts/create-profile.{sh,ps1}`.
5. **Choose a switch trigger** (ask the user; any combination):
   - **terminal** — a terminal app maps to an account (e.g. Ghostty = work).
     Not reliable under tmux or in kitty/alacritty — see `reference/triggers.md`.
   - **directory** — account follows a path subtree (e.g. `~/work/*`).
   - **alias** — explicit `claude-work` command, zero magic, most portable.
   - **per-project `.env`** — a repo pins itself to an account (direnv).
   Snippets + trade-offs: → `reference/triggers.md`. Apply via
   `scripts/add-trigger.{sh,ps1}`.
6. **Status line (optional but recommended)** — show the active account email
   so you never act in the wrong account. → `reference/statusline.md`, apply
   via `scripts/install-statusline.{sh,ps1}`.
7. **Verify + login.** Open a fresh shell, confirm `CLAUDE_CONFIG_DIR`, run
   `claude` → `/login` for the new account. **`/login` is always manual** — the
   skill cannot perform it.

## Default share-set

Symlinked (shared, single source of truth in primary dir):
`settings.json`, `skills/`, `commands/`, `hooks/`, `plugins/`, `CLAUDE.md`,
and any MCP config (`.mcp.json` / `mcp-servers/` if present).

Kept separate (per-account, do **not** symlink):
`.claude.json` (account identity + project state), `projects/`, `history.jsonl`,
`sessions/`, `tasks/`, `telemetry/`, `statsig/`, and other runtime state.

`plugins/` symlinking note: which plugins are *enabled* is stored in
`settings.json` (`enabledPlugins`), so sharing `settings.json` enables the same
plugins everywhere automatically.

## Safety rules

- **Never touch the primary/default account.** Only create *additional*
  profiles and append guarded blocks to rc files.
- **Idempotent.** Scripts use `ln -sfn`, marker-guarded rc blocks, and back up
  any file they edit (`.bak`). Safe to re-run.
- **Confirm before editing shell rc files.** Show the user the exact block.
- **Terminal-trigger caveat:** binding "terminal X = account Y" reassigns *all*
  sessions in that terminal. Make sure the user has another terminal for the
  other account. Flag this explicitly.

## Scripts

All scripts are self-documenting (`--help`) and print what they did.

| Script | Does | Key args |
|---|---|---|
| `create-profile.sh` / `.ps1` | mkdir config dir + symlink share-set | `--dir`, `--from`, `--share` |
| `add-trigger.sh` / `.ps1` | append a switch trigger to shell rc | `--dir`, `--strategy`, `--match`, `--rc` |
| `install-statusline.sh` / `.ps1` | add account-email line to status line | `--target`, `--mode` |
| `remove-profile.sh` / `.ps1` | tear down a profile (reverse of the above) | `--dir`, `--yes`, `--keychain-hash`, `--dry-run` |

## Removal / teardown

To undo a profile, run `scripts/remove-profile.sh --dir <profile-dir>`. It
reverses each setup step and is idempotent:

1. Strips the guarded trigger block(s) from the shell rc (backs it up).
2. Strips the account-line block from the status-line script (backs it up).
3. Optionally deletes the profile's macOS keychain credential (`--keychain-hash`).
4. Deletes the profile config dir — **only with `--yes`** (it holds that
   account's `.claude.json`, sessions, projects, history; deletion is permanent).

```bash
# preview everything first
scripts/remove-profile.sh --dir ~/.claude-work --dry-run
# do it (keeps keychain cred unless --keychain-hash given)
scripts/remove-profile.sh --dir ~/.claude-work --yes
```

**De-authing the account fully:** deleting the dir leaves the keychain
credential orphaned (harmless). To remove it too, either run
`CLAUDE_CONFIG_DIR=<dir> claude` → `/logout` *before* deleting the dir, or pass
`--keychain-hash <hash>` (finding the hash: `reference/mechanics.md`).

**Caveat:** `remove-profile` only removes blocks added via the skill's marker
comments (`# >>> cc-account-switch: ... >>>`, plus legacy
`# >>> claude-account-switch: ... >>>` blocks from before the skill was
renamed). Trigger/account lines added by hand use different comments — remove
those manually.

## References

- `reference/mechanics.md` — how isolation works per OS; what to share/separate; gotchas.
- `reference/triggers.md` — the four trigger strategies, snippets per shell, trade-offs.
- `reference/statusline.md` — account-email status line: dynamic source, multiline, merge-safe, per-OS.
