# Product map

What the user works with, where each thing lives, and how to get from one thing to another.
The code is the source of truth: every row points to a file. Updated in the same change as the code.
Built and refreshed with `/swift-harness:product-map`. Read this before showing an entity in a new place
or adding something the user creates or organizes.

## Rules

- **Every appearance leads to its destination.** Wherever an entity is shown (row, tile, header, inspector,
  menu, search result, mini player, notification), the user can open its destination from there: click,
  double-click, context menu or keyboard.
- **Related entities are reachable.** If a row shows a related entity (its container, owner, author,
  category), that name opens the related entity's destination. Text that looks like a link is a link.
- **Same entity, same actions.** An entity offers the actions in its action set wherever it appears, through
  the shared menu or command. Leaving one out is a decision, written in "Exceptions".
- **What the user creates, the user can manage.** Collections the user makes or organizes support create,
  rename, reorder, delete and undo, or the table says why not.

## Entities

| Entity | Model | Destination (full page) | Opened by |
|---|---|---|---|
| | `File.swift:line` | `DetailView` (`File.swift:line`) or none | the navigation call, e.g. `router.open(.entity(id))` |

## Relations

| From | To | Kind (belongs to, author, category, ...) | Shown as link where |
|---|---|---|---|

## Appearances

One row per place an entity is displayed. ✓ = offered, — = missing (a gap), n/a = does not apply.

| Entity | Where (`File.swift:line`) | Opens destination | Related entities reachable | Action set |
|---|---|---|---|---|

## Action sets

| Entity | Actions | Shared entry point |
|---|---|---|
| | Open, Rename, Delete, ... | the shared menu or command type, with its file |

## User-managed collections

| Collection | Create | Rename | Reorder | Delete | Undo |
|---|---|---|---|---|---|

## Exceptions

Deliberate departures from the rules, so they are not reported again.

| Where | Rule not applied | Why |
|---|---|---|

## Known gaps

Found and not fixed yet, most important first.

| Gap | Evidence | Priority |
|---|---|---|
