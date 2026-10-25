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
- **Claude Code:** CLAUDE.md [Created with `@AGENTS.md` | Import added | Already imports AGENTS.md]. `.mcp.json` [Created | Updated (added: <list>) | Already configured]. Plugin in `.claude/settings.json` [Declared | Already declared | Not written, add it by hand].
  Each developer: run `claude plugin install xh@hoist-ai --scope project` once.
- **Cursor:** `.cursor/mcp.json` [Created | Updated (added: <list>) | Already configured]. Plugin in `.cursor/settings.json` [Declared | Already declared].
  Each developer: add the marketplace once, in Customize from GitHub with `https://github.com/xh/hoist-ai`, or with `agent plugin marketplace add https://github.com/xh/hoist-ai`. Skip this if an admin provides it as a team marketplace.
- **Codex:** no MCP config, Codex uses `AGENTS.md` and the CLI launchers. Plugin in `.codex/config.toml` [Declared | Already declared].
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
