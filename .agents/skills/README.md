<!-- sauron:start (managed by Sauron; edit outside this block) -->
# .agents/skills

Shared Agent Skills folder (https://agentskills.io). Each skill is a folder containing a `SKILL.md`.

## Format

```text
.agents/skills/<name>/SKILL.md
```

`SKILL.md` starts with YAML frontmatter holding `name` (must match the folder name) and `description` (what the skill does and when to use it), followed by Markdown instructions:

```markdown
---
name: my-skill
description: One sentence on what this skill does and when to use it.
---

# My Skill

Step-by-step instructions.
```

## Runtimes Reading This Folder

- Verified: Cursor, GitHub Copilot, Windsurf, Gemini CLI, omp.
<!-- unverified: Codex and Pi docs reference .agents/skills but discovery is not confirmed -->
- Unverified: Codex, Pi.

## Adding a Skill

- Run `sauron add <skill>` to install a Sauron skill into `.agents/skills/<skill>/SKILL.md`.
- Or create `.agents/skills/<name>/SKILL.md` by hand using the format above.
<!-- sauron:end -->
