---
name: product-map
description: Read-only product map of a Swift/SwiftUI macOS app built from its code - entities, destinations, every place each entity appears, relations, user-managed collections and action sets - then the gaps it reveals (dead ends, related items shown as plain text, missing lifecycle actions, inconsistent menus), with file:line evidence. Writes docs/PRODUCT_MAP.md after approval. Use when the user asks for a product map, a navigation or coherence review, or why the app feels built in pieces.
disable-model-invocation: true
---

# Product map

Goal: see the product as a whole, not one screen at a time. A feature can be well built and still leave the
user stuck: an item shown with no way to open it, an owner's name that looks like a link but isn't, a list
the user created but cannot rename or reorder, an action offered in one place and missing in another. A
generic UX review rarely finds these, because each screen looks fine on its own. A map of the whole does.

Best run in plan mode. It reads a lot of code: tell the user it is a long task before starting.

## Ground rules

- Modify nothing. The only file you write is `docs/PRODUCT_MAP.md`, after the user approves it.
- Every claim cites `file:line`. No evidence, no row. "Not found" means you searched: say what you searched for,
  and that it is not proof of absence.
- The code is the source of truth. If `docs/PRODUCT_MAP.md` already exists, check it against the code and
  report the rows that are wrong.
- Describe what the user can do, not how the code is organized. Do not propose code.
- The app's domain decides the entities. Examples like "item", "container" or "author" are placeholders.

## Method

Keep the main context clean. First find the entities yourself (domain models, persistence models, what the
main views display), then run Explore subagents in parallel, for example one per two or three entities,
each answering steps 2 to 4 and 6 for its entities with `file:line` evidence. Do step 5 in one subagent.
Merge and deduplicate in the main thread.

1. **Entities.** Every kind of object the user sees and cares about. For each: the model type and its file.
   Include derived ones the user perceives as things (a generated mix, a saved search, a smart folder).
2. **Destinations.** For each entity, the screen that shows it in full, if any, and the call that opens it
   (router, navigation path, selection, `openWindow`). Note entities with two different destinations.
3. **Appearances.** Every place the entity is displayed: list and table rows, tiles, headers, sidebars,
   inspectors, search results, menus, popovers, the menu bar, mini players, widgets, notifications.
   For each: can the user reach the destination from there, and how (click, double-click, context menu,
   keyboard)? Text drawn in an accent or link style that does nothing is a finding.
4. **Relations.** Entity A belongs to or points to entity B (an item and its container, an item and its
   author, a record and its category). Wherever A is shown together with B's name, can the user go to B?
5. **Ownership and lifecycle.** Entities and collections the user creates or organizes (lists, folders,
   sidebar sections, categories, tags, presets). For each: create, rename, reorder, delete, undo. Where,
   and through which code path? Note destructive actions without confirmation or undo.
6. **Actions.** What each entity supports (open, edit, share, duplicate, add to a collection, reveal, ...).
   Find the shared menu or command, then check whether every appearance offers the same set.
   Also check: the same gesture meaning different things for the same entity in two views, and visible
   controls that do nothing on some screens.

## Report

Show it in the conversation first:

1. The map as compact tables, in the layout of `docs/PRODUCT_MAP.md`
   (template: `${CLAUDE_PLUGIN_ROOT}/skills/setup/templates/docs/PRODUCT_MAP.md`).
2. **Gaps**, most important first. Each with: evidence (`file:line`), why it matters to the user in one or
   two sentences, and a priority (high: a common path is a dead end or misleading; medium: inconsistent or
   missing in secondary places; low: polish).
3. What you could not check, and why.

## After the report

- Ask before writing `docs/PRODUCT_MAP.md`. If it exists, propose a merge: keep rows the user wrote in
  "Exceptions", update the rest.
- Put the gaps in "Known gaps". Do not start fixing them in the same session; suggest one branch per gap or
  per group of related gaps, highest priority first.
- If the project has no `docs/PRODUCT_MAP.md` link in `CLAUDE.md`, suggest adding one line under
  "Where things are", so later sessions read it before showing an entity in a new place.
