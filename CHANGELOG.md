# Changelog

## swift-harness 1.0.1 (2026-11-05)

Fixes. No configuration changes needed.

- `verify.sh` template: an empty package list crashed the script on macOS bash 3.2 (`PACKAGES[@]: unbound variable`), so Xcode-only projects never built and the Stop check always failed. Regenerate or patch `scripts/verify.sh` in existing projects.
- `verify.sh` template: never reports PASS without running a check. No scheme and no package gives `NOT CONFIGURED`; a missing package folder, an unknown mode or unfilled `{{...}}` placeholders fail.
- Guard: `protectedPaths` did not match when the project was opened through a symlinked path. Paths are now resolved, including `../` and symlinked aliases of protected files.
- Stop check: edits to `.xcconfig`, plists, entitlements, string catalogs, resources, snapshot baselines, `scripts/` and `swift-harness.json` now trigger verification. Build output in `.build` and DerivedData is ignored.
- Session state: the starting state is stored as a baseline, not as verified, and a failed check is no longer forgotten when a new session starts.
- `SnapshotTest.swift` reference: fixed a compile error (`.aqua` instead of `.light`).
- Docs: the guard covers the Edit and Write tools only and is not a sandbox; `verify.command` runs repository code.
- Tests: `tests/run.sh` covers the hooks and the `verify.sh` template.

## swift-harness 1.0.0 (2026-11-05)

First release.

- Skills: `setup`, `audit`, `ui-change`, `design-system`, `feature`, `adr`
- Subagent: `ui-reviewer`
- Hooks: session baseline and tool check, guard for `project.pbxproj` and protected paths, format and lint after edits, verification before a turn ends
- Templates: `CLAUDE.md`, path-scoped rules, architecture hub, design system doc, component registry, ADR, SwiftLint config with design system rules, swiftformat config, `verify.sh`
