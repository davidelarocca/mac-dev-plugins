# {{APP_NAME}} design system

Code: `{{DESIGN_SYSTEM_PATH}}`. Gallery: {{GALLERY_LOCATION}}.

## Principles

1. Native first: follow macOS conventions and the current system materials before inventing a pattern.
2. One behavior, one component. Things that look alike but behave differently stay separate (a transient pill is not an anchored popover).
3. Intent over values: callers say what (`.success`, `.section`), the design system decides how.

## Tokens

| Token family | Type | Examples | Notes |
|---|---|---|---|
| `Spacing` | `CGFloat` | `xs`, `s`, `m`, `l`, `xl` | |
| `Radius` | `CGFloat` | `control`, `card`, `pill` | |
| `Typography` | `Font` | `body`, `caption`, `pillLabel` | built on system text styles, so Dynamic Type keeps working |
| `Motion` | `Animation` | `standard`, `quick`, `emphasized` | durations live only here |
| Colors | `Color` | semantic names from the asset catalog | light and dark variants defined in the catalog |

Keep this table in sync with the code. The code wins if they differ.

## Interaction patterns

| Pattern | Use for | Component |
|---|---|---|
| Transient feedback | confirmations, non-blocking errors | see registry |
| Anchored detail | extra info tied to a control | see registry |
| Blocking decision | destructive or irreversible actions | system alert or confirmation dialog |

## Adding or changing a component

Follow the `ui-change` skill. In short: search, decide reuse, extend or create, implement with tokens, previews for every state, snapshot tests, registry update in the same change.
