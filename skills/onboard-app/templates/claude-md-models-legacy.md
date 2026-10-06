#### Models and Decorators

This app uses TypeScript's legacy `experimentalDecorators`. Hoist v88 replaced them with TC39
decorators. After an upgrade to v88 or later, regenerate this section with `/xh:hoist-upgrade` or
`/xh:onboard-app`.

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
        const users = await XH.fetchJson({url: 'api/users'});
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
Forgetting this is the most common Hoist bug: observables silently stop reacting.
