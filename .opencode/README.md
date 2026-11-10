<!-- sauron:start (managed by Sauron; edit outside this block) -->
# OpenCode Scaffold

Scaffolded by Sauron v1.0.0 for SNOOZY.

OpenCode reads project instructions from `AGENTS.md` at the repository root and config from `opencode.json`.

Keep this note here. OpenCode loads every Markdown file in `agents/` and `commands/`, so a note in those folders becomes an agent or a command.

## OpenCode Agents

Folder: `.opencode/agents/`

Project-scoped custom agents (primary agents and subagents).

Add one markdown file per agent, e.g. `reviewer.md`. The filename is the agent name. Use YAML frontmatter (`description`, `mode: primary | subagent`, `model`, `tools`) followed by the agent prompt.

Official docs: https://opencode.ai/docs/agents

## OpenCode Commands

Folder: `.opencode/commands/`

Project-scoped custom slash commands.

Add one markdown file per command, e.g. `test.md` becomes `/test`. Use YAML frontmatter (`description`, `agent`, `model`) followed by the prompt template. `$ARGUMENTS` expands to the command arguments.

Official docs: https://opencode.ai/docs/commands

## OpenCode Skills

Folder: `.opencode/skills/`

Project-scoped agent skills loaded on demand.

Add one folder per skill containing a `SKILL.md`, e.g. `my-skill/SKILL.md`. Frontmatter requires `name` (matching the folder) and `description`.

Official docs: https://opencode.ai/docs/skills
<!-- sauron:end -->
