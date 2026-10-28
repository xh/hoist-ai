# Phase 3: Configure Each Harness

For each confirmed harness, write the hoist-react MCP entry if the harness has an MCP config file,
then declare the plugin.

A harness can refuse a write to its own config files. Claude Code asks for approval to write
`.mcp.json` and `.claude/settings.json`, and the Codex sandbox makes `.codex/` read-only. Ask the
user to approve the write. If it is still refused, carry on, and show the exact entry to add in
the Phase 6 report.

## hoist-react MCP entry

If the installed `@xh/hoist` version is v82.0 or later, add the hoist-react MCP server to the
project's MCP config for each confirmed harness that has one: Claude Code and Cursor. The plugin
cannot ship this entry, because the server binary lives in the project's own `node_modules`.

The entry is harmless in environments that block MCP: the harness does not connect to it, and
it starts to work if the environment later permits MCP. In MCP-blocked environments, the CLI
surface (`./bin/hoist-docs`, `./bin/hoist-ts`) is the working path, and the generated AGENTS.md
documents it.

1. **Before writing anything**, confirm the binary exists at
   `client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs`, with a file read or `test -f`. If it
   does not exist, skip the MCP entries only. Carry on with the plugin declaration and the rest
   of onboarding, and tell the user in the Phase 6 report to run the package manager install
   from `client-app/` and then run onboarding again to add the MCP entries.
2. For each harness, check whether its config file exists and already has a `hoist-react` entry
   under `mcpServers`. If it does, skip that file.
3. If the file exists without a `hoist-react` entry, add the entry to its `mcpServers` object.
   Preserve all other entries. If the file does not exist, create it with the content below.

**Claude Code**, `.mcp.json`. Claude Code starts the server from the project root:

```json
{
  "mcpServers": {
    "hoist-react": {
      "type": "stdio",
      "command": "node",
      "args": [
        "client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs"
      ],
      "env": {}
    }
  }
}
```

**Cursor**, `.cursor/mcp.json`. Cursor expands `${workspaceFolder}` to the project root:

```json
{
  "mcpServers": {
    "hoist-react": {
      "type": "stdio",
      "command": "node",
      "args": [
        "${workspaceFolder}/client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs"
      ],
      "env": {}
    }
  }
}
```

The MCP server is not available until the next agent session after this file is written.
Phase 5 tries to verify the connection, but a fresh configuration is usually not running yet.

## Plugin declaration

The plugin runs onboarding, so it is installed for the current developer. Other developers on the
project get it from a declaration in each harness's project config.

Merge into an existing file. Keep every other key and entry. If the file already enables or
disables `xh@hoist-ai`, leave that value alone, because `false` is a developer's opt-out. If a
`hoist-ai` marketplace entry already exists with a different source, such as a branch or a local
folder, leave it and name it in the report.

**Claude Code**, `.claude/settings.json`. `autoUpdate` keeps the plugin
current, because Claude Code does not update a third-party marketplace by default. If an existing
`hoist-ai` entry with this source lacks `autoUpdate` or sets it to `false`, set it to `true`.

```json
{
  "extraKnownMarketplaces": {
    "hoist-ai": {
      "source": { "source": "github", "repo": "xh/hoist-ai" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "xh@hoist-ai": true
  }
}
```

**Cursor**, `.cursor/settings.json`. Cursor keeps marketplaces per account, so this entry only
turns the plugin on. Each developer adds the marketplace once, unless a team marketplace
provides it.

```json
{
  "plugins": {
    "xh@hoist-ai": { "enabled": true }
  }
}
```

**Codex**, `.codex/config.toml`. The entry names the marketplace and turns the plugin on. Codex
reads project config only in a trusted project.

```toml
[marketplaces.hoist-ai]
source_type = "git"
source = "https://github.com/xh/hoist-ai.git"

[plugins."xh@hoist-ai"]
enabled = true
```

# Phase 3.5: Install hoist-core MCP Server and CLI Tools (optional)

The hoist-core developer tools ship as a fat JAR (`io.xh:hoist-core-mcp:<version>:all`) that
the project's Gradle build resolves through normal Maven resolution. The install task writes
project-local launchers under `bin/`. They expose both the MCP server (`bin/hoist-core-mcp`,
referenced from the MCP config) and the CLI tools (`bin/hoist-core-docs`,
`bin/hoist-core-symbols`). The CLI surface is the primary path in MCP-blocked environments. It
works as soon as it is installed, with no new session and no MCP.

## Step 1: Detect current state

1. Check whether `bin/hoist-core-mcp` exists at the project root and is executable, with
   `test -x`.
2. Check whether the MCP config file of each confirmed harness that has one has a `hoist-core`
   entry under `mcpServers`.
3. If the launcher and every entry are present, this phase is already done. Skip it.
4. If `hoistCoreVersion < 39.0` (the first release containing the `installHoistCoreTools`
   task), skip with a note in Phase 6: "hoist-core MCP+CLI install requires hoistCoreVersion
   >= 39.0. Run the `hoist-upgrade` skill first, then run `onboard-app` again to install."

## Step 2: Ask permission

Show the user a focused confirmation BEFORE making any Gradle-level changes:

```
### Install hoist-core MCP server and CLI tools?

This will:
- Add ~15 lines to `build.gradle`: a `hoistCoreCli` configuration and the
  `installHoistCoreTools` Sync task.
- Run `./gradlew installHoistCoreTools` to resolve the version-locked fat JAR
  (`io.xh:hoist-core-mcp:<hoistCoreVersion>:all`) and write launchers under `bin/`.
- Add a `hoist-core` entry that points at `bin/hoist-core-mcp` to [`.mcp.json` | `.cursor/mcp.json`].
- [If `build.gradle` already has the task without them: add the `hoist-ai-snippet` marker comments around it.]

The CLI surface (`./bin/hoist-core-docs`, `./bin/hoist-core-symbols`) works in any environment,
including MCP-blocked ones. The MCP entry is harmless if MCP is blocked, and it starts to work
if MCP later becomes available.

Proceed? (yes/no)
```

Make no change to `build.gradle` before the user says yes, and that includes the marker
comments. If the user says no, record the decision and show a deferred-step note in the Phase 6
report. The user can install later: an ask to install or set up the hoist-core MCP+CLI in this
app loads the `using-hoist-core-reference` skill, which walks through it.

## Step 3: Run the install procedure

If the user agreed, follow the install procedure in the `using-hoist-core-reference` skill, the
source of truth for this flow. Read `reference/install.md` in that skill's folder, which is
`../using-hoist-core-reference/` from the onboard-app skill folder. If you cannot find it there,
search for `**/skills/using-hoist-core-reference/reference/install.md`.

Follow its steps from start to end: the Gradle snippet, `installHoistCoreTools`, the CLI check,
and the MCP config. Do not duplicate the snippet here. The reference skill holds the canonical
copy, and later runs read it again.
