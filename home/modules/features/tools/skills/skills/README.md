# Shared agent skills

Skills placed here are available to both Claude Code (`~/.claude/skills/`) and
OpenCode (`~/.config/opencode/skills/`).

Add one directory per skill, each containing a `SKILL.md` with frontmatter:

```markdown
---
name: my-skill
description: One-line description used to decide when the skill applies.
---

Instructions for the agent...
```

Skills fetched from external repos (e.g. anthropics/skills) are wired in via
`default.nix` in the parent directory.
