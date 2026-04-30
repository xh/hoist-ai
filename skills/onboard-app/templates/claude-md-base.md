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
XH.fetchJson({url: 'api/data'});            // FetchService alias
XH.getConf('featureFlag', false);            // ConfigService alias
XH.getPref('pageSize', 50);                  // PrefService alias
XH.<yourCustomService>.<yourMethodAsync>();  // Your app's services, registered during app init
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

## Hoist Reference Skills

When working with Hoist code, the `using-hoist-react-reference` and `using-hoist-core-reference`
skills (shipped by the `xh` Claude Code plugin) guide reference lookups. They fire
automatically when you're about to author Hoist code or ask for orientation, and route you to
the right MCP tool or CLI command. The hoist-core skill also fires on requests to install or
upgrade the hoist-core MCP+CLI tools. You don't need to invoke them manually.

Each skill has two interchangeable surfaces -- MCP tools (when MCP is enabled) and CLI
launchers (always available once installed). In MCP-blocked environments the CLI is the
working path; the skills route to it transparently. If neither surface is reachable, run
`/xh:onboard-app` to wire things up.

### hoist-core (server-side)

- Grails application with the `hoist-core` plugin providing server-side framework
- Controllers extend `BaseController`, services extend `BaseService`
- Server configuration managed via `configService` and the Admin UI config entries
- Groovy/Grails conventions: convention-over-configuration, GORM for persistence
- Dev server: `./gradlew bootRun`
- Production build: `./gradlew war`

For server-side work, the `using-hoist-core-reference` skill (see above) routes you to the
hoist-core developer tools. Two surfaces ship from the same fat JAR:

- **MCP tools** -- `mcp__hoist-core__*` when MCP is enabled (after running
  `installHoistCoreTools` and restarting Claude Code).
- **CLI launchers** -- `./bin/hoist-core-docs` and `./bin/hoist-core-symbols` once installed.
  These work in any environment, including MCP-blocked ones.

The hoist-core docs are also available via the public GitHub repository at
https://github.com/xh/hoist-core.

## Commands

### Frontend (run from `client-app/`)
- Install: `yarn install` (or `npm install`)
- Dev server: `yarn start` (or `npm start`)
- Lint: `yarn lint` (or `npm run lint`)
- Type check: `npx tsc --noEmit`

### Backend (run from project root)
- Dev server: `./gradlew bootRun`
- Production build: `./gradlew war`
