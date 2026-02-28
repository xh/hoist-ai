# Hoist Application

This is a Hoist application built on `@xh/hoist` (hoist-react) and `hoist-core`.

## Hoist Framework Documentation — READ THIS FIRST

### hoist-react (client-side)

Read the Architecture Primer below, then use the MCP tools for full documentation on any topic.

#### Architecture Primer

Hoist applications are built around three artifact types:

| Artifact | Base Class | Purpose | Lifecycle |
|----------|------------|---------|-----------|
| **Component** | `hoistCmp.factory` | UI rendering (React) | Transient — mount/unmount with views |
| **Model** | `HoistModel` | Observable state + business logic | Varies — linked to component or standalone |
| **Service** | `HoistService` | App-wide data access + shared state | Singleton — lives for app lifetime |

**Element factories over JSX.** Hoist uses element factory functions, not JSX:
```typescript
// ✅ Hoist style
panel({title: 'Users', items: [grid(), button({text: 'Refresh'})]})

// ❌ Not used in Hoist
<Panel title="Users"><Grid /><Button text="Refresh" /></Panel>
```

**Components** are created with `hoistCmp.factory`. Each component declares its model relationship:
```typescript
export const userList = hoistCmp.factory({
    model: creates(UserListModel),  // Component creates and owns this model
    render({model}) {
        return panel({title: 'Users', item: grid()});
    }
});
```

**Model wiring — `creates()` vs `uses()`:**
- `creates(ModelClass)` — component instantiates, owns, and destroys the model on unmount.
- `uses(ModelClass)` — component receives model from a parent via context or explicit prop.

**Context-based model lookup** eliminates prop drilling. When a component `creates()` a model, that
model is published to React context. Child components using `uses(ModelClass)` automatically find
the nearest matching model in the ancestor tree. All public properties of ancestor models are
searched — so if `PanelModel` has a `gridModel: GridModel` property, a child `grid()` call
resolves it automatically. (Note: `@managed` is unrelated to lookup — it controls cleanup on
destroy. A property does not need `@managed` to be found via context lookup.)

When multiple models of the same type exist in context (e.g. two `GridModel` instances), pass the
model explicitly: `grid({model: model.leftGridModel})`.

**HoistModel** — the core state holder:
```typescript
class UserListModel extends HoistModel {
    @observable.ref users: User[] = [];
    @bindable selectedUserId: string = null;
    @managed detailModel = new UserDetailModel();

    constructor() {
        super();
        makeObservable(this);  // Required when class adds new observables
    }

    override async doLoadAsync(loadSpec: LoadSpec) {
        const users = await XH.fetchJson({url: 'api/users', loadSpec});
        runInAction(() => this.users = users);
    }
}
```

**Key decorators:**

| Decorator | Purpose |
|-----------|---------|
| `@observable` / `@observable.ref` | MobX observable state |
| `@bindable` | Observable + auto-generated action-wrapped setter |
| `@managed` | Mark child object for automatic cleanup on `destroy()` |
| `@persist` | Sync property with a persistence provider (requires `persistWith`) |
| `@lookup(ModelClass)` | Inject ancestor model (linked models only, available after `onLinked`) |
| `@computed` | Cached derived value |
| `@action` | Mark method as state-modifying |

**`makeObservable(this)`** must be called in the constructor of any class that introduces new
`@observable`, `@bindable`, or `@computed` properties. The base class call does not cover subclass
decorators. Forgetting this is the most common Hoist bug.

**`doLoadAsync(loadSpec)`** — implement this template method to opt into managed data loading.
Call `model.loadAsync()` or `model.refreshAsync()` to trigger — never call `doLoadAsync` directly.
Linked models with `doLoadAsync` are loaded automatically on mount.

**HoistService** — singleton services installed during app init and accessed via `XH`:
```typescript
XH.tradeService.submitTradeAsync(trade);  // Custom service
XH.fetchJson({url: 'api/data'});          // FetchService alias
XH.getConf('featureFlag', false);         // ConfigService alias
XH.getPref('pageSize', 50);              // PrefService alias
```

**XH singleton** — the top-level API entry point. Provides service access, data fetching
(`fetchJson`, `postJson`), user interaction (`toast`, `confirm`, `prompt`, `handleException`),
navigation (`navigate`, `appendRoute`), and app state (`appState`, `darkTheme`).

**Critical pitfalls:**
1. **Forgetting `makeObservable(this)`** — observables silently won't react.
2. **Managing objects you don't own** — only `@managed` objects your class creates. Objects passed
   in from outside are owned by the provider.
3. **Mutating observables outside actions** — use `runInAction()`, `@action`, or `@bindable`.
4. **Calling `lookupModel()` too early** — only works during or after `onLinked()`.
5. **Calling `doLoadAsync()` directly** — use `loadAsync()` / `refreshAsync()` entry points.

#### Quick Reference — MCP Doc IDs by Task

Use `hoist-search-docs` with the doc ID for full documentation on any topic.

| If you need to... | Doc ID |
|---|---|
| Understand the component/model/service pattern | `core` |
| Work with Stores, Records, Fields, or Filters | `data` |
| Fetch data, read configuration, or manage preferences | `svc` |
| Build or configure a data grid | `cmp/grid` |
| Build a form with validation | `cmp/form` |
| Understand input change/commit lifecycle | `cmp/input` |
| Use layout containers (Box, HBox, VBox) | `cmp/layout` |
| Create a tabbed interface | `cmp/tab` |
| Save and restore named view configurations | `cmp/viewmanager` |
| Build a configurable dashboard with draggable widgets | `desktop/cmp/dash` |
| Configure a desktop panel (toolbars, masks, collapse) | `desktop/cmp/panel` |
| Build a mobile app | `mobile` |
| Format numbers, dates, or currencies | `format` |
| Understand app lifecycle and startup sequence | `lifecycle-app` |
| Understand model/service lifecycles and loading | `lifecycle-models-and-services` |
| Add authentication (OAuth, login) | `authentication` |
| Persist UI state (columns, filters, panel sizes) | `persistence` |
| Check roles, gates, or app access | `authorization` |
| Configure client-side routing | `routing` |
| Handle exceptions and display errors | `error-handling` |
| Add testId selectors for test automation | `test-automation` |
| Use Promises with error handling and tracking | `promise` |
| Work with MobX observables and `@bindable` | `mobx` |
| Use timers, decorators, or utility functions | `utils` |
| Configure the app shell, dialogs, toasts, or theming | `appcontainer` |
| Use icons in buttons, menus, and grids | `icon` |
| Configure OAuth with Auth0 or Microsoft Entra | `security` |

#### MCP Tools

For full documentation beyond this primer, use the hoist-react MCP tools:

- **`hoist-search-docs`** — keyword search across all docs; use doc IDs from the table above
- **`hoist-search-symbols`** — search TypeScript symbols, classes, and API signatures
- **`hoist-list-docs`** — browse the complete documentation catalog
- **`hoist-get-symbol`** / **`hoist-get-members`** — detailed type info for specific classes

**Skipping the docs risks producing code that conflicts with established patterns or misses
built-in functionality.**

### hoist-core (server-side)

- Grails application with the `hoist-core` plugin providing server-side framework
- Controllers extend `BaseController`, services extend `BaseService`
- Server configuration managed via `configService` and the Admin UI config entries
- Groovy/Grails conventions: convention-over-configuration, GORM for persistence
- Dev server: `./gradlew bootRun`
- Production build: `./gradlew war`

The hoist-core repository contains a growing `docs/` directory with documentation on server-side
architecture, services, and conventions. Consult these docs via the public GitHub repository at
https://github.com/xh/hoist-core for specific guidance on server-side work.

## Commands

### Frontend (run from `client-app/`)
- Install: `yarn install` (or `npm install`)
- Dev server: `yarn start` (or `npm start`)
- Lint: `yarn lint` (or `npm run lint`)
- Type check: `npx tsc --noEmit`

### Backend (run from project root)
- Dev server: `./gradlew bootRun`
- Production build: `./gradlew war`
