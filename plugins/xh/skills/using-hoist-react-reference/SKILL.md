---
name: using-hoist-react-reference
description: |
  Reference for the @xh/hoist React framework, for writing, changing, debugging, or explaining TypeScript/React code that touches Hoist, or answering how Hoist works. Why this matters: Hoist's API evolves, `*Config` interfaces look like React props but aren't, and `loadAsync`/`addReaction` differ from plain MobX. Guesses type-check, then fail at runtime: persistence no-ops, leaked autoruns, ignored props, state that never re-renders. TRIGGER on a Hoist symbol (`hoistCmp`, `HoistModel`, `HoistService`, `XH`, `Grid`, `Panel`, `Store`, `*Config`), decorator (`@bindable`, `@managed`, `@persist`), or concept (persistence, autorun, reaction, `loadAsync`, refresh, element factory); a `*Model.ts`/`*Panel.tsx` file; a `client-app/` change that adds or changes Hoist API usage; Hoist docs or conventions; "Hoist", "@xh/hoist", "our framework" in React/TS. SKIP for plain TypeScript, React, or MobX with no Hoist surface, config passed through Hoist to a third-party lib, and files outside `client-app/`.
allowed-tools: Read, Bash, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-read-doc, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-get-members
---

# Using Hoist React Reference

You are about to write or change code that uses the `@xh/hoist` framework. Look up the API with the reference tools before you write it. The Hoist API is large, and prop names and decorators are easy to misremember. A wrong guess compiles but fails at runtime.

## Routing table

Each step has an MCP tool and a CLI command. If the `hoist-react` MCP server's tools are in your tool context, use them. If not, use the CLI column. The MCP column gives the server's tool names. Some harnesses add a prefix, for example `mcp__hoist-react__hoist-read-doc` in Claude Code and Codex. The names are the same for a local server and a remote one.

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `hoist-search-docs` | `./bin/hoist-docs search "<query>"` |
| List docs by category | `hoist-list-docs` | `./bin/hoist-docs list -c <category>` |
| Read a doc | `hoist-read-doc` with `id: "<docId>"` | `./bin/hoist-docs read <docId>` |
| Read the docs index | `hoist-read-doc` with `id: "index"` | `./bin/hoist-docs index` |
| Read coding conventions | `hoist-read-doc` with `id: "conventions"` | `./bin/hoist-docs conventions` |
| Search symbols and members | `hoist-search-symbols` | `./bin/hoist-ts search "<query>"` |
| Get symbol details | `hoist-get-symbol` | `./bin/hoist-ts symbol <name>` |
| List members | `hoist-get-members` | `./bin/hoist-ts members <name>` |

`hoist-read-doc` accepts a canonical id such as `cmp/grid/README.md` and short forms such as `cmp/grid`, `grid`, or `v87` for upgrade notes. If it is not in your tool list (it arrived in `@xh/hoist` v86), read the doc with the CLI, or read the file under `client-app/node_modules/@xh/hoist/`.

The tools describe themselves. Each `@xh/hoist` version ships its own MCP server, so read the tool descriptions and result text for what the installed version can do, and branch on that rather than on a version number.

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
- **Version: trust the installed one.** The local MCP and CLI describe the `@xh/hoist` version in `client-app/node_modules`. Docs on GitHub `develop` and the default Context7 entry can describe a different major. If they disagree with the installed version, read the upgrade notes for that major, for example `hoist-read-doc` with `id: "v87"`. The MCP server reads the installed version when it starts. After `@xh/hoist` is installed or upgraded in this session, use the CLI, which reads it on each call, until the server is reconnected, for example with `/mcp` in Claude Code, or in a new agent session.

## Pitfalls

- **Config interface or model class.** `GridConfig` holds configuration options. `GridModel` holds runtime state. Call `hoist-get-members` on the one that answers your question.
- **Name collisions.** Some names exist in more than one package, for example `View` in `cmp/viewmanager` and `data/cube`. When the tool says so, pass `filePath` to pick one.
- **Reading framework source.** The reference tools show JSDoc and decorators more clearly than the source. Read the source only as a last resort.
- **Decorator syntax.** Write new fields in the form the app's existing models and the installed `conventions` doc use, for example whether `@observable` and `@bindable` fields take `accessor`. Older Hoist code in your training data uses a different form, and a field in the wrong form can compile and still not react.
- **Trusting training data.** Decorators change names and base classes move between versions. Check the API with the reference tools before you write it.

## CLI launchers

The CLI commands run through project-local launchers at `./bin/hoist-docs` and `./bin/hoist-ts`. Before the first CLI call in a session, run the preflight in [reference/cli-launchers.md](reference/cli-launchers.md). Skip it if you use MCP only. The same file has the install procedure for missing, stale, or broken launchers.

## When the tools are not available

If you have neither the hoist-react MCP tools nor the CLI launchers:

1. If `client-app/package.json` lists `@xh/hoist`, install the launchers with [reference/cli-launchers.md](reference/cli-launchers.md#install). The CLI works in any environment, including one that blocks MCP.
2. If the project is not a Hoist app, stop and tell the user. Do not write Hoist API calls from training data. Prop names, decorators, and conventions change, and stale guesses cause bugs.
3. As a last resort, read the package READMEs under `client-app/node_modules/@xh/hoist/`, for example `core/README.md`. Installing the launchers is the better fix.
