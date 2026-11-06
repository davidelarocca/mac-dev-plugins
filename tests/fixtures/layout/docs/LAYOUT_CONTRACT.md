# Layout contract

Fixture for #34: LibraryView, UnboundedWindow and InspectorPane break; the others hold.

## Screens

| Screen | View | File | Window | Min | Default | Max | Compact below | Compact behavior |
|---|---|---|---|---|---|---|---|---|
| Library | `LibraryView` | Sources/Screens/Screens.swift | LibraryWindow | 640x400 | 1000x700 | - | - | |
| Library, compact | CompactLibraryView | Sources/Screens/Screens.swift | | 640x400 | 1000x700 | - | 800 | Filters collapse into a menu |
| Unbounded | UnboundedWindow | Sources/Screens/Screens.swift | UnboundedWindow | 480 × 300 | - | - | - | |
| Inspector | InspectorPane | Sources/Screens/Screens.swift | | 260x300 | - | - | - | |
| Bounded | BoundedWindow | Sources/Screens/Screens.swift | BoundedWindow | 480x300 | - | 1200x900 | - | |
