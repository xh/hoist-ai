**Element factories over JSX.** Hoist uses element factory functions, not JSX:
```typescript
// ✅ Hoist style
panel({title: 'Users', children: [grid(), button({text: 'Refresh'})]})
```
```tsx
// ❌ Not used in Hoist
<Panel title="Users"><Grid /><Button text="Refresh" /></Panel>
```

Pass child elements with the standard React `children` key. A container component destructures
`children` from its props and passes it on as `children`. `item` and `items` are legacy aliases
for `children`. Do not use them in new code.

**Components.** Create a component with `hoistCmp.factory`. Each component declares its model relationship:
```typescript
export const userList = hoistCmp.factory({
    model: creates(UserListModel),  // Component creates and owns this model
    render({model}) {
        return panel({title: 'Users', children: grid()});
    }
});
```
