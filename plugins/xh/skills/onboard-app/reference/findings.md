# Phase 2 templates

## Detection summary

```
## Project Detection Results

- **Harness:** [Claude Code | Cursor | Codex | other: <name>] [(existing config for: <other harnesses>)]
- **@xh/hoist (hoist-react):** v[version] [(direct | via [plugin name])] [(canary: tracks `next`)] ([up to date | upgrade available: v[latest]])
- **Decorators:** [TC39 | legacy]
- **hoist-core:** v[version] [(direct | via [plugin name])]
- **Client plugins:** [None detected | See table below]
- **Agent docs:** [None, will create AGENTS.md | AGENTS.md exists, merge needed | CLAUDE.md only, move to AGENTS.md proposed]
```

For both hoist-react and hoist-core, report the resolved version from the dependency manager
(npm/yarn for hoist-react, Gradle for hoist-core) and indicate whether the dependency is direct
or provided transitively via a client plugin.

## Client plugins

Include this table only if Phase 1 detected client plugins:

```
### Client Plugins

| Plugin | Type | Version | Provides |
|--------|------|---------|----------|
| @clientname/hoist-toolkit | npm | 4.2.0 | @xh/hoist transitively |
| com.client:hoist-core-ext | Grails | 3.1.0 | hoist-core transitively |

These plugins add a client-specific layer between this app and the core Hoist
framework. AGENTS.md will document them so AI agents understand the dependency chain.
```

## Planned actions

```
### Planned Actions
Harnesses: [the proposed list from Phase 1]

- [Create | Update] AGENTS.md with Hoist conventions (~[N] lines)
- [Include client plugin documentation (if plugins detected)]
- Claude Code: [Create | Verify] CLAUDE.md with `@AGENTS.md`, the hoist-react MCP server in `.mcp.json` (if @xh/hoist v82+), and the plugin in `.claude/settings.json`
- Cursor: [Create | Verify] the hoist-react MCP server in `.cursor/mcp.json` (if @xh/hoist v82+), and the plugin in `.cursor/settings.json`
- Codex: [Create | Verify] the plugin in `.codex/config.toml`. No MCP config, Codex uses the CLI.
- Detect whether hoist-core MCP+CLI tools are installed. If `hoistCoreVersion >= 39.0` and
  they are not yet wired up, ask separately whether to install them (modifies `build.gradle`)
- Verify both surfaces: hoist-react MCP with a ping, hoist-core with the CLI launcher, which
  works even in MCP-blocked environments
```

List only the lines for the proposed harnesses. Use "Verify" for a file that already holds the
entry.

## Upgrade notices

The Hoist MCP server is first available in `@xh/hoist` v82.0. If the installed version is
below v82, the MCP server will not exist and the AI tooling will be significantly limited.

If the installed version is **below v82**, show:

```
### Hoist Upgrade Required

Your project is on @xh/hoist v[installed], but the Hoist MCP server requires v82.0 or later.
Without it, AI tooling is limited to the static conventions in AGENTS.md: no live
framework documentation, API lookup, or symbol search.

**Recommendation:** Run the `hoist-upgrade` skill before you complete onboarding.
```

If the installed version is **v82+ but behind the latest stable release**, show:

```
### Hoist Upgrade Available

Your project is on @xh/hoist v[installed], but v[latest] is available.
Newer versions include improved MCP server capabilities and AI tooling support.

**Recommendation:** Run the `hoist-upgrade` skill before you complete onboarding.
```
