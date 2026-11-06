---
name: ui-change
description: Reuse-first procedure for any change to SwiftUI or AppKit interface code in a macOS app - new views, overlays, pills, toasts, popovers, buttons, styles, modifiers, lists or visual tweaks. Use before writing or modifying UI code, so existing components are reused and the component registry stays accurate.
---

# Reuse-first UI change

The goal is that every interaction pattern exists once. Visual bugs usually come from a second, slightly different copy of something that already exists.

## 1. Discover (before writing code)

1. Read `docs/COMPONENT_REGISTRY.md` and `docs/DESIGN_SYSTEM.md` if they exist.
2. Search the code for the same behavior, not only the same name. Examples: for a top notification search `overlay(alignment: .top`, `transition(.move(edge: .top`, `Toast`, `Pill`, `Banner`, `HUD`; for a hover button search `onHover`, `ButtonStyle`.
3. List every place the new or changed element will appear.
4. If the change displays an entity (a row, tile, header, menu or inspector showing a domain object), read its rows in `docs/PRODUCT_MAP.md`: its destination and how it is opened, its relations, its action set. Without a map, find them in the code: an existing appearance of the same entity shows the navigation call and the shared menu.

## 2. Decide

| Situation | Action |
|---|---|
| A component with the same behavior and responsibility exists | Reuse it as is |
| Same behavior, needs a new variant or option | Extend it: add a case to its kind enum or a parameter with a default. Check every caller still works |
| Looks similar, different behavior (e.g. transient pill vs anchored popover) | Separate component. Say why in the registry |
| Nothing similar | Create it in the design system, not inside the feature |
| Two or more existing copies | Stop and propose consolidation first. Do not add a third |

State the decision in one line before implementing.

For an entity shown in a new place, the default is the whole: it opens its destination, related entities shown with it open theirs (no plain text styled as a link), and it offers its action set through the shared menu or command. Leave something out only for a reason, and say which.

## 3. Implement

- Inside the design system: tokens only, presentation separated from behavior (a view draws, a presenter or style decides when and how it shows).
- In feature code: call the component's public API with intent (`.success("Added to library")`), never with layout numbers.
- Shared transient UI is presented from a single host at the root, driven by an observable presenter in the environment. See the `design-system` skill for the pattern.
- Respect macOS conventions: hover states, focus rings, keyboard access, pointer and accessibility labels, reduced motion.

## 4. Verify

- Previews for every state of the component: default, hover or pressed where relevant, disabled, selected, light and dark, long and localized text.
- Snapshot tests for shared components when the project has snapshot testing set up. Re-record only intentional changes and mention it.
- Build. For non-trivial changes, delegate a review to the `ui-reviewer` agent with the list of changed files.
- If the component is used in several places, check each caller listed in the registry.

## 5. Record

- Update `docs/COMPONENT_REGISTRY.md` in the same change: new entry, new variant, new callers, or a move to "Retired".
- Update `docs/PRODUCT_MAP.md` if it exists: new appearances, actions or relations, and deliberate omissions under "Exceptions".
- If you found duplicates you did not fix, add them to "To consolidate".
- If you introduced a new pattern, ask whether it deserves an ADR.
