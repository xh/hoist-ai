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

# Phase 6: Report

Display a final summary that distinguishes "working now" from "queued for activation" and
calls out the CLI fallback for MCP-blocked environments:

```
## Onboarding Complete

### Configuration
- **AGENTS.md:** [Created | Updated (added N sections) | Moved from CLAUDE.md | Already up to date]
- **Client plugins:** [N plugin(s) documented | None detected]

### Harnesses
Include a line for each confirmed harness only.
- **Claude Code:** CLAUDE.md [Created with `@AGENTS.md` | Import added | Already imports AGENTS.md]. `.mcp.json` [Created | Updated (added: <list>) | Already configured | Not written, add it by hand]. Plugin in `.claude/settings.json` [Declared, with auto-update | Already declared | Not written, add it by hand].
  Each developer: trust the project folder when Claude Code asks. Claude Code then adds the marketplace and loads the plugin.
- **Cursor:** `.cursor/mcp.json` [Created | Updated (added: <list>) | Already configured | Not written, add it by hand]. Plugin in `.cursor/settings.json` [Declared | Already declared | Not written, add it by hand].
  Each developer: add the marketplace once, in Customize from GitHub with `https://github.com/xh/hoist-ai`, or with `agent plugin marketplace add https://github.com/xh/hoist-ai`. Skip this if an admin provides it as a team marketplace.
- **Codex:** no MCP config, Codex uses `AGENTS.md` and the CLI launchers. Plugin in `.codex/config.toml` [Declared | Already declared | Not written, add it by hand].
  Each developer: trust the project when Codex asks, then run `codex plugin marketplace upgrade hoist-ai` once.

### hoist-react
- **MCP entry:** [Written | Already present | Skipped (requires @xh/hoist v82+, run the hoist-upgrade skill first)]
- **MCP runtime:** [Active (verified via ping) | Activates in the next agent session, or stays dormant if the environment blocks MCP]
- **CLI launchers:** [Installed at `./bin/hoist-docs`, `./bin/hoist-ts` | Not yet installed. The `using-hoist-react-reference` skill installs them on first CLI use]
- **CLI surface:** `./bin/hoist-docs` and `./bin/hoist-ts` work in any environment, including MCP-blocked ones.

### hoist-core
- **MCP+CLI tools:** [Installed via installHoistCoreTools, CLI verified working | User deferred (run onboard-app again, or ask the agent to install the hoist-core MCP+CLI tools) | Skipped (requires hoistCoreVersion >= 39.0, upgrade hoist-core first) | Already installed]
- **CLI surface:** `./bin/hoist-core-docs` and `./bin/hoist-core-symbols` work in any environment.
- **MCP runtime:** [Active (verified via ping) | Activates in the next agent session, or stays dormant if the environment blocks MCP | N/A (not installed)]

### Reference skills
The `using-hoist-react-reference` and `using-hoist-core-reference` skills from the `xh` plugin
load themselves when you write Hoist code, ask for orientation, or ask to install or upgrade the
hoist-core MCP+CLI tools. You do not need to invoke them.

### MCP-blocked environments
If your environment blocks MCP traffic, the CLI surfaces above are the working path. Use
`./bin/hoist-docs`/`./bin/hoist-ts` (hoist-react) and `./bin/hoist-core-docs`/`./bin/hoist-core-symbols`
(hoist-core) directly. Both pairs are project-root launchers usable from any working directory.
The MCP entries are harmless in this state and start to work if MCP later becomes available. You
do not need to run onboarding again.

### Next steps
Start a new agent session to load the new MCP entries, and approve the hoist servers when the
harness asks. Skip this if MCP is blocked in your environment: the CLI surfaces are already
live. Commit AGENTS.md and the harness files listed above so the whole team gets them. Then
start coding. The reference skills route you to framework docs and API lookups.
```
