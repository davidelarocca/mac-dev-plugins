---
name: setup
description: Bootstrap or retrofit the swift-harness method in a Swift/SwiftUI macOS project - CLAUDE.md, path-scoped rules, design system docs, component registry, ADRs, SwiftLint/formatter config, verify script and quality-gate config. Use when the user asks to set up, initialize or onboard a project to swift-harness.
disable-model-invocation: true
---

# Set up swift-harness in a project

Goal: leave the project with persistent instructions, a documented design system, a component registry and active quality gates, without overwriting anything the project already has.

Templates live in `${CLAUDE_PLUGIN_ROOT}/skills/setup/templates/`. Placeholders look like `{{NAME}}`.

## 1. Safety first

1. Confirm the folder is a git repository. If not, stop and ask whether to run `git init`.
2. Run `git status --porcelain`. If there are uncommitted changes, ask the user to commit them first. Do not commit their work for them.
3. Create a branch `chore/swift-harness-setup` unless the user is already on a dedicated branch.

## 2. Detect the project (read only)

Collect, and show the user a short summary:

- Project type: `.xcworkspace`, `.xcodeproj`, `Package.swift`, local packages under `Packages/` or similar.
- Schemes and targets: `xcodebuild -list -json` (workspace or project as appropriate).
- Swift version and minimum macOS version (build settings or `Package.swift`).
- Whether the Xcode project uses synchronized folders: search `project.pbxproj` for `PBXFileSystemSynchronizedRootGroup`. If present, new files do not touch `project.pbxproj`.
- Existing instruction files: `CLAUDE.md`, `.claude/CLAUDE.md`, `AGENTS.md`, `.claude/rules/`, `.claude/settings.json`.
- Existing docs: hub and spoke docs, roadmap, step plans, any architecture or design notes.
- Existing tooling: `.swiftlint.yml`, `.swiftformat`, `.swift-format`, test targets, snapshot tests.
- Installed tools: `which swiftlint swiftformat jq`, and `xcrun --find swift-format`.
- Protected areas candidates: audio engines, persistence/migrations, crypto, anything the docs flag as critical.

## 3. Ask only what you cannot detect

Use one AskUserQuestion call with at most four questions, for example:

- Design system location: a local Swift package `Packages/DesignSystem` (recommended) or a folder inside the app target.
- Formatter: `swiftformat` (recommended, needs Homebrew) or Apple `swift-format` (ships with Xcode).
- Protected paths that require explicit approval before Claude edits them.
- Verify commands: the fast check run before Claude ends a turn, and the full check run before merging.

## 4. Generate files

For each template, if the target file does not exist, create it with placeholders filled. If it exists, never overwrite: show the user the proposed additions and merge only what they approve.

| Template | Target |
|---|---|
| `CLAUDE.md` | `CLAUDE.md` (if the repo uses `AGENTS.md` only, add `@AGENTS.md` at the top of the new CLAUDE.md instead of duplicating) |
| `rules/ui-features.md` | `.claude/rules/ui-features.md` |
| `rules/design-system.md` | `.claude/rules/design-system.md` |
| `rules/architecture.md` | `.claude/rules/architecture.md` |
| `docs/ARCHITECTURE.md` | `docs/ARCHITECTURE.md` |
| `docs/DESIGN_SYSTEM.md` | `docs/DESIGN_SYSTEM.md` |
| `docs/COMPONENT_REGISTRY.md` | `docs/COMPONENT_REGISTRY.md` |
| `docs/PRODUCT_MAP.md` | `docs/PRODUCT_MAP.md` |
| `docs/adr/0000-template.md` | `docs/adr/0000-template.md` |
| `swiftlint.yml` | `.swiftlint.yml` |
| `swiftformat` | `.swiftformat` (only if swiftformat was chosen) |
| `swift-format` | `.swift-format` (only if swift-format was chosen; without it swift-format uses 2-space indentation and reformats every edited file) |
| `verify.sh` | `scripts/verify.sh` (then `chmod +x`) |
| `swift-harness.json` | `.claude/swift-harness.json` (this file switches the plugin hooks on for this project) |

Rules for filling templates:

- Fill `paths:` globs in the rules with the real folder layout found in step 2.
- Fill the SwiftLint `excluded` regex for custom rules with the real design system path.
- In `verify.sh`: `{{LOCAL_PACKAGES}}` becomes quoted paths (`"Packages/DesignSystem" "Packages/Domain"`) or nothing for `PACKAGES=()`; `{{SCHEME}}` and `{{XCODE_CONTAINER_FLAG}}` become empty strings for a packages-only project. At least one of the two must be set: with neither, the script reports `NOT CONFIGURED` and fails.
- Keep CLAUDE.md under 100 lines. Link to docs, do not copy them.
- If the project has existing hub and spoke docs, make `docs/ARCHITECTURE.md` the hub that links to them. Do not move or rewrite the existing docs in this step; list outdated ones as follow-ups.
- Populate `COMPONENT_REGISTRY.md` only with components that really exist and are shared. Unknown or duplicated ones go in the "To consolidate" section. Do not invent entries.
- Leave the `PRODUCT_MAP.md` tables empty: filling them needs `/swift-harness:product-map`, which reads the whole app.

## 5. Tooling check

- Missing tools: tell the user the exact install command (`brew install swiftlint swiftformat jq`). Do not install them yourself.
- Run `scripts/verify.sh fast` once. Report the result. If it fails for reasons unrelated to setup, record that in the summary instead of fixing it now.
- Run SwiftLint once on the whole project and report the count per custom rule. This is the baseline of hardcoded values to migrate. If the count is high, suggest `swiftlint lint --write-baseline .swiftlint-baseline.json` and adding `--baseline .swiftlint-baseline.json` in `verify.sh`, so only new violations count.

## 6. Architecture contracts (SwiftPM, optional)

Only when the code is split into SwiftPM packages with several targets. Offer to create `docs/architecture-contracts.json`, which makes the end-of-turn check fail when a target gains a dependency the contract does not allow:

1. Read the current graph with `swift package dump-package` in each package folder (it runs `Package.swift`: ask before running it in a project you have not built).
2. Propose one entry per non-test target, listing its current dependencies: local targets by name, products of other packages as `package/product`. Point out any dependency that looks like a boundary violation instead of copying it silently.
3. Write the file only after the user agrees, with `"version": 1` and package folders as keys (`"."` for the root package). Suggest adding it to `protectedPaths` so Claude asks before editing it.

Skip this step for Xcode-only projects or a single target: there is nothing to check.

## 7. Companion plugins

Check `/plugin` state and recommend, without installing on your own:

- `swift-lsp@claude-plugins-official`: type diagnostics and code navigation after edits. Recommended for every Swift project.
- Optional: XcodeBuildMCP for build/run/test loops without Xcode open, or the Xcode 26.3+ MCP (`xcrun mcpbridge`) for RenderPreview. Suggest at most one to start.

## 8. Finish

1. Show the list of created and merged files.
2. Commit on the setup branch with message `chore: set up swift-harness` only after the user confirms.
3. Tell the user that the end-of-turn check does not run `verify.command` until they approve it by typing `/swift-harness:approve-verify`, and that it asks again whenever the command or `scripts/verify.sh` changes. Do not run the approval yourself.
4. Suggest the next step: `/swift-harness:audit` and `/swift-harness:product-map` if the project already has code, otherwise start with the design system skill.
