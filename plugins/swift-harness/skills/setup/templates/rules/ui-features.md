---
paths:
  - "{{FEATURES_GLOB}}"
---

# UI rules for feature code

- Before adding a view, style, modifier, overlay or popover, read `docs/COMPONENT_REGISTRY.md` and search the code for the same behavior. Reuse or extend; create only when behavior and responsibility differ.
- Import the design system and use its tokens: `Spacing`, `Radius`, `Typography`, `Motion`, semantic colors. No numeric padding, spacing, radius, font size, color or animation duration here.
- Showing an entity in a new place (row, tile, header, menu, inspector): check `docs/PRODUCT_MAP.md`. The new appearance opens the entity's destination, related entities shown with it (container, owner, category) open theirs, and it offers the entity's action set through the shared menu or command. Add the appearance to the map in the same change.
- Collections the user creates or organizes get create, rename, reorder, delete and undo, or a row in the map's "Exceptions" saying why not.
- Transient feedback (pills, toasts, banners) goes through the shared presenter in the environment. Never build a local overlay for it.
- Buttons use the shared `ButtonStyle`s. Hover, pressed, selected and disabled states come from the design system.
- Keep `body` small. Extract subviews when a body grows past roughly 40 lines or mixes several responsibilities.
- Views read state and send intents. Business rules, file I/O and playback control live in models or services.
- If you need something the design system lacks, add it to the design system first (follow the `ui-change` skill), then use it here.
