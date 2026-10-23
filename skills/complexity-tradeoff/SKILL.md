---
name: complexity-tradeoff
description: |
  Weigh the complexity a change adds against the cases it covers, and give the developer a menu of options from simplest to most complete. Why this matters: an agent asked to fix a race or an edge case tends to build the complete mechanism, with in-flight tracking, sequence counters, retry queues, dirty flags or recursion. Most of that code guards windows that are narrow, self-healing, or already bounded by a server fix or the next refresh. The developer then has to ask "do we still need X?" one field at a time. The bulk of a change's complexity should never go to its rarest cases unless the developer chose that. TRIGGER when the user asks whether a change is as simple as it can be, mentions 80/20, asks "do we still need X" or "can we just use Y", says a mechanism scares or worries them, or asks what a race, overlap or failure would actually cost; when you are about to add, or have just written, a mechanism that guards a race, overlap, retry, in-flight state, ordering or staleness; when you write a PR description for such a change; and when you review a diff or PR that adds one. SKIP for style and reuse cleanups with no behavior at stake, for bug hunting, for a mechanism the user specified and already weighed, and when the uncovered failure is unrecoverable (lost money, corrupted data, a security hole). There, completeness is not optional.
allowed-tools: Read, Glob, Grep, Bash
---

# Complexity Tradeoff

Most of the code in a hardening change guards its rarest cases. This skill makes that cost
visible before the developer pays it. You name each mechanism, score the case it covers, and
present a menu from simplest to most complete. The developer picks. The result is a change
whose complexity matches the risk it removes, and a PR that says which cases it left open.

## Step 1: Name each mechanism

List every piece of machinery the change adds or keeps: a field, a flag, a counter, a queue, a
retry, a lock, a comparison, a second code path. For each one, write one line: the scenario it
covers, and what happens without it.

Scrutinize a mechanism when:

- It exists only to make another mechanism correct, such as a counter that closes a window the
  flag left open.
- It is novel where a standard tool covers most of the ground: recursion, a hand-rolled queue,
  a sequence number, where a debounce, a reaction, or an existing utility would do.
- The comment that explains it is longer than the code.
- Its spec needs held requests and fake timers to reach the case at all.
- Something else already bounds the damage: the next refresh resyncs, a server fix is tracked,
  the user can redo the action.
- It optimizes work the platform already bounds, such as scoping a refresh the library already
  virtualizes to visible cells, or caching a lookup that runs once per user action.

## Step 2: Score each case

For each case a mechanism covers, answer four questions in a line each:

1. **Likelihood.** What has to line up? Name it: "the server takes longer than the debounce and
   the user changes state again inside that window".
2. **Cost.** Rank it on this scale: cosmetic, redo the action, self-heals on the next refresh or
   reload, silent stale state until the next change, permanent loss, corrupted data or a
   security hole.
3. **Existing bound.** What already limits the damage, if anything?
4. **Complexity.** Lines, fields, concepts a reader must hold, novel or standard mechanism, and
   the specs it needs.

A mechanism whose case is rare and self-healing is a candidate to drop. A mechanism whose case
is rare and permanent is not.

## Step 3: Present a menu

Order the options from simplest to most complete. Each option must still fix the reported bug.
The menu trades hardening, never the fix.

| Option | Mechanism | Covers | Leaves open | Complexity |
|--------|-----------|--------|-------------|------------|
| A | one debounced reaction | bursts, the reported overlap | a write slower than the debounce plus a second change: one logged update, resynced on refresh | one reaction, one method |
| B | A plus one request in flight | A plus slow servers | a write that starts and ends inside a fetch: a reverted value, resynced on refresh | one field, one loop |
| C | B plus a sequence counter | everything above | nothing known | two fields, two bumps, one more spec |

Rules for the menu:

- State each open case as a concrete scenario, with its likelihood and cost from Step 2. Never
  write "some edge cases".
- Name the recovery for each open case: what repairs the state when it hits.
- Prefer a standard mechanism with a known gap over a novel one that closes it.
- Recommend one option in one sentence. When the simplest option leaves open only rare and
  self-healing cases, recommend it. Put the recommended option first if you present the choice
  through a question tool.
- Say that a simpler option can grow into the next one later, when evidence shows the need.
- Do not build the most complete option by default and then offer to remove parts of it.

Run this step before you write the mechanism when the design is yours. Run it on the diff when
the mechanism is already written, by you or by someone else.

## Step 4: Record the call

In the PR description, add one line per case the change leaves open and why that is acceptable.
A reviewer then sees a deliberate call, not an oversight. The code comment states the same case
in one sentence where the gap lives. The commit message carries the fuller reasoning.

When you review a PR, report the same thing from the other side. Name the mechanisms whose
cases are rare, low-risk, or self-healing, with their share of the diff. The developer can then
decide whether to keep them.

## Guards

- When an open case loses money, corrupts data, or opens a security hole, the menu says so and
  recommends the complete option. The developer can still choose, with the cost stated.
- Keep what the developer already decided. If they chose a mechanism knowingly, do not reopen
  it on the next turn.
- Never describe a simple option as covering more than it does.
- The fix for the reported bug is not complexity to trade away.
- Follow the clear-writing skill for the menu and the PR text.

## Worked examples

### A state writer

A model wrote three keys of user state to the server from three reactions. The writes
overlapped, and the server lost one. The first draft built the complete mechanism. It had a
writer that merged pending keys with one request in flight, a retry queue for failed writes, and
a flush of that queue on refresh. It also had a sequence counter, so a refresh could detect a
write that started and ended while its fetch was out. Four rounds of "do we still need X"
removed a layer each:

- The retry queue and the flush covered failures the single writer had already made rare. A
  failed write is now logged, and the next refresh resyncs.
- The counter covered a write that fit entirely inside a fetch. A check at send and at return
  covers the rest.
- The in-flight tracking, first a loop with a dirty flag and then a recursion, kept one request
  in flight. A debounced reaction that writes the full state replaced it. An overlap now needs a
  slow server and a second change inside the debounce, and costs one logged update that the next
  refresh resyncs.

The final change was one debounced reaction, a plain write method, and a refresh guard that
already existed. The menu above is the one that should have opened the conversation.

### A targeted cell refresh

Column group edge borders in `Grid` are cell classes, and they stayed on their original columns
when the column chooser reordered or hid columns, because the refresh that re-evaluated them only
ran on header drags. The fix was one gridOptions handler on `displayedColumnsChanged`. The first
draft also added a `GridModel` method that walked the column tree, collected the leaf columns
inside bordered groups, and passed their ids to `refreshCells`, so only those cells re-ran.

The developer asked whether that beat refreshing all cells. It did not, by much. `refreshCells`
touches rendered cells only, and without `force` it re-applies class rules but re-renders a cell
only when its value changed. The scoping saved value getters and formatters on the other visible
columns of a grid, once per column move. The tree walk cost fifteen lines, a public method and a
second place that had to know what `borders: false` means.

The second draft kept one guard, skipping grids with no bordered groups. The developer asked
whether it was safer to always refresh. The guard matched exactly the one rule Hoist ships, so it
protected nothing an app rule might need, and a read of the refresh path plus a test in the inline
editing demo showed the refresh never touches focus or an open editor. The final handler:

```ts
onDisplayedColumnsChanged = ev => ev.api.refreshCells();
```

Two questions to ask before scoping work. What does the library already skip? Here it skipped
everything off screen and every unchanged value. And what does the guard buy beyond the case in
front of you? Here the unconditional version gave a simpler contract, that cell class rules are
re-evaluated whenever displayed columns change, for a cost nobody would measure.
