---
name: onboard-app
description: Configure and verify AI setup for a Hoist project. Detects the project type and the agent harnesses the team uses, generates AGENTS.md (imported by CLAUDE.md for Claude Code), configures the hoist-react MCP server for Claude Code and Cursor, declares the xh plugin in each harness's project config so every developer gets it, optionally installs the hoist-core MCP+CLI tools, and verifies the surfaces in the current environment.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, mcp__hoist-react__*
---

# Hoist Project Onboarding

Configure this Hoist project for AI-augmented development. Follow each phase in order. The
detailed steps are in the `reference/` folder beside this SKILL.md. When a phase starts, read the
section it names and follow it from start to end. If you cannot find the folder, search for
`**/onboard-app/reference/detect.md`.

## Hoist Project Structure

All Hoist applications share the same layout: a Grails/Groovy backend at the project root and
a React/TypeScript frontend in `client-app/`. Key locations:

- `client-app/package.json`: frontend dependencies, including `@xh/hoist`
- `client-app/yarn.lock`, `client-app/package-lock.json`, or `client-app/pnpm-lock.yaml`: the
  package manager lockfile
- `client-app/src/`: frontend application source
- `build.gradle`: Gradle build config with the `hoist-core` dependency, direct or through a
  client plugin
- `gradle.properties`: app metadata. It holds `xhAppCode` and typically `hoistCoreVersion`. The
  version is absent if a client-specific Grails plugin provides `hoist-core` transitively.
- `grails-app/`: Grails controllers, services, domain classes

`node_modules` and `bin/` launchers are often gitignored, and some harnesses' search tools skip
gitignored paths. Check that a file exists with a file read or a shell command such as
`test -f`, never with a search or glob tool alone.

## Agent Harnesses

A harness is the agent app a developer uses. Onboarding sets up each harness the team uses, not
only the one that runs this skill, so every developer gets the same tooling:

| Harness | Agent docs | MCP config | Plugin declaration | Detect |
|---|---|---|---|---|
| Claude Code | `CLAUDE.md`, which imports `AGENTS.md` | `.mcp.json` | `.claude/settings.json` | `CLAUDECODE` is set |
| Cursor | `AGENTS.md` | `.cursor/mcp.json` | `.cursor/settings.json` | `CURSOR_AGENT` is set |
| Codex | `AGENTS.md` | none, the skills use the CLI | `.codex/config.toml` | `CODEX_THREAD_ID` is set |

Every harness reads `AGENTS.md`. Write a harness's other files only if the team uses that
harness. A Cursor-only project gets no `CLAUDE.md` and no `.claude/` folder.

Codex gets no MCP config because it resolves relative server paths against the session's working
directory, not the project root. The CLI launchers work in Codex from any directory.

## Rules for Every Phase

- Write nothing until the user confirms the setup in Phase 2.
- Ask about the hoist-core install separately, in Phase 3.5. Make no change to `build.gradle`
  before the user answers, and that includes marker comments.
- Write files only for the harnesses the user confirms.
- Write each skill command the way the current harness invokes it: `/xh:hoist-upgrade` in Claude
  Code, `/hoist-upgrade` in Cursor, `$xh:hoist-upgrade` in Codex.

## Phase 1: Detect Project

Follow Phase 1 in [reference/detect.md](reference/detect.md).

## Phase 2: Present Findings and Confirm

The templates for this phase are under Phase 2 in [reference/detect.md](reference/detect.md).

1. Show the detection summary, the client plugins table if there are any, and the planned
   actions for the proposed harnesses.
2. If the app is behind, show the upgrade notice. Behind means older than the latest stable
   release. In canary mode, it means only that `next` is a newer major (see Phase 1). Then ask:
   **"Would you like to upgrade first? (yes = run the hoist-upgrade skill, no = continue with
   current version)"**
   - If yes: tell the developer to run the `hoist-upgrade` skill, then to run `onboard-app`
     again after the upgrade. Stop here.
   - If no: continue on the current version. If it is below v82, Phase 5 skips the MCP check.
3. Ask: **"Proceed with setup for [harness list]? Name a harness to add or remove: Claude Code,
   Cursor, Codex."** If the user changes the list, show the planned actions again for the new
   list. Wait for a yes before you change anything.

## Phase 3: Configure Each Harness

Follow Phase 3 in [reference/configure.md](reference/configure.md): the hoist-react MCP entry for
Claude Code and Cursor, and the plugin declaration for every confirmed harness.

## Phase 3.5: Install hoist-core MCP Server and CLI Tools (optional)

Follow Phase 3.5 in [reference/configure.md](reference/configure.md).

## Phase 4: Generate AGENTS.md

Follow [reference/agent-docs.md](reference/agent-docs.md).

## Phase 5: Verify Surfaces

Follow Phase 5 in [reference/finish.md](reference/finish.md). A missing MCP connection is not an
error: the CLI is the universal check.

## Phase 6: Report

Follow Phase 6 in [reference/finish.md](reference/finish.md).
