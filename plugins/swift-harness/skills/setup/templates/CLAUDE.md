# {{APP_NAME}}

{{ONE_LINE_DESCRIPTION}}

## Commands
- Fast check (runs automatically before each turn ends): `scripts/verify.sh fast`
- Full check (before merging a branch): `scripts/verify.sh full`
- Lint: `swiftlint lint --quiet`
- Format: {{FORMAT_COMMAND}}

## Where things are
- Architecture hub, module map, links to all docs: @docs/ARCHITECTURE.md
- Design system rules and tokens: `docs/DESIGN_SYSTEM.md`
- Reusable components, one line each: `docs/COMPONENT_REGISTRY.md`
- Decisions already taken, do not reopen without a new ADR: `docs/adr/`
- Design system code: `{{DESIGN_SYSTEM_PATH}}`

## Non-negotiable rules
- The code is the source of truth. If docs and code disagree, say so and ask.
- UI: reuse before creating. Check `docs/COMPONENT_REGISTRY.md` and search the code before adding any view, style or modifier.
- No raw visual values outside the design system: colors, font sizes, spacing, radii and animation durations come from tokens.
- Views do not own business logic and never talk to {{PROTECTED_AREA_NAME}} directly.
- {{PROTECTED_PATHS}} are protected. Changes there need an explicit request and a plan first.
- Do not edit `project.pbxproj` by hand. Add files through the file system{{PBXPROJ_NOTE}}.
- One feature per branch. Do not rewrite unrelated code while implementing a feature.

## Definition of done
- `scripts/verify.sh fast` passes.
- New or changed shared components have previews for every state and an updated registry entry.
- Behavior changes have a test. Visual changes to shared components have a snapshot.
- Report what you verified and what you could not verify. Never claim a check passed without running it.
- Significant architectural choices are recorded as an ADR.
