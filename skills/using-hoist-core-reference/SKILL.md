---
name: using-hoist-core-reference
description: |
  Authoritative reference for the io.xh:hoist-core Grails/Groovy framework -- use when writing, modifying, debugging, or explaining Groovy/Java backend code that touches hoist-core, or installing, refreshing or removing the hoist-core tooling. Why this matters: hoist-core's base classes and infrastructure types have conventions that differ from plain Spring/Grails for injection, clustering, and config. Guessing produces code that compiles and runs single-node, then misbehaves under cluster failover -- invalidations that don't propagate, timers that double-fire, scheduled tasks that miss their slot. TRIGGER when the user mentions a hoist-core symbol (`BaseService`, `BaseController`, `Cache`, `Timer`, `ConfigService`, `ClusterService`, `MonitorService`, `JSONClient`); a hoist-core concept (caching, cluster-aware, distributed cache, config-driven, monitoring, scheduled task, conventions); a service/controller under `grails-app/`/`src/`; doing a backend task the framework way or using our conventions; installing, upgrading or removing the hoist-core MCP server, CLI tools, `bin/hoist-core-*` launchers, or `installHoistCoreTools`; `hoistCoreVersion`; "hoist-core"/"io.xh.hoist"/"our framework". SKIP for plain Spring without hoist-core, Grails not importing `io.xh.hoist`, Liquibase/Flyway migrations, and build-tooling-only changes. Reach for the reference tools (MCP `mcp__hoist-docs__*` with `library: "core"`, or before hoist-core v45 `mcp__hoist-core__*` or CLI `./bin/hoist-core-docs`/`./bin/hoist-core-symbols`) first.
allowed-tools: Read, Edit, Write, Bash, mcp__hoist-docs__hoist-ping, mcp__hoist-docs__hoist-search-docs, mcp__hoist-docs__hoist-list-docs, mcp__hoist-docs__hoist-read-doc, mcp__hoist-docs__hoist-search-symbols, mcp__hoist-docs__hoist-get-symbol, mcp__hoist-docs__hoist-get-members, mcp__hoist-core__hoist-core-ping, mcp__hoist-core__hoist-core-search-docs, mcp__hoist-core__hoist-core-list-docs, mcp__hoist-core__hoist-core-read-doc, mcp__hoist-core__hoist-core-search-symbols, mcp__hoist-core__hoist-core-get-symbol, mcp__hoist-core__hoist-core-get-members
---

# Using Hoist Core Reference

You're about to write or modify Groovy/Java backend code that consumes the `io.xh:hoist-core` framework, OR the user has asked you to install, upgrade or remove the hoist-core developer tools in their app. Consult the reference tools before authoring - hoist-core's API surface is large, base-class semantics are easy to misremember, and a wrong guess produces code that compiles but fails at runtime.

## Which tools serve hoist-core

It depends on `hoistCoreVersion` (in `gradle.properties`, or resolved through a client plugin):

- **v45 and later: Hoist Docs.** Each hoist-core build publishes a docs index to Maven, and the Hoist Docs MCP server (`@xh/hoist-docs`, a dev dependency of the client app) serves it. Its tools are `mcp__hoist-docs__*`, shared with hoist-react: pass `library: "core"`. hoist-core doc ids carry a `core:` prefix, for example `core:docs/caching.md`. There is no CLI, and nothing to install on the Gradle side.
- **v39 to v44: the bundled tools.** A fat JAR (`io.xh:hoist-core-mcp`) serves an MCP server, `mcp__hoist-core__hoist-core-*`, and the CLI launchers `./bin/hoist-core-docs` and `./bin/hoist-core-symbols`, installed by the `installHoistCoreTools` Gradle task. See [Bundled tools (hoist-core v39 to v44)](#bundled-tools-hoist-core-v39-to-v44).
- **Before v39:** no tools. Recommend `/xh:hoist-upgrade`.

An app can mix them. On hoist-react v91 or later with hoist-core v44, Hoist Docs serves hoist-react only (`hoist-ping` says why), and the bundled tools still serve hoist-core. The reverse is not supported: hoist-core v45 requires hoist-react v91, so an app on an earlier hoist-react has no hoist-core tools. Recommend `/xh:hoist-upgrade`.

Use whichever tools are in your tool context. If both are, prefer `mcp__hoist-docs__*` when its `hoist-ping` lists `core`.

## Routing table

| Step | Hoist Docs (v45+) | Bundled MCP (v39 to v44) | Bundled CLI (v39 to v44) |
|---|---|---|---|
| Sanity check | `mcp__hoist-docs__hoist-ping` | `mcp__hoist-core__hoist-core-ping` | `./bin/hoist-core-docs ping` |
| Search docs | `mcp__hoist-docs__hoist-search-docs` with `library: "core"` | `mcp__hoist-core__hoist-core-search-docs` | `./bin/hoist-core-docs search "<query>"` |
| List docs by category | `mcp__hoist-docs__hoist-list-docs` with `library: "core"` | `mcp__hoist-core__hoist-core-list-docs` | `./bin/hoist-core-docs list --category <category>` |
| Read a specific doc | `mcp__hoist-docs__hoist-read-doc` with `id: "core:<docId>"` | `mcp__hoist-core__hoist-core-read-doc` | `./bin/hoist-core-docs read <docId>` |
| Read coding conventions | `mcp__hoist-docs__hoist-read-doc` with `id: "core:docs/coding-conventions.md"` | `mcp__hoist-core__hoist-core-read-doc` with `id: "docs/coding-conventions.md"` | `./bin/hoist-core-docs conventions` |
| Search symbols / members | `mcp__hoist-docs__hoist-search-symbols` with `library: "core"` | `mcp__hoist-core__hoist-core-search-symbols` | `./bin/hoist-core-symbols search "<query>"` |
| Get symbol details | `mcp__hoist-docs__hoist-get-symbol` with `library: "core"` | `mcp__hoist-core__hoist-core-get-symbol` | `./bin/hoist-core-symbols symbol <name>` |
| List class members | `mcp__hoist-docs__hoist-get-members` with `library: "core"` | `mcp__hoist-core__hoist-core-get-members` | `./bin/hoist-core-symbols members <name>` |

Always pass `library: "core"` to the Hoist Docs tools for server code. Unscoped, they search hoist-react too, and some names exist in both: `Timer`, `Filter` and `Cache` among them. The client class compiles nowhere near a Groovy service, but its docs can look plausible. If a result says the name also exists in another library, check that you have the hoist-core one.

## Workflow

Standard sequence for any hoist-core authoring task:

1. **Index first.** List the docs when you're new to the area. Find the right doc.
2. **Search docs** for context on conventions, architecture, and common patterns in the area you're touching.
3. **Search symbols** for specific class/method names. Multi-word queries are AND-matched against names AND Groovydoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and annotations.
5. **Disambiguate** by passing `filePath` when symbol names collide.

Hoist Docs indexes the members of every class, so `search-symbols` with a member name (e.g. `getOrCreate`, `withSpan`) finds the class that provides it. The bundled tools index members only for `BaseService`, `BaseController`, `RestController`, `HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`, `FieldFilter`, `CompoundFilter`, `JSONClient`, `ClusterService`, `ConfigService`, `MonitorResult`, `LogSupport`, `HttpException` and `IdentitySupport`.

## Common queries

Shown for Hoist Docs. With the bundled tools, use the matching `mcp__hoist-core__hoist-core-*` tool or CLI command from the routing table, without `library`.

**Look up the methods on `BaseService`.** `hoist-get-members` with `name: "BaseService"`, `library: "core"`.

**Find which class provides a method like `getOrCreate`.** `hoist-search-symbols` with `query: "getOrCreate"`, `library: "core"`. It returns matching symbols and members with their owning class.

**Find the convention for something cross-cutting (caching, monitoring, cluster).** `hoist-search-docs` with `query: "cache cluster"`, `library: "core"`.

**Read the docs index.** `hoist-list-docs` with `library: "core"`.

**Look up an annotation or trait by name.** `hoist-get-symbol` with `name: "<TraitName>"`, `library: "core"`. Pass `kind: "trait"` to `hoist-search-symbols` to filter.

## Common pitfalls

- **Hand-rolling caching.** hoist-core ships `Cache`, `CachedValue`, and `Timer`. Search for them before writing your own.
- **Guessing controller render helpers.** `BaseController` provides `renderJSON`, `renderJSONP`, exception handling, and identity support. Look it up via `get-members` instead of using raw Grails `render`.
- **Mistaking ClusterService for raw Hazelcast.** hoist-core wraps cluster operations in `ClusterService` with conventions for monitoring, replication, and identity. Use it through that wrapper.
- **Stomping on the cluster boundary.** Some `Cache` configurations are local; some are distributed. Read the Cache docs and use the right form.
- **Falling back to reading framework source.** If the reference tools answer the question, prefer them - they expose Groovydoc and annotations more cleanly than reading source. Read the source only as a last resort.

## Bundled tools (hoist-core v39 to v44)

Everything from here to [When the tools aren't available](#when-the-tools-arent-available) applies only to hoist-core v39 to v44. From v45, hoist-core no longer publishes `io.xh:hoist-core-mcp`, so `installHoistCoreTools` fails, and Hoist Docs serves hoist-core instead. On v45 or later, follow [Removing the bundled tools](#removing-the-bundled-tools) if they are still installed.

### Apps with Gradle dependency locking

An app locks its server dependencies if a `gradle.lockfile` sits at the project root. Adding, refreshing or removing the install snippet changes the locked graph, because the snippet adds a `hoistCoreCli` configuration. Under `STRICT` locking, a configuration with no lock state fails to resolve, so `installHoistCoreTools` fails until the locks are regenerated. After each edit to the snippet, and before any Gradle task, run this from the project root:

    ./gradlew dependencies --write-locks -PrunHoistInline=false

Keep `-PrunHoistInline=false` if the build reads `runHoistInline`. A run in inline mode wipes the lock state. After a removal, delete `gradle.lockfile` before the run. `--write-locks` keeps the entries of a configuration that no longer exists, so the old `hoistCoreCli` lines would stay. Commit `gradle.lockfile` and `buildscript-gradle.lockfile` with the `build.gradle` change. Do not edit a lockfile by hand.

### CLI preflight (do once per session before first CLI use)

Skip this if you're working through MCP only. For the CLI surface, before the first `./bin/hoist-core-*` call in a session, verify the launchers are present and functional:

1. Check that `./bin/hoist-core-docs`, `./bin/hoist-core-symbols`, and `./bin/hoist-core-mcp` exist at the project root.
2. Sanity-check one of them:

       ./bin/hoist-core-docs ping

   Expect: `hoist-core CLI is running.`

3. **Snippet-currency check (low-cost, informational).** Grep `build.gradle` for the install snippet's drift marker:

       grep -E '^// hoist-ai-snippet: hoist-core-install/v[0-9]+' build.gradle

   The current canonical version is **`v2`**. Three possible outcomes:
   - **Match on `v2`**: snippet is current. No action.
   - **Match on a lower version** (e.g. `v1`): snippet has drifted from the canonical. Jump to **[Refreshing a stale install snippet](#refreshing-a-stale-install-snippet)** and offer to update. A `v1` snippet fails under Grails 8 (hoist-core v43+), so if `hoistCoreVersion` is 43.0 or later, the refresh is required, not optional - `installHoistCoreTools` will not run until it is applied.
   - **No match**: snippet was installed before the drift marker was introduced (or hand-removed). Treat the same as the lower-version case.

If any launcher file is **missing**, jump to **[Installing the MCP server and CLI tools](#installing-the-mcp-server-and-cli-tools)** and run the full install procedure.

If the files exist but `ping` **fails** (most common cause: `./gradlew clean` wiped the JAR the absolute path in each launcher points at, but the launcher itself was retained on disk), re-run only `./gradlew installHoistCoreTools` - it's idempotent and re-resolves the JAR. No need to re-edit `build.gradle` or `.mcp.json`.

Briefly mention the refresh in your next user-facing message (e.g. "refreshed hoist-core launchers after the JAR was cleaned").

The preflight runs once per session - once you've confirmed (or fixed) the launchers, you don't need to re-check on every CLI call. For the snippet-currency check specifically: surface it **once** per session. If the user defers the refresh, do not re-prompt during the session.

### Installing the MCP server and CLI tools

Trigger this section when:

- The user asks to install, set up, wire up, or upgrade the hoist-core MCP server or CLI tools in an app on hoist-core v39 to v44. On v45 or later, tell them Hoist Docs serves hoist-core, and offer `/xh:onboard-app` if `.mcp.json` has no `hoist-docs` entry.
- You attempted a tool call from the routing table on hoist-core v39 to v44, and neither the `mcp__hoist-core__*` tools nor the `./bin/hoist-core-*` launchers are present.
- The user just upgraded `hoistCoreVersion` and the existing `bin/` launchers are now stale (they're version-locked to the JAR they wrap).

Both surfaces ship from the same fat JAR (`io.xh:hoist-core-mcp:<version>:all`). One Gradle task installs project-local launchers for both.

#### Prerequisites

- App is a Hoist project: `build.gradle` exists at the project root, `hoist-core` is a dependency (direct or transitively via a client plugin). The install snippet resolves the active hoist-core version from the runtime classpath, so it works regardless of how the dependency is declared.
- `hoistCoreVersion` resolves to a release that includes the install task and bundled-content fat JAR: **v39.0 to v44.x**. v45 and later publish no fat JAR. **Floor: v39.0** (first release containing the bundled JAR + CLI subsystem).
- Java 17+ on PATH (already required by Hoist).

If `hoistCoreVersion` is below the floor, stop and recommend `/xh:hoist-upgrade` first. If it is v45 or later, stop: Hoist Docs serves hoist-core. Do not attempt to back-port the install task to older versions.

#### Procedure

1. **Read the canonical install snippet.** Either:
   - MCP: `mcp__hoist-core__hoist-core-read-doc` with `id: "mcp/README.md"` and look for the **App-Side Distribution** section, OR
   - CLI: `./bin/hoist-core-docs read mcp/README.md` (only if the launchers are already present from a prior install — typical when upgrading), OR
   - Read `mcp/README.md` directly from a sibling hoist-core checkout if available.

   The README is the source of truth. The snippet below is a current-as-of-v43.0 mirror; if it diverges from what the README shows, trust the README. Exception: apps on hoist-core before v43 have a README that still shows the older `v1` snippet. Use the `v2` mirror below for those apps - it works on Grails 7 / Gradle 8 as well as Grails 8 / Gradle 9.

2. **Add the install snippet to the app's `build.gradle`.** Insert at the top level (outside any subproject block):

    ```groovy
    // hoist-ai-snippet: hoist-core-install/v2 -- DO NOT REMOVE (drift marker, see hoist-core/mcp/README.md)
    configurations {
        hoistCoreCli
    }

    // Resolve the active hoist-core version lazily from the runtime classpath, so the install task
    // stays aligned with whatever version actually resolves at build time. `withDependencies` defers
    // this to when `hoistCoreCli` is resolved (task execution), avoiding configuration-time resolution
    // of runtimeClasspath -- which under the Grails/Spring Boot plugin would lock `developmentOnly`
    // before its afterEvaluate hook can populate it.
    configurations.hoistCoreCli.withDependencies { deps ->
        def hc = configurations.runtimeClasspath.incoming.resolutionResult.allComponents
            .find { it.moduleVersion?.group == 'io.xh' && it.moduleVersion?.name == 'hoist-core' }
        if (!hc) throw new GradleException(
            'hoist-core not found on the runtimeClasspath -- cannot install hoist-core tools.')
        deps.add(project.dependencies.create("io.xh:hoist-core-mcp:${hc.moduleVersion.version}:all@jar"))
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

3. **Run the install task.** In a locked app, [regenerate the locks](#apps-with-gradle-dependency-locking) first.

    ```bash
    ./gradlew installHoistCoreTools
    ```

   Expect the task to download (or resolve from cache) the fat JAR into `build/hoist-core-tools/lib/` and write six launchers under `bin/`: three POSIX (`hoist-core-mcp`, `hoist-core-docs`, `hoist-core-symbols`) and three Windows `.bat` mirrors.

4. **Sanity-check the CLI immediately.** This is fast (no Claude restart needed) and catches snapshot-resolution / Java-version issues:

    ```bash
    ./bin/hoist-core-docs ping
    ./bin/hoist-core-symbols members BaseService
    ```

   The first symbols invocation pays a ~2-3s AST cold-start. If `ping` doesn't return cleanly, surface the error to the user before proceeding.

5. **Wire up `.mcp.json`.** The MCP server now launches via the local launcher (`./bin/hoist-core-mcp`), not via a `bootstrap.sh` or any version-suffixed JAR path. Edit (or create) `.mcp.json` at the project root:

    ```json
    {
      "mcpServers": {
        "hoist-core": {
          "command": "./bin/hoist-core-mcp"
        }
      }
    }
    ```

   If `.mcp.json` already exists, preserve other entries (e.g. `hoist-react` or `hoist-docs`) and only update or add the `hoist-core` entry. Replace any prior `start-hoist-core-mcp.sh` or `mcp/bootstrap.sh` command with the new launcher path.

6. **Commit `bin/.gitignore`.** The install task writes a scoped `bin/.gitignore` excluding only the generated launchers (each launcher embeds an absolute path to the resolved JAR and is therefore machine-specific -- a committed launcher silently breaks for every other developer). Commit `bin/.gitignore` once; subsequent regenerations stay out of source control automatically. The rest of `bin/` (if the project uses it for other things) is untouched. The `build/hoist-core-tools/` directory is normally already covered by the project's top-level `build/` ignore.

7. **Tell the user to restart Claude Code** so it picks up the new `.mcp.json` entry. Until restart, only the CLI surface will be available.

#### Verification after install

- CLI: `./bin/hoist-core-docs ping` returns cleanly. `./bin/hoist-core-symbols members BaseService` lists BaseService's public methods/properties.
- MCP (after Claude restart): `mcp__hoist-core__hoist-core-ping` returns cleanly. `mcp__hoist-core__hoist-core-list-docs` returns the doc registry.

If both surfaces work, the routing table at the top of this skill is now usable in either column.

#### Upgrading

When `hoistCoreVersion` is bumped to v45 or later, do not re-run the install task: follow [Removing the bundled tools](#removing-the-bundled-tools). When it is bumped within v39 to v44, re-run `./gradlew installHoistCoreTools` to refresh the launchers (they embed an absolute path to a version-suffixed JAR; stale launchers point at a deleted JAR and will fail at exec time). The snippet in `build.gradle` rarely needs to change on a `hoistCoreVersion` bump -- the Provider resolves the new version automatically. The snippet itself is versioned independently via its `hoist-ai-snippet:` marker; see [Refreshing a stale install snippet](#refreshing-a-stale-install-snippet) for that separate concern.

#### Refreshing a stale install snippet

Triggered when the preflight's snippet-currency check finds a missing or outdated `// hoist-ai-snippet: hoist-core-install/v<N>` marker in `build.gradle` -- the working launchers will keep working, but the snippet has been improved since the user last pasted it (e.g. updated Gradle APIs, improved launcher script, new install-task behavior).

This is an **in-place edit of the user's source-controlled `build.gradle`**, not a regenerated file copy. Be careful:

1. **Read the current canonical** the same way as a fresh install -- step 1 of the install procedure above (`mcp__hoist-core__hoist-core-read-doc` with `id: "mcp/README.md"`, or `./bin/hoist-core-docs read mcp/README.md`, or a sibling hoist-core checkout). Trust the README's snippet over the mirror in this SKILL.md if they diverge -- but they shouldn't if both repos have been kept in lockstep.

2. **Locate the existing snippet boundaries** in `build.gradle`:

       grep -nE '^// (hoist-ai-snippet|end hoist-ai-snippet)' build.gradle

   If both an opening and closing marker are present, you have a clean bounded block. If only the opening is present, find the end manually -- the `}` that closes `tasks.register('installHoistCoreTools', Sync)`. If neither is present (pre-stamp install), find the install fragments by their well-known identifiers: the `configurations { hoistCoreCli }` block, the `hoistCoreCli ...` line inside `dependencies { ... }`, and the `tasks.register('installHoistCoreTools', ...)` block.

3. **Detect hand-edits.** Compare the in-place snippet against the canonical. Common harmless local modifications: tweaked `description = ...`, added logging, additional launcher topics, custom `into` location, extra `.gitignore` entries. **Preserve these in the refresh.** If you see edits you cannot explain as harmless, stop and ask the user before editing.

4. **Present the diff to the user and get explicit confirmation** before applying. Frame it as: "Your install snippet is at <old version or unstamped>; current canonical is <new version>. The diff below shows what would change. Proceed?"

5. **Apply the refresh via Edit** -- replace the bounded block byte-for-byte with the canonical (merging in any preserved hand-edits). If the snippet was unstamped, add the markers as part of the refresh.

6. **Re-run the install task** to regenerate launchers with the new logic. In a locked app, [regenerate the locks](#apps-with-gradle-dependency-locking) first:

       ./gradlew installHoistCoreTools

7. **Verify** as in the standard install procedure -- `./bin/hoist-core-docs ping` should still return cleanly.

If the user defers the refresh, do not re-prompt during the session. They can re-trigger by asking for the install task to be re-run or by starting a new session.

### Removing the bundled tools

Run this when the app is on hoist-core v45 or later and still has the bundled tools: a `bin/hoist-core-mcp` launcher, a `hoist-core` entry in `.mcp.json`, or the install snippet in `build.gradle`. The user may also ask for it directly. The JAR the launchers run is gone after a `./gradlew clean`, and `installHoistCoreTools` fails on v45, so the leftovers only cause errors.

1. **Check that Hoist Docs is set up.** `.mcp.json` should have a `hoist-docs` entry, and `client-app/package.json` should list `@xh/hoist-docs`. If not, offer `/xh:onboard-app` to add it. Hoist Docs needs `@xh/hoist` v91 or later, so on an older `@xh/hoist` offer `/xh:hoist-upgrade` instead. Until Hoist Docs is set up, removing the bundled tools leaves the app with no hoist-core reference, so say so.
2. **Show the user what will be removed and get confirmation:**
   - The install snippet in `build.gradle`: the `configurations { hoistCoreCli }` block, the `hoistCoreCli ...` dependency, and the `installHoistCoreTools` task. Find it by its markers, as in [Refreshing a stale install snippet](#refreshing-a-stale-install-snippet) step 2.
   - The generated launchers `bin/hoist-core-mcp`, `bin/hoist-core-docs`, `bin/hoist-core-symbols` and their `.bat` mirrors, and the `bin/.gitignore` the task wrote. Keep any other entries in that `.gitignore`.
   - The `hoist-core` entry in `.mcp.json`. Keep the other entries.
   - In `.claude/settings.json` and `.claude/settings.local.json`: `hoist-core` in `enabledMcpjsonServers`, and the `mcp__hoist-core__*`, `Bash(./bin/hoist-core-*)` and `Bash(./gradlew installHoistCoreTools:*)` permissions. Add `mcp__hoist-docs__*` and `hoist-docs` in their place if the file allows the old ones.
   - Agent docs (`CLAUDE.md`, `AGENTS.md`) that send agents to `./bin/hoist-core-*` or `mcp__hoist-core__*`. Point them at the Hoist Docs tools with `library: "core"`.
3. **Apply the removal** with Edit, then delete the launchers. In a locked app, [regenerate the locks](#apps-with-gradle-dependency-locking) and commit them with the `build.gradle` change.
4. **Tell the user to restart Claude Code**, so it drops the old server.

## When the tools aren't available

If no hoist-core reference tools are in your context:

1. **hoist-core v45 or later:** Hoist Docs serves hoist-core. If `.mcp.json` has no `hoist-docs` entry, offer `/xh:onboard-app`. If it has one, Claude Code needs a restart, or the environment blocks MCP. If `hoist-ping` lists no `core` library, it gives the reason: usually the Maven fetch of the hoist-core docs index. Behind an organization's Maven mirror, set `HOIST_DOCS_MAVEN_REPO` and `HOIST_DOCS_MAVEN_SNAPSHOT_REPO` (plus `HOIST_DOCS_MAVEN_USER` and `HOIST_DOCS_MAVEN_PASSWORD` if it needs credentials) in the `env` of the `hoist-docs` entry. Behind an HTTP proxy, also set `NODE_USE_ENV_PROXY=1`.
2. **hoist-core v39 to v44:** offer to [install the bundled tools](#installing-the-mcp-server-and-cli-tools). This is almost always the right next step for an app on these versions.
3. If the user declines, or the project is on `hoistCoreVersion < 39.0` and they don't want to upgrade right now, do **not** improvise hoist-core APIs from training data - class names and member signatures evolve, and stale guesses produce real bugs. Tell the user the limitation explicitly.
4. As a last resort, read the docs and source for the app's version: from a sibling hoist-core checkout if there is one, or from https://github.com/xh/hoist-core at the matching release tag. Surface this as a workaround, not a steady state.
