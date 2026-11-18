Each skill has two interchangeable surfaces: MCP tools when MCP is enabled, and CLI launchers once
installed. In MCP-blocked environments the CLI is the working path, and the skills route to it. If
neither surface is reachable, run `/xh:onboard-app` to configure them.

- **hoist-react:** MCP tools `mcp__hoist-react__*`, from `@xh/hoist` itself. CLI launchers
  `./bin/hoist-docs` and `./bin/hoist-ts`.
- **hoist-core:** MCP tools `mcp__hoist-core__*`, available when MCP is enabled, after you run
  `installHoistCoreTools` and restart Claude Code. CLI launchers `./bin/hoist-core-docs` and
  `./bin/hoist-core-symbols`, once installed. These work in any environment, including
  MCP-blocked ones.

From `@xh/hoist` v91, one MCP server, Hoist Docs, replaces these tools. `/xh:hoist-upgrade`
switches the app over.
