---
name: using-hoist-react-reference
description: |
  Authoritative reference for the @xh/hoist React framework -- use when about to write, modify, debug, or explain TypeScript/React code that touches Hoist, or to answer how Hoist (or "our framework"/"our app") works in the React/TS layer.
  Why this matters: Hoist's API evolves -- decorator names and semantics shift between versions, `*Config` interfaces (`GridConfig`, `PanelConfig`) look like plain React props but aren't, and `loadAsync`/`addAutorun`/`addReaction` patterns differ from plain MobX. Guessing from training-data recall produces code that type-checks and compiles but fails at runtime: silent persistence no-ops, leaked autoruns, props that get ignored, observable state that never re-renders.
  TRIGGER when the user mentions: any Hoist symbol or decorator (`hoistCmp`, `HoistModel`, `HoistService`, `XH`, `Grid`, `GridConfig`, `Panel`, `TabContainer`, `FormPanel`, `DashContainer`, `Store`, `@bindable`, `@managed`, `@observable`, `@action`, `@computed`, `@persist`); a Hoist concept (persistence, autorun, reaction, `loadAsync`, refresh, element factory, MobX integration, model lifecycle, grid columns, dashboard, framework conventions, validation); a model/panel file (`*Model.ts`, `*Panel.tsx`) with state/refresh/persistence/validation/grid-column questions; a change under `client-app/` that introduces or modifies Hoist API usage (importing from `@xh/hoist`, extending a Hoist class, calling `XH.*`) -- NOT config-only refactors that just pass values through a Hoist component to a third-party lib like Highcharts or AG-Grid; Hoist docs, orientation, or coding conventions; "Hoist", "@xh/hoist", "our framework", or "our app" in any React/TypeScript context.
  SKIP for plain TypeScript with no Hoist surface (utility refactors, type fixes, generics, `tsconfig.json`, `package.json`, lint config), pure React/MobX questions without Hoist primitives, and files outside `client-app/`.
  Reach for the reference tools (MCP `mcp__hoist-react__*` or CLI `./bin/hoist-docs` / `./bin/hoist-ts`) first.
allowed-tools: Read, Bash, mcp__hoist-react__hoist-ping, mcp__hoist-react__hoist-search-docs, mcp__hoist-react__hoist-list-docs, mcp__hoist-react__hoist-search-symbols, mcp__hoist-react__hoist-get-symbol, mcp__hoist-react__hoist-get-members
---

# Using Hoist React Reference

You're about to write or modify code that consumes the `@xh/hoist` framework. Consult the reference tools before authoring - Hoist's API surface is large, prop names and decorators are easy to misremember, and a wrong guess produces code that compiles but fails at runtime.

## Routing table

Each workflow step has two interfaces. Use the column that matches what's in your tool context.

| Step | MCP tool | CLI command |
|---|---|---|
| Search docs | `mcp__hoist-react__hoist-search-docs` | `./bin/hoist-docs search "<query>"` |
| List docs by category | `mcp__hoist-react__hoist-list-docs` | `./bin/hoist-docs list -c <category>` |
| Read a specific doc | `mcp__hoist-react__hoist-search-docs` (with id query) | `./bin/hoist-docs read <docId>` |
| Search symbols / members | `mcp__hoist-react__hoist-search-symbols` | `./bin/hoist-ts search "<query>"` |
| Get symbol details | `mcp__hoist-react__hoist-get-symbol` | `./bin/hoist-ts symbol <name>` |
| List class members | `mcp__hoist-react__hoist-get-members` | `./bin/hoist-ts members <name>` |

If `mcp__hoist-react__*` tools are listed in your tool context, prefer them. Otherwise use the CLI column. The MCP tool names look the same regardless of whether the server is running locally or as a deployed remote endpoint - transport is invisible to you.

The CLI launchers are project-local thin wrappers at `<project>/bin/hoist-docs` and `<project>/bin/hoist-ts`. They exec the `@xh/hoist`-provided binaries through `client-app/node_modules/.bin/`, so the consumer doesn't need to know where the frontend tree lives or change directories. Always invoke them as `./bin/hoist-...` from the app project root.

## Preflight (do once per session before first CLI use)

Skip this if you're working through MCP only. For the CLI surface, before the first `./bin/hoist-docs` or `./bin/hoist-ts` call in a session, verify the launchers are present, current, and functional:

1. Check that `./bin/hoist-docs` and `./bin/hoist-ts` exist at the project root.
2. Read the first 3 lines of each. The second line should be exactly:

       # hoist-ai-launcher: hoist-react/v2

3. Functional smoke check -- invoke one launcher and confirm it resolves its target. Run:

       ./bin/hoist-docs --help

   Exit 0 with help/usage output is success. Exit non-zero with `No such file or directory` in stderr means the launcher's path resolution is broken (most often the `$0` literal was lost in transit and `dirname ""` resolves to `.`, sending the exec target one level above the project root). Treat this the same as a missing-or-stale-stamp case.

If any check fails, jump to **[Installing the CLI launchers](#installing-the-cli-launchers)**, follow it end to end (it's idempotent -- safe to re-run), then return here. Briefly mention the refresh in your next user-facing message (e.g. "refreshed hoist-react launchers to v2").

The preflight runs once per session -- once you've confirmed (or fixed) the launchers, you don't need to re-check on every CLI call.

## Workflow

Standard sequence for any Hoist authoring task:

1. **Index first.** Read the docs index (`mcp__hoist-react__hoist-list-docs`, `mcp__hoist-react__hoist-search-docs` with a broad query, or `./bin/hoist-docs index`) when you're new to the area. Find the right README.
2. **Search docs** for context on conventions, architecture, common pitfalls in the area you're touching.
3. **Search symbols** for specific class/method/decorator names. Multi-word queries are AND-matched against names AND JSDoc - `"panel modal"` finds `ModalSupportModel` via its JSDoc.
4. **Drill** with `get-symbol` for full details, or `get-members` to list a class's properties and methods with types and decorators.
5. **Disambiguate** by passing `filePath` when symbol names collide (e.g. `View` exists in both `cmp/viewmanager` and `data/cube`).

## Common queries

**Look up a component's available props.**
- MCP: `mcp__hoist-react__hoist-get-members` with `name: "GridConfig"` (or whatever `*Config` interface fronts the component).
- CLI: `./bin/hoist-ts members GridConfig`

**Find which decorator a model property uses.**
- MCP: `mcp__hoist-react__hoist-get-members` with `name: "<MyModelClass>"`.
- CLI: `./bin/hoist-ts members <MyModelClass>`

**Look up a service method by behavior, not name.**
- MCP: `mcp__hoist-react__hoist-search-symbols` with `query: "fetch loadConfigs"` (multi-word AND match against names + JSDoc).
- CLI: `./bin/hoist-ts search "fetch loadConfigs"`

**Find the convention for something cross-cutting (persistence, theming, lifecycle).**
- MCP: `mcp__hoist-react__hoist-search-docs` with `query: "persistence MobX integration"`.
- CLI: `./bin/hoist-docs search "persistence MobX integration"`

**Read the docs index.**
- MCP: `mcp__hoist-react__hoist-list-docs` (or `hoist-search-docs` with a broad query).
- CLI: `./bin/hoist-docs index` (shorthand for `read docs/README.md`).

**Print coding conventions.**
- MCP: `mcp__hoist-react__hoist-search-docs` with `query: "coding conventions"` then read the matching id.
- CLI: `./bin/hoist-docs conventions`

## Common pitfalls

- **Searching by display name, not symbol name.** Querying `"modal"` may miss the answer. Use multi-word queries that include behavior keywords (`"panel modal"`) - JSDoc matching surfaces symbols whose names don't include the term.
- **Confusing a `*Config` interface with its consuming class.** `GridModel` (the class) and `GridConfig` (its config interface) both exist. `GridModel`'s properties are runtime state; `GridConfig`'s are configuration knobs. Use `members` on whichever you actually need - they answer different questions.
- **Symbol disambiguation.** When `search-symbols` returns multiple matches with the same name (e.g. `View` in `cmp/viewmanager` AND `data/cube`), the tool will hint that you should pass a file path. Do so.
- **Falling back to `Read` on framework source.** If the reference tools answer the question, prefer them - they expose JSDoc and decorator info more cleanly than reading source. Read the source only as a last resort.
- **Trusting training data.** Hoist's API has evolved. Decorators have changed names, base classes have moved. Always verify with the reference tools before authoring.

## Installing the CLI launchers

Trigger this section when:

- The preflight above found the launchers missing or stamped at the wrong version.
- The user explicitly asks to install, set up, or refresh the hoist-react CLI launchers.
- You attempted a CLI call and saw "no such file or directory" or a stale stamp.

The launchers are short shell scripts that exec the `@xh/hoist`-provided binaries through the npm `node_modules/.bin/` symlinks. They live at the project root so they're invocable from the harness's default working directory with no `cd` required.

### Prerequisites

- App is a Hoist project: `client-app/package.json` lists `@xh/hoist` (direct or transitive).
- `client-app/node_modules` is populated (i.e. `yarn install` or `npm install` has been run from `client-app/`). The launchers themselves write fine without this, but they'll fail at runtime until packages are installed.

If `node_modules` is missing, surface that to the user as a separate prerequisite step — don't skip the launcher install on its account, the two are independent.

### Procedure

The canonical launcher content lives in two template files shipped alongside this SKILL.md, at `templates/hoist-docs` and `templates/hoist-ts`. Copy them byte-for-byte into the project's `bin/` rather than transcribing their content -- nested-double-quoted shell expansions like `"$(dirname "$0")"` can be mangled when content round-trips through serialization layers (the `$0` literal has been observed disappearing in some skill-loading paths), and a byte-copy sidesteps that risk entirely.

1. Use `Glob` with pattern `**/using-hoist-react-reference/templates/hoist-docs` to locate the template directory on disk. The match path's parent is `<plugin-cache>/.../using-hoist-react-reference/templates/` -- both launchers live there.

2. Use `Bash` to copy the templates into the project's `bin/` and mark them executable:

       mkdir -p bin
       cp "<templates-dir>/hoist-docs" bin/hoist-docs
       cp "<templates-dir>/hoist-ts" bin/hoist-ts
       chmod +x bin/hoist-docs bin/hoist-ts

   Substitute `<templates-dir>` with the directory path you got from the Glob result. Do **not** use `Read` + `Write` to copy content -- that path serializes the file body through tooling that can mangle nested-quoted shell content. `cp` is byte-exact.

3. Verify what landed:

       grep -F '$0' bin/hoist-docs && grep -F '$0' bin/hoist-ts

   Both should match. If either doesn't, the copy didn't preserve the literal `$0` and the launcher is broken; do not proceed.

The templates are canonical for `hoist-react/v2`. If on-disk launchers exist but differ from the templates (different stamp version, missing `$0`, or any other delta), overwrite them -- the launcher is regenerated deterministically and there's no manual-edit case to preserve.

### Verification

```bash
./bin/hoist-docs --help
./bin/hoist-docs index
./bin/hoist-ts members GridConfig
```

`--help` is the launcher-resolution smoke check: exit 0 with usage output means the launcher's path math is working. `No such file or directory` from `--help` means the launcher itself is broken (typically the `$0` literal was lost during copy -- redo the procedure with `Bash cp` rather than `Read`+`Write`). If `--help` works but `index` / `members` fail with "command not found" or similar from the `node_modules/.bin/` target, the `client-app/node_modules` install hasn't been run.

### .gitignore

The launchers are deterministic from this skill's canonical content. Two valid stances:

- **Track them in git** (recommended for teams that want fresh clones to work out of the box). New checkouts have working launchers immediately, and the preflight is a no-op until the stamp version bumps.
- **Ignore them** (`bin/hoist-docs` and `bin/hoist-ts` in `.gitignore`). Each fresh checkout's first agent invocation triggers the preflight, which installs them on demand.

Either is fine — the preflight handles both states identically.

## When the tools aren't available

If neither the MCP tools (`mcp__hoist-react__*`) nor the CLI launchers (`./bin/hoist-docs`, `./bin/hoist-ts`) are present in your context:

1. **Default action.** If the project is a Hoist app (has `@xh/hoist` installed in `client-app/`), jump to **[Installing the CLI launchers](#installing-the-cli-launchers)** above and install them. The CLI works in any environment, including MCP-blocked ones, and is the recommended first move.
2. If the project doesn't appear to be a Hoist app, stop and tell the user. Do not improvise Hoist APIs from training data — prop names, decorators, and conventions evolve, and stale guesses produce real bugs.
3. As a last resort, if `@xh/hoist` is installed locally, you may use `Read` on its package READMEs (e.g. `client-app/node_modules/@xh/hoist/core/README.md`) — but the recommended fix is to install the launchers via the procedure above.
