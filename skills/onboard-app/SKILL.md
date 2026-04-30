---
name: onboard-app
description: Configure and verify AI setup for a Hoist project. Detects project type, generates CLAUDE.md, configures the hoist-react MCP server, optionally installs the hoist-core MCP+CLI tools, and verifies the surfaces in the current environment.
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
   `npm view` is a registry-query command -- it works in any Node.js environment regardless of
   which package manager the project uses, since `npm` ships with Node itself. No need to
   route through the project's detected manager here.

   Compare the installed version (from step 2) to the latest available. Store both values for
   use in Phase 2. Note: `@xh/hoist` (hoist-react) is the primary upgrade signal -- it is the
   more frequently updated package and the one applications depend on most heavily. Upgrades to
   hoist-react drive the process and specify the required `hoist-core` version to match.

   **SNAPSHOT handling.** If the installed version contains `-SNAPSHOT` (e.g.
   `85.0.0-SNAPSHOT.1777529713059`), the developer is intentionally on a pre-release that is
   typically *ahead* of the published `latest` tag. Do not flag this as "behind latest" --
   semver comparison against `dist-tags.latest` will lie. Treat SNAPSHOT installs as up-to-date
   for upgrade-prompt purposes; surface "on a pre-release SNAPSHOT" in Phase 2's detection
   summary instead of an upgrade nudge.

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
- Detect whether hoist-core MCP+CLI tools are installed; if `hoistCoreVersion >= 39.0` and
  they're not yet wired up, ask separately whether to install them (modifies `build.gradle`)
- Verify both surfaces -- hoist-react MCP via ping, hoist-core via the CLI launcher (universal,
  works even in MCP-blocked environments)
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

**Recommendation:** Run `/xh:hoist-upgrade` to upgrade before completing onboarding.
```

If the installed version is **v82+ but behind the latest stable release**, show:

```
### Hoist Upgrade Available

Your project is on @xh/hoist v[installed], but v[latest] is available.
Newer versions include improved MCP server capabilities and AI tooling support.

**Recommendation:** Run `/xh:hoist-upgrade` to upgrade before completing onboarding.
```

In either case, ask: **"Would you like to upgrade first? (yes = run /xh:hoist-upgrade, no = continue with current version)"**

- If yes: Tell the developer to run `/xh:hoist-upgrade`. The onboarding skill should stop here
  and instruct the developer to re-run `/xh:onboard-app` after the upgrade completes. (Skills
  cannot invoke other skills directly -- this is a handoff.)
- If no: Continue with onboarding as normal using the current version. If below v82, note that
  the MCP server verification in Phase 5 will be skipped.

If the installed version is already up to date, skip the upgrade recommendation and proceed
directly to:

Ask the user: **"Proceed with setup? (yes/no)"**

Wait for the user to confirm before making any changes. Do NOT write any files until the user says yes.

## Phase 3: Configure hoist-react MCP Server

If the installed `@xh/hoist` version is v82.0 or later, configure the project's `.mcp.json` so
the hoist-react MCP server launches automatically. This must be done at the project level (not
via the plugin) because the server binary lives in the project's own `node_modules`.

The `.mcp.json` entry is harmless in environments where MCP is blocked: Claude Code simply
won't connect to it, and the entry becomes functional automatically if the environment later
permits MCP. In MCP-blocked environments, the parallel CLI surface (`npx hoist-docs`,
`npx hoist-ts`) is the working path and is documented in the generated CLAUDE.md.

1. Check if `.mcp.json` already exists at the project root.
2. If it exists, read it and check whether a `hoist-react` entry is already present under
   `mcpServers`. If so, skip this phase -- it's already configured.
3. **Before writing anything**, confirm the binary exists at
   `client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs`. If it does not, warn the user that
   they need to run their package manager install from `client-app/` first, then re-run
   onboarding.
4. If `.mcp.json` exists but has no `hoist-react` entry, add it to the existing `mcpServers`
   object. Preserve all other entries.
5. If `.mcp.json` does not exist, create it with the following content:

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

Note: the MCP server will not be available until the next Claude Code restart after this file is
written. Phase 5 will attempt to verify connectivity, but if this is a fresh configuration it
may not be running yet.

## Phase 3.5: Install hoist-core MCP Server and CLI Tools (optional)

The hoist-core developer tools ship as a fat JAR (`io.xh:hoist-core-mcp:<version>:all`) that
project Gradle builds resolve through normal Maven resolution. Running the install task writes
project-local launchers under `bin/` -- these expose both the MCP server (`bin/hoist-core-mcp`,
referenced from `.mcp.json`) and the CLI tools (`bin/hoist-core-docs`, `bin/hoist-core-symbols`).
The CLI surface is the primary path in MCP-blocked environments and works once installed
without depending on Claude Code restarts or MCP availability.

### Step 1: Detect current state

1. Check whether `bin/hoist-core-mcp` exists at the project root and is executable.
2. Check whether `.mcp.json` already has a `hoist-core` entry under `mcpServers`.
3. If both are present, this phase is already done -- skip.
4. If `hoistCoreVersion < 39.0` (the first release containing the `installHoistCoreTools`
   task), skip with a note in Phase 6: "hoist-core MCP+CLI install requires hoistCoreVersion
   >= 39.0 -- run `/xh:hoist-upgrade` first, then re-run `/xh:onboard-app` to install."

### Step 2: Ask permission

Show the user a focused confirmation BEFORE making any Gradle-level changes:

```
### Install hoist-core MCP server and CLI tools?

This will:
- Add ~15 lines to `build.gradle`: a `hoistCoreCli` configuration and the
  `installHoistCoreTools` Sync task.
- Run `./gradlew installHoistCoreTools` to resolve the version-locked fat JAR
  (`io.xh:hoist-core-mcp:<hoistCoreVersion>:all`) and write launchers under `bin/`.
- Add a `hoist-core` entry to `.mcp.json` pointing at `./bin/hoist-core-mcp`.

The CLI surface (`./bin/hoist-core-docs`, `./bin/hoist-core-symbols`) works in any environment,
including MCP-blocked ones. The `.mcp.json` entry is forward-compatible -- harmless if MCP is
blocked, functional automatically if MCP later becomes available.

Proceed? (yes/no)
```

If the user says no: record the decision and surface a clear deferred-step note in the Phase 6
report. The install can be run later by asking Claude to install/setup the hoist-core MCP+CLI
in this app -- the `using-hoist-core-reference` skill will fire on that ask and walk through it.

### Step 3: Run the install procedure

If the user agreed, follow the install procedure documented in the
`using-hoist-core-reference` skill (the source of truth for this flow). Read it via:

```
**/skills/using-hoist-core-reference/SKILL.md
```

Jump to the **"Installing the MCP server and CLI tools"** section and follow its steps end to
end (Gradle snippet, `installHoistCoreTools`, `.mcp.json` wiring including `--source bundled`
on the mcp launcher). Do not duplicate the snippet here -- the reference skill is the canonical
copy and is what will be re-read on future re-runs.

### Step 4: Verify (CLI-first, MCP-opportunistic)

After install, verify with the CLI -- this works in any environment, no restart required:

```bash
./bin/hoist-core-docs ping
```

Expect: `hoist-core CLI is running.` If this fails, surface the error to the user before
continuing.

Do **not** depend on `mcp__hoist-core__hoist-core-ping` succeeding here -- the `.mcp.json`
write is fresh and Claude Code has not yet restarted, AND the environment may block MCP. The
CLI ping is the universal sanity check.

## Phase 4: Generate CLAUDE.md

Locate the template files bundled with this skill. Use `Glob` to find the templates:
```
**/onboard-app/templates/claude-md-base.md
```
Read the base template from the matched path.

1. Read the base template. The base template includes both client-side (hoist-react) and
   server-side (hoist-core) documentation. Version substitution is not needed -- actual Hoist
   versions should be determined at runtime from the dependency managers rather than baked into
   CLAUDE.md where they can go stale.

   **Do** substitute the package-manager tokens in the Commands section to reflect the manager
   detected in Phase 1 (yarn for `yarn.lock`, npm for `package-lock.json`):
   - `{{PKG_MGR_INSTALL}}` → `yarn install` or `npm install`
   - `{{PKG_MGR_START}}` → `yarn start` or `npm start`
   - `{{PKG_MGR_LINT}}` → `yarn lint` or `npm run lint`

   The generated CLAUDE.md should show only the commands that match the project's actual
   package manager -- not both with a "(or X)" parenthetical that implies a preference.
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

## Phase 5: Verify Surfaces (CLI-first, MCP-opportunistic)

Verification's job is to confirm the working surfaces are reachable in the *current*
environment. Treat MCP as opportunistic (it requires Claude Code restart and may be blocked by
the environment); treat CLI as the universal sanity check (works as soon as it's installed).

### hoist-react

If `@xh/hoist < v82.0`, skip hoist-react verification -- MCP is unavailable in those versions.
Note this in the Phase 6 report.

Otherwise:

1. **Opportunistic MCP ping.** Call `mcp__hoist-react__hoist-ping` if the tool is in your
   context. Success → "MCP active". Tool not present or fails → "MCP entry written, will
   activate on next Claude Code restart (or remain dormant in MCP-blocked environments)" --
   this is not an error.
2. **CLI sanity (only if MCP failed).** From `client-app/`, run `npx hoist-docs index` and
   confirm it prints the docs index. If the project's `node_modules` aren't installed, surface
   the package-manager install step as the user's next action.

### hoist-core (only if Phase 3.5 installed it)

1. **CLI sanity (always run).** From the project root, run `./bin/hoist-core-docs ping`. Expect
   `hoist-core CLI is running.` If this fails, the install didn't take -- surface the error.
2. **Opportunistic MCP ping.** Call `mcp__hoist-core__hoist-core-ping` if the tool is in your
   context. Same semantics as hoist-react: success → "MCP active"; not present → "entry
   written, activates on Claude Code restart in environments that permit MCP". Not an error.

### Why CLI-first matters for enterprise environments

In environments that block MCP traffic, the CLI surface is the working path. Onboarding must
not stall or surface scary "verification failed" errors when MCP isn't reachable -- the
`.mcp.json` entries are forward-compatible (harmless if MCP is blocked, functional if and when
the environment unblocks it), and the CLI is fully usable today. Phase 6 must clearly
distinguish "working now" from "queued for activation".

## Phase 6: Report

Display a final summary that distinguishes "working now" from "queued for activation" and
calls out the CLI fallback for MCP-blocked environments:

```
## Onboarding Complete

### Configuration
- **CLAUDE.md:** [Created | Updated (added N sections) | Already up to date]
- **`.mcp.json`:** [Created | Updated (added entries: <list>) | Already configured]
- **Client plugins:** [N plugin(s) documented | None detected]

### hoist-react
- **MCP entry:** [Written | Already present | Skipped (requires @xh/hoist v82+ -- run /xh:hoist-upgrade first)]
- **MCP runtime:** [Active (verified via ping) | Will activate on Claude Code restart, or remain dormant if the environment blocks MCP]
- **CLI fallback:** `npx hoist-docs ...` and `npx hoist-ts ...` from `client-app/` -- works in any environment.

### hoist-core
- **MCP+CLI tools:** [Installed via installHoistCoreTools, CLI verified working | User deferred (run again later or ask Claude to install/set up the hoist-core MCP+CLI tools) | Skipped (requires hoistCoreVersion >= 39.0 -- upgrade hoist-core first) | Already installed]
- **CLI surface:** `./bin/hoist-core-docs` and `./bin/hoist-core-symbols` -- works in any environment.
- **MCP runtime:** [Active (verified via ping) | Will activate on Claude Code restart, or remain dormant if the environment blocks MCP | N/A (not installed)]

### Reference skills
The `using-hoist-react-reference` and `using-hoist-core-reference` skills (shipped by the `xh`
plugin) fire automatically when authoring Hoist code, asking for orientation, or asking to
install/upgrade the hoist-core MCP+CLI tools. No manual invocation needed.

### MCP-blocked environments
If your environment blocks MCP traffic, the CLI surfaces above are the working path. Use
`npx hoist-docs`/`npx hoist-ts` (hoist-react) and `./bin/hoist-core-docs`/`./bin/hoist-core-symbols`
(hoist-core) directly. The `.mcp.json` entries are harmless in this state and become
functional automatically if MCP later becomes available -- no rerun required.

### Next steps
Restart Claude Code to pick up new `.mcp.json` entries (skip if MCP is blocked in your
environment -- the CLI surfaces are already live). Then start coding -- the reference skills
will route you to framework docs and API lookups.
```
