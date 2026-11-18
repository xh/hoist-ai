The tools come from Hoist Docs: one MCP server, `hoist-docs` in `.mcp.json`, run from the
`@xh/hoist-docs` dev dependency of `client-app`. It answers for the Hoist versions this app has
installed, for hoist-react, hoist-core and any other Hoist library that ships docs. Its tools are
`mcp__hoist-docs__*`. Pass `library: "react"` for client code and `library: "core"` for server
code: some names, such as `Timer`, exist in both. After a Hoist upgrade, restart Claude Code so
the server reads the new versions.

If MCP is blocked or the server is not running, read the docs that ship with hoist-react under
`client-app/node_modules/@xh/hoist/docs/`, and its package READMEs. If the tools are missing, run
`/xh:onboard-app` to configure them.
