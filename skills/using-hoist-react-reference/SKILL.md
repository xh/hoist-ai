---
name: using-hoist-react-reference
description: Authoritative reference for the @xh/hoist React framework. Use when (a) about to write or modify TypeScript/React code under a Hoist app's `client-app/` directory that consumes Hoist APIs - components (`hoistCmp`), models (`HoistModel`), services (`HoistService`), the `XH` singleton, decorators (`@bindable`, `@managed`, `@observable`, `@action`), or framework patterns (element factories, persistence, MobX integration) - OR (b) the user asks for orientation, the docs index, or where to start learning Hoist concepts (models, components, services, decorators, grids, dashboards, framework patterns) in the @xh/hoist framework, even if they're not yet authoring code. Do not guess at prop names, method signatures, decorators, or conventions - consult the reference tools first. Skip for code outside `client-app/` or for TypeScript work that doesn't import from `@xh/hoist`.
allowed-tools: Read, Bash, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-get-members
---

# Using Hoist React Reference

You're about to write or modify code that consumes the `@xh/hoist` framework. Consult the reference tools before authoring - Hoist's API surface is large, prop names and decorators are easy to misremember, and a wrong guess produces code that compiles but fails at runtime.

## Routing table

Each workflow step has two interfaces. Use the column that matches what's in your tool context.

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `mcp__hoist-react__hoist-search-docs` | `npx hoist-docs search "<query>"` |
| List docs by category | `mcp__hoist-react__hoist-list-docs` | `npx hoist-docs list -c <category>` |
| Read a specific doc | `mcp__hoist-react__hoist-search-docs` (with id query) | `npx hoist-docs read <docId>` |
| Search symbols / members | `mcp__hoist-react__hoist-search-symbols` | `npx hoist-ts search "<query>"` |
| Get symbol details | `mcp__hoist-react__hoist-get-symbol` | `npx hoist-ts symbol <name>` |
| List class members | `mcp__hoist-react__hoist-get-members` | `npx hoist-ts members <name>` |

If `mcp__hoist-react__*` tools are listed in your tool context, prefer them. Otherwise use the CLI column. The MCP tool names look the same regardless of whether the server is running locally or as a deployed remote endpoint - transport is invisible to you.

## CLI working directory

The `npx hoist-docs` and `npx hoist-ts` commands resolve `@xh/hoist` from the local
`node_modules`, so they must be run from the Hoist app's `client-app/` directory --
not the project root. This is where agents most often stumble.

Hoist apps consistently put their Grails/Groovy backend at the project root and the
React/TypeScript frontend under `client-app/`. If Claude was launched at the project
root (the common case), prefer a subshell so the parent cwd isn't disturbed:

    (cd client-app && npx hoist-docs search "<query>")
    (cd client-app && npx hoist-ts members GridConfig)

`cd client-app` once at the start of a sequence of CLI calls also works. MCP tool
calls don't have this concern -- the MCP server resolves paths internally.

## Workflow

Standard sequence for any Hoist authoring task:

1. **Index first.** Read the docs index (`mcp__hoist-react__hoist-list-docs`, `mcp__hoist-react__hoist-search-docs` with a broad query, or `npx hoist-docs index`) when you're new to the area. Find the right README.
2. **Search docs** for context on conventions, architecture, common pitfalls in the area you're touching.
3. **Search symbols** for specific class/method/decorator names. Multi-word queries are AND-matched against names AND JSDoc - `"panel modal"` finds `ModalSupportModel` via its JSDoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and decorators.
5. **Disambiguate** by passing `filePath` when symbol names collide (e.g. `View` exists in both `cmp/viewmanager` and `data/cube`).

## Common queries

**Look up a component's available props.**
- MCP: `mcp__hoist-react__hoist-get-members` with `name: "GridConfig"` (or whatever `*Config` interface fronts the component).
- CLI: `npx hoist-ts members GridConfig`

**Find which decorator a model property uses.**
- MCP: `mcp__hoist-react__hoist-get-members` with `name: "<MyModelClass>"`.
- CLI: `npx hoist-ts members <MyModelClass>`

**Look up a service method by behavior, not name.**
- MCP: `mcp__hoist-react__hoist-search-symbols` with `query: "fetch loadConfigs"` (multi-word AND match against names + JSDoc).
- CLI: `npx hoist-ts search "fetch loadConfigs"`

**Find the convention for something cross-cutting (persistence, theming, lifecycle).**
- MCP: `mcp__hoist-react__hoist-search-docs` with `query: "persistence MobX integration"`.
- CLI: `npx hoist-docs search "persistence MobX integration"`

**Read the docs index.**
- MCP: `mcp__hoist-react__hoist-list-docs` (or `hoist-search-docs` with a broad query).
- CLI: `npx hoist-docs index` (shorthand for `read docs/README.md`).

**Print coding conventions.**
- MCP: `mcp__hoist-react__hoist-search-docs` with `query: "coding conventions"` then read the matching id.
- CLI: `npx hoist-docs conventions`

## Common pitfalls

- **Searching by display name, not symbol name.** Querying `"modal"` may miss the answer. Use multi-word queries that include behavior keywords (`"panel modal"`) - JSDoc matching surfaces symbols whose names don't include the term.
- **Confusing a `*Config` interface with its consuming class.** `GridModel` (the class) and `GridConfig` (its config interface) both exist. `GridModel`'s properties are runtime state; `GridConfig`'s are configuration knobs. Use `members` on whichever you actually need - they answer different questions.
- **Symbol disambiguation.** When `search-symbols` returns multiple matches with the same name (e.g. `View` in `cmp/viewmanager` AND `data/cube`), the tool will hint that you should pass a file path. Do so.
- **Falling back to `Read` on framework source.** If the reference tools answer the question, prefer them - they expose JSDoc and decorator info more cleanly than reading source. Read the source only as a last resort.
- **Trusting training data.** Hoist's API has evolved. Decorators have changed names, base classes have moved. Always verify with the reference tools before authoring.

## When the tools aren't available

If neither MCP tools (`mcp__hoist-react__*`) nor the CLI (`npx hoist-docs`, `npx hoist-ts`) are present in your context, stop and tell the user. Do not improvise Hoist APIs from training data - prop names, decorators, and conventions evolve, and stale guesses produce real bugs.

If the project has `@xh/hoist` installed locally, you may use the `Read` tool to read package READMEs (e.g. `client-app/node_modules/@xh/hoist/core/README.md`) as a last resort. Surface the limitation to the user; the recommended fix is to ensure the plugin's MCP server or CLI is wired up via `/xh:onboard-app`.
