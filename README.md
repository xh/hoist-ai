# @xh/hoist-ai

Claude Code plugin for AI-augmented Hoist application development, by
[Extremely Heavy Industries](https://xh.io).

## What It Provides

- **MCP Servers** - onboarding adds the Hoist reference MCP server to your project's `.mcp.json`.
  It gives Claude access to Hoist docs and API lookups. From `@xh/hoist` v91 that is
  [Hoist Docs](https://github.com/xh/hoist-docs) (`@xh/hoist-docs`), one server for hoist-react
  and hoist-core. Earlier versions use the servers bundled with hoist-react and hoist-core.
- **Skills** - project onboarding, version upgrades, worktree setup, a house writing style, and
  Hoist API reference for AI agents (see [Available Skills](#available-skills) below).
- **Tool Pre-Approval** - each skill pre-approves the MCP tools it calls while it runs. To
  allow them outside the skills, see [Project-Level Setup](#project-level-setup).

## Requirements

- [Claude Code](https://claude.com/code) CLI installed and authenticated.
- `@xh/hoist` installed in your project's `node_modules`. From v91, onboarding adds the
  `@xh/hoist-docs` dev dependency, which provides the MCP server. Before v91, `@xh/hoist`
  provides it.

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

This installs the plugin at user scope: one copy for every project and worktree on this machine.
Install it once per machine. Do not also install it at project or local scope. Separate installs
per project are harder to keep current, and projects can drift to different versions.

### 3. Turn On Auto-Update

Claude Code does not update a third-party marketplace by default. In a session, run `/plugin`,
open the Marketplaces tab, select `hoist-ai`, and select "Enable auto-update". Projects set up
with `/xh:onboard-app` also turn it on in their committed settings.

Updates run in the background shortly after startup. A running session keeps the version it
loaded, so run `/reload-plugins` or restart to use the new one. To update by hand:

```sh
claude plugin marketplace update hoist-ai
claude plugin update xh@hoist-ai
```

Claude Code clones the marketplace over SSH first. Without a GitHub SSH key, for example on a
fresh Linux workstation, set `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`.

### 4. Run Onboarding

In any Hoist project directory:

```
/xh:onboard-app
```

This will:
1. Detect your project and its installed Hoist versions.
2. Show what it found and what it plans to configure.
3. Declare the plugin in `.claude/settings.json`, with auto-update on, so teammates get it.
4. Generate or merge a CLAUDE.md with Hoist conventions (after your confirmation).
5. Verify the reference tools: on v91 and later, by starting Hoist Docs once and listing the
   versions it serves.

## Available Skills

| Skill | Command | Description |
|-------|---------|-------------|
| Onboard | `/xh:onboard-app` | Configure AI setup for a Hoist project |
| Upgrade | `/xh:hoist-upgrade` | Upgrade `@xh/hoist` across one or more major versions |
| Worktree | `/xh:setup-worktree` | Create a runnable git worktree for a Hoist app |
| Clear Writing | `/xh:clear-writing` | House style for CHANGELOG entries, PR descriptions, docs, and comments |
| Complexity Tradeoff | `/xh:complexity-tradeoff` | Weighs the complexity a change adds against the cases it covers, and offers a menu from simplest to most complete. Loads itself when you ask whether a change is as simple as it can be |
| hoist-react reference | `/xh:using-hoist-react-reference` | Routes Hoist React questions to the docs and TypeScript API tools. Loads itself when you write Hoist code |
| hoist-core reference | `/xh:using-hoist-core-reference` | Routes hoist-core questions to its docs and symbol tools. Loads itself when you write Grails/Groovy code, and installs or removes the bundled tools of hoist-core v39 to v44 |

### Worktrees without an agent

The worktree skill runs a script that needs no agent. Editor integrations, git hooks, and plain
shells can call it directly:

```sh
provision-worktree.sh --repo <abs path> --branch <name> [--base <ref> | --existing-branch]
```

The script detects the base ref, the destination, the locals, the toolchain, and the package
manager. On success, stdout holds only the worktree path. Progress goes to stderr. Exit code 3
means the request needs a decision, such as a new branch name that already exists. Run it with
`--help` for the full contract.

Call it from Claude Code's clone of this marketplace, which tracks `main`:
`~/.claude/plugins/marketplaces/hoist-ai/skills/setup-worktree/scripts/provision-worktree.sh`.
That layout belongs to Claude Code and can change. As a fallback, use the highest version under
`~/.claude/plugins/cache/hoist-ai/xh/`. A symlink to the script also works, for example in
`~/.local/bin`.

The script uses the caller's `PATH` and `JAVA_HOME`. A hook or editor process often skips the
login shell, so set both before you call the script. Do not capture stdout through an
interactive shell such as `zsh -ilc`: terminal integrations can write escape codes to stdout.

Outside a Hoist repo, the script still copies locals and installs dependencies. It skips the
Hoist steps. To copy extra gitignored files, add a `.worktreeinclude` file with gitignore
patterns to the repo root.

## Project-Level Setup

`/xh:onboard-app` adds this block to the project's committed `.claude/settings.json`. To set up a
project by hand, add it yourself:

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

The block registers the marketplace with auto-update on, and turns the plugin on for the
project. Claude Code reads it only after a developer accepts the folder's trust dialog. It does
not install the plugin: each developer installs it once per machine, as in
[Installation](#installation).

A branch cut before this commit has no `enabledPlugins` entry, so `/xh:setup-worktree` also
enables the plugin in each new worktree's `.claude/settings.local.json`.

A plugin cannot grant permissions. To stop prompts, add the Hoist tools to the same file. From
`@xh/hoist` v91, with Hoist Docs:

```json
{
  "enabledMcpjsonServers": ["hoist-docs"],
  "permissions": {
    "allow": ["mcp__hoist-docs__*"]
  }
}
```

Before v91, with the tools bundled with hoist-react and hoist-core:

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

Once onboarding has configured a project, these MCP tools are available. With Hoist Docs
(`@xh/hoist` v91 and later) they are `mcp__hoist-docs__*`, and serve hoist-react, hoist-core and
Hoist Chat Kit: pass `library: "react"`, `"core"` or `"chat-kit"` to scope a call. Before v91,
hoist-react's are `mcp__hoist-react__*`, and hoist-core's (v39 to v44) are
`mcp__hoist-core__hoist-core-*`.

| Tool | Description |
|------|-------------|
| `hoist-ping` | Verify MCP server connectivity, and list the Hoist versions served |
| `hoist-search-docs` | Search framework documentation by keyword |
| `hoist-list-docs` | Browse available documentation by category |
| `hoist-read-doc` | Read one document by ID (`@xh/hoist` v86+) |
| `hoist-search-symbols` | Find classes, interfaces, types and their members |
| `hoist-get-symbol` | Get detailed type signatures and JSDoc |
| `hoist-get-members` | List members of a class or interface |

## License

Apache-2.0
