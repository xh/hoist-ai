# Phase 3.5: Install hoist-core MCP Server and CLI Tools (optional)

The hoist-core developer tools ship as a fat JAR (`io.xh:hoist-core-mcp:<version>:all`) that
the project's Gradle build resolves through normal Maven resolution. The install task writes
project-local launchers under `bin/`. They expose both the MCP server (`bin/hoist-core-mcp`,
referenced from the MCP config) and the CLI tools (`bin/hoist-core-docs`,
`bin/hoist-core-symbols`). The CLI surface is the primary path in MCP-blocked environments. It
works as soon as it is installed, with no new session and no MCP.

## Step 1: Detect current state

1. Check whether `bin/hoist-core-mcp` exists at the project root and is executable, with
   `test -x`.
2. Check whether the MCP config file of each confirmed harness that has one (Phase 3) has a
   `hoist-core` entry under `mcpServers`.
3. If the launcher and every entry are present, this phase is already done. Skip it.
4. If `hoistCoreVersion < 39.0` (the first release containing the `installHoistCoreTools`
   task), skip with a note in Phase 6: "hoist-core MCP+CLI install requires hoistCoreVersion
   >= 39.0. Run the `hoist-upgrade` skill first, then run `onboard-app` again to install."

## Step 2: Ask permission

Show the user a focused confirmation BEFORE making any Gradle-level changes:

```
### Install hoist-core MCP server and CLI tools?

This will:
- Add ~15 lines to `build.gradle`: a `hoistCoreCli` configuration and the
  `installHoistCoreTools` Sync task.
- Run `./gradlew installHoistCoreTools` to resolve the version-locked fat JAR
  (`io.xh:hoist-core-mcp:<hoistCoreVersion>:all`) and write launchers under `bin/`.
- Add a `hoist-core` entry that points at `bin/hoist-core-mcp` to [`.mcp.json` | `.cursor/mcp.json`].
- [If `build.gradle` already has the task without them: add the `hoist-ai-snippet` marker comments around it.]

The CLI surface (`./bin/hoist-core-docs`, `./bin/hoist-core-symbols`) works in any environment,
including MCP-blocked ones. The MCP entry is harmless if MCP is blocked, and it starts to work
if MCP later becomes available.

Proceed? (yes/no)
```

Make no change to `build.gradle` before the user says yes, and that includes the marker
comments. If the user says no, record the decision and show a deferred-step note in the Phase 6
report.
The user can install later: an ask to install or set up the hoist-core MCP+CLI in this app loads
the `using-hoist-core-reference` skill, which walks through it.

## Step 3: Run the install procedure

If the user agreed, follow the install procedure in the `using-hoist-core-reference` skill, the
source of truth for this flow. Read `reference/install.md` in that skill's folder, which is
`../using-hoist-core-reference/` from the onboard-app skill folder. If you cannot find it there,
search for `**/skills/using-hoist-core-reference/reference/install.md`.

Follow its steps from start to end: the Gradle snippet, `installHoistCoreTools`, and the MCP
config. Do not duplicate the snippet here. The reference skill holds the canonical copy, and later
runs read it again.

## Step 4: Verify (CLI-first, MCP-opportunistic)

After install, verify with the CLI. This works in any environment, with no new session:

```bash
./bin/hoist-core-docs ping
```

Expect: `hoist-core CLI is running.` If this fails, show the error to the user before
continuing.

Do **not** depend on the MCP `hoist-core-ping` tool here. The MCP config is fresh and the
session has not restarted, and the environment may block MCP. The CLI ping is the universal
sanity check.
