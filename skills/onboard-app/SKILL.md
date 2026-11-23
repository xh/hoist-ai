---
name: onboard-app
description: Configure and verify AI setup for a Hoist project. Detects project type, generates CLAUDE.md, configures the Hoist reference tools (the Hoist Docs MCP server from @xh/hoist v91, or the tools bundled with earlier versions), and verifies them in the current environment.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, mcp__hoist-docs__*, mcp__hoist-react__*, mcp__hoist-core__*
---

# Hoist Project Onboarding

Configure this Hoist project for AI-augmented development. Follow each phase in order.

## Hoist Project Structure

All Hoist applications share the same layout: a Grails/Groovy backend at the project root and
a React/TypeScript frontend in `client-app/`. Key locations:

- `client-app/package.json` -- frontend dependencies, including `@xh/hoist`
- `client-app/yarn.lock`, `client-app/package-lock.json`, or `client-app/pnpm-lock.yaml` --
  package manager lockfile
- `client-app/src/` -- frontend application source
- `build.gradle` -- Gradle build config with `hoist-core` dependency (direct or via client plugin)
- `gradle.properties` -- app metadata (`xhAppCode`, and typically `hoistCoreVersion` -- though
  this may be absent if `hoist-core` is provided transitively by a client-specific Grails plugin)
- `grails-app/` -- Grails controllers, services, domain classes

## Phase 1: Detect Project

1. **Detect package manager.** Check which lockfile exists in `client-app/`:
   - `yarn.lock` -- use `yarn` (e.g. `yarn install`, `yarn why`)
   - `package-lock.json` -- use `npm` (e.g. `npm install`, `npm ls`)
   - `pnpm-lock.yaml` -- use `pnpm` (e.g. `pnpm install`, `pnpm why`)
   Store the detected package manager for use throughout this skill.
2. Determine the installed `@xh/hoist` version. Read `client-app/package.json` and check
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
5. Read `gradle.properties` and extract `hoistCoreVersion`. If a `gradle.lockfile` sits at the
   project root, the app uses Gradle dependency locking. Record that for Phase 4, and read the
   locked version with `grep '^io.xh:hoist-core:' gradle.lockfile`. It is the version the app
   builds with. If `hoistCoreVersion` is not present (i.e. it is inherited from a client-specific
   Grails plugin) and there is no lockfile, determine the resolved version using Gradle's
   dependency graph:
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

   **SNAPSHOT handling.** If the app is in canary mode (step 2) or the installed version
   contains `-SNAPSHOT` (e.g. `85.0.0-SNAPSHOT.1777529713059`), the developer is intentionally
   on a pre-release that is typically *ahead* of the published `latest` tag. Do not flag this as
   "behind latest". Semver comparison against `dist-tags.latest` will lie. Treat SNAPSHOT
   installs as up-to-date for upgrade-prompt purposes; surface "on a pre-release SNAPSHOT" in
   Phase 2's detection summary instead of an upgrade nudge.
<!-- legacy-api:start -->
8. **Detect the decorator style.** It picks the Models and Decorators section of the generated
   CLAUDE.md (Phase 4). Read `client-app/tsconfig.json`, and any config it `extends`:
   - `experimentalDecorators: true`: **legacy** decorators.
   - Otherwise: **TC39** decorators, with `accessor` fields.
   If no tsconfig can be read, use the installed `@xh/hoist` major from step 2: v88 or later is
   TC39, earlier is legacy.
<!-- legacy-api:end -->
9. **Detect the reference tooling.** It picks the setup in Phase 3 and the tooling section of
   the generated CLAUDE.md:
   - **Hoist Docs** if `client-app/node_modules/@xh/hoist/package.json` has a `hoistDocs` key,
     which `@xh/hoist` v91 and later carry. If dependencies are not installed, use the version
     from step 2: v91 or later is Hoist Docs. One MCP server, `hoist-docs`, from the
     `@xh/hoist-docs` dev dependency, serves hoist-react, hoist-core (from v45) and Hoist Chat
     Kit. hoist-react ships no MCP server or CLI from v91.
   - **Bundled** otherwise: `@xh/hoist`'s own MCP server (v82 and later) and CLI, and hoist-core's
     fat JAR tools (v39 to v44).

   Also record what the project already has: a `hoist-docs`, `hoist-react` or `hoist-core` entry
   in `.mcp.json`, `@xh/hoist-docs` in `client-app/package.json`, the `bin/hoist-docs` and
   `bin/hoist-ts` launchers, `bin/hoist-core-mcp`, and `installHoistCoreTools` in `build.gradle`.
   In Hoist Docs mode, the `hoist-react` entry and the `bin/hoist-docs` and `bin/hoist-ts`
   launchers are broken leftovers. With hoist-core v45 or later, so are the hoist-core tools.

## Phase 2: Present Findings

Display a summary of what was detected:

```
## Project Detection Results

- **@xh/hoist (hoist-react):** v[version] [(direct | via [plugin name])] [(canary: tracks `next`)] ([up to date | upgrade available: v[latest]])
- **Decorators:** [TC39 | legacy]
- **Reference tools:** [Hoist Docs (@xh/hoist v91+) | bundled with @xh/hoist and hoist-core]
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
{Hoist Docs mode:}
- [Add | Verify] `@xh/hoist-docs` as a `client-app` dev dependency
- [Configure | Verify] the `hoist-docs` server in `.mcp.json` [, replacing the `hoist-react` entry]
- [Remove the old `bin/hoist-docs` / `bin/hoist-ts` launchers (if present)]
- [List the server-side client plugins in `hoistDocsLibraries` in `gradle.properties`]
- [hoist-core v45+: remove the old hoist-core tools (if present; asks first, edits `build.gradle`)]
- [hoist-core v39 to v44: Hoist Docs serves hoist-react only; ask whether to install the hoist-core
  tools (modifies `build.gradle`)]
{Bundled mode:}
- [Configure | Verify] `.mcp.json` with hoist-react MCP server (if @xh/hoist v82+)
- Detect whether hoist-core MCP+CLI tools are installed; if `hoistCoreVersion >= 39.0` and
  they're not yet wired up, ask separately whether to install them (modifies `build.gradle`)
{Both:}
- [Add | Verify] the `xh@hoist-ai` plugin declaration in `.claude/settings.json`, with auto-update on
- [Add | Verify] `Skill(xh:...)` permissions for the plugin's skills in `.claude/settings.json`
- Check that this machine installs the plugin at user scope
- [Create | Update] CLAUDE.md with Hoist conventions (~[N] lines)
- [Include client plugin documentation (if plugins detected)]
- Verify the reference tools in this environment
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
Newer versions include improved MCP server capabilities and AI tooling support. From v91, one
MCP server, Hoist Docs, serves hoist-react and hoist-core together.

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

## Phase 3: Configure the Reference Tools

The MCP server must be configured at the project level (not via the plugin) because it runs from
the project's own `node_modules`. A `.mcp.json` entry is harmless in environments where MCP is
blocked: Claude Code simply won't connect to it, and the entry becomes functional automatically
if the environment later permits MCP.

Follow 3A in Hoist Docs mode, 3B in bundled mode (Phase 1, step 9).

### 3A: Hoist Docs (@xh/hoist v91 and later)

1. **Add the dependency.** If `client-app/package.json` does not list `@xh/hoist-docs` in
   `devDependencies`, add it with the detected package manager, from `client-app/`:
   - pnpm: `pnpm add -D @xh/hoist-docs`
   - yarn: `yarn add -D @xh/hoist-docs`
   - npm: `npm install -D @xh/hoist-docs`

   Use the release even when the app tracks Hoist SNAPSHOTs (canary mode, Phase 1): each Hoist
   build ships its own docs index, and `@xh/hoist-docs`'s `next` dist-tag is its own unreleased
   next major version. If the install fails because a registry proxy does not carry
   `@xh/hoist-docs`, stop and tell the developer: their organization's npm proxy needs to allow
   it.
2. **Write the `.mcp.json` entry.** Create `.mcp.json` at the project root if it does not exist.
   Add or update the `hoist-docs` entry under `mcpServers`, and keep every other entry:

```json
{
  "mcpServers": {
    "hoist-docs": {
      "type": "stdio",
      "command": "node",
      "args": [
        "client-app/node_modules/@xh/hoist-docs/bin/hoist-docs.mjs"
      ]
    }
  }
}
```

   Point at the package's own launcher, as above, not at `node_modules/.bin/hoist-docs`.
3. **Remove the `hoist-react` entry** if `.mcp.json` has one. It runs
   `@xh/hoist/bin/hoist-mcp.mjs`, which v91 no longer ships.
4. **Remove the old hoist-react launchers.** If `bin/hoist-docs` or `bin/hoist-ts` exist, and
   their second line is `# hoist-ai-launcher: hoist-react/...`, delete them. From v91 the
   `bin/hoist-docs` launcher would start the Hoist Docs server instead of answering a query. If
   either file lacks that stamp, leave it and name it in the Phase 6 report. If `.gitignore`
   lists `bin/hoist-docs` or `bin/hoist-ts`, remove those lines.
5. **Update settings that name the old server.** In `.claude/settings.json` and
   `.claude/settings.local.json`, if present:
   - In `enabledMcpjsonServers`, replace `hoist-react` with `hoist-docs`.
   - In `permissions.allow`, replace `mcp__hoist-react__*` with `mcp__hoist-docs__*`, and remove
     `Bash(npx hoist-docs:*)`, `Bash(npx hoist-ts:*)`, `Bash(./bin/hoist-docs:*)` and
     `Bash(./bin/hoist-ts:*)`.

   Do not add permissions the files did not grant before.
6. **Maven access for hoist-core's docs.** Hoist Docs fetches hoist-core's docs index from Maven
   Central (releases) or Sonatype's snapshot repository (snapshots), once per version. If the
   app's `build.gradle` resolves Hoist from an organization's mirror instead, ask the developer
   for the mirror's URL and add it to the entry's `env`: `HOIST_DOCS_MAVEN_REPO`, and
   `HOIST_DOCS_MAVEN_SNAPSHOT_REPO` for snapshots. Credentials go in `HOIST_DOCS_MAVEN_USER`
   and `HOIST_DOCS_MAVEN_PASSWORD`, set in the developer's environment rather than the
   committed file. Behind an HTTP proxy, add `NODE_USE_ENV_PROXY=1`.
7. **List the server-side client plugins.** Hoist Docs serves the docs index of each Grails
   library listed in `hoistDocsLibraries` in `gradle.properties`, at the version `gradle.lockfile`
   locks. Add the `group:artifact` of each server-side client plugin from Phase 1, step 3, with no
   version, comma-separated, and keep any entries already there:
   ```properties
   hoistDocsLibraries=com.clientname:clientname-hoist
   ```
   Do not list `io.xh:hoist-core`. Hoist Docs finds it without the entry. Phase 5 removes any
   plugin that publishes no docs index.

   Hoist Docs reads these versions, and hoist-core's version when a plugin brings it in, from
   `gradle.lockfile`. If the project has no `gradle.lockfile` (Phase 1, step 5), do not change
   the build. Name it in the Phase 6 report: enable dependency locking in `build.gradle`
   (`dependencyLocking { lockAllConfigurations() }`), run
   `./gradlew dependencies --write-locks -PrunHoistInline=false`, and commit the lockfile.

Phase 5 checks the server without a restart. Claude Code connects to it after the next restart.

### 3B: Bundled hoist-react MCP server (@xh/hoist v82 to v90)

If the installed `@xh/hoist` version is v82.0 or later, configure the project's `.mcp.json` so
the hoist-react MCP server launches automatically. In MCP-blocked environments, the parallel CLI
surface (`./bin/hoist-docs`, `./bin/hoist-ts`) is the working path and is documented in the
generated CLAUDE.md.

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

## Phase 3.2: Declare the Plugin

The committed `.claude/settings.json` declares the plugin for the whole team. The declaration
turns the plugin on and keeps it current, but it does not install it. Each developer installs it
once per machine, at user scope, which covers every project and worktree. A project-scope or
local-scope install is a separate copy for one path. Claude Code updates it only when a session
runs in that path, so it drifts to an old version.

The declaration has two parts:

- `extraKnownMarketplaces` registers the `hoist-ai` marketplace. `autoUpdate: true` keeps the
  plugin current, because Claude Code does not update a third-party marketplace by default.
- `enabledPlugins` turns the plugin on for the project.

```json
{
  "extraKnownMarketplaces": {
    "hoist-ai": {
      "source": { "source": "github", "repo": "xh/hoist-ai" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "xh@hoist-ai": true
  }
}
```

1. If `.claude/settings.json` does not exist, create it with the content above.
2. If it exists, merge into it. Keep every other key and entry.
3. If the file already sets `xh@hoist-ai` in `enabledPlugins`, to `true` or `false`, leave the
   value alone. `false` is a team's opt-out.
4. If a `hoist-ai` marketplace entry already exists with this source and lacks `autoUpdate` or
   sets it to `false`, set it to `true`.
5. If a `hoist-ai` entry exists with a different source, such as a branch or a local folder,
   leave it alone and name it in the Phase 6 report.
6. Never write this declaration to `.claude/settings.local.json`. That file is per developer, and
   the point of this phase is a declaration the whole team gets.
7. Add `Skill(xh:<name>)` to `permissions.allow` for each skill the plugin ships, so they run
   without a prompt. The skills are the folders beside this skill's own folder that hold a
   `SKILL.md`. Read the names from those folders, not from a fixed list, so the next run adds a
   new skill. Add the missing entries and keep every other entry.

Tell the developer to commit `.claude/settings.json`.

### Check This Machine's Install

Run `claude plugin list --json` and keep the records with `id` `xh@hoist-ai`. If `claude` is not
on the `PATH`, skip this check and put the install command in the Phase 6 report.

- **No record with `scope` `user`:** tell the developer the plugin has no user-scope install,
  give them `claude plugin install xh@hoist-ai --scope user`, and offer to run it for them. It
  takes effect in the next session. If they decline, put the command in the Phase 6 report.
- **Records with `scope` `project`:** expected. Claude Code adds one by itself when a session
  starts in a repo whose committed settings enable the plugin. Do not report them or remove them.
- **Records with `scope` `local` and a `projectPath` in this repo or its worktrees:** they come
  from an `xh@hoist-ai` entry in that folder's `.claude/settings.local.json`. Do not remove them
  now, because this session may be running from one. List them in the Phase 6 report, with the
  command to run from each `projectPath`: `claude plugin uninstall xh@hoist-ai --scope local`. It
  also removes the entry.

## Phase 3.5: hoist-core Tools

Which hoist-core tools apply depends on `hoistCoreVersion`:

- **v45 or later, in Hoist Docs mode:** Hoist Docs serves hoist-core. Nothing to install. If the
  project still has the bundled hoist-core tools (a `hoist-core` entry in `.mcp.json`,
  `bin/hoist-core-mcp`, or `installHoistCoreTools` in `build.gradle`), ask whether to remove
  them, and follow **Removing the bundled tools** in the `using-hoist-core-reference` skill
  (`**/skills/using-hoist-core-reference/SKILL.md`). It edits `build.gradle`, so ask first, as
  in Step 2 below.
- **v45 or later, in bundled mode** (`@xh/hoist` before v91): an unsupported pairing. hoist-core
  v45 requires `@xh/hoist` v91: it publishes no bundled tools, and its docs come only from Hoist
  Docs. Skip, and note in Phase 6: "hoist-core v45 requires @xh/hoist v91 -- run
  `/xh:hoist-upgrade`."
- **v39 to v44:** the optional install below. In Hoist Docs mode, Hoist Docs serves hoist-react
  only, and these tools serve hoist-core beside it.
- **Before v39:** skip, as in Step 1 below.

### Install the bundled hoist-core tools (optional, hoist-core v39 to v44)

The hoist-core developer tools ship as a fat JAR (`io.xh:hoist-core-mcp:<version>:all`) that
project Gradle builds resolve through normal Maven resolution. Running the install task writes
project-local launchers under `bin/` -- these expose both the MCP server (`bin/hoist-core-mcp`,
referenced from `.mcp.json`) and the CLI tools (`bin/hoist-core-docs`, `bin/hoist-core-symbols`).
The CLI surface is the primary path in MCP-blocked environments and works once installed
without depending on Claude Code restarts or MCP availability.

#### Step 1: Detect current state

1. Check whether `bin/hoist-core-mcp` exists at the project root and is executable.
2. Check whether `.mcp.json` already has a `hoist-core` entry under `mcpServers`.
3. If both are present, this phase is already done -- skip.
4. If `hoistCoreVersion >= 45.0`, skip: see above.
5. If `hoistCoreVersion < 39.0` (the first release containing the `installHoistCoreTools`
   task), skip with a note in Phase 6: "hoist-core MCP+CLI install requires hoistCoreVersion
   >= 39.0 -- run `/xh:hoist-upgrade` first, then re-run `/xh:onboard-app` to install."

#### Step 2: Ask permission

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

#### Step 3: Run the install procedure

If the user agreed, follow the install procedure documented in the
`using-hoist-core-reference` skill (the source of truth for this flow). Read it via:

```
**/skills/using-hoist-core-reference/SKILL.md
```

Jump to the **"Installing the MCP server and CLI tools"** section, under **"Bundled tools"**, and follow its steps end to
end (Gradle snippet, `installHoistCoreTools`, `.mcp.json` wiring including `--source bundled`
on the mcp launcher). Do not duplicate the snippet here -- the reference skill is the canonical
copy and is what will be re-read on future re-runs.

#### Step 4: Verify (CLI-first, MCP-opportunistic)

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
   detected in Phase 1 (yarn for `yarn.lock`, npm for `package-lock.json`, pnpm for
   `pnpm-lock.yaml`):
   - `{{PKG_MGR_INSTALL}}` → `yarn install`, `npm install`, or `pnpm install`
   - `{{PKG_MGR_START}}` → `yarn start`, `npm start`, or `pnpm start`
   - `{{PKG_MGR_LINT}}` → `yarn lint`, `npm run lint`, or `pnpm lint`

   The generated CLAUDE.md should show only the commands that match the project's actual
   package manager -- not both with a "(or X)" parenthetical that implies a preference.

   **Do** replace `{{GRADLE_LOCKS}}` if the app uses Gradle dependency locking (Phase 1, step 5).
   Otherwise delete the line. Drop `-PrunHoistInline=false` if the build does not read
   `runHoistInline`:
   ```
   - After a server dependency or version change: `./gradlew dependencies --write-locks -PrunHoistInline=false`. Commit `gradle.lockfile` and `buildscript-gradle.lockfile` with the change. Never edit a lockfile by hand.
   ```

   **Do** replace `{{MODEL_PRIMER}}` with the full content of the models template for the
   decorator style detected in Phase 1, from the same templates directory:
   - TC39: `claude-md-models-tc39.md`
   - legacy: `claude-md-models-legacy.md`

   **Do** replace `{{REFERENCE_TOOLS}}` with the content of the tooling template for the mode
   detected in Phase 1, step 9:
   - Hoist Docs: `claude-md-tools-hoist-docs.md`. If `hoistCoreVersion` is below v45, append
     `claude-md-tools-core-bundled.md` after it, as a separate paragraph.
   - bundled: `claude-md-tools-bundled.md`
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
   - **Exception: stale tooling text.** In Hoist Docs mode, text that sends agents to the old
     tools is wrong for this app: `./bin/hoist-docs`, `./bin/hoist-ts`, `npx hoist-docs`,
     `npx hoist-ts`, or `mcp__hoist-react__`. With hoist-core v45 or later, so are
     `./bin/hoist-core-docs`, `./bin/hoist-core-symbols`, `mcp__hoist-core__` and
     `installHoistCoreTools`. Offer to replace the "Hoist Reference Skills" section with the
     generated one, and to fix each other sentence that names them. Keep project-specific text.
   - Show the user what will be added or replaced before writing.
   - Preserve all existing project-specific content.
4. If no `CLAUDE.md` exists: write the complete generated template to `./CLAUDE.md`.

## Phase 5: Verify Surfaces (CLI-first, MCP-opportunistic)

Verification's job is to confirm the working surfaces are reachable in the *current*
environment. Treat MCP as opportunistic (it requires Claude Code restart and may be blocked by
the environment). Check each surface in a way that works without a restart.

### Hoist Docs (Hoist Docs mode)

1. **Start the server once, without MCP.** `Glob` for `**/onboard-app/templates/hoist-docs-ping.sh`
   and run it with `bash` from the project root. It starts the project's Hoist Docs server over
   stdio, asks for `hoist-ping`, and prints the answer: the Hoist versions served, and any
   library not loaded, with the reason. It needs no restart and works where MCP is blocked.
   - **hoist-react listed:** Hoist Docs works.
   - **`core` under "Not loaded"** with "has no docs-index artifact": expected for hoist-core
     before v45. Otherwise the reason names the Maven problem. Behind a mirror or proxy, add the
     settings from Phase 3A, step 6, and run the script again.
   - **A `hoistDocsLibraries` plugin under "Not loaded"** with "has no docs-index artifact": the
     plugin publishes no docs index. Remove it from `hoistDocsLibraries` and name it in the
     report. For another reason, keep the entry and surface the reason.
   - **A `hoistDocsLibraries` plugin neither listed nor under "Not loaded"**: the installed
     `@xh/hoist-docs` does not read `hoistDocsLibraries` yet. Keep the entry. It takes effect when
     the app updates `@xh/hoist-docs`.
   - **"Hoist Docs is not installed"**: the `client-app` install did not run. Surface it.
   - **"Hoist Docs did not start"**: surface the error.
2. **Opportunistic MCP ping.** Call `mcp__hoist-docs__hoist-ping` if the tool is in your context.
   Success → "MCP active". Tool not present → "MCP entry written, will activate on next Claude
   Code restart (or remain dormant in MCP-blocked environments)". Not an error.

### hoist-react (bundled mode)

If `@xh/hoist < v82.0`, skip hoist-react verification -- MCP is unavailable in those versions.
Note this in the Phase 6 report.

Otherwise:

1. **Opportunistic MCP ping.** Call `mcp__hoist-react__hoist-ping` if the tool is in your
   context. Success → "MCP active". Tool not present or fails → "MCP entry written, will
   activate on next Claude Code restart (or remain dormant in MCP-blocked environments)" --
   this is not an error.
2. **CLI launcher presence (informational).** Check whether `./bin/hoist-docs` and
   `./bin/hoist-ts` exist at the project root.
   - If both present, optionally run `./bin/hoist-docs index` to confirm output. If
     `client-app/node_modules` isn't installed yet, surface the package-manager install step.
   - If absent, do **not** install them here. Note in the Phase 6 report: "hoist-react CLI
     launchers not yet installed -- the `using-hoist-react-reference` skill installs them
     automatically the first time an agent reaches for the CLI surface in this project."
   This deferred-install model keeps onboarding focused on once-only setup
   (`.mcp.json`, `CLAUDE.md`) and lets the reference skill own the launcher lifecycle,
   including refresh when the stamp version bumps.

### Bundled hoist-core tools (only if Phase 3.5 installed them)

1. **CLI sanity (always run).** From the project root, run `./bin/hoist-core-docs ping`. Expect
   `hoist-core CLI is running.` If this fails, the install didn't take -- surface the error.
2. **Opportunistic MCP ping.** Call `mcp__hoist-core__hoist-core-ping` if the tool is in your
   context. Same semantics as hoist-react: success → "MCP active"; not present → "entry
   written, activates on Claude Code restart in environments that permit MCP". Not an error.

### Why CLI-first matters for enterprise environments

In environments that block MCP traffic, onboarding must not stall or surface scary
"verification failed" errors when MCP isn't reachable -- the `.mcp.json` entries are
forward-compatible (harmless if MCP is blocked, functional if and when the environment unblocks
it). With the bundled tools, the CLI is fully usable today. Hoist Docs has no CLI: where MCP is
blocked, agents read the docs that ship in `client-app/node_modules/@xh/hoist/docs/`. Phase 6
must clearly distinguish "working now" from "queued for activation".

## Phase 6: Report

Display a final summary that distinguishes "working now" from "queued for activation" and
calls out the CLI fallback for MCP-blocked environments:

```
## Onboarding Complete

### Configuration
- **CLAUDE.md:** [Created | Updated (added N sections) | Already up to date]
- **`.mcp.json`:** [Created | Updated (added entries: <list>) | Already configured]
- **Plugin declaration:** [Added to `.claude/settings.json` -- commit it | Turned on auto-update | Already present | Left alone: `hoist-ai` points at <source>]
- **Skill permissions:** [Added `Skill(xh:...)` for <names> | Already present]
- **Plugin install:** [User scope, version <v> | Installed at user scope -- restart to load it | Not installed at user scope -- run `claude plugin install xh@hoist-ai --scope user`]
- **Local installs:** [None | <projectPath>, version <v> -- remove with `claude plugin uninstall xh@hoist-ai --scope local` from that folder]
- **Client plugins:** [N plugin(s) documented | None detected]

{Hoist Docs mode:}
### Hoist Docs
- **Dependency:** [Added `@xh/hoist-docs` to `client-app` devDependencies | Already present]
- **MCP entry:** [Written | Already present] [; replaced the `hoist-react` entry]
- **Server check:** [Serves <libraries and versions from the ping script> | Failed: <reason>]
- **Not loaded:** [None | <library and reason, e.g. hoist-core 44.1.0 ships no docs index>]
- **Client plugin docs:** [Listed in `hoistDocsLibraries`: <plugins> | Removed <plugins>: no docs index | No server-side client plugins]
- **gradle.lockfile:** [Present | Missing: enable dependency locking, run `./gradlew dependencies --write-locks -PrunHoistInline=false`, and commit the lockfile]
- **MCP runtime:** [Active (verified via ping) | Will activate on Claude Code restart, or remain dormant if the environment blocks MCP]
- **Removed:** [<old launchers, entries and settings removed> | Nothing to remove]
- **hoist-core:** [Served by Hoist Docs | Bundled hoist-core tools: installed / already installed / user deferred (hoist-core before v45)]

{Bundled mode:}
### hoist-react
- **MCP entry:** [Written | Already present | Skipped (requires @xh/hoist v82+ -- run /xh:hoist-upgrade first)]
- **MCP runtime:** [Active (verified via ping) | Will activate on Claude Code restart, or remain dormant if the environment blocks MCP]
- **CLI launchers:** [Installed at `./bin/hoist-docs`, `./bin/hoist-ts` | Not yet installed -- `using-hoist-react-reference` skill installs on first CLI use]
- **CLI surface:** `./bin/hoist-docs` and `./bin/hoist-ts` -- works in any environment, including MCP-blocked ones.

### hoist-core
- **MCP+CLI tools:** [Installed via installHoistCoreTools, CLI verified working | User deferred (run again later or ask Claude to install/set up the hoist-core MCP+CLI tools) | Skipped (requires hoistCoreVersion >= 39.0 -- upgrade hoist-core first) | Skipped (hoist-core v45 requires @xh/hoist v91 -- run /xh:hoist-upgrade) | Already installed]
- **CLI surface:** `./bin/hoist-core-docs` and `./bin/hoist-core-symbols` -- works in any environment.
- **MCP runtime:** [Active (verified via ping) | Will activate on Claude Code restart, or remain dormant if the environment blocks MCP | N/A (not installed)]

### Reference skills
The `using-hoist-react-reference` and `using-hoist-core-reference` skills (shipped by the `xh`
plugin) fire automatically when authoring Hoist code, asking for orientation, or asking to
install, upgrade or remove the hoist-core tools. No manual invocation needed.

### MCP-blocked environments
{Hoist Docs mode:} Hoist Docs has no CLI. If your environment blocks MCP traffic, agents read the
docs that ship in `client-app/node_modules/@xh/hoist/docs/`. The `.mcp.json` entry is harmless in
this state and becomes functional automatically if MCP later becomes available.
{Bundled mode:} If your environment blocks MCP traffic, the CLI surfaces above are the working
path. Use `./bin/hoist-docs`/`./bin/hoist-ts` (hoist-react) and
`./bin/hoist-core-docs`/`./bin/hoist-core-symbols` (hoist-core) directly. Both pairs are
project-root launchers usable from any working directory. The `.mcp.json` entries are harmless in
this state and become functional automatically if MCP later becomes available -- no rerun
required.

### Next steps
{If @xh/hoist-docs was added:} Commit `client-app/package.json`, the lockfile and `.mcp.json`.
Restart Claude Code to pick up new `.mcp.json` entries (skip if MCP is blocked in your
environment). Then start coding -- the reference skills
will route you to framework docs and API lookups.
```
