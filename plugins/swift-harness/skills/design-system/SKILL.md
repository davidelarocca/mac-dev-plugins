---
name: design-system
description: How to build or migrate to a SwiftUI design system for a macOS app - local Swift package layout, tokens, shared presenters for pills and toasts, button styles, component gallery and snapshot tests, plus a step-by-step migration from hardcoded values. Use when creating the design system, adding tokens, extracting a shared component, or setting up snapshot tests.
---

# SwiftUI design system for macOS apps

## Package layout

Prefer a local Swift package. It compiles and tests with `swift build` and `swift test` without touching `project.pbxproj`, and its boundary keeps app code out.

```
Packages/DesignSystem/
├── Package.swift
├── Sources/DesignSystem/
│   ├── Tokens/          Spacing, Radius, Typography, Motion, Color+Semantic
│   ├── Components/      one folder per component (view + presenter + styles)
│   ├── Styles/          ButtonStyle, LabelStyle, ToggleStyle
│   ├── Modifiers/       shared ViewModifiers (hover, card, selection)
│   ├── Resources/       Colors.xcassets
│   └── Gallery/         GalleryView listing every component in every state
└── Tests/DesignSystemTests/
    └── Snapshots/
```

`Package.swift`: platforms `.macOS(.v14)` or higher (match the app), resources `.process("Resources")`, test dependency on `swift-snapshot-testing`. Add the package to the app once in Xcode (File > Add Package Dependencies > Add Local). After that, new files inside the package never need project edits.

## Tokens

See `references/Tokens.swift`. Rules:

- Names describe intent (`Spacing.section`), not the value.
- Typography builds on system text styles so Dynamic Type and accessibility keep working.
- Colors are semantic names in the package asset catalog with light and dark variants, exposed as `Color.DS.surface` style accessors.
- Motion tokens are `Animation` values. Respect Reduce Motion where an animation moves content.

## Shared presenters (pills, toasts, banners)

One presenter object owns the state, one host renders it at the root, features only call `show`. See `references/PillCenter.swift`.

- `@MainActor @Observable` presenter, injected with `.environment(_:)` at the root.
- A single `.pillHost()` modifier at the root window content draws the overlay.
- Message kinds are an enum (`info`, `success`, `warning`, `error`). New needs become new cases, not new views.
- Queueing, duration and dismissal live in the presenter, never in features.

The same shape works for any transient UI that appears in several screens.

## Interaction styles

Hover, pressed, selected and disabled states belong in `ButtonStyle`s and `ViewModifier`s in the design system. Features apply `.buttonStyle(.dsToolbar)` and never re-implement `onHover` logic.

## Gallery

A `GalleryView` in the package lists every component in every state, in light and dark. Show it from a debug-only menu item or a dedicated preview. It is the visual inventory for both the user and Claude.

## Snapshot tests

See `references/SnapshotTest.swift`. Notes for macOS:

- Render through `NSHostingView` with a fixed frame and an explicit appearance (`.aqua`, `.darkAqua`).
- Rendering differs between macOS versions: record snapshots on the same OS the checks run on, and re-record after a major macOS update in a dedicated commit.
- Use a small `perceptualPrecision` tolerance (around 0.98) to avoid font antialiasing noise.

## Migration from an existing app

Work in small steps, each on its own branch, each verifiable:

1. Create the package with tokens only. Build.
2. Pick the most duplicated element from the audit. Build the shared component with previews and snapshot tests.
3. Replace one call site. Compare before and after (screenshot or snapshot). Then the others, one screen at a time.
4. Delete the old copies. Update `docs/COMPONENT_REGISTRY.md` and move them to "Retired".
5. Repeat for the next element. Replace raw values file by file using the SwiftLint `ds_*` warnings as the to-do list.
6. When a category reaches zero warnings, switch that SwiftLint rule to `severity: error` so it cannot come back.
