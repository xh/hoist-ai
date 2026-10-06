#### Models and Decorators

This app uses TC39 decorators. Every `@observable`, `@observableRef`, `@bindable`, and
`@bindableRef` field takes the `accessor` keyword.

**HoistModel** is the core state holder:
```typescript
class UserListModel extends HoistModel {
    @observableRef accessor users: User[] = [];
    @bindable accessor selectedUserId: string = null;
    @bindable @persist accessor showInactive = false;
    @managed detailModel = new UserDetailModel();

    override async doLoadAsync(loadSpec: LoadSpec) {
        const users = await XH.fetchJson({url: 'api/users'}, {loadSpec});
        runInAction(() => this.users = users);
    }
}
```

**Key decorators:**

| Decorator | Purpose | `accessor`? |
|-----------|---------|-------------|
| `@observable` / `@observableRef` | MobX observable state, deep or reference-only | Yes |
| `@bindable` / `@bindableRef` | Observable + auto-generated action-wrapped setter | Yes |
| `@persist` | Sync property with a persistence provider (requires `persistWith`) | Yes, with the MobX decorator |
| `@managed` | Mark child object for automatic cleanup on `destroy()` | No |
| `@lookup(ModelClass)` | Inject ancestor model (linked models only, available after `onLinked`) | No |
| `@computed` | Cached derived value, on a getter | No |
| `@action` | Mark method as state-modifying | No |

**Decorator pitfalls:**
1. **Forgetting `accessor`.** The field compiles but silently stops reacting.
2. **`@persist` before the MobX decorator.** Write `@bindable @persist accessor x`. A reversed
   pair logs a console error and the field stops persisting, with no type error.
3. **Adding MobX setup calls to a constructor.** TC39 decorators register themselves. A
   constructor needs no MobX boilerplate.
4. **Enumerating a model.** `accessor` fields are prototype getters. `Object.keys()`,
   `JSON.stringify()`, and spread do not see them. Read named properties instead.
5. **Passing `loadSpec` inside fetch options.** Pass the load context as the second argument:
   `XH.fetchJson({url}, {loadSpec})`.
