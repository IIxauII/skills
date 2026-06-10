# claude-skills

A collection of [Agent Skills](https://www.skills.sh/) for Claude Code.

## Install

Install any skill in this repo with the [`skills`](https://github.com/vercel-labs/skills) CLI:

```bash
npx skills add IIxauII/claude-skills
```

Or pull a single skill:

```bash
npx skills add IIxauII/claude-skills/skills/claude-account-switch
```

`npx skills` drops the skill into your agent's skills directory (e.g. `~/.claude/skills/`).

## Skills

| Skill | What it does |
|-------|--------------|
| [`claude-account-switch`](skills/claude-account-switch) | Run multiple Claude Code accounts on one machine, fully isolated, via `CLAUDE_CONFIG_DIR` — shared settings/skills/hooks through symlinks, an auto-switch trigger (terminal / directory / alias / per-project `.env`), and a status line showing the active account email. Cross-platform (macOS, Linux, Windows). |

## Repo layout

```
skills/
  <skill-name>/
    SKILL.md        # frontmatter (name + description) + instructions
    reference/      # progressive-disclosure docs loaded on demand
    scripts/        # executable helpers (.sh + .ps1)
```

The `skills` CLI discovers any `skills/<name>/SKILL.md` automatically — no manifest or registry submission required. Push a public repo and it is installable.

## License

[MIT](LICENSE)
