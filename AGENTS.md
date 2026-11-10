This is an Expo/React Native mobile application. Prioritize mobile-first patterns, performance, and cross-platform compatibility.

## Expo has changed — do not trust your training data

Expo ships breaking changes every SDK release. APIs you remember are likely renamed, moved, or removed. Before writing any code that touches an Expo, EAS, or React Native API:

1. Read the major version of the `expo` package in `package.json`.
2. Fetch the matching versioned docs: `https://docs.expo.dev/versions/v<major>.0.0/`
3. For anything else, fetch https://docs.expo.dev/llms.txt — an index of all Expo docs with corrections to common LLM misconceptions. Follow its links to the specific page you need; never answer from memory.

## Commands

Use `bunx` instead of `npx` if the project uses bun (`bun.lock` present).

```bash
npx expo install <package>  # ALWAYS use instead of npm/yarn/pnpm/bun add — resolves SDK-compatible versions
npx expo start              # start the dev server
npx expo lint               # lint
npx tsc --noEmit            # typecheck
npx expo-doctor             # diagnose dependency and config issues
npx expo install --fix      # fix incompatible package versions
```

Run lint and typecheck before declaring any task done.

## Navigation & Routing

- Use **Expo Router** for all navigation. Routes live in `src/app/` — every file there is a screen, `_layout.tsx` files define navigators. Keep non-route code (components, hooks, utils) outside `src/app/`.
- Import `Link`, `router`, and `useLocalSearchParams` from `expo-router`.
- Docs: https://docs.expo.dev/router/introduction.md

## Building with EAS

Use EAS to build, sign, and submit the app in the cloud (`eas build`, `eas submit`) and to ship over-the-air updates (`eas update`) — no local Xcode or Android Studio required. Run EAS CLI as `bunx eas-cli <command>` in Bun projects, or `npx eas-cli@latest <command>` otherwise; substitute that for bare `eas` in docs examples.
Docs: https://docs.expo.dev/eas/index.md

## Rules

- If `ios/` and `android/` directories do not exist, they are generated (Continuous Native Generation). Never create or edit them by hand — configure native behavior in `app.json` and config plugins.
- Expo Go only includes its bundled native modules. After adding a library with native code, the app needs a development build: `npx expo run:ios|android` locally, or `eas build --profile development`.
- Prefer recommended Expo modules over third-party libraries, and check your available skills before adding dependencies. Docs: https://docs.expo.dev/versions/latest/index.md

<!-- Repository-specific note: this project has no `npm run build` script. Use the Expo commands above; the generic Build line in the Sauron block below does not apply. -->

<!-- sauron:start (managed by Sauron; edit outside this block) -->
<!--
  AGENTS.md: shared agent instructions standard (https://agents.md).
  Read by Codex, Cursor, GitHub Copilot, Windsurf, Cline, OpenCode, Kiro, Zed, CodeBuddy, Pi, and omp.
-->

# AGENTS.md

> Governed by Sauron v1.0.0. Shared instructions for every AGENTS.md-aware coding agent.

## Project Overview

Production codebase governed by Sauron Universal Agent Harness.

## Essential Commands

- Build: `npm run build`
- Test All: `npm test`
- Typecheck: `npx tsc --noEmit`

## Engineering Rules

- Present tense, active voice, English language exclusively.
- Zero emojis across all code files, comments, and commit messages.
- Prohibit Latin abbreviations: use 'for example', 'that is', 'and so forth'.
- Prohibit em dashes: use colons, parentheses, or separate sentences.
- Strict Red-Green-Refactor TDD required before touching production code.
- Zero untyped boundary parameters: enforce runtime validation (Zod, Pydantic).
- Zero hardcoded secrets, connection strings, or unredacted logging output.
- Token Conservation & Caveman Mode: off by default. Enable with '/caveman lite', '/caveman full', or '/caveman ultra'.

## Token Optimization & Caveman Mode

- Default: OFF. Reply in normal style until the user enables it.
- Never compress code blocks, diffs, commands, file paths, URLs, error messages, or quoted text. Copy them verbatim.
- Never drop negations (`not`, `never`, `no`). Compression must not flip meaning.
- Use normal prose for security warnings and confirmations of irreversible actions.
- Switch tiers on request: `/caveman lite`, `/caveman full`, `/caveman ultra`. Disable with `/caveman off`.

## Fellowship Sub-Agents

- **Elessar** (`/aragorn`): Principal System Architect
- **Shield of Gondor** (`/boromir`): Security Auditor and Shield
- **Ringbearer** (`/frodo`): Core Task Executor
- **Mithrandir** (`/gandalf`): Master Planner and Strategy Guide
- **Lockbearer** (`/gimli`): Refactorer and AST Dead Code Slasher
- **Greenleaf** (`/legolas`): Precision Linter and Syntax Bug Hunter
- **Brandir** (`/merry`): QA and TDD Specialist
- **Took** (`/pippin`): Edge Case and Chaos Prober
- **The Brave** (`/samwise`): Git Commits and State Keeper

## Anti-Pattern Guardrails

- AP-1 (Vague task verb) : Always decompose requests into concrete atomic tasks.
- AP-6 (Monolithic prompt) : Never combine architecture, code, and test in one step.
- AP-14 (Leaking secrets) : Zero credentials in version control.
- AP-17 (Skipping tests) : Code without a prior failing test is unverified code.
- AP-18 (Non-atomic commit) : One logical concern per commit.
- AP-52 (Fake fix) : Masking errors with type casts or empty catch blocks is prohibited.
- Full catalog: see `.agents/anti-patterns.md` before planning non-trivial work.

## Skills

- Shared Agent Skills live in `.agents/skills/<name>/SKILL.md`. See `.agents/skills/README.md`.
<!-- sauron:end -->
