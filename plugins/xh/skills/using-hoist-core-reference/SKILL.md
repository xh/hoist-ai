---
name: using-hoist-core-reference
description: |
  Reference for the io.xh:hoist-core Grails/Groovy framework, for writing, changing, debugging, or explaining backend code that uses it, and for installing its MCP/CLI tools. Why this matters: hoist-core's base classes differ from plain Spring/Grails for injection, clustering, and config. Guesses run on one node, then fail under cluster failover: invalidations that don't propagate, timers that double-fire, scheduled tasks that miss their slot. TRIGGER on a hoist-core symbol (`BaseService`, `BaseController`, `Cache`, `Timer`, `ConfigService`, `ClusterService`, `JSONClient`) or concept (caching, cluster-aware, config-driven, monitoring, scheduled task); a service or controller under `grails-app/`; a backend task done the framework way; installing the hoist-core MCP server, CLI, `bin/hoist-core-*` launchers, or `installHoistCoreTools`; `hoistCoreVersion`; "hoist-core", "io.xh.hoist", "our framework". SKIP for plain Spring, Grails without `io.xh.hoist`, Liquibase/Flyway migrations, and build-only changes.
allowed-tools: Read, Edit, Write, Bash, mcp__hoist-core__hoist-core-ping, mcp__hoist-core__hoist-core-search-docs, mcp__hoist-core__hoist-core-list-docs, mcp__hoist-core__hoist-core-read-doc, mcp__hoist-core__hoist-core-search-symbols, mcp__hoist-core__hoist-core-get-symbol, mcp__hoist-core__hoist-core-get-members
---

# Using Hoist Core Reference

You're about to write or modify Groovy/Java backend code that consumes the `io.xh:hoist-core` framework, OR the user has asked you to install/upgrade the hoist-core developer tools in their app. Consult the reference tools before authoring - hoist-core's API surface is large, base-class semantics are easy to misremember, and a wrong guess produces code that compiles but fails at runtime. If the tools aren't installed yet, jump to **[Installing the MCP server and CLI tools](#installing-the-mcp-server-and-cli-tools)**.

## Routing table

Each workflow step has two interfaces. Use the column that matches what's in your tool context. The MCP column gives the tool names of the `hoist-core` MCP server. Some harnesses add a prefix, for example `mcp__hoist-core__hoist-core-ping` in Claude Code and Codex.

| Step | MCP tool | CLI command |
|---|---|---|
| Sanity check | `hoist-core-ping` | `./bin/hoist-core-docs ping` |
| Search docs | `hoist-core-search-docs` | `./bin/hoist-core-docs search "<query>"` |
| List docs by category | `hoist-core-list-docs` | `./bin/hoist-core-docs list --category <category>` |
| Read a specific doc | `hoist-core-read-doc` | `./bin/hoist-core-docs read <docId>` |
| Read the docs index | `hoist-core-list-docs` (no args) | `./bin/hoist-core-docs index` |
| Read coding conventions | `hoist-core-read-doc` with `id: "docs/coding-conventions.md"` | `./bin/hoist-core-docs conventions` |
| Search symbols / members | `hoist-core-search-symbols` | `./bin/hoist-core-symbols search "<query>"` |
| Get symbol details | `hoist-core-get-symbol` | `./bin/hoist-core-symbols symbol <name>` |
| List class members | `hoist-core-get-members` | `./bin/hoist-core-symbols members <name>` |

If the hoist-core MCP tools are in your tool context, prefer them - they amortize the Groovy AST index across calls. The CLI launchers pay a ~2-3s cold-start hit on the first symbols invocation per process. Both surfaces share the same formatters, so output is byte-identical apart from formatting; `--json` on any CLI subcommand emits the same shape an MCP client would receive.

The CLI launchers are project-local (created at `<project>/bin/hoist-core-*` by the `installHoistCoreTools` Gradle task). Always invoke them as `./bin/hoist-core-...` from the app project root, not `npx`-style.

## Preflight (do once per session before first CLI use)

Skip this if you're working through MCP only. For the CLI surface, before the first `./bin/hoist-core-*` call in a session, verify the launchers are present and functional:

1. Check that `./bin/hoist-core-docs`, `./bin/hoist-core-symbols`, and `./bin/hoist-core-mcp` exist at the project root, with `test -x`. The launchers are gitignored, and some harnesses' search tools skip gitignored files.
2. Sanity-check one of them:

       ./bin/hoist-core-docs ping

   Expect: `hoist-core CLI is running.`

3. **Snippet-currency check (low-cost, informational).** Grep `build.gradle` for the install snippet's drift marker:

       grep -E '^// hoist-ai-snippet: hoist-core-install/v[0-9]+' build.gradle

   The current canonical version is **`v1`**. Three possible outcomes:
   - **Match on `v1`**: snippet is current. No action.
   - **Match on a lower version** (e.g. `v0`): snippet has drifted from the canonical. Follow **Refreshing a stale install snippet** in [reference/install.md](reference/install.md#refreshing-a-stale-install-snippet) and offer to update.
   - **No match**: snippet was installed before the drift marker was introduced (or hand-removed). Treat the same as the lower-version case.

If any launcher file is **missing**, jump to **[Installing the MCP server and CLI tools](#installing-the-mcp-server-and-cli-tools)** and run the full install procedure.

If the files exist but `ping` **fails** (most common cause: `./gradlew clean` wiped the JAR the absolute path in each launcher points at, but the launcher itself was retained on disk), re-run only `./gradlew installHoistCoreTools` — it's idempotent and re-resolves the JAR. No need to re-edit `build.gradle` or the MCP config.

Briefly mention the refresh in your next user-facing message (e.g. "refreshed hoist-core launchers after the JAR was cleaned").

The preflight runs once per session — once you've confirmed (or fixed) the launchers, you don't need to re-check on every CLI call. For the snippet-currency check specifically: surface it **once** per session. If the user defers the refresh, do not re-prompt during the session.

## Workflow

Standard sequence for any hoist-core authoring task:

1. **Index first.** Use `hoist-core-list-docs` (or `./bin/hoist-core-docs index`) when you're new to the area. Find the right doc.
2. **Search docs** for context on conventions, architecture, and common patterns in the area you're touching.
3. **Search symbols** for specific class/method names. Multi-word queries are AND-matched against names AND Groovydoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and annotations.
5. **Disambiguate** by passing `filePath` when symbol names collide.

Member-indexed classes (those whose public members are individually searchable): `BaseService`, `BaseController`, `RestController`, `HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`, `FieldFilter`, `CompoundFilter`, `JSONClient`, `ClusterService`, `ConfigService`, `MonitorResult`, `LogSupport`, `HttpException`, `IdentitySupport`. Use `search-symbols` with a member name (e.g. `getOrCreate`, `expireTime`) to find which of these classes provides it.

## Common queries

**Look up the methods on `BaseService`.**
- MCP: `hoist-core-get-members` with `name: "BaseService"`.
- CLI: `./bin/hoist-core-symbols members BaseService`

**Find which class provides a method like `getOrCreate`.**
- MCP: `hoist-core-search-symbols` with `query: "getOrCreate"` - returns matching symbols and matching members with their owning class.
- CLI: `./bin/hoist-core-symbols search getOrCreate`

**Find the convention for something cross-cutting (caching, monitoring, cluster).**
- MCP: `hoist-core-search-docs` with `query: "cache cluster"` (multi-word AND match).
- CLI: `./bin/hoist-core-docs search "cache cluster"`

**Read the docs index.**
- MCP: `hoist-core-list-docs` (with no `category` param).
- CLI: `./bin/hoist-core-docs index`

**Look up an annotation or trait by name.**
- MCP: `hoist-core-get-symbol` with `name: "<TraitName>"`. Use `kind: trait` on `search-symbols` to filter.
- CLI: `./bin/hoist-core-symbols search "<TraitName>" --kind trait` then `./bin/hoist-core-symbols symbol <TraitName>`.

## Common pitfalls

- **Hand-rolling caching.** hoist-core ships `Cache`, `CachedValue`, and `Timer`. Search for them before writing your own.
- **Guessing controller render helpers.** `BaseController` provides `renderJSON`, `renderJSONP`, exception handling, and identity support. Look it up via `get-members` instead of using raw Grails `render`.
- **Mistaking ClusterService for raw Hazelcast.** hoist-core wraps cluster operations in `ClusterService` with conventions for monitoring, replication, and identity. Use it through that wrapper.
- **Stomping on the cluster boundary.** Some `Cache` configurations are local; some are distributed. Read the Cache docs and use the right form.
- **Falling back to reading framework source.** If the reference tools answer the question, prefer them - they expose Groovydoc and annotations more cleanly than reading source. Read the source only as a last resort.

## Installing the MCP server and CLI tools

Read [reference/install.md](reference/install.md) and follow it when:

- The user asks to install, set up, wire up, or upgrade the hoist-core MCP server or CLI tools in an app.
- You attempted a tool call from the routing table and neither the hoist-core MCP tools nor the `./bin/hoist-core-*` launchers are present.
- The user just upgraded `hoistCoreVersion` and the existing `bin/` launchers are now stale (they're version-locked to the JAR they wrap).
- The preflight's snippet-currency check found a missing or older marker. Use its **Refreshing a stale install snippet** section.

## When the tools aren't available

If neither the hoist-core MCP tools nor the CLI launchers (`./bin/hoist-core-*`) are present in your context:

1. Default action: jump to **[Installing the MCP server and CLI tools](#installing-the-mcp-server-and-cli-tools)** above and offer to install them. This is almost always the right next step for an app project on a recent enough hoist-core.
2. If the user declines or the project is on `hoistCoreVersion < 39.0` and they don't want to upgrade right now, do **not** improvise hoist-core APIs from training data - class names and member signatures evolve, and stale guesses produce real bugs. Tell the user the limitation explicitly.
3. As a last resort only, if the project has hoist-core checked out as a sibling repo, you may read its `docs/` or source. Surface this as a workaround, not a steady state.
