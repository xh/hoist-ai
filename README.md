# @xh/hoist-ai

Claude Code plugin for AI-augmented Hoist application development, by
[Extremely Heavy Industries](https://xh.io).

## What It Provides

- **MCP Server Auto-Configuration** -- automatically connects the hoist-react MCP server,
  giving Claude access to Hoist framework documentation and TypeScript API lookups.
- **Onboarding Skill** (`/hoist-ai:hoist-onboard`) -- detects your project type, generates a
  tailored CLAUDE.md with Hoist conventions, and verifies MCP server connectivity.
- **Feedback Skill** (`/hoist-ai:hoist-feedback`) -- files sanitized GitHub issues for
  documentation gaps, convention problems, or tooling bugs.
- **Permission Defaults** -- pre-approves hoist-react MCP tools so they work without prompts.

## Requirements

- [Claude Code](https://claude.com/code) CLI installed and authenticated.
- `@xh/hoist` installed in your project's `node_modules` (provides the MCP server).
- `gh` CLI installed and authenticated (for the feedback skill).

## Installation

### 1. Add the Marketplace

In a Claude Code session:

```
/plugin marketplace add xh/hoist-ai
```

### 2. Install the Plugin

```
/plugin install hoist-ai@xh-hoist-ai
```

The plugin is now active for all your projects.

### 3. Run Onboarding

In any Hoist project directory:

```
/hoist-ai:hoist-onboard
```

This will:
1. Detect your project type (frontend-only or full-stack with hoist-core).
2. Show what it found and what it plans to configure.
3. Generate or merge a CLAUDE.md with Hoist conventions (after your confirmation).
4. Verify MCP server connectivity.

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Onboard | `/hoist-ai:hoist-onboard` | Configure AI setup for a Hoist project |
| Feedback | `/hoist-ai:hoist-feedback` | File feedback as a GitHub issue |

## Project-Level Auto-Discovery

To ensure all developers on a project have the plugin, add this to the project's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "xh-hoist-ai": {
      "source": {
        "source": "github",
        "repo": "xh/hoist-ai"
      }
    }
  },
  "enabledPlugins": {
    "hoist-ai@xh-hoist-ai": true
  }
}
```

Claude Code will prompt developers to install the marketplace and plugin when they open the
project.

## MCP Tools

When the plugin is active in a project with `@xh/hoist` installed, these MCP tools are
available:

| Tool | Description |
|------|-------------|
| `hoist-ping` | Verify MCP server connectivity |
| `hoist-search-docs` | Search framework documentation by keyword |
| `hoist-list-docs` | Browse available documentation by category |
| `hoist-search-symbols` | Find TypeScript classes, interfaces, and types |
| `hoist-get-symbol` | Get detailed type signatures and JSDoc |
| `hoist-get-members` | List members of a class or interface |

## License

Apache-2.0
