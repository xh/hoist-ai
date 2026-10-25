# Harness testing

This document records how the `xh` plugin behaves in each harness we target: Claude Code,
Cursor, Codex, and GitHub Copilot CLI. It covers two questions. What does `onboard-app` write
when each harness runs it? What does each harness do when it opens a project that onboarding set
up, with and without the plugin installed?

The results below test the `multi-harness` branch at plugin version 1.8.0, in October 2026. That
version writes no project-level plugin declaration and asks no harness-selection question, so
these runs are a baseline for that design change. After these runs, we dropped Copilot as a target.
Findings 7 and 8 explain why.

## Method

### Fixture

The fixture is `xh/app-template` at commit `1eb5e72`, from the `upgrade/hoist-v73.0.1-to-v86.2.0`
branch, with its AI files removed: `AGENTS.md`, `CLAUDE.md`, `.claude/`, and `.mcp.json`. It runs
`@xh/hoist` 86.2.0 with npm, legacy decorators, and hoist-core 40.1.0. Its `build.gradle` already
holds the `installHoistCoreTools` task without the `hoist-ai-snippet` markers. The template's `main`
branch has since moved to pnpm, `@xh/hoist` 87, and hoist-core 41, so the next round uses `main`.

Each case is a fresh copy of the fixture, committed as its own git repo, so `git status` shows
exactly what a run wrote. The copies share one `client-app/node_modules` through a symlink.

### Runs

Each harness ran from its own CLI in non-interactive mode, one turn per command, with the
session resumed for each answer:

| Harness | CLI | Model | Plugin on | Plugin off |
|---|---|---|---|---|
| Claude Code 2.1.304 | `claude -p` | `claude-opus-5-5` | `--plugin-dir` from this branch | the user-scope `xh@hoist-ai` disabled with `--settings` |
| Codex 0.163.0 | `codex exec` | `gpt-6-astra` | a local marketplace at user scope | `--ignore-user-config` |
| Copilot CLI 1.0.100 | `copilot -p` | Auto, which picked `mai-code-1.1-flash` or `gpt-6-luna` | `--plugin-dir` from this branch | no plugin installed |
| Cursor CLI 2026.10.19 | `agent -p` | Auto | `--plugin-dir` from this branch | not run |

Every onboarding run started with the same note: follow the skill and its questions, and ask
instead of running a package install or a Gradle command. The answers were the same in every
run: continue on the current version, yes to the setup, and no to the hoist-core install.

### Limits of scripted runs

- Claude Code print mode refuses to write `.mcp.json`, even with `acceptEdits`. An interactive
  session asks for approval instead.
- Each CLI ran with a short allow-list of shell commands. A compound command outside the list
  was denied, where an interactive session would ask the user. Copilot hit this the most.
- The Cursor CLI account hit its usage limit during the first run, and the Codex account hit its
  limit during the probes. Full runs need team accounts.
- Every source was a local path. A project file that names a GitHub source is untested until the
  branch is pushed.

## Test A: onboarding output

| Run | Runner | Start | Choices | Files written | Notes |
|---|---|---|---|---|---|
| A1 | Claude Code | bare | itself | `AGENTS.md`, `CLAUDE.md` | `.mcp.json` blocked by print mode |
| A1 | Codex | bare | itself | `AGENTS.md`, `CLAUDE.md` | no MCP config, as designed |
| A1 | Copilot | bare | itself | `AGENTS.md`, `CLAUDE.md` | needed help past a false "binary missing" check |
| A1 | Cursor | bare | itself | none | planned `.cursor/mcp.json`, then hit the usage limit |
| A2 | Codex | bare | itself, Claude Code, Cursor | `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `.cursor/mcp.json` | all files correct |
| A3 | Codex | A2 output | the same | none | a second run changes nothing |
| A5 | Codex | 1.7.0 output | itself | `AGENTS.md` moved from `CLAUDE.md` | carried the Claude-only wording over |
| A5 | Claude Code | 1.7.0 output | itself | `AGENTS.md` moved from `CLAUDE.md` | offered the neutral wording, which the user accepted |

Every harness detected itself, asked the upgrade question, then asked for the setup confirmation
and the separate hoist-core question. The exception is Copilot, which the skill does not list.
Claude Code and Codex wrote byte-identical `AGENTS.md` files. Copilot's copy dropped one line from
the template's JSX example.

## Test B: opening an onboarded project

Each harness opened five states with the plugin on and off, and answered one probe. The probe
asked which skills, project docs, and Hoist MCP tools it had. Then it asked how to add a column
chooser with persisted columns to a grid, and what it consulted.

The states:

- **bare**: the fixture with no AI files.
- **docs**: `AGENTS.md` and `CLAUDE.md`, which is what onboarding writes for Codex or Copilot.
- **cc**: docs plus `.mcp.json`.
- **cursor**: docs plus `.cursor/mcp.json`.
- **all**: docs plus both MCP files.

| Harness | Plugin | Skills | Project docs | Hoist MCP | How it answered |
|---|---|---|---|---|---|
| Claude Code | on | all six | `CLAUDE.md` and the imported `AGENTS.md` | in cc and all | the reference skill, then MCP where present, else the installed source |
| Claude Code | off | none | the same | in cc and all | MCP where present, else from memory |
| Codex | on | all six, as `xh:*` | `AGENTS.md` | none | the reference skill, then the installed source through the shell |
| Codex | off | none | `AGENTS.md` | none | the installed source, or hoist-react on GitHub at the installed tag |
| Copilot | on | all six | `AGENTS.md` only | none, in every state | the reference skill, then local files or GitHub |
| Copilot | off | none | `AGENTS.md` only | none | its built-in GitHub MCP server, reading `xh/hoist-react` on GitHub |
| Cursor | on, off | not run | | | |

In every state without MCP, the reference skill asked to install the CLI launchers into `bin/`.
The probe told each agent to skip installs, so none did.

## Findings

1. **Copilot's glob tool skips gitignored folders.** It reported
   `client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs` as missing, but a file read and
   `test -f` found it. Every real app ignores `node_modules`, so this affects every Copilot run.
   Fix: check that a file exists with a file read or `test -f`, not a search.
2. **A missing MCP binary stops all of onboarding.** The skill says to warn and run onboarding
   again after the install. Fix: write the agent docs, skip only the MCP entry, and report it.
3. **Copilot changed the template while copying it.** Its `AGENTS.md` lost
   `<Button text="Refresh" />` from the JSX example. Fix: build `AGENTS.md` from the template
   files with a script that substitutes the placeholders, not by retyping them.
4. **The migration carries 1.7.0's Claude-only text into `AGENTS.md`.** The moved sections still
   say "The `xh` Claude Code plugin", `mcp__hoist-core__*`, and "restart Claude Code". Codex moved
   them unchanged. Claude Code noticed and offered the neutral wording. Fix: during the move,
   replace the sections that onboarding generated with the current template, and keep the
   project's own text.
5. **The hoist-core question comes after a `build.gradle` edit.** In a 1.7.0 run, the model added
   the snippet markers to `build.gradle` before it asked whether to install. 1.8.0 has the same
   text. Fix: state that the markers are part of the install and wait for the answer.
6. **Several harness variables can be set at once.** Codex launched from a Claude Code terminal
   saw both `CODEX_THREAD_ID` and `CLAUDECODE`. It still picked Codex. Fix: tell the agent to
   prefer the harness it knows it runs in, and to ask when the variables disagree.
7. **Copilot gets no MCP and skips `CLAUDE.md`.** It reads `AGENTS.md` but does not load
   `.mcp.json`, and the skill has no Copilot MCP file. Without the plugin, Copilot reads
   hoist-react from GitHub, which can describe a different version than the one installed.
8. **Copilot's Auto mode picks small models.** Auto chose `mai-code-1.1-flash` and `gpt-6-luna`.
   Those runs skipped rules that the larger models followed, such as the setup confirmation.
   The canary-mode upgrade prompt in Toolbox is likely the same cause.
9. **Final reports vary.** Claude Code follows the Phase 6 template. Codex and Copilot return a
   short summary.
10. **Onboarding writes `CLAUDE.md` for every harness.** A Cursor-only or Codex-only project still
    gets it. The planned design writes it only when the project uses Claude Code.
11. **Without the plugin, `AGENTS.md` points at a skill that is not there.** It tells the agent
    to run `onboard-app` when no surface is reachable. Claude Code and Codex then answered from
    the installed source or from memory. Fix: name `npx hoist-docs` and `npx hoist-ts` from
    `client-app/`, which work without the plugin.
12. **The snippet markers differ between repos.** Toolbox has `hoist-core-install/v2`. The local
    hoist-core README and `using-hoist-core-reference` both say `v1`. app-template has no marker.

## Not yet tested

- Cursor: every onboarding and probe run, in the IDE and the CLI.
- Claude Code onboarding in an interactive session, where `.mcp.json` can be written.
- A project file that declares the plugin, which 1.8.0 does not write.
- A teammate who has the plugin at user scope while the project declares it, and opting out of a
  declared plugin.
- A fresh clone with no `node_modules`, and a declined or blocked MCP approval.
- Install from a GitHub source on a branch ref.
- `setup-worktree` in each harness.
