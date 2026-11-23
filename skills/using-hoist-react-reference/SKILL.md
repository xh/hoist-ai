---
name: using-hoist-react-reference
description: |
  Authoritative reference for the @xh/hoist React framework - use when writing, modifying, debugging, or explaining TypeScript/React code that touches Hoist, or when answering how Hoist works. Why this matters: Hoist's API evolves; decorator names shift between versions, `*Config` interfaces look like plain React props but aren't, and `loadAsync`/`addAutorun`/`addReaction` differ from plain MobX. Guessing produces code that type-checks but fails at runtime: silent persistence no-ops, leaked autoruns, ignored props, observable state that never re-renders. TRIGGER when the user mentions a Hoist symbol (`hoistCmp`, `HoistModel`, `HoistService`, `XH`, `Grid`, `Panel`, `TabContainer`, `Store`, `*Config`); a Hoist decorator (`@bindable`, `@managed`, `@persist`, etc.); a Hoist concept (persistence, autorun, reaction, `loadAsync`, refresh, element factory, MobX integration, grid columns); a `*Model.ts`/`*Panel.tsx` file with state/refresh/persistence/grid questions; a change under `client-app/` that introduces or modifies Hoist API usage - NOT config-only refactors passing values through a Hoist component to a third-party lib (Highcharts, AG-Grid); Hoist docs/orientation/conventions; "Hoist"/"@xh/hoist"/"our framework"/"our app" in any React/TS context. SKIP for plain TypeScript with no Hoist surface, pure React/MobX without Hoist primitives, and files outside `client-app/`. Reach for the reference tools (MCP `mcp__hoist-docs__*`, or before v91 `mcp__hoist-react__*` or CLI `./bin/hoist-docs`/`./bin/hoist-ts`) first.
allowed-tools: Read, Bash, mcp__hoist-docs__hoist-ping, mcp__hoist-docs__hoist-search-docs, mcp__hoist-docs__hoist-list-docs, mcp__hoist-docs__hoist-read-doc, mcp__hoist-docs__hoist-search-symbols, mcp__hoist-docs__hoist-get-symbol, mcp__hoist-docs__hoist-get-members, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-read-doc, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-get-members
---

# Using Hoist React Reference

You are about to write or change code that uses the `@xh/hoist` framework. Look up the API with the reference tools before you write it. The Hoist API is large, and prop names and decorators are easy to misremember. A wrong guess compiles but fails at runtime.

## Routing table

The reference tools come from one of two places, depending on the installed `@xh/hoist`:

- **Hoist Docs** (`@xh/hoist` v91 and later). One MCP server, `hoist-docs`, from the app's `@xh/hoist-docs` dev dependency. It serves hoist-react, hoist-core and Hoist Chat Kit. Its tools are `mcp__hoist-docs__*`. Pass `library: "react"` to keep a call to hoist-react.
- **Bundled tools** (before v91). `@xh/hoist` ships its own MCP server, `mcp__hoist-react__*`, and the CLI launchers `./bin/hoist-docs` and `./bin/hoist-ts`.

Use whichever MCP tools are in your tool context. The tool names after the prefix are the same. If neither set is there, use the CLI column, which exists only before v91.

| Step | MCP tool | CLI command (before v91) |
|---|---|---|
| Search docs | `hoist-search-docs` | `./bin/hoist-docs search "<query>"` |
| List docs by category | `hoist-list-docs` | `./bin/hoist-docs list -c <category>` |
| Read a doc | `hoist-read-doc` with `id: "<docId>"` | `./bin/hoist-docs read <docId>` |
| Read the docs index | `hoist-read-doc` with `id: "index"` | `./bin/hoist-docs index` |
| Read coding conventions | `hoist-read-doc` with `id: "conventions"` | `./bin/hoist-docs conventions` |
| Search symbols and members | `hoist-search-symbols` | `./bin/hoist-ts search "<query>"` |
| Get symbol details | `hoist-get-symbol` | `./bin/hoist-ts symbol <name>` |
| List members | `hoist-get-members` | `./bin/hoist-ts members <name>` |
| Check the server and versions | `hoist-ping` | `./bin/hoist-docs --help` |

`hoist-read-doc` accepts a canonical id such as `cmp/grid/README.md` and short forms such as `cmp/grid`, `grid`, or `v87` for upgrade notes. If it is not in your tool list (it arrived in `@xh/hoist` v86), read the doc with the CLI, or `Read` the file under `client-app/node_modules/@xh/hoist/`.

The tools describe themselves. Read the tool descriptions and result text for what the installed version can do, and branch on that rather than on a version number.

## Retrieval workflow

Each rule below removes a lookup that agents often waste. Apply them in this order.

- **Search once, then read one thing.** Run `hoist-search-docs` with two or three keywords. If the results are sections (each shows a section path and a token count), read the best one with `hoist-read-doc` and its `section`; use `outline: true` to pick a section in a large doc. If the results are whole docs, read the README for the area instead, for example `cmp/grid`, `data`, `format`, or `desktop/cmp/panel`. One README read answers several questions. Do not run a second search before you read.
- **Exact props: members on the interface.** Call `hoist-get-members` on the Props or Config interface, for example `GridConfig`, `PanelProps`, or `ColumnSpec`. If the tool offers a `filter`, use it on a large class (`GridModel` with `col`) instead of reading every member. Use `hoist-get-symbol` for a signature or JSDoc; if its result includes a member summary, that is often enough to write the code.
- **Symbol search: one strong keyword.** `persistWith`, `confirm`, or `Select` beats a sentence, and a camelCase name also finds text about its parts. If you get zero results, remove words. Do not add them. A hit that names its owner (`XHApi.confirm`) tells you which class or config to read next.
- **Imports: use the package barrel.** If a result shows an import path, use it. Otherwise import from `@xh/hoist/` plus the package in the results, shown as `package:` in text output and `sourcePackage` in structured output. If that folder is a sub-folder of a package, such as `renderers` or `impl`, import from the parent. Never import from a file path or an `impl` folder.
  - `cmp/grid/renderers` becomes `@xh/hoist/cmp/grid`
  - `desktop/cmp/panel` becomes `@xh/hoist/desktop/cmp/panel`
  - `utils/js` becomes `@xh/hoist/utils/js`
- **Inherited props: assume the standard ones.** A Props interface that extends a Blueprint or React type, such as `ButtonProps`, does not list the props it inherits, such as `onClick`. Assume the standard props exist. Do not search for them.
- **Budget: about six lookups before you write code.** If you pass it while you look up names one at a time, stop and read the README for the area.
- **Version: trust the installed one.** The MCP server and CLI describe the `@xh/hoist` version in `client-app/node_modules`. Docs on GitHub `develop` and the default Context7 entry can describe a different major. If they disagree with the installed version, read the upgrade notes for that major, for example `hoist-read-doc` with `id: "v87"`. The MCP server reads the installed version when it starts. After `@xh/hoist` is installed or upgraded in this session, its answers describe the old version until the server is reconnected with `/mcp`. Until then, `Read` the docs under `client-app/node_modules/@xh/hoist/`, or use the CLI before v91, which reads the installed version on each call.

## Pitfalls

- **Config interface or model class.** `GridConfig` holds configuration options. `GridModel` holds runtime state. Call `hoist-get-members` on the one that answers your question.
- **Name collisions.** Some names exist in more than one package, for example `View` in `cmp/viewmanager` and `data/cube`. When the tool says so, pass `filePath` to pick one. Hoist Docs also notes a name that exists in another library, such as `Timer` in hoist-core. Pass `library: "react"` for client code.
- **Reading framework source.** The reference tools show JSDoc and decorators more clearly than the source. Read the source only as a last resort.
- **Decorator syntax.** Write new fields in the form the app's existing models and the installed `conventions` doc use, for example whether `@observable` and `@bindable` fields take `accessor`. Older Hoist code in your training data uses a different form, and a field in the wrong form can compile and still not react.
- **Trusting training data.** Decorators change names and base classes move between versions. Check the API with the reference tools before you write it.

## CLI launchers (before v91)

Before `@xh/hoist` v91, the CLI commands run through project-local launchers at `./bin/hoist-docs` and `./bin/hoist-ts`. Before the first CLI call in a session, run the preflight in [reference/cli-launchers.md](reference/cli-launchers.md). Skip it if you use MCP only. The same file has the install procedure for missing, stale, or broken launchers.

From v91 there is no CLI, and the launchers break: `bin/hoist-docs` would start the Hoist Docs MCP server instead. If `client-app/node_modules/@xh/hoist/package.json` has a `hoistDocs` key, the app is on v91 or later. Do not install the launchers there. If the launchers or a `hoist-react` entry in `.mcp.json` remain, offer to run `/xh:onboard-app`. It moves the app to Hoist Docs and removes the old entry, launchers and permissions.

## When the tools are not available

If no reference tools are in your context:

1. If the project is not a Hoist app, stop and tell the user. Do not write Hoist API calls from training data. Prop names, decorators, and conventions change, and stale guesses cause bugs.
2. On `@xh/hoist` v91 or later (its `package.json` has a `hoistDocs` key), Hoist Docs is not set up yet, or MCP is blocked. If `.mcp.json` has no `hoist-docs` entry, offer to run `/xh:onboard-app`, which adds the `@xh/hoist-docs` dev dependency and the entry. If the entry exists, the server needs a restart of Claude Code, or the environment blocks MCP.
3. Before v91, install the CLI launchers with [reference/cli-launchers.md](reference/cli-launchers.md#install). The CLI works in any environment, including one that blocks MCP.
4. Without either, `Read` the docs that ship in the package: `client-app/node_modules/@xh/hoist/docs/` and the package READMEs, for example `core/README.md` and `cmp/grid/README.md`. `docs/README.md` there is the index.
