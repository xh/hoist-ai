---
name: onboard-app
description: Configure and verify AI setup for a Hoist project. Detects project type, generates CLAUDE.md, and verifies MCP server connectivity.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, mcp__hoist-react__*
---

# Hoist Project Onboarding

Configure this Hoist project for AI-augmented development. Follow each phase in order.

## Hoist Project Structure

All Hoist applications share the same layout: a Grails/Groovy backend at the project root and
a React/TypeScript frontend in `client-app/`. Key locations:

- `client-app/package.json` -- frontend dependencies, including `@xh/hoist`
- `client-app/yarn.lock` or `client-app/package-lock.json` -- package manager lockfile
- `client-app/src/` -- frontend application source
- `build.gradle` -- Gradle build config with `hoist-core` dependency (direct or via client plugin)
- `gradle.properties` -- app metadata (`xhAppCode`, and typically `hoistCoreVersion` -- though
  this may be absent if `hoist-core` is provided transitively by a client-specific Grails plugin)
- `grails-app/` -- Grails controllers, services, domain classes

## Phase 1: Detect Project

1. **Detect package manager.** Check which lockfile exists in `client-app/`:
   - `yarn.lock` -- use `yarn` (e.g. `yarn install`, `yarn why`)
   - `package-lock.json` -- use `npm` (e.g. `npm install`, `npm ls`)
   Store the detected package manager for use throughout this skill.
2. Determine the installed `@xh/hoist` version. Read `client-app/package.json` and check
   `dependencies` for `@xh/hoist`.
   - **Direct dependency:** If `@xh/hoist` appears in `dependencies`, extract the version.
   - **Transitive dependency:** If not found directly, `@xh/hoist` may be pulled in via a
     client-specific plugin. Run (from `client-app/`):
     - Yarn: `yarn why @xh/hoist`
     - npm: `npm ls @xh/hoist`
     Parse the output to find the resolved version and note which package depends on it.
   - If neither approach finds `@xh/hoist`, inform the user: "This does not appear to be a
     Hoist project -- `@xh/hoist` was not found as a direct or transitive dependency." Then stop.
3. **Detect client plugins.** Enterprise Hoist applications often use one or more client-specific
   plugins -- npm packages that wrap `@xh/hoist` (client-side) and/or Grails plugins that wrap
   `hoist-core` (server-side). These are important for AI agents to understand because they add
   an intermediate layer between the application and the core Hoist framework.

   **Naming convention:** Client plugins always include the word "hoist" in their name. This is
   the primary signal for detection on both sides -- look for any dependency containing "hoist"
   that is NOT published by XH (i.e. not `@xh/hoist` on npm or `io.xh:hoist-core` on Gradle).

   **Client-side (npm):**
   Scan `client-app/package.json` `dependencies` for packages containing "hoist" in their name
   that are NOT `@xh/hoist`. The typical naming convention is `clientname-hoist-react`.
   If `@xh/hoist` was detected as a transitive dependency in step 2, the package that pulls it
   in is itself a client plugin.

   For each detected client plugin, record:
   - Package name and current version
   - Whether it provides `@xh/hoist` transitively (from step 2)

   **Server-side (Grails):**
   Read `build.gradle` and look for dependencies containing "hoist" in their artifact name that
   are NOT `io.xh:hoist-core`. The typical naming convention is `clientname-hoist` (e.g.
   `com.clientname:clientname-hoist`). If `hoistCoreVersion` is NOT set directly in
   `gradle.properties`, check `build.gradle` for a client plugin dependency that may provide
   `hoist-core` transitively.

   For each detected server-side plugin, record:
   - Dependency coordinates (group:artifact:version)
   - Whether it provides `hoist-core` transitively

   Even when Hoist dependencies are provided transitively through client plugins, always verify
   the actual installed versions using the package manager (step 2 for npm) and Gradle's
   dependency graph (step 5 for hoist-core).

4. Confirm standard project structure: check that `build.gradle`, `grails-app/`, and
   `gradle.properties` exist at the project root.
5. Read `gradle.properties` and extract `hoistCoreVersion`. If `hoistCoreVersion` is not present
   (i.e. it is inherited from a client-specific Grails plugin), determine the resolved version
   using Gradle's dependency graph:
   ```bash
   ./gradlew dependencies --configuration runtimeClasspath | grep hoist-core
   ```
   Record the resolved version and note that it is provided transitively.
6. Check for an existing `CLAUDE.md` at the project root.
7. Query npm for the latest stable `@xh/hoist` version:
   ```bash
   npm view @xh/hoist dist-tags.latest
   ```
   Compare the installed version (from step 2) to the latest available. Store both values for
   use in Phase 2. Note: `@xh/hoist` (hoist-react) is the primary upgrade signal -- it is the
   more frequently updated package and the one applications depend on most heavily. Upgrades to
   hoist-react drive the process and specify the required `hoist-core` version to match.

## Phase 2: Present Findings

Display a summary of what was detected:

```
## Project Detection Results

- **@xh/hoist (hoist-react):** v[version] [(direct | via [plugin name])] ([up to date | upgrade available: v[latest]])
- **hoist-core:** v[version] [(direct | via [plugin name])]
- **Client plugins:** [None detected | See table below]
- **Existing CLAUDE.md:** [Yes -- merge needed | No -- will create fresh]
```

For both hoist-react and hoist-core, report the resolved version from the dependency manager
(npm/yarn for hoist-react, Gradle for hoist-core) and indicate whether the dependency is direct
or provided transitively via a client plugin.

If client plugins were detected in Phase 1, include a table:

```
### Client Plugins

| Plugin | Type | Version | Provides |
|--------|------|---------|----------|
| @clientname/hoist-toolkit | npm | 4.2.0 | @xh/hoist transitively |
| com.client:hoist-core-ext | Grails | 3.1.0 | hoist-core transitively |

These plugins add a client-specific layer between this app and the core Hoist
framework. They will be documented in CLAUDE.md so AI agents understand the
dependency chain.
```

Then list the planned actions:

```
### Planned Actions
- [Configure | Verify] `.mcp.json` with hoist-react MCP server (if @xh/hoist v82+)
- [Create | Update] CLAUDE.md with Hoist conventions (~[N] lines)
- [Include client plugin documentation (if plugins detected)]
- Verify MCP server connectivity
```

If the installed `@xh/hoist` version is behind the latest stable release, add this section after
the detection summary and BEFORE the "Proceed with setup?" confirmation:

The Hoist MCP server is first available in `@xh/hoist` v82.0. If the installed version is
below v82, the MCP server will not exist and the AI tooling will be significantly limited.

If the installed version is **below v82**, show:

```
### Hoist Upgrade Required

Your project is on @xh/hoist v[installed], but the Hoist MCP server requires v82.0 or later.
Without it, AI tooling will be limited to the static conventions in CLAUDE.md -- no live
framework documentation, API lookup, or symbol search will be available.

**Recommendation:** Run `/hoist-upgrade` to upgrade before completing onboarding.
```

If the installed version is **v82+ but behind the latest stable release**, show:

```
### Hoist Upgrade Available

Your project is on @xh/hoist v[installed], but v[latest] is available.
Newer versions include improved MCP server capabilities and AI tooling support.

**Recommendation:** Run `/hoist-upgrade` to upgrade before completing onboarding.
```

In either case, ask: **"Would you like to upgrade first? (yes = run /hoist-upgrade, no = continue with current version)"**

- If yes: Tell the developer to run `/hoist-upgrade` (or `/xh:hoist-upgrade`). The
  onboarding skill should stop here and instruct the developer to re-run `/onboard-app` after
  the upgrade completes. (Skills cannot invoke other skills directly -- this is a handoff.)
- If no: Continue with onboarding as normal using the current version. If below v82, note that
  the MCP server verification in Phase 4 will be skipped.

If the installed version is already up to date, skip the upgrade recommendation and proceed
directly to:

Ask the user: **"Proceed with setup? (yes/no)"**

Wait for the user to confirm before making any changes. Do NOT write any files until the user says yes.

## Phase 3: Configure MCP Server

If the installed `@xh/hoist` version is v82.0 or later, configure the project's `.mcp.json` so
the hoist-react MCP server launches automatically. This must be done at the project level (not
via the plugin) because the server binary lives in the project's own `node_modules`.

1. Check if `.mcp.json` already exists at the project root.
2. If it exists, read it and check whether a `hoist-react` entry is already present under
   `mcpServers`. If so, skip this phase -- it's already configured.
3. If `.mcp.json` exists but has no `hoist-react` entry, add it to the existing `mcpServers`
   object. Preserve all other entries.
4. If `.mcp.json` does not exist, create it with the following content:

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

5. Before writing, confirm the binary exists at `client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs`.
   If it does not, warn the user that they need to run their package manager install from
   `client-app/` first, then re-run onboarding.

Note: the MCP server will not be available until the next Claude Code restart after this file is
written. Phase 5 will attempt to verify connectivity, but if this is a fresh configuration it
may not be running yet.

## Phase 4: Generate CLAUDE.md

Locate the template files bundled with this skill. Use `Glob` to find the templates:
```
**/onboard-app/templates/claude-md-base.md
```
Read the base template from the matched path.

1. Read the base template. The base template includes both client-side (hoist-react) and
   server-side (hoist-core) documentation. No version substitution is needed -- actual Hoist
   versions should be determined at runtime from the dependency managers rather than baked into
   CLAUDE.md where they can go stale.
2. If client plugins were detected in Phase 1, also read `claude-md-client-plugins.md` from
   the same templates directory and append its content. Replace the placeholder table with a
   row for each detected plugin:
   - `{{PLUGIN_TABLE}}` -- one row per plugin: `| name | npm or Grails | version | what it provides |`
   - `{{PLUGIN_NOTES}}` -- for each npm plugin, note if it provides `@xh/hoist` transitively
     (meaning the app does not depend on `@xh/hoist` directly). For Grails plugins, note if
     `hoist-core` is provided transitively. Add a brief note advising AI agents to check
     plugin source/docs when changes touch plugin-provided APIs.
   If no client plugins were detected, skip this template entirely.
3. If an existing `CLAUDE.md` is present:
   - Read the existing file.
   - Check which Hoist sections are already present (look for headings like
     "Architecture Primer", "MCP Tools", "hoist-core", "Commands", "Client Plugins").
   - Append only sections that are missing. Do NOT overwrite or duplicate existing content.
   - Show the user what will be added before writing.
   - Preserve all existing project-specific content.
4. If no `CLAUDE.md` exists: write the complete generated template to `./CLAUDE.md`.

## Phase 5: Verify MCP Server

If the installed `@xh/hoist` version is below v82.0, skip this phase entirely -- the MCP server
is not available in earlier versions. Note this in the Phase 6 report.

1. Call `mcp__hoist-react__hoist-ping`. Expect the response to contain "Hoist MCP server is running."
2. If ping succeeds: call `mcp__hoist-react__hoist-search-docs` with query `"HoistModel"` as a
   sample query to confirm docs are accessible.
3. If ping fails or the MCP tool is not available: inform the user that the MCP server is not
   currently reachable but the CLAUDE.md has been configured and works standalone. Suggest:
   - Ensure `@xh/hoist` is installed (run the project's package manager install from `client-app/`)
   - Check that the hoist-react MCP server is configured (the `xh` plugin should handle this
     automatically)

## Phase 6: Report

Display a final summary:

```
## Onboarding Complete

- **CLAUDE.md:** [Created | Updated (added N sections) | Already up to date]
- **`.mcp.json`:** [Created | Updated (added hoist-react) | Already configured | Skipped (requires @xh/hoist v82+)]
- **Client plugins:** [N plugin(s) documented | None detected]
- **MCP server:** [Connected -- docs accessible | Not available (restart Claude Code to activate) | Requires @xh/hoist v82+ (upgrade needed)]
- **Next steps:** Start coding with AI assistance. The MCP server tools provide
  framework documentation and API lookup when available.
```
