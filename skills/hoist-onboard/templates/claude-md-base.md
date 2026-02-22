# Hoist Application

This is a Hoist application built on `@xh/hoist` {{HOIST_VERSION}} with React and MobX state management.

## Architecture

- **Components**: Use `hoistCmp.factory()` element factories, NOT JSX
- **Models**: Extend `HoistModel`, call `makeObservable(this)` in constructor
- **Services**: Extend `HoistService`, access via `XH.myService`
- **XH singleton**: Top-level API for services, configuration, and utilities

## Key Conventions

- Element factories over JSX: `panel({items: [grid(), button({text: 'Save'})]})`
- `@managed` decorator on child `HoistBase` instances for lifecycle cleanup
- `@observable` / `@bindable` for reactive state, `@computed` for derived values
- `makeObservable(this)` required in constructor when declaring new observables
- Async methods use `*Async` suffix (e.g. `loadDataAsync`)
- `addAutorun()` / `addReaction()` for managed MobX subscriptions

## Commands

- Install: `yarn`
- Dev server: `yarn start`
- Lint: `yarn lint`
- Type check: `npx tsc --noEmit`

## MCP Server

The Hoist MCP server provides framework documentation and API lookup when available.
Use these tools to look up Hoist conventions rather than guessing:

- `hoist-search-docs` -- search framework documentation by keyword
- `hoist-search-symbols` -- find TypeScript types and API signatures
- `hoist-list-docs` -- browse available documentation by category
- `hoist-get-symbol` -- get full type details for a specific symbol
