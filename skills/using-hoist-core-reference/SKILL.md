---
name: using-hoist-core-reference
description: Authoritative reference for the io.xh:hoist-core Grails/Groovy framework. Use when about to write or modify Groovy/Java backend code (typically under `grails-app/` or `src/`) that consumes hoist-core APIs - services (`BaseService`), controllers (`BaseController`, `RestController`), domain types (`HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`), framework annotations, or patterns (cluster services, config service, monitoring, JSON client). Do not guess at class names, method signatures, annotations, or conventions - consult the reference tools first. Skip for non-Hoist Grails/Groovy code or pure Spring/Hibernate work that doesn't import from `io.xh.hoist`.
allowed-tools: Read, Bash, mcp__hoist-core__hoist-core-ping, mcp__hoist-core__hoist-core-search-docs, mcp__hoist-core__hoist-core-list-docs, mcp__hoist-core__hoist-core-search-symbols, mcp__hoist-core__hoist-core-get-symbol, mcp__hoist-core__hoist-core-get-members
---

# Using Hoist Core Reference

You're about to write or modify Groovy/Java backend code that consumes the `io.xh:hoist-core` framework. Consult the reference tools before authoring - hoist-core's API surface is large, base-class semantics are easy to misremember, and a wrong guess produces code that compiles but fails at runtime.

## Routing table

Each workflow step has two interfaces. Use the column that matches what's in your tool context.

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `mcp__hoist-core__hoist-core-search-docs` | `<TBD: hoist-core CLI not yet shipped>` |
| List docs by category | `mcp__hoist-core__hoist-core-list-docs` | `<TBD>` |
| Search symbols / members | `mcp__hoist-core__hoist-core-search-symbols` | `<TBD>` |
| Get symbol details | `mcp__hoist-core__hoist-core-get-symbol` | `<TBD>` |
| List class members | `mcp__hoist-core__hoist-core-get-members` | `<TBD>` |

If `mcp__hoist-core__*` tools are listed in your tool context, prefer them. The CLI column will be populated when the hoist-core CLI ships - until then, MCP is the only path. The MCP tool names look the same regardless of whether the server is running locally or as a deployed remote endpoint.

## Workflow

Standard sequence for any hoist-core authoring task:

1. **Index first.** Use `mcp__hoist-core__hoist-core-list-docs` (or search with a broad query) when you're new to the area. Find the right doc.
2. **Search docs** for context on conventions, architecture, and common patterns in the area you're touching.
3. **Search symbols** for specific class/method names. Multi-word queries are AND-matched against names AND Groovydoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and annotations.
5. **Disambiguate** by passing `filePath` when symbol names collide.

Member-indexed classes (those whose public members are individually searchable): `BaseService`, `BaseController`, `RestController`, `HoistUser`, `Cache`, `CachedValue`, `Timer`, `Filter`, `FieldFilter`, `CompoundFilter`, `JSONClient`, `ClusterService`, `ConfigService`, `MonitorResult`, `LogSupport`, `HttpException`, `IdentitySupport`. Use `search-symbols` with a member name (e.g. `getOrCreate`, `expireTime`) to find which of these classes provides it.

## Common queries

**Look up the methods on `BaseService`.**
- MCP: `mcp__hoist-core__hoist-core-get-members` with `name: "BaseService"`.

**Find which class provides a method like `getOrCreate`.**
- MCP: `mcp__hoist-core__hoist-core-search-symbols` with `query: "getOrCreate"` - returns matching symbols and matching members with their owning class.

**Find the convention for something cross-cutting (caching, monitoring, cluster).**
- MCP: `mcp__hoist-core__hoist-core-search-docs` with `query: "cache cluster"` (multi-word AND match).

**Read the docs index.**
- MCP: `mcp__hoist-core__hoist-core-list-docs` (with no `category` param).

**Look up an annotation or trait by name.**
- MCP: `mcp__hoist-core__hoist-core-get-symbol` with `name: "<TraitName>"`. Use `kind: trait` on `search-symbols` to filter.

## Common pitfalls

- **Hand-rolling caching.** hoist-core ships `Cache`, `CachedValue`, and `Timer`. Search for them before writing your own.
- **Guessing controller render helpers.** `BaseController` provides `renderJSON`, `renderJSONP`, exception handling, and identity support. Look it up via `get-members` instead of using raw Grails `render`.
- **Mistaking ClusterService for raw Hazelcast.** hoist-core wraps cluster operations in `ClusterService` with conventions for monitoring, replication, and identity. Use it through that wrapper.
- **Stomping on the cluster boundary.** Some `Cache` configurations are local; some are distributed. Read the Cache docs and use the right form.
- **Falling back to reading framework source.** If the reference tools answer the question, prefer them - they expose Groovydoc and annotations more cleanly than reading source. Read the source only as a last resort.

## When the tools aren't available

If `mcp__hoist-core__*` tools are not present in your context (and the CLI is not yet shipped), stop and tell the user. Do not improvise hoist-core APIs from training data - class names and member signatures evolve, and stale guesses produce real bugs.

If the project has hoist-core checked out as a sibling repo, you may use `Read` to consult its docs (`docs/`) or source as a last resort. Surface the limitation to the user; the recommended fix is to ensure the plugin's hoist-core MCP server is wired up via `/xh:onboard-app`.
