# @xh/hoist-ai

Agent plugin for AI-augmented Hoist application development, by
[Extremely Heavy Industries](https://xh.io). It supports Claude Code, Cursor, and Codex. The skills
follow the [Agent Skills](https://agentskills.io) spec, so other harnesses that read that format can
load them, without support from us.

## What It Provides

- **MCP Servers** - onboarding adds the hoist-react and hoist-core MCP servers to your project's
  MCP config: `.mcp.json` for Claude Code, `.cursor/mcp.json` for Cursor. They give the agent
  Hoist docs and API lookups. Codex and MCP-blocked environments use the equivalent CLI
  launchers.
- **Skills** - project onboarding, version upgrades, worktree setup, a house writing style, and
  Hoist API reference for AI agents (see [Available Skills](#available-skills) below).
- **Agent Docs** - onboarding writes the Hoist conventions to `AGENTS.md`, which every harness
  reads, and a `CLAUDE.md` that imports it.
- **Tool Pre-Approval** - in Claude Code, each skill pre-approves the MCP tools it calls while it
  runs. To allow them outside the skills, see [Project-Level Setup](#project-level-setup).

## Requirements

- An agent harness: [Claude Code](https://claude.com/code), [Cursor](https://cursor.com), or
  [Codex](https://developers.openai.com/codex).
- `@xh/hoist` installed in your project's `node_modules` (provides the MCP server).

## Installation

### Claude Code

In a Claude Code session:

```
/plugin marketplace add xh/hoist-ai
/plugin install xh@hoist-ai
```

The plugin is now active for all your projects.

### Cursor

In the Customize view, add a marketplace from GitHub with the URL
`https://github.com/xh/hoist-ai`, then install the `xh` plugin. With the Cursor CLI:

```
agent plugin marketplace add https://github.com/xh/hoist-ai
```

On a Teams or Enterprise plan, an admin should import the repo as a team marketplace instead,
from Dashboard > Plugins & MCPs, with Auto Refresh on. A marketplace that one user adds from GitHub
stays on the commit it was added at and does not get new releases.

### Codex

```
codex plugin marketplace add xh/hoist-ai
codex plugin add xh@hoist-ai
```

### Run Onboarding

In any Hoist project directory, run the `onboard-app` skill:

| Harness | Command |
|---------|---------|
| Claude Code | `/xh:onboard-app` |
| Cursor | `/onboard-app` |
| Codex | `$xh:onboard-app` |

This will:
1. Detect your project, its installed Hoist versions, and your agent harness.
2. Show what it found and what it plans to configure.
3. Generate or merge `AGENTS.md` with Hoist conventions, and a `CLAUDE.md` that imports it
   (after your confirmation).
4. Verify MCP server connectivity.

## Available Skills

The Command column shows the Claude Code form. Cursor drops the `xh:` prefix, and Codex starts
with `$` instead of `/`.

| Skill | Command | Description |
|-------|---------|-------------|
| Onboard | `/xh:onboard-app` | Configure AI setup for a Hoist project |
| Upgrade | `/xh:hoist-upgrade` | Upgrade `@xh/hoist` across one or more major versions |
| Worktree | `/xh:setup-worktree` | Create a runnable git worktree for a Hoist app |
| Clear Writing | `/xh:clear-writing` | House style for CHANGELOG entries, PR descriptions, docs, and comments |
| hoist-react reference | `/xh:using-hoist-react-reference` | Routes Hoist React questions to the docs and TypeScript API tools. Loads itself when you write Hoist code |
| hoist-core reference | `/xh:using-hoist-core-reference` | Routes hoist-core questions to its docs and symbol tools. Loads itself when you write Grails/Groovy code, and installs the tools |

## Project-Level Setup

`onboard-app` declares the plugin in the project config of each harness the team uses, so every
developer on the project gets it. The entries below are what it writes, for a project you set up
by hand.

### Claude Code

To give all developers on a project the plugin, add this to the project's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "hoist-ai": {
      "source": {
        "source": "github",
        "repo": "xh/hoist-ai"
      },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "xh@hoist-ai": true
  }
}
```

When a developer trusts the project folder, Claude Code adds the marketplace and loads the
plugin. `autoUpdate` keeps it current: Claude Code does not update a third-party marketplace by
default. A worktree on a branch older than this commit has no `enabledPlugins` entry, so
`/xh:setup-worktree` also enables the plugin in each worktree's `.claude/settings.local.json`.

A plugin cannot grant permissions. To stop prompts, add the Hoist tools to the same file:

```json
{
  "enabledMcpjsonServers": ["hoist-react", "hoist-core"],
  "permissions": {
    "allow": [
      "mcp__hoist-react__*",
      "mcp__hoist-core__*",
      "Bash(npx hoist-docs:*)",
      "Bash(npx hoist-ts:*)",
      "Bash(./bin/hoist-core-docs:*)",
      "Bash(./bin/hoist-core-symbols:*)",
      "Bash(./bin/hoist-core-mcp:*)",
      "Bash(./gradlew installHoistCoreTools:*)"
    ]
  }
}
```

### Cursor

Commit this to the project's `.cursor/settings.json`. Each developer still adds the marketplace
once, as in [Installation](#cursor), unless a team marketplace provides it:

```json
{
  "plugins": {
    "xh@hoist-ai": { "enabled": true }
  }
}
```

To stop prompts for the Hoist tools, commit a `.cursor/permissions.json`. A key in this file
replaces the developer's own allowlist for that key, so list every entry the team needs:

```json
{
  "mcpAllowlist": ["hoist-react:*", "hoist-core:*"],
  "terminalAllowlist": [
    "./bin/hoist-docs",
    "./bin/hoist-ts",
    "./bin/hoist-core-docs",
    "./bin/hoist-core-symbols"
  ]
}
```

### Codex

Commit this to the project's `.codex/config.toml`. Codex reads it only in a trusted project.
Each developer runs `codex plugin marketplace upgrade hoist-ai` once to fetch the plugin:

```toml
[marketplaces.hoist-ai]
source_type = "git"
source = "https://github.com/xh/hoist-ai.git"

[plugins."xh@hoist-ai"]
enabled = true
```

## MCP Tools

When the plugin is active in a project with `@xh/hoist` installed, these MCP tools are
available:

| Tool | Description |
|------|-------------|
| `hoist-ping` | Verify MCP server connectivity |
| `hoist-search-docs` | Search framework documentation by keyword |
| `hoist-list-docs` | Browse available documentation by category |
| `hoist-read-doc` | Read one document by ID (`@xh/hoist` v86+) |
| `hoist-search-symbols` | Find TypeScript classes, interfaces, and types |
| `hoist-get-symbol` | Get detailed type signatures and JSDoc |
| `hoist-get-members` | List members of a class or interface |

## License

Apache-2.0
