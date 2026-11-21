**Element factories over JSX.** Hoist uses element factory functions, not JSX:
```typescript
// ✅ Hoist style
panel({title: 'Users', items: [grid(), button({text: 'Refresh'})]})
```
```tsx
// ❌ Not used in Hoist
<Panel title="Users"><Grid /><Button text="Refresh" /></Panel>
```

Pass child elements with `item` / `items`: `item` for one child, `items` for an array. Do not use
`children` in an element spec on this version of Hoist. Hoist v91 moves to the standard React
`children` key. Its upgrade guide ships a codemod that converts app code and these examples.

**Components.** Create a component with `hoistCmp.factory`. Each component declares its model relationship:
```typescript
export const userList = hoistCmp.factory({
    model: creates(UserListModel),  // Component creates and owns this model
    render({model}) {
        return panel({title: 'Users', item: grid()});
    }
});
```
