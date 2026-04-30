---
name: using-hoist-core-reference
description: Authoritative reference for the io.xh:hoist-core Grails/Groovy framework, AND the source of truth for installing or upgrading its MCP server + CLI tools (`hoist-core-mcp`, `hoist-core-docs`, `hoist-core-symbols`) in a Hoist app. Use when (a) about to write or modify Groovy/Java backend code (typically under `grails-app/` or `src/`) that consumes hoist-core APIs - services (`BaseService`), controllers (`BaseController`, `RestController`), domain types (`HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`), framework annotations, or patterns (cluster services, config service, monitoring, JSON client) - OR (b) the user asks to install, set up, wire up, or upgrade the hoist-core MCP server or CLI launchers in their app (Gradle `installHoistCoreTools` task, project-local `bin/` launchers, `.mcp.json` wiring). Do not guess at class names, method signatures, annotations, or conventions - consult the reference tools first. Skip for non-Hoist Grails/Groovy code or pure Spring/Hibernate work that doesn't import from `io.xh.hoist`.
allowed-tools: Read, Edit, Write, Bash, mcp__hoist-core__hoist-core-ping, mcp__hoist-core__hoist-core-search-docs, mcp__hoist-core__hoist-core-list-docs, mcp__hoist-core__hoist-core-read-doc, mcp__hoist-core__hoist-core-search-symbols, mcp__hoist-core__hoist-core-get-symbol, mcp__hoist-core__hoist-core-get-members
---

# Using Hoist Core Reference

You're about to write or modify Groovy/Java backend code that consumes the `io.xh:hoist-core` framework, OR the user has asked you to install/upgrade the hoist-core developer tools in their app. Consult the reference tools before authoring - hoist-core's API surface is large, base-class semantics are easy to misremember, and a wrong guess produces code that compiles but fails at runtime. If the tools aren't installed yet, jump to **[Installing the MCP server and CLI tools](#installing-the-mcp-server-and-cli-tools)**.

## Routing table

Each workflow step has two interfaces. Use the column that matches what's in your tool context.

| Step | MCP tool | CLI command |
|---|---|---|
| Sanity check | `mcp__hoist-core__hoist-core-ping` | `./bin/hoist-core-docs ping` |
| Search docs | `mcp__hoist-core__hoist-core-search-docs` | `./bin/hoist-core-docs search "<query>"` |
| List docs by category | `mcp__hoist-core__hoist-core-list-docs` | `./bin/hoist-core-docs list --category <category>` |
| Read a specific doc | `mcp__hoist-core__hoist-core-read-doc` | `./bin/hoist-core-docs read <docId>` |
| Read the docs index | `mcp__hoist-core__hoist-core-list-docs` (no args) | `./bin/hoist-core-docs index` |
| Read coding conventions | `mcp__hoist-core__hoist-core-read-doc` with `id: "docs/coding-conventions.md"` | `./bin/hoist-core-docs conventions` |
| Search symbols / members | `mcp__hoist-core__hoist-core-search-symbols` | `./bin/hoist-core-symbols search "<query>"` |
| Get symbol details | `mcp__hoist-core__hoist-core-get-symbol` | `./bin/hoist-core-symbols symbol <name>` |
| List class members | `mcp__hoist-core__hoist-core-get-members` | `./bin/hoist-core-symbols members <name>` |

If `mcp__hoist-core__*` tools are listed in your tool context, prefer them - they amortize the Groovy AST index across calls. The CLI launchers pay a ~2-3s cold-start hit on the first symbols invocation per process. Both surfaces share the same formatters, so output is byte-identical apart from formatting; `--json` on any CLI subcommand emits the same shape an MCP client would receive.

The CLI launchers are project-local (created at `<project>/bin/hoist-core-*` by the `installHoistCoreTools` Gradle task). Always invoke them as `./bin/hoist-core-...` from the app project root, not `npx`-style.

## Workflow

Standard sequence for any hoist-core authoring task:

1. **Index first.** Use `mcp__hoist-core__hoist-core-list-docs` (or `./bin/hoist-core-docs index`) when you're new to the area. Find the right doc.
2. **Search docs** for context on conventions, architecture, and common patterns in the area you're touching.
3. **Search symbols** for specific class/method names. Multi-word queries are AND-matched against names AND Groovydoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and annotations.
5. **Disambiguate** by passing `filePath` when symbol names collide.

Member-indexed classes (those whose public members are individually searchable): `BaseService`, `BaseController`, `RestController`, `HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`, `FieldFilter`, `CompoundFilter`, `JSONClient`, `ClusterService`, `ConfigService`, `MonitorResult`, `LogSupport`, `HttpException`, `IdentitySupport`. Use `search-symbols` with a member name (e.g. `getOrCreate`, `expireTime`) to find which of these classes provides it.

## Common queries

**Look up the methods on `BaseService`.**
- MCP: `mcp__hoist-core__hoist-core-get-members` with `name: "BaseService"`.
- CLI: `./bin/hoist-core-symbols members BaseService`

**Find which class provides a method like `getOrCreate`.**
- MCP: `mcp__hoist-core__hoist-core-search-symbols` with `query: "getOrCreate"` - returns matching symbols and matching members with their owning class.
- CLI: `./bin/hoist-core-symbols search getOrCreate`

**Find the convention for something cross-cutting (caching, monitoring, cluster).**
- MCP: `mcp__hoist-core__hoist-core-search-docs` with `query: "cache cluster"` (multi-word AND match).
- CLI: `./bin/hoist-core-docs search "cache cluster"`

**Read the docs index.**
- MCP: `mcp__hoist-core__hoist-core-list-docs` (with no `category` param).
- CLI: `./bin/hoist-core-docs index`

**Look up an annotation or trait by name.**
- MCP: `mcp__hoist-core__hoist-core-get-symbol` with `name: "<TraitName>"`. Use `kind: trait` on `search-symbols` to filter.
- CLI: `./bin/hoist-core-symbols search "<TraitName>" --kind trait` then `./bin/hoist-core-symbols symbol <TraitName>`.

## Common pitfalls

- **Hand-rolling caching.** hoist-core ships `Cache`, `CachedValue`, and `Timer`. Search for them before writing your own.
- **Guessing controller render helpers.** `BaseController` provides `renderJSON`, `renderJSONP`, exception handling, and identity support. Look it up via `get-members` instead of using raw Grails `render`.
- **Mistaking ClusterService for raw Hazelcast.** hoist-core wraps cluster operations in `ClusterService` with conventions for monitoring, replication, and identity. Use it through that wrapper.
- **Stomping on the cluster boundary.** Some `Cache` configurations are local; some are distributed. Read the Cache docs and use the right form.
- **Falling back to reading framework source.** If the reference tools answer the question, prefer them - they expose Groovydoc and annotations more cleanly than reading source. Read the source only as a last resort.

## Installing the MCP server and CLI tools

Trigger this section when:

- The user asks to install, set up, wire up, or upgrade the hoist-core MCP server or CLI tools in an app.
- You attempted a tool call from the routing table and neither the `mcp__hoist-core__*` tools nor the `./bin/hoist-core-*` launchers are present.
- The user just upgraded `hoistCoreVersion` and the existing `bin/` launchers are now stale (they're version-locked to the JAR they wrap).

Both surfaces ship from the same fat JAR (`io.xh:hoist-core-mcp:<version>:all`). One Gradle task installs project-local launchers for both.

### Prerequisites

- App is a Hoist project: `build.gradle` exists at the project root, `hoist-core` is a dependency (direct or transitively via a client plugin), `gradle.properties` typically declares `hoistCoreVersion`.
- `hoistCoreVersion` resolves to a release that includes the install task and bundled-content fat JAR. **Floor: v39.0** (first release containing the bundled JAR + CLI subsystem). For pre-release work against `develop`, use `39.0-SNAPSHOT` from a Sonatype snapshot repo or `mavenLocal()` (after `./gradlew :mcp:publishToMavenLocal` in a hoist-core checkout).
- Java 17+ on PATH (already required by Hoist).

If `hoistCoreVersion` is below the floor, stop and recommend `/xh:hoist-upgrade` first. Do not attempt to back-port the install task to older versions.

### Procedure

1. **Read the canonical install snippet.** Either:
   - MCP: `mcp__hoist-core__hoist-core-read-doc` with `id: "mcp/README.md"` and look for the **App-Side Distribution** section, OR
   - CLI: `./bin/hoist-core-docs read mcp/README.md` (only if the launchers are already present from a prior install — typical when upgrading), OR
   - Read `mcp/README.md` directly from a sibling hoist-core checkout if available.

   The README is the source of truth. The snippet below is a current-as-of-v39.0 mirror; if it diverges from what the README shows, trust the README.

2. **Add the install snippet to the app's `build.gradle`.** Insert at the top level (outside any subproject block):

    ```groovy
    configurations {
        hoistCoreCli
    }

    dependencies {
        hoistCoreCli "io.xh:hoist-core-mcp:${hoistCoreVersion}:all@jar"
    }

    tasks.register('installHoistCoreTools', Sync) {
        description = 'Install version-locked launchers for the hoist-core MCP server and CLI tools.'
        group = 'hoist'
        from configurations.hoistCoreCli
        into "$buildDir/hoist-core-tools/lib"
        doLast {
            def jar = fileTree("$buildDir/hoist-core-tools/lib").singleFile
            def binDir = file('bin')
            binDir.mkdirs()
            ['mcp', 'docs', 'symbols'].each { topic ->
                // mcp mode: pass --source bundled so the server reads JAR-embedded content. Without this,
                //           HoistCoreMcpServer defaults to local mode and fails when the app has no
                //           hoist-core checkout sibling. (CLI subcommands already default to bundled.)
                // docs/symbols mode: dispatched via `cli`, which routes to picocli with bundled default.
                def args = topic == 'mcp' ? '--source bundled' : "cli ${topic}"
                new File(binDir, "hoist-core-${topic}").with {
                    text = "#!/usr/bin/env bash\nexec java -jar \"${jar.absolutePath}\" ${args} \"\$@\"\n"
                    setExecutable(true)
                }
                new File(binDir, "hoist-core-${topic}.bat").text =
                    "@echo off\r\njava -jar \"${jar.absolutePath}\" ${args} %*\r\n"
            }
        }
    }
    ```

    > **Note on `--source bundled`:** As of the first release containing the install task (v39.0),
    > the snippet shown in `mcp/README.md` does **not** pass `--source bundled` to the mcp
    > launcher. That snippet works only when the app has a sibling `../hoist-core/` checkout. The
    > version above adds the flag so the install works for any app, regardless of sibling layout.
    > A follow-up to align hoist-core's bare-MCP default with bundled is tracked separately.

   If `hoistCoreVersion` is provided transitively by a client plugin and isn't declared in `gradle.properties`, change the `hoistCoreCli` dependency line to use the resolved version (e.g. `"io.xh:hoist-core-mcp:39.0:all@jar"`) or wire it through `ext.hoistCoreVersion = ...` first. Confirm the resolved version with `./gradlew dependencies --configuration runtimeClasspath | grep io.xh:hoist-core` if needed.

3. **Run the install task.**

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

   If `.mcp.json` already exists, preserve other entries (e.g. `hoist-react`) and only update or add the `hoist-core` entry. Replace any prior `start-hoist-core-mcp.sh` or `mcp/bootstrap.sh` command with the new launcher path.

6. **Decide on `.gitignore`.** The launchers and the unpacked JAR are deterministic artifacts of `installHoistCoreTools`. Two valid stances - ask the user which they prefer if it's unclear:
   - **Ignore them** (recommended for teams that re-run the task on version bumps): add `bin/hoist-core-*` and `build/hoist-core-tools/` to `.gitignore`.
   - **Commit them** (recommended for teams that want zero-setup checkouts): leave them tracked. The Gradle snippet writes them deterministically, so diffs only appear on real version bumps.

7. **Tell the user to restart Claude Code** so it picks up the new `.mcp.json` entry. Until restart, only the CLI surface will be available.

### Verification after install

- CLI: `./bin/hoist-core-docs ping` returns cleanly. `./bin/hoist-core-symbols members BaseService` lists BaseService's public methods/properties.
- MCP (after Claude restart): `mcp__hoist-core__hoist-core-ping` returns cleanly. `mcp__hoist-core__hoist-core-list-docs` returns the doc registry.

If both surfaces work, the routing table at the top of this skill is now usable in either column.

### Upgrading

When `hoistCoreVersion` is bumped, re-run `./gradlew installHoistCoreTools` to refresh the launchers (they embed an absolute path to a version-suffixed JAR; stale launchers point at a deleted JAR and will fail at exec time). The Gradle snippet itself rarely needs to change.

## When the tools aren't available

If neither MCP tools (`mcp__hoist-core__*`) nor the CLI launchers (`./bin/hoist-core-*`) are present in your context:

1. Default action: jump to **[Installing the MCP server and CLI tools](#installing-the-mcp-server-and-cli-tools)** above and offer to install them. This is almost always the right next step for an app project on a recent enough hoist-core.
2. If the user declines or the project is on `hoistCoreVersion < 39.0` and they don't want to upgrade right now, do **not** improvise hoist-core APIs from training data - class names and member signatures evolve, and stale guesses produce real bugs. Tell the user the limitation explicitly.
3. As a last resort only, if the project has hoist-core checked out as a sibling repo, you may use `Read` to consult its `docs/` or source. Surface this as a workaround, not a steady state.
