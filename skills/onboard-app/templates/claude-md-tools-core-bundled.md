hoist-core here is on a release before v45, which ships no docs for Hoist Docs. Hoist Docs serves
hoist-react only, and the bundled hoist-core tools serve hoist-core: MCP tools
`mcp__hoist-core__*`, and the CLI launchers `./bin/hoist-core-docs` and
`./bin/hoist-core-symbols` once `installHoistCoreTools` has run. From hoist-core v45, Hoist Docs
serves hoist-core too, and the bundled tools are removed.
