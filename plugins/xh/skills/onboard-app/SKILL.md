---
name: onboard-app
description: Configure and verify AI setup for a Hoist project. Detects the project type and the agent harness, generates AGENTS.md (imported by CLAUDE.md), configures the hoist-react MCP server for Claude Code or Cursor, optionally installs the hoist-core MCP+CLI tools, and verifies the surfaces in the current environment.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, mcp__hoist-react__*
---

# Hoist Project Onboarding

Configure this Hoist project for AI-augmented development. Follow each phase in order.

## Hoist Project Structure

All Hoist applications share the same layout: a Grails/Groovy backend at the project root and
a React/TypeScript frontend in `client-app/`. Key locations:

- `client-app/package.json`: frontend dependencies, including `@xh/hoist`
- `client-app/yarn.lock`, `client-app/package-lock.json`, or `client-app/pnpm-lock.yaml`: the
  package manager lockfile
- `client-app/src/`: frontend application source
- `build.gradle`: Gradle build config with the `hoist-core` dependency, direct or through a
  client plugin
- `gradle.properties`: app metadata. It holds `xhAppCode` and typically `hoistCoreVersion`. The
  version is absent if a client-specific Grails plugin provides `hoist-core` transitively.
- `grails-app/`: Grails controllers, services, domain classes

## Agent Harnesses

The setup differs by harness, the agent app that runs this skill:

| Harness | Agent docs | MCP config | Detect |
|---|---|---|---|
| Claude Code | `CLAUDE.md`, which imports `AGENTS.md` | `.mcp.json` | `CLAUDECODE` is set |
| Cursor | `AGENTS.md` | `.cursor/mcp.json` | `CURSOR_AGENT` is set |
| Codex | `AGENTS.md` | none, the skills use the CLI | `CODEX_THREAD_ID` is set |

Codex gets no MCP config because it resolves relative server paths against the session's working
directory, not the project root. The CLI launchers work in Codex from any directory.

## Phase 1: Detect Project

1. **Detect the harness.** Run `env | grep -E '^(CLAUDECODE|CURSOR_AGENT|CODEX_THREAD_ID)='` and
   match the result to the table above. If nothing matches and you do not know which harness you
   run in, ask the user. The harnesses to configure are the current one plus each harness that
   already has project config: `.mcp.json` or a `.claude/` folder for Claude Code, a `.cursor/`
   folder for Cursor.
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

   **SNAPSHOT handling.** If the app is in canary mode (step 3) or the installed version
   contains `-SNAPSHOT` (for example `85.0.0-SNAPSHOT.1777529713059`), the developer is on a
   pre-release that is typically *ahead* of the published `latest` tag. Do not flag this as
   "behind latest". Semver comparison against `dist-tags.latest` will lie. Treat SNAPSHOT
   installs as up-to-date for upgrade-prompt purposes. Show "on a pre-release SNAPSHOT" in
   Phase 2's detection summary instead of an upgrade nudge.
<!-- legacy-api:start -->
9. **Detect the decorator style.** It picks the Models and Decorators section of the generated
   AGENTS.md (Phase 4). Read `client-app/tsconfig.json`, and any config it `extends`:
   - `experimentalDecorators: true`: **legacy** decorators.
   - Otherwise: **TC39** decorators, with `accessor` fields.
   If no tsconfig can be read, use the installed `@xh/hoist` major from step 3: v88 or later is
   TC39, earlier is legacy.
<!-- legacy-api:end -->

## Phase 2: Present Findings

Display a summary of what was detected:

```
## Project Detection Results

- **Harness:** [Claude Code | Cursor | Codex] [(also configuring: <other harnesses with project config>)]
- **@xh/hoist (hoist-react):** v[version] [(direct | via [plugin name])] [(canary: tracks `next`)] ([up to date | upgrade available: v[latest]])
- **Decorators:** [TC39 | legacy]
- **hoist-core:** v[version] [(direct | via [plugin name])]
- **Client plugins:** [None detected | See table below]
- **Agent docs:** [None, will create AGENTS.md and CLAUDE.md | AGENTS.md exists, merge needed | CLAUDE.md only, move to AGENTS.md proposed]
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
framework. AGENTS.md will document them so AI agents understand the dependency chain.
```

Then list the planned actions:

```
### Planned Actions
- [Configure | Verify] the hoist-react MCP server in [`.mcp.json` | `.cursor/mcp.json`] (if @xh/hoist v82+)
- [Create | Update] AGENTS.md with Hoist conventions (~[N] lines)
- [Create CLAUDE.md that imports AGENTS.md | Add the AGENTS.md import to CLAUDE.md | Move CLAUDE.md content to AGENTS.md and leave the import]
- [Include client plugin documentation (if plugins detected)]
- Detect whether hoist-core MCP+CLI tools are installed. If `hoistCoreVersion >= 39.0` and
  they are not yet wired up, ask separately whether to install them (modifies `build.gradle`)
- Verify both surfaces: hoist-react MCP with a ping, hoist-core with the CLI launcher, which
  works even in MCP-blocked environments
```

Name each harness the plan configures, so the user can add or remove one before confirming.

If the installed `@xh/hoist` version is behind the latest stable release, add this section after
the detection summary and BEFORE the "Proceed with setup?" confirmation:

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

In either case, ask: **"Would you like to upgrade first? (yes = run the hoist-upgrade skill, no = continue with current version)"**

Write the skill command the way the current harness invokes it: `/xh:hoist-upgrade` in Claude
Code, `/hoist-upgrade` in Cursor, `$xh:hoist-upgrade` in Codex. Do the same for every skill
command you show the user.

- If yes: Tell the developer to run the `hoist-upgrade` skill. Stop here and tell the developer
  to run `onboard-app` again after the upgrade completes. A skill cannot invoke another skill,
  so this is a handoff.
- If no: Continue with onboarding as normal using the current version. If below v82, note that
  the MCP server verification in Phase 5 will be skipped.

If the installed version is already up to date, skip the upgrade recommendation and proceed
directly to:

Ask the user: **"Proceed with setup? (yes/no)"**

Wait for the user to confirm before making any changes. Do NOT write any files until the user says yes.

## Phase 3: Configure hoist-react MCP Server

If the installed `@xh/hoist` version is v82.0 or later, add the hoist-react MCP server to the
project's MCP config for each harness from Phase 1. The plugin cannot ship this entry, because
the server binary lives in the project's own `node_modules`.

The entry is harmless in environments that block MCP: the harness does not connect to it, and
it starts to work if the environment later permits MCP. In MCP-blocked environments, the CLI
surface (`./bin/hoist-docs`, `./bin/hoist-ts`) is the working path, and the generated AGENTS.md
documents it.

1. **Before writing anything**, confirm the binary exists at
   `client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs`. If it does not, warn the user that
   they need to run their package manager install from `client-app/` first, then run
   onboarding again.
2. For each harness, check whether its config file exists and already has a `hoist-react` entry
   under `mcpServers`. If it does, skip that file.
3. If the file exists without a `hoist-react` entry, add the entry to its `mcpServers` object.
   Preserve all other entries. If the file does not exist, create it with the content below.

**Claude Code**, `.mcp.json`. Claude Code starts the server from the project root:

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

**Cursor**, `.cursor/mcp.json`. Cursor expands `${workspaceFolder}` to the project root:

```json
{
  "mcpServers": {
    "hoist-react": {
      "type": "stdio",
      "command": "node",
      "args": [
        "${workspaceFolder}/client-app/node_modules/@xh/hoist/bin/hoist-mcp.mjs"
      ],
      "env": {}
    }
  }
}
```

The MCP server is not available until the next agent session after this file is written.
Phase 5 tries to verify the connection, but a fresh configuration is usually not running yet.

## Phase 3.5: Install hoist-core MCP Server and CLI Tools (optional)

The hoist-core developer tools ship as a fat JAR (`io.xh:hoist-core-mcp:<version>:all`) that
the project's Gradle build resolves through normal Maven resolution. The install task writes
project-local launchers under `bin/`. They expose both the MCP server (`bin/hoist-core-mcp`,
referenced from the MCP config) and the CLI tools (`bin/hoist-core-docs`,
`bin/hoist-core-symbols`). The CLI surface is the primary path in MCP-blocked environments. It
works as soon as it is installed, with no new session and no MCP.

### Step 1: Detect current state

1. Check whether `bin/hoist-core-mcp` exists at the project root and is executable.
2. Check whether the MCP config file of each harness that gets MCP config (Phase 3) has a
   `hoist-core` entry under `mcpServers`.
3. If the launcher and every entry are present, this phase is already done. Skip it.
4. If `hoistCoreVersion < 39.0` (the first release containing the `installHoistCoreTools`
   task), skip with a note in Phase 6: "hoist-core MCP+CLI install requires hoistCoreVersion
   >= 39.0. Run the `hoist-upgrade` skill first, then run `onboard-app` again to install."

### Step 2: Ask permission

Show the user a focused confirmation BEFORE making any Gradle-level changes:

```
### Install hoist-core MCP server and CLI tools?

This will:
- Add ~15 lines to `build.gradle`: a `hoistCoreCli` configuration and the
  `installHoistCoreTools` Sync task.
- Run `./gradlew installHoistCoreTools` to resolve the version-locked fat JAR
  (`io.xh:hoist-core-mcp:<hoistCoreVersion>:all`) and write launchers under `bin/`.
- Add a `hoist-core` entry that points at `bin/hoist-core-mcp` to [`.mcp.json` | `.cursor/mcp.json`].

The CLI surface (`./bin/hoist-core-docs`, `./bin/hoist-core-symbols`) works in any environment,
including MCP-blocked ones. The MCP entry is harmless if MCP is blocked, and it starts to work
if MCP later becomes available.

Proceed? (yes/no)
```

If the user says no, record the decision and show a deferred-step note in the Phase 6 report.
The user can install later: an ask to install or set up the hoist-core MCP+CLI in this app loads
the `using-hoist-core-reference` skill, which walks through it.

### Step 3: Run the install procedure

If the user agreed, follow the install procedure in the `using-hoist-core-reference` skill, the
source of truth for this flow. Read its SKILL.md in the sibling skill folder,
`../using-hoist-core-reference/SKILL.md` from this skill's folder. If you cannot find it there,
search for `**/skills/using-hoist-core-reference/SKILL.md`.

Jump to the **"Installing the MCP server and CLI tools"** section and follow its steps from start
to end: the Gradle snippet, `installHoistCoreTools`, and the MCP config. Do not duplicate the
snippet here. The reference skill holds the canonical copy, and later runs read it again.

### Step 4: Verify (CLI-first, MCP-opportunistic)

After install, verify with the CLI. This works in any environment, with no new session:

```bash
./bin/hoist-core-docs ping
```

Expect: `hoist-core CLI is running.` If this fails, show the error to the user before
continuing.

Do **not** depend on the MCP `hoist-core-ping` tool here. The MCP config is fresh and the
session has not restarted, and the environment may block MCP. The CLI ping is the universal
sanity check.

## Phase 4: Generate AGENTS.md

`AGENTS.md` holds the project guidance, because every harness reads it. `CLAUDE.md` holds the
line `@AGENTS.md`, which makes Claude Code load the same file.

The templates are in the `templates/` folder beside this SKILL.md. If you cannot find that
folder, search for `**/onboard-app/templates/agents-md-base.md`. Read
`agents-md-base.md` from that folder.

1. Read the base template. The base template includes both client-side (hoist-react) and
   server-side (hoist-core) documentation. Do not substitute versions. Agents get the Hoist
   versions from the dependency managers at runtime, and a version in AGENTS.md goes stale.

   **Do** substitute the package-manager tokens in the Commands section to reflect the manager
   detected in Phase 1 (yarn for `yarn.lock`, npm for `package-lock.json`, pnpm for
   `pnpm-lock.yaml`):
   - `{{PKG_MGR_INSTALL}}` → `yarn install`, `npm install`, or `pnpm install`
   - `{{PKG_MGR_START}}` → `yarn start`, `npm start`, or `pnpm start`
   - `{{PKG_MGR_LINT}}` → `yarn lint`, `npm run lint`, or `pnpm lint`

   Show only the commands for the project's package manager. Do not add a second manager in
   parentheses, which implies a preference.

   **Do** replace `{{MODEL_PRIMER}}` with the full content of the models template for the
   decorator style detected in Phase 1, from the same templates directory:
   - TC39: `agents-md-models-tc39.md`
   - legacy: `agents-md-models-legacy.md`
2. If client plugins were detected in Phase 1, also read `agents-md-client-plugins.md` from
   the same templates directory and append its content. Replace the placeholders:
   - `{{PLUGIN_TABLE}}`: one row per plugin: `| name | npm or Grails | version | what it provides |`
   - `{{PLUGIN_NOTES}}`: for each npm plugin, note if it provides `@xh/hoist` transitively,
     which means the app does not depend on `@xh/hoist` directly. For Grails plugins, note if
     `hoist-core` is provided transitively. Add a brief note that tells AI agents to check
     plugin source and docs when changes touch plugin-provided APIs.
   If no client plugins were detected, skip this template entirely.
3. Pick the target file from what Phase 1 found. An `AGENTS.md` that only points readers to
   `CLAUDE.md` counts as absent: replace it when you move the content.
   - **Neither file exists.** Write the generated content to `./AGENTS.md`. Write `./CLAUDE.md`
     with the single line `@AGENTS.md`.
   - **`AGENTS.md` exists.** Merge into it with the rules in step 4. Then make sure `CLAUDE.md`
     imports it: create `CLAUDE.md` with the line `@AGENTS.md`, or add that line at the top of
     an existing `CLAUDE.md` that lacks it. If `CLAUDE.md` also holds Hoist sections from an
     older onboarding, move them into `AGENTS.md` and remove them from `CLAUDE.md`.
   - **Only `CLAUDE.md` exists.** Older onboarding runs wrote the Hoist guidance there. Propose
     to move its content to a new `AGENTS.md`, so Cursor and Codex read it too. `CLAUDE.md` then
     keeps the line `@AGENTS.md` and any line that only Claude Code understands, such as an
     `@path` import of another file. Then merge into `AGENTS.md` with the rules in step 4. If
     the user declines the move, merge into `CLAUDE.md` with the same rules and write no
     `AGENTS.md`.
4. Merge rules for an existing file:
   - Read the existing file.
   - Check which Hoist sections are already present (look for headings like
     "Architecture Primer", "Models and Decorators", "MCP Tools", "hoist-core", "Writing Style",
     "Commands", "Client Plugins").
   - Append only sections that are missing. Do NOT overwrite or duplicate existing content.
   <!-- legacy-api:start -->
   - **Exception: a stale model primer.** Hoist primer text that teaches the other decorator
     style is wrong for this app. Older onboarding runs put the HoistModel example inside
     "Architecture Primer", not in a "Models and Decorators" section. Judge it by the
     primer's HoistModel code example, not by prose that only names an API. The primer is
     stale if the app uses TC39 decorators and the example declares `@observable` or
     `@bindable` fields without `accessor`, or calls `makeObservable(this)`. It is also stale
     if the app uses legacy decorators and the example uses `accessor` fields.
     Offer to replace the "Architecture Primer" and "Models and Decorators" sections with the
     generated ones. Keep any project-specific text the user added inside them.
   <!-- legacy-api:end -->
   - Show the user what will be added, moved, or replaced before writing.
   - Preserve all existing project-specific content.

## Phase 5: Verify Surfaces (CLI-first, MCP-opportunistic)

Verification confirms which surfaces work in the *current* environment. Treat MCP as
opportunistic: it needs a new agent session, and the environment may block it. Treat the CLI as
the universal sanity check: it works as soon as it is installed.

### hoist-react

If `@xh/hoist < v82.0`, skip hoist-react verification, because those versions have no MCP
server. Note this in the Phase 6 report.

Otherwise:

1. **Opportunistic MCP ping.** If the hoist-react server's `hoist-ping` tool is in your tool list
   (`mcp__hoist-react__hoist-ping` in Claude Code), call it. Success → "MCP active". Tool not
   present or fails → "MCP entry written, activates in the next agent session (or stays dormant
   in MCP-blocked environments)". This is not an error.
2. **CLI launcher presence (informational).** Check whether `./bin/hoist-docs` and
   `./bin/hoist-ts` exist at the project root.
   - If both are present, optionally run `./bin/hoist-docs index` to confirm output. If
     `client-app/node_modules` is not installed yet, tell the user to run the package manager
     install.
   - If absent, do **not** install them here. Note in the Phase 6 report: "hoist-react CLI
     launchers not yet installed. The `using-hoist-react-reference` skill installs them
     the first time an agent reaches for the CLI surface in this project."
   This keeps onboarding to the once-only setup (MCP config, AGENTS.md). The reference skill
   owns the launcher lifecycle, including a refresh when the stamp version changes.

### hoist-core (only if Phase 3.5 installed it)

1. **CLI sanity (always run).** From the project root, run `./bin/hoist-core-docs ping`. Expect
   `hoist-core CLI is running.` If this fails, the install did not work. Show the error.
2. **Opportunistic MCP ping.** If the hoist-core server's `hoist-core-ping` tool is in your tool
   list, call it. Same semantics as hoist-react: success → "MCP active". Not present → "entry
   written, activates in the next agent session in environments that permit MCP". Not an error.

### Why CLI-first matters for enterprise environments

In environments that block MCP traffic, the CLI surface is the working path. Onboarding must
not stall or report "verification failed" when MCP is not reachable. The MCP entries are
harmless if MCP is blocked and start to work if the environment unblocks it, and the CLI works
today. Phase 6 must clearly distinguish "working now" from "queued for activation".

## Phase 6: Report

Display a final summary that distinguishes "working now" from "queued for activation" and
calls out the CLI fallback for MCP-blocked environments:

```
## Onboarding Complete

### Configuration
- **Harnesses:** [Claude Code, Cursor, Codex: those configured]
- **AGENTS.md:** [Created | Updated (added N sections) | Moved from CLAUDE.md | Already up to date]
- **CLAUDE.md:** [Created with `@AGENTS.md` | Import added | Already imports AGENTS.md]
- **MCP config:** [`.mcp.json`: Created | Updated (added entries: <list>) | Already configured] [`.cursor/mcp.json`: ...]
- **Client plugins:** [N plugin(s) documented | None detected]

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
live. Commit AGENTS.md, CLAUDE.md, and the MCP config files so the whole team gets them. Then
start coding. The reference skills route you to framework docs and API lookups.
```
