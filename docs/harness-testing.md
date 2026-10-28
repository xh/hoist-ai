# Harness testing

How to test the `xh` plugin in each harness we target: Claude Code, Cursor, and Codex. Two tests
cover it. Test A runs `onboard-app` and checks what it writes. Test B opens an onboarded project
and checks what the agent finds and uses.

GitHub Copilot CLI is not a target. It reads `AGENTS.md` but not `.mcp.json`, and its Auto mode
picks small models that skip the skills' confirmation steps.

## Fixture

Use `xh/app-template` with its AI files removed: `AGENTS.md`, `CLAUDE.md`, `.claude/`,
`.cursor/`, `.codex/`, and `.mcp.json`. Make each case a fresh copy, committed as its own git
repo, so `git status` shows exactly what a run wrote. The copies can share one
`client-app/node_modules` through a symlink.

## Runs

Run each harness from its own CLI in non-interactive mode, one turn per command, and resume the
session for each answer:

| Harness | CLI | Plugin on | Plugin off |
|---|---|---|---|
| Claude Code | `claude -p` | `--plugin-dir plugins/xh` | disable a user-scope `xh@hoist-ai` with `--settings` |
| Codex | `codex exec` | a local marketplace at user scope | `--ignore-user-config` |
| Cursor | `agent -p` | `--plugin-dir plugins/xh` | no plugin installed |

Start every onboarding run with the same note: follow the skill and its questions, and ask
instead of running a package install or a Gradle command. Give the same answers in every run.

## Test A: onboarding output

Start from a bare copy, a copy that 1.7.0 onboarded (Hoist guidance in `CLAUDE.md`), and a
re-run on a copy this version already onboarded. Check:

- Only the confirmed harnesses get files.
- `AGENTS.md` is byte-identical across harnesses for the same answers.
- A re-run changes nothing.
- A 1.7.0 copy moves to `AGENTS.md` with no Claude Code-only text left.
- No `build.gradle` change before the hoist-core answer.

## Test B: opening an onboarded project

Open five states with the plugin on and off: bare, docs only (`AGENTS.md` and `CLAUDE.md`),
docs plus `.mcp.json`, docs plus `.cursor/mcp.json`, and docs plus both. Ask which skills, project
docs, and Hoist MCP tools the agent has, then a Hoist coding question such as a grid column
chooser with persisted columns. Check that it routes through the reference skill or the CLI, not
memory.

## Limits of scripted runs

- Claude Code print mode refuses to write `.mcp.json` and `.claude/settings.json`, even with
  `acceptEdits`. An interactive session asks for approval instead.
- A shell allow-list denies compound commands that an interactive session would ask about.
- Codex reads `.codex/config.toml` only in a trusted folder, so trust each case before a run.
- A local-path source does not test a project file that names the GitHub source. Test that
  after a push.

## Not yet tested

- Cursor: onboarding and both tests, in the IDE and the CLI.
- Claude Code onboarding in an interactive session, where it can write `.mcp.json` and
  `.claude/settings.json`.
- A teammate who opens a project with a declared plugin, in each harness. In Claude Code, the
  plugin should load after the folder trust prompt, with no install command.
- A teammate who has the plugin at user scope while the project declares it, and opting out of a
  declared plugin.
- Codex: an MCP entry in `.codex/config.toml` with `cwd`, and whether a new worktree needs its own
  trust.
- A fresh clone with no `node_modules`, and a declined or blocked MCP approval.
- `setup-worktree` in each harness.
- The hoist-core install snippet marker: Toolbox has `hoist-core-install/v2`, while hoist-core's
  README and `using-hoist-core-reference` say `v1`.
