# Phase 3: Configure hoist-react MCP Server

If the installed `@xh/hoist` version is v82.0 or later, add the hoist-react MCP server to the
project's MCP config for each confirmed harness that has one: Claude Code and Cursor. The plugin
cannot ship this entry, because the server binary lives in the project's own `node_modules`.

The entry is harmless in environments that block MCP: the harness does not connect to it, and
it starts to work if the environment later permits MCP. In MCP-blocked environments, the CLI
surface (`./bin/hoist-docs`, `./bin/hoist-ts`) is the working path, and the generated AGENTS.md
documents it.

1. **Before writing anything**, confirm the binary exists at
   `client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs`, with a file read or `test -f`. If it
   does not exist, skip this phase only. Carry on with the rest of onboarding, and tell the user
   in the Phase 6 report to run the package manager install from `client-app/` and then run
   onboarding again to add the MCP entries.
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
