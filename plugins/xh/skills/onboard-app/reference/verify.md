# Phase 5: Verify Surfaces (CLI-first, MCP-opportunistic)

Verification confirms which surfaces work in the *current* environment. Treat MCP as
opportunistic: it needs a new agent session, and the environment may block it. Treat the CLI as
the universal sanity check: it works as soon as it is installed.

## hoist-react

If `@xh/hoist < v82.0`, skip hoist-react verification, because those versions have no MCP
server. Note this in the Phase 6 report.

Otherwise:

1. **Opportunistic MCP ping.** If the hoist-react server's `hoist-ping` tool is in your tool list
   (`mcp__hoist-react__hoist-ping` in Claude Code), call it. Success → "MCP active". Tool not
   present or fails → "MCP entry written, activates in the next agent session (or stays dormant
   in MCP-blocked environments)". This is not an error.
2. **CLI launcher presence (informational).** Check whether `./bin/hoist-docs` and
   `./bin/hoist-ts` exist at the project root, with `test -f`.
   - If both are present, optionally run `./bin/hoist-docs index` to confirm output. If
     `client-app/node_modules` is not installed yet, tell the user to run the package manager
     install.
   - If absent, do **not** install them here. Note in the Phase 6 report: "hoist-react CLI
     launchers not yet installed. The `using-hoist-react-reference` skill installs them
     the first time an agent reaches for the CLI surface in this project."
   This keeps onboarding to the once-only setup (MCP config, AGENTS.md). The reference skill
   owns the launcher lifecycle, including a refresh when the stamp version changes.

## hoist-core (only if Phase 3.5 installed it)

1. **CLI sanity (always run).** From the project root, run `./bin/hoist-core-docs ping`. Expect
   `hoist-core CLI is running.` If this fails, the install did not work. Show the error.
2. **Opportunistic MCP ping.** If the hoist-core server's `hoist-core-ping` tool is in your tool
   list, call it. Same semantics as hoist-react: success → "MCP active". Not present → "entry
   written, activates in the next agent session in environments that permit MCP". Not an error.

## Why CLI-first matters for enterprise environments

In environments that block MCP traffic, the CLI surface is the working path. Onboarding must
not stall or report "verification failed" when MCP is not reachable. The MCP entries are
harmless if MCP is blocked and start to work if the environment unblocks it, and the CLI works
today. Phase 6 must clearly distinguish "working now" from "queued for activation".
