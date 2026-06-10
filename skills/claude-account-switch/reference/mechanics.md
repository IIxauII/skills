# Mechanics — how multi-account isolation works

## The one lever: `CLAUDE_CONFIG_DIR`

Claude Code reads all its config from one directory, default `~/.claude`. Set
`CLAUDE_CONFIG_DIR=/some/dir` before launching and it uses that instead —
**including authentication**. This is the only official mechanism; there is no
built-in account picker or profile system.

When set, these relocate into the config dir:
- `.claude.json` → `$CLAUDE_CONFIG_DIR/.claude.json` (account identity +
  per-project state + onboarding flags)
- credentials (Linux/Windows) → `$CLAUDE_CONFIG_DIR/.credentials.json`
- settings, skills, commands, hooks, plugins, history, sessions, projects

## Auth storage per OS — the key to isolation

| OS | Where creds live | How profiles separate |
|---|---|---|
| **macOS** | Keychain, service `Claude Code-credentials-<hash>` | `<hash>` is derived from the config dir path → each `CLAUDE_CONFIG_DIR` gets its **own keychain entry**. No clobber. |
| **Linux** | `$CLAUDE_CONFIG_DIR/.credentials.json` (file) | Separate dir → separate file. |
| **Windows** | `%CLAUDE_CONFIG_DIR%\.credentials.json` (file) | Separate dir → separate file. |

Verify the macOS keychain hashing yourself:
```bash
security dump-keychain 2>/dev/null | grep -i "Claude Code-credentials" | sort -u
```
You'll see one `...-<hash>` entry per config dir you've logged into.

## The `~/.claude.json` home-global trap (esp. Windows)

Historically Claude Code also keeps a large `.claude.json` in the **home dir**.
If two instances share the same real home and `CLAUDE_CONFIG_DIR` is *not* set
for one of them, they write the same `~/.claude.json` and fight over account
state. Setting `CLAUDE_CONFIG_DIR` for the *non-default* profile relocates its
`.claude.json` into the profile dir and avoids this. Rule: the default account
uses `~/.claude` (and `~/.claude.json`); every *other* account gets an explicit
`CLAUDE_CONFIG_DIR`.

## What to share vs separate

**Share (symlink from primary):** config you want identical everywhere.
- `settings.json` — includes `enabledPlugins`, so plugins enable everywhere
- `skills/`, `commands/`, `hooks/`, `plugins/`
- `CLAUDE.md` (global instructions)
- MCP config: `.mcp.json` and/or `mcp-servers/` if you use them

**Separate (never symlink):** identity + runtime state.
- `.claude.json` — *this is what makes the accounts different*; symlinking it
  defeats the whole purpose
- `projects/`, `history.jsonl`, `sessions/`, `tasks/`, `telemetry/`,
  `statsig/`, `file-history/`, `shell-snapshots/`, caches

Symlink caveat (from official architecture notes): auto-reload detection and
backup systems may not perfectly follow symlinks. In practice sharing the items
above is fine and widely used (clausona does exactly this); just be aware if a
backup tool behaves oddly.

## How the account email is discoverable

The email is **not** in the status-line stdin payload (open issues
anthropics/claude-code#24679, #16793). It lives at:
```
$CLAUDE_CONFIG_DIR/.claude.json  →  .oauthAccount.emailAddress
# or, default account: ~/.claude.json → .oauthAccount.emailAddress
```
Reading that file (respecting `CLAUDE_CONFIG_DIR`) is the sanctioned way to show
the active account — what `ccstatusline`'s account widget does.

## Finding a profile's keychain hash (macOS)

To delete a specific profile's credential you need its `<hash>`. The hash is
derived from the config dir path, so you can't trivially reverse it — identify
the entry by **creation time** (right after you logged that profile in):

```bash
# list all Claude credential services with creation dates
security dump-keychain 2>/dev/null \
  | awk '/"svce".*Claude Code-credentials/{svce=$0} /"cdat"/{print $0"  "svce}'
```
Match the `cdat` (creation date) to when you ran `/login` for the profile, read
the `<hash>` off that `svce` line, then:
```bash
security delete-generic-password -s "Claude Code-credentials-<hash>"
```
Safer alternative that needs no hash: `CLAUDE_CONFIG_DIR=<dir> claude` →
`/logout` clears exactly that profile's credential.

## Rollback

Per profile:
```bash
rm -rf <profile-config-dir>      # e.g. ~/.claude-work
# remove the guarded trigger block from the shell rc (marked with comments)
```
The default account is never modified, so nothing to undo there.
