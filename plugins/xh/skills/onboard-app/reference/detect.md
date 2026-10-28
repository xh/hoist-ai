# Phase 1: Detect Project

1. **Detect the harness.** If you know which harness you run in, use it. Otherwise run
   `env | grep -E '^(CLAUDECODE|CURSOR_AGENT|CODEX_THREAD_ID)='` and match the result to the
   Agent Harnesses table in SKILL.md. A harness started from another harness's terminal inherits
   its variables, so more than one can match. If none or several match, ask the user. The
   proposed harnesses are the current one plus each harness that already has project config:
   `.mcp.json` or a `.claude/` folder for Claude Code, a `.cursor/` folder for Cursor, a `.codex/`
   folder for Codex. The user confirms the list in Phase 2.
2. **Detect package manager.** Check which lockfile exists in `client-app/`:
   - `yarn.lock`: use `yarn` (for example `yarn install`, `yarn why`)
   - `package-lock.json`: use `npm` (for example `npm install`, `npm ls`)
   - `pnpm-lock.yaml`: use `pnpm` (for example `pnpm install`, `pnpm why`)
   Store the detected package manager for use throughout this skill.
3. Determine the installed `@xh/hoist` version. Read `client-app/package.json` and check
   `dependencies` for `@xh/hoist`.
   - **Direct dependency:** If `@xh/hoist` appears in `dependencies`, extract the version.
   - **Dist-tag spec:** The spec can be an npm dist-tag such as `next` instead of a version
     range. Then the app tracks hoist-react SNAPSHOTs ("canary mode"), and the spec has no
     version in it. Read the resolved version from `client-app/node_modules/@xh/hoist/package.json`, or
     from the lockfile if dependencies are not installed. Record canary mode for Phase 2.
   - **Transitive dependency:** If not found directly, `@xh/hoist` may be pulled in via a
     client-specific plugin. Run (from `client-app/`):
     - Yarn: `yarn why @xh/hoist`
     - npm: `npm ls @xh/hoist`
     - pnpm: `pnpm why @xh/hoist`
     Parse the output to find the resolved version and note which package depends on it.
   - If neither approach finds `@xh/hoist`, inform the user: "This does not appear to be a
     Hoist project. `@xh/hoist` was not found as a direct or transitive dependency." Then stop.
4. **Detect client plugins.** Enterprise Hoist applications often use one or more client-specific
   plugins: npm packages that wrap `@xh/hoist` (client-side) and Grails plugins that wrap
   `hoist-core` (server-side). Agents need to know about them because they add a layer between
   the application and the core Hoist framework.

   **Naming convention:** Client plugins always include the word "hoist" in their name. This is
   the primary signal for detection on both sides. Look for any dependency containing "hoist"
   that is NOT published by XH, that is, not `@xh/hoist` on npm or `io.xh:hoist-core` on Gradle.

   **Client-side (npm):**
   Scan `client-app/package.json` `dependencies` for packages containing "hoist" in their name
   that are NOT `@xh/hoist`. The typical naming convention is `clientname-hoist-react`.
   If `@xh/hoist` was detected as a transitive dependency in step 3, the package that pulls it
   in is itself a client plugin.

   For each detected client plugin, record:
   - Package name and current version
   - Whether it provides `@xh/hoist` transitively (from step 3)

   **Server-side (Grails):**
   Read `build.gradle` and look for dependencies containing "hoist" in their artifact name that
   are NOT `io.xh:hoist-core`. The typical naming convention is `clientname-hoist` (for example
   `com.clientname:clientname-hoist`). If `hoistCoreVersion` is NOT set directly in
   `gradle.properties`, check `build.gradle` for a client plugin dependency that may provide
   `hoist-core` transitively.

   For each detected server-side plugin, record:
   - Dependency coordinates (group:artifact:version)
   - Whether it provides `hoist-core` transitively

   Even when client plugins provide the Hoist dependencies, always verify the installed versions
   with the package manager (step 3 for npm) and Gradle's dependency graph (step 6 for
   hoist-core).

5. Confirm standard project structure: check that `build.gradle`, `grails-app/`, and
   `gradle.properties` exist at the project root.
6. Read `gradle.properties` and extract `hoistCoreVersion`. If `hoistCoreVersion` is not present,
   because it comes from a client-specific Grails plugin, get the resolved version from Gradle's
   dependency graph:
   ```bash
   ./gradlew dependencies --configuration runtimeClasspath | grep hoist-core
   ```
   Record the resolved version and note that it is provided transitively.
7. Check for an existing `AGENTS.md` and `CLAUDE.md` at the project root. Record which Hoist
   sections each one holds (see Phase 4).
8. Query npm for the latest stable `@xh/hoist` version:
   ```bash
   npm view @xh/hoist dist-tags.latest
   ```
   `npm view` queries the registry. It works whatever package manager the project uses, because
   `npm` ships with Node.

   Compare the installed version (from step 3) to the latest available. Store both values for
   use in Phase 2. `@xh/hoist` (hoist-react) is the primary upgrade signal. It changes more often
   than hoist-core, and each hoist-react release specifies the `hoist-core` version it needs.

   **Canary mode.** If the spec is a dist-tag such as `next` (step 3), never compare against
   `latest`. Run `npm view @xh/hoist dist-tags.next` and compare the installed version with it:
   - `next` is a newer major: offer the `hoist-upgrade` skill in Phase 2. Its canary path
     applies the migrations for each major it crosses.
   - Same major, newer build: show "behind `next`, run the package manager update" in the
     detection summary. Ask no upgrade question.
   - Otherwise the app is current.

   **SNAPSHOT pin.** If the installed version contains `-SNAPSHOT` (for example
   `85.0.0-SNAPSHOT.1777529713059`) and the spec is not a dist-tag, the developer pinned a
   pre-release that is typically *ahead* of `latest`. Treat it as up to date and show "on a
   pre-release SNAPSHOT" in the detection summary.
<!-- legacy-api:start -->
9. **Detect the decorator style.** It picks the Models and Decorators section of the generated
   AGENTS.md (Phase 4). Read `client-app/tsconfig.json`, and any config it `extends`:
   - `experimentalDecorators: true`: **legacy** decorators.
   - Otherwise: **TC39** decorators, with `accessor` fields.
   If no tsconfig can be read, use the installed `@xh/hoist` major from step 3: v88 or later is
   TC39, earlier is legacy.
<!-- legacy-api:end -->

# Phase 2: Templates

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
