# {{APP_NAME}} architecture

Hub document. Keep it short: it is imported into every Claude session. Detail lives in the linked documents.

## Modules

| Module | Responsibility | May depend on |
|---|---|---|
| App | Composition root, windows, scenes, environment wiring | everything below |
| Features/* | Screens and their view models | DesignSystem, Domain, Services (via protocols) |
| DesignSystem | Tokens, shared components, presenters, styles | nothing app-specific |
| Domain | Models and pure logic (queues, rules, sorting) | nothing UI |
| Services | I/O, persistence, playback, system integration | Domain |

Replace this table with the real modules after setup or after the first audit.

## Data flow

{{STATE_PATTERN_DESCRIPTION}}

## Protected areas

- {{PROTECTED_PATHS}}: {{WHY_PROTECTED}}

## Documents

- Design system: `docs/DESIGN_SYSTEM.md`
- Component registry: `docs/COMPONENT_REGISTRY.md`
- Product map (entities, destinations, relations, actions): `docs/PRODUCT_MAP.md`
- Layout contract (window sizes per screen, compact behavior, presented UI): `docs/LAYOUT_CONTRACT.md`
- Decisions: `docs/adr/` (index below)
- Feature specs and step plans: {{EXISTING_DOCS_LINKS}}
- Latest audit: `docs/audit/`

## Decision index

| ADR | Title | Status |
|---|---|---|
