# Hoist Application

This is a Hoist application built on `@xh/hoist` (hoist-react) and `hoist-core`.

## Hoist Framework Documentation - READ THIS FIRST

### hoist-react (client-side)

Read the Architecture Primer below. Then use the MCP tools for full documentation on any topic. In MCP-blocked environments, use the `./bin/hoist-docs` and `./bin/hoist-ts` CLI launchers instead. The `using-hoist-react-reference` skill loads itself when you author Hoist code and routes you to the right surface.

#### Architecture Primer

A Hoist application has three artifact types:

| Artifact | Base Class | Purpose | Lifecycle |
|----------|------------|---------|-----------|
| **Component** | `hoistCmp.factory` | UI rendering (React) | Transient - mounts and unmounts with views |
| **Model** | `HoistModel` | Observable state + business logic | Varies - linked to a component, or standalone |
| **Service** | `HoistService` | App-wide data access + shared state | Singleton - lives for the app lifetime |

**Element factories over JSX.** Hoist uses element factory functions, not JSX:
```typescript
// ✅ Hoist style
panel({title: 'Users', items: [grid(), button({text: 'Refresh'})]})

// ❌ Not used in Hoist
<Panel title="Users"><Grid /><Button text="Refresh" /></Panel>
```

**Components.** Create a component with `hoistCmp.factory`. Each component declares its model relationship:
```typescript
export const userList = hoistCmp.factory({
    model: creates(UserListModel),  // Component creates and owns this model
    render({model}) {
        return panel({title: 'Users', item: grid()});
    }
});
```

**Model wiring: `creates()` vs `uses()`**
- `creates(ModelClass)`: the component instantiates, owns, and destroys the model on unmount.
- `uses(ModelClass)`: the component receives the model from a parent, via context or an explicit prop.

**Context-based model lookup** eliminates prop drilling. When a component `creates()` a model,
Hoist publishes that model to React context. A child component that calls `uses(ModelClass)` finds
the nearest matching model in the ancestor tree. The lookup searches all public properties of
ancestor models. If `PanelModel` has a `gridModel: GridModel` property, a child `grid()` call
resolves it.

`@managed` does not affect lookup. It controls cleanup on destroy, and lookup finds a property with
or without it.

When context holds more than one model of the same type, for example two `GridModel` instances,
pass the model explicitly: `grid({model: model.leftGridModel})`.

**HoistModel** is the core state holder:
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

**`makeObservable(this)`.** Call it in the constructor of any class that adds new `@observable`,
`@bindable`, or `@computed` properties. The base class call does not cover subclass decorators.
Forgetting this is the most common Hoist bug.

**`doLoadAsync(loadSpec)`.** Implement this template method to opt into managed data loading.
Trigger a load with `model.loadAsync()` or `model.refreshAsync()`. Never call `doLoadAsync`
directly. A linked model that implements `doLoadAsync` loads on mount.

**HoistService.** Singleton services, installed during app init and accessed through `XH`:
```typescript
XH.fetchJson({url: 'api/data'});            // FetchService alias
XH.getConf('featureFlag', false);            // ConfigService alias
XH.getPref('pageSize', 50);                  // PrefService alias
XH.<yourCustomService>.<yourMethodAsync>();  // Your app's services, registered during app init
```

**XH singleton.** The top-level API entry point. It gives access to services, data fetching
(`fetchJson`, `postJson`), user interaction (`toast`, `confirm`, `prompt`, `handleException`),
navigation (`navigate`, `appendRoute`), and app state (`appState`, `darkTheme`).

**Critical pitfalls:**
1. **Forgetting `makeObservable(this)`.** Observables silently stop reacting.
2. **Managing objects you do not own.** Only `@managed` objects your class creates. The provider
   owns objects passed in from outside.
3. **Mutating observables outside actions.** Use `runInAction()`, `@action`, or `@bindable`.
4. **Calling `lookupModel()` too early.** It only works during or after `onLinked()`.
5. **Calling `doLoadAsync()` directly.** Use the `loadAsync()` or `refreshAsync()` entry points.

## Hoist Reference Skills

The `xh` Claude Code plugin ships two reference skills: `using-hoist-react-reference` and
`using-hoist-core-reference`. They load themselves when you are about to author Hoist code or ask
for orientation. Each one routes you to the right MCP tool or CLI command. The hoist-core skill also
loads on a request to install or upgrade the hoist-core MCP and CLI tools. You do not need to
invoke them.

Each skill has two interchangeable surfaces: MCP tools when MCP is enabled, and CLI launchers once
installed. In MCP-blocked environments the CLI is the working path, and the skills route to it. If
neither surface is reachable, run `/xh:onboard-app` to configure them.

### hoist-core (server-side)

- Grails application. The `hoist-core` plugin supplies the server-side framework
- Controllers extend `BaseController`, services extend `BaseService`
- Server configuration lives in `configService` and the Admin UI config entries
- Groovy/Grails conventions: convention-over-configuration, GORM for persistence
- Dev server: `./gradlew bootRun`
- Production build: `./gradlew war`

For server-side work, the `using-hoist-core-reference` skill routes you to the hoist-core
developer tools. Two surfaces ship from the same fat JAR:

- **MCP tools**: `mcp__hoist-core__*`. Available when MCP is enabled, after you run
  `installHoistCoreTools` and restart Claude Code.
- **CLI launchers**: `./bin/hoist-core-docs` and `./bin/hoist-core-symbols`, once installed. These
  work in any environment, including MCP-blocked ones.

The hoist-core docs are also on GitHub at https://github.com/xh/hoist-core.

## Writing Style

Prose that ships with this code follows the `clear-writing` skill from the `xh` plugin: CHANGELOG
entries, PR descriptions, docs, and code comments. Short active sentences, one idea each, no
semicolons, no em dashes. The skill loads itself when you write a CHANGELOG entry, a PR
description, or a document. It also loads when you review a diff that includes comments. Invoke
`/xh:clear-writing` to apply it to any text.

## Commands

### Frontend (run from `client-app/`)
- Install: `{{PKG_MGR_INSTALL}}`
- Dev server: `{{PKG_MGR_START}}`
- Lint: `{{PKG_MGR_LINT}}`
- Type check: `npx tsc --noEmit`

### Backend (run from project root)
- Dev server: `./gradlew bootRun`
- Production build: `./gradlew war`
