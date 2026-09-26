---
name: using-hoist-react-reference
description: |
  Authoritative reference for the @xh/hoist React framework - use when writing, modifying, debugging, or explaining TypeScript/React code that touches Hoist, or when answering how Hoist works. Why this matters: Hoist's API evolves; decorator names shift between versions, `*Config` interfaces look like plain React props but aren't, and `loadAsync`/`addAutorun`/`addReaction` differ from plain MobX. Guessing produces code that type-checks but fails at runtime: silent persistence no-ops, leaked autoruns, ignored props, observable state that never re-renders. TRIGGER when the user mentions a Hoist symbol (`hoistCmp`, `HoistModel`, `HoistService`, `XH`, `Grid`, `Panel`, `TabContainer`, `Store`, `*Config`); a Hoist decorator (`@bindable`, `@managed`, `@persist`, etc.); a Hoist concept (persistence, autorun, reaction, `loadAsync`, refresh, element factory, MobX integration, grid columns); a `*Model.ts`/`*Panel.tsx` file with state/refresh/persistence/grid questions; a change under `client-app/` that introduces or modifies Hoist API usage - NOT config-only refactors passing values through a Hoist component to a third-party lib (Highcharts, AG-Grid); Hoist docs/orientation/conventions; "Hoist"/"@xh/hoist"/"our framework"/"our app" in any React/TS context. SKIP for plain TypeScript with no Hoist surface, pure React/MobX without Hoist primitives, and files outside `client-app/`. Reach for the reference tools (MCP `mcp__hoist-react__*` or CLI `./bin/hoist-docs`/`./bin/hoist-ts`) first.
allowed-tools: Read, Bash, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-read-doc, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-get-members
---

# Using Hoist React Reference

You are about to write or change code that uses the `@xh/hoist` framework. Look up the API with the reference tools before you write it. The Hoist API is large, and prop names and decorators are easy to misremember. A wrong guess compiles but fails at runtime.

## Routing table

Each step has an MCP tool and a CLI command. If `mcp__hoist-react__*` tools are in your tool context, use them. If not, use the CLI column. The MCP tool names are the same for a local server and a remote one.

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `mcp__hoist-react__hoist-search-docs` | `./bin/hoist-docs search "<query>"` |
| List docs by category | `mcp__hoist-react__hoist-list-docs` | `./bin/hoist-docs list -c <category>` |
| Read a doc | `mcp__hoist-react__hoist-read-doc` with `id: "<docId>"` | `./bin/hoist-docs read <docId>` |
| Read the docs index | `mcp__hoist-react__hoist-read-doc` with `id: "index"` | `./bin/hoist-docs index` |
| Read coding conventions | `mcp__hoist-react__hoist-read-doc` with `id: "conventions"` | `./bin/hoist-docs conventions` |
| Search symbols and members | `mcp__hoist-react__hoist-search-symbols` | `./bin/hoist-ts search "<query>"` |
| Get symbol details | `mcp__hoist-react__hoist-get-symbol` | `./bin/hoist-ts symbol <name>` |
| List members | `mcp__hoist-react__hoist-get-members` | `./bin/hoist-ts members <name>` |

`hoist-read-doc` accepts a canonical id such as `cmp/grid/README.md` and short forms such as `cmp/grid`, `grid`, or `v87` for upgrade notes. If it is not in your tool list (it arrived in `@xh/hoist` v86), read the doc with the CLI, or `Read` the file under `client-app/node_modules/@xh/hoist/`.

The tools describe themselves. Each `@xh/hoist` version ships its own MCP server, so read the tool descriptions and result text for what the installed version can do, and branch on that rather than on a version number.

## Retrieval workflow

Each rule below removes a lookup that agents often waste. Apply them in this order.

- **Search once, then read one thing.** Run `hoist-search-docs` with two or three keywords. If the results are sections (each shows a section path and a token count), read the best one with `hoist-read-doc` and its `section`; use `outline: true` to pick a section in a large doc. If the results are whole docs, read the README for the area instead, for example `cmp/grid`, `data`, `format`, or `desktop/cmp/panel`. One README read answers several questions. Do not run a second search before you read.
- **Exact props: members on the interface.** Call `hoist-get-members` on the Props or Config interface, for example `GridConfig`, `PanelProps`, or `ColumnSpec`. Use `hoist-get-symbol` when you need a signature or JSDoc, not for a member list.
- **Symbol search: one strong keyword.** `hoist-search-symbols` matches every word of the query against names and JSDoc. `persistWith`, `confirm`, or `Select` beats a sentence. If you get zero results, remove words. Do not add them.
- **Imports: use the package barrel.** If a result shows an import path, use it. Otherwise import from `@xh/hoist/` plus the package in the results, shown as `package:` in text output and `sourcePackage` in structured output. If that folder is a sub-folder of a package, such as `renderers` or `impl`, import from the parent. Never import from a file path or an `impl` folder.
  - `cmp/grid/renderers` becomes `@xh/hoist/cmp/grid`
  - `desktop/cmp/panel` becomes `@xh/hoist/desktop/cmp/panel`
  - `utils/js` becomes `@xh/hoist/utils/js`
- **Inherited props: assume the standard ones.** A Props interface that extends a Blueprint or React type, such as `ButtonProps`, does not list the props it inherits, such as `onClick`. Assume the standard props exist. Do not search for them.
- **Budget: about six lookups before you write code.** If you pass it while you look up names one at a time, stop and read the README for the area.
- **Version: trust the installed one.** The local MCP and CLI describe the `@xh/hoist` version in `client-app/node_modules`. Docs on GitHub `develop` and the default Context7 entry can describe a different major. If they disagree with the installed version, read the upgrade notes for that major, for example `hoist-read-doc` with `id: "v87"`.

## Pitfalls

- **Config interface or model class.** `GridConfig` holds configuration options. `GridModel` holds runtime state. Call `hoist-get-members` on the one that answers your question.
- **Name collisions.** Some names exist in more than one package, for example `View` in `cmp/viewmanager` and `data/cube`. When the tool says so, pass `filePath` to pick one.
- **Reading framework source.** The reference tools show JSDoc and decorators more clearly than the source. Read the source only as a last resort.
- **Trusting training data.** Decorators change names and base classes move between versions. Check the API with the reference tools before you write it.

## CLI launchers

The CLI commands run through project-local launchers at `./bin/hoist-docs` and `./bin/hoist-ts`. Before the first CLI call in a session, run the preflight in [reference/cli-launchers.md](reference/cli-launchers.md). Skip it if you use MCP only. The same file has the install procedure for missing, stale, or broken launchers.

## When the tools are not available

If you have neither the `mcp__hoist-react__*` tools nor the CLI launchers:

1. If `client-app/package.json` lists `@xh/hoist`, install the launchers with [reference/cli-launchers.md](reference/cli-launchers.md#install). The CLI works in any environment, including one that blocks MCP.
2. If the project is not a Hoist app, stop and tell the user. Do not write Hoist API calls from training data. Prop names, decorators, and conventions change, and stale guesses cause bugs.
3. As a last resort, `Read` the package READMEs under `client-app/node_modules/@xh/hoist/`, for example `core/README.md`. Installing the launchers is the better fix.
