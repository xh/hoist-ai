# Installing the hoist-core MCP server and CLI tools

Both surfaces ship from the same fat JAR (`io.xh:hoist-core-mcp:<version>:all`). One Gradle task installs project-local launchers for both.

## Prerequisites

- App is a Hoist project: `build.gradle` exists at the project root, `hoist-core` is a dependency (direct or transitively via a client plugin). The install snippet resolves the active hoist-core version from the runtime classpath, so it works regardless of how the dependency is declared.
- `hoistCoreVersion` resolves to a release that includes the install task and bundled-content fat JAR. **Floor: v39.0** (first release containing the bundled JAR + CLI subsystem). For pre-release work against `develop`, use `39.0-SNAPSHOT` from a Sonatype snapshot repo or `mavenLocal()` (after `./gradlew :mcp:publishToMavenLocal` in a hoist-core checkout).
- Java 17+ on PATH (already required by Hoist).

If `hoistCoreVersion` is below the floor, stop and recommend the `hoist-upgrade` skill first. Do not attempt to back-port the install task to older versions.

## Procedure

1. **Read the canonical install snippet.** Either:
   - MCP: `hoist-core-read-doc` with `id: "mcp/README.md"` and look for the **App-Side Distribution** section, OR
   - CLI: `./bin/hoist-core-docs read mcp/README.md` (only if the launchers are already present from a prior install — typical when upgrading), OR
   - Read `mcp/README.md` directly from a sibling hoist-core checkout if available.

   The README is the source of truth. The snippet below is a current-as-of-v39.0 mirror; if it diverges from what the README shows, trust the README.

2. **Add the install snippet to the app's `build.gradle`.** Insert at the top level (outside any subproject block):

    ```groovy
    // hoist-ai-snippet: hoist-core-install/v1 -- DO NOT REMOVE (drift marker, see hoist-core/mcp/README.md)
    configurations {
        hoistCoreCli
    }

    dependencies {
        // Resolve the active hoist-core version lazily from the runtime classpath. Works whether
        // hoist-core is declared directly, via gradle.properties, or pulled in transitively via a
        // client plugin -- the install task stays aligned with whatever hoist-core version actually
        // resolves at build time.
        hoistCoreCli providers.provider {
            def hc = configurations.runtimeClasspath.incoming.resolutionResult.allComponents
                .find { it.moduleVersion?.group == 'io.xh' && it.moduleVersion?.name == 'hoist-core' }
            if (!hc) throw new GradleException(
                'hoist-core not found on the runtimeClasspath -- cannot install hoist-core tools.')
            "io.xh:hoist-core-mcp:${hc.moduleVersion.version}:all@jar"
        }
    }

    tasks.register('installHoistCoreTools', Sync) {
        description = 'Install version-locked launchers for the hoist-core MCP server and CLI tools.'
        group = 'hoist'
        from configurations.hoistCoreCli
        into layout.buildDirectory.dir('hoist-core-tools/lib')
        doLast {
            def jar = fileTree(layout.buildDirectory.dir('hoist-core-tools/lib')).singleFile
            def binDir = file('bin')
            binDir.mkdirs()
            def launcherNames = []
            ['mcp', 'docs', 'symbols'].each { topic ->
                // mcp mode: pass --source bundled so the server reads JAR-embedded content. Without
                //           this, HoistCoreMcpServer defaults to local mode and fails when the app
                //           has no hoist-core checkout sibling.
                // docs/symbols: dispatched via `cli`, which routes to picocli (defaults to bundled).
                def args = topic == 'mcp' ? '--source bundled' : "cli ${topic}"
                // The bash launcher resolves `java` from PATH, falling back to JAVA_HOME, so it
                // works under MCP clients launched from non-interactive shells where a JDK version
                // manager (mise, asdf, jenv) may not have activated.
                new File(binDir, "hoist-core-${topic}").with {
                    text = """\
#!/usr/bin/env bash
if command -v java >/dev/null 2>&1; then
    JAVA=java
elif [ -n "\$JAVA_HOME" ] && [ -x "\$JAVA_HOME/bin/java" ]; then
    JAVA="\$JAVA_HOME/bin/java"
else
    cat >&2 <<'EOF'
[hoist-core] ERROR: 'java' not on PATH and JAVA_HOME is unset or invalid.

If you use a JDK version manager (mise, asdf, jenv), it likely activates only in
interactive shells - but this script runs in the non-interactive shell launched by
your MCP client. Either export JAVA_HOME from a non-interactive init file (e.g.
~/.bash_profile, ~/.zshenv) so it is visible here, or activate the version manager
from one of those files. Pointing JAVA_HOME at any JDK 17+ install is sufficient.
EOF
    exit 1
fi
exec "\$JAVA" -jar "${jar.absolutePath}" ${args} "\$@"
"""
                    setExecutable(true)
                }
                new File(binDir, "hoist-core-${topic}.bat").text =
                    "@echo off\r\njava -jar \"${jar.absolutePath}\" ${args} %*\r\n"
                launcherNames << "hoist-core-${topic}"
                launcherNames << "hoist-core-${topic}.bat"
            }
            // Generated launchers embed an absolute path to the resolved JAR, so they are
            // machine-specific and must not be committed. Write a scoped bin/.gitignore that
            // excludes only the generated launchers, leaving the rest of bin/ untouched.
            new File(binDir, '.gitignore').text = launcherNames.sort().join('\n') + '\n'
        }
    }
    // end hoist-ai-snippet
    ```

3. **Run the install task.**

    ```bash
    ./gradlew installHoistCoreTools
    ```

   Expect the task to download (or resolve from cache) the fat JAR into `build/hoist-core-tools/lib/` and write six launchers under `bin/`: three POSIX (`hoist-core-mcp`, `hoist-core-docs`, `hoist-core-symbols`) and three Windows `.bat` mirrors.

4. **Sanity-check the CLI immediately.** This is fast (no new agent session needed) and catches snapshot-resolution / Java-version issues:

    ```bash
    ./bin/hoist-core-docs ping
    ./bin/hoist-core-symbols members BaseService
    ```

   The first symbols invocation pays a ~2-3s AST cold-start. If `ping` doesn't return cleanly, surface the error to the user before proceeding.

5. **Wire up the MCP config.** The MCP server launches through the local launcher (`bin/hoist-core-mcp`), not through a `bootstrap.sh` or any version-suffixed JAR path. Add the entry to the project MCP config of each harness the team uses. Edit the file, or create it:

   | Harness | File | `command` |
   |---|---|---|
   | Claude Code | `.mcp.json` | `./bin/hoist-core-mcp` |
   | Cursor | `.cursor/mcp.json` | `${workspaceFolder}/bin/hoist-core-mcp` |

    ```json
    {
      "mcpServers": {
        "hoist-core": {
          "command": "./bin/hoist-core-mcp"
        }
      }
    }
    ```

   If the file already exists, preserve other entries (e.g. `hoist-react`) and only update or add the `hoist-core` entry. Replace any prior `start-hoist-core-mcp.sh` or `mcp/bootstrap.sh` command with the new launcher path. Codex needs no entry: it resolves a relative `command` against the session's working directory, so it uses the CLI launchers.

6. **Commit `bin/.gitignore`.** The install task writes a scoped `bin/.gitignore` excluding only the generated launchers (each launcher embeds an absolute path to the resolved JAR and is therefore machine-specific -- a committed launcher silently breaks for every other developer). Commit `bin/.gitignore` once; subsequent regenerations stay out of source control automatically. The rest of `bin/` (if the project uses it for other things) is untouched. The `build/hoist-core-tools/` directory is normally already covered by the project's top-level `build/` ignore.

7. **Tell the user to start a new agent session** so the harness picks up the new MCP entry, and to approve the server when the harness asks. Until then, only the CLI surface is available.

## Verification after install

- CLI: `./bin/hoist-core-docs ping` returns cleanly. `./bin/hoist-core-symbols members BaseService` lists BaseService's public methods/properties.
- MCP (in a new agent session): `hoist-core-ping` returns cleanly. `hoist-core-list-docs` returns the doc registry.

If both surfaces work, the routing table in SKILL.md is now usable in either column.

## Upgrading

When `hoistCoreVersion` is bumped, re-run `./gradlew installHoistCoreTools` to refresh the launchers (they embed an absolute path to a version-suffixed JAR; stale launchers point at a deleted JAR and will fail at exec time). The snippet in `build.gradle` rarely needs to change on a `hoistCoreVersion` bump -- the Provider resolves the new version automatically. The snippet itself is versioned independently via its `hoist-ai-snippet:` marker; see [Refreshing a stale install snippet](#refreshing-a-stale-install-snippet) for that separate concern.

## Refreshing a stale install snippet

Triggered when the preflight's snippet-currency check finds a missing or outdated `// hoist-ai-snippet: hoist-core-install/v<N>` marker in `build.gradle` -- the working launchers will keep working, but the snippet has been improved since the user last pasted it (e.g. updated Gradle APIs, improved launcher script, new install-task behavior).

This is an **in-place edit of the user's source-controlled `build.gradle`**, not a regenerated file copy. Be careful:

1. **Read the current canonical** the same way as a fresh install -- step 1 of the install procedure above (`hoist-core-read-doc` with `id: "mcp/README.md"`, or `./bin/hoist-core-docs read mcp/README.md`, or a sibling hoist-core checkout). Trust the README's snippet over the mirror in this SKILL.md if they diverge -- but they shouldn't if both repos have been kept in lockstep.

2. **Locate the existing snippet boundaries** in `build.gradle`:

       grep -nE '^// (hoist-ai-snippet|end hoist-ai-snippet)' build.gradle

   If both an opening and closing marker are present, you have a clean bounded block. If only the opening is present, find the end manually -- the `}` that closes `tasks.register('installHoistCoreTools', Sync)`. If neither is present (pre-stamp install), find the install fragments by their well-known identifiers: the `configurations { hoistCoreCli }` block, the `hoistCoreCli ...` line inside `dependencies { ... }`, and the `tasks.register('installHoistCoreTools', ...)` block.

3. **Detect hand-edits.** Compare the in-place snippet against the canonical. Common harmless local modifications: tweaked `description = ...`, added logging, additional launcher topics, custom `into` location, extra `.gitignore` entries. **Preserve these in the refresh.** If you see edits you cannot explain as harmless, stop and ask the user before editing.

4. **Present the diff to the user and get explicit confirmation** before applying. Frame it as: "Your install snippet is at <old version or unstamped>; current canonical is <new version>. The diff below shows what would change. Proceed?"

5. **Apply the refresh via Edit** -- replace the bounded block byte-for-byte with the canonical (merging in any preserved hand-edits). If the snippet was unstamped, add the markers as part of the refresh.

6. **Re-run the install task** to regenerate launchers with the new logic:

       ./gradlew installHoistCoreTools

7. **Verify** as in the standard install procedure -- `./bin/hoist-core-docs ping` should still return cleanly.

If the user defers the refresh, do not re-prompt during the session. They can re-trigger by asking for the install task to be re-run or by starting a new session.
