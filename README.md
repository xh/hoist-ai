# @xh/hoist-ai

Claude Code plugin for AI-augmented Hoist application development, by
[Extremely Heavy Industries](https://xh.io).

## What It Provides

- **MCP Servers** - onboarding adds the hoist-react and hoist-core MCP servers to your project's
  `.mcp.json`. They give Claude access to Hoist docs and API lookups.
- **Skills** - project onboarding, version upgrades, worktree setup, a house writing style, and
  Hoist API reference for AI agents (see [Available Skills](#available-skills) below).
- **Tool Pre-Approval** - each skill pre-approves the MCP tools it calls while it runs. To
  allow them outside the skills, see [Project-Level Setup](#project-level-setup).

## Requirements

- [Claude Code](https://claude.com/code) CLI installed and authenticated.
- `@xh/hoist` installed in your project's `node_modules` (provides the MCP server).

## Installation

### 1. Add the Marketplace

In a Claude Code session:

```
/plugin marketplace add xh/hoist-ai
```

### 2. Install the Plugin

```
/plugin install xh@hoist-ai
```

The plugin is now active for all your projects.

### 3. Run Onboarding

In any Hoist project directory:

```
/xh:onboard-app
```

This will:
1. Detect your project and its installed Hoist versions.
2. Show what it found and what it plans to configure.
3. Generate or merge a CLAUDE.md with Hoist conventions (after your confirmation).
4. Verify MCP server connectivity.

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Onboard | `/xh:onboard-app` | Configure AI setup for a Hoist project |
| Upgrade | `/xh:hoist-upgrade` | Upgrade `@xh/hoist` across one or more major versions |
| Worktree | `/xh:setup-worktree` | Create a runnable git worktree for a Hoist app |
| Clear Writing | `/xh:clear-writing` | House style for CHANGELOG entries, PR descriptions, docs, and comments |
| hoist-react reference | `/xh:using-hoist-react-reference` | Routes Hoist React questions to the docs and TypeScript API tools. Loads itself when you write Hoist code |
| hoist-core reference | `/xh:using-hoist-core-reference` | Routes hoist-core questions to its docs and symbol tools. Loads itself when you write Grails/Groovy code, and installs the tools |

## Project-Level Setup

To give all developers on a project the plugin, add this to the project's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "hoist-ai": {
      "source": {
        "source": "github",
        "repo": "xh/hoist-ai"
      }
    }
  },
  "enabledPlugins": {
    "xh@hoist-ai": true
  }
}
```

This turns the plugin on for the project but does not install it. Each developer runs this
once in the project:

```
claude plugin install xh@hoist-ai --scope project
```

The install covers every git worktree of the project. A worktree on a branch older than this
commit has no `enabledPlugins` entry, so `/xh:setup-worktree` also enables the plugin in each
worktree's `.claude/settings.local.json`.

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
