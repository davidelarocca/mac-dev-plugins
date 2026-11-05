# Changelog

## swift-harness 1.0.3 (2026-11-05)

Clearer feedback to Claude, from the Claude Code smoke test of 1.0.2. No configuration changes needed.

- Post-edit: the formatter note now lists the lines the formatter changed (up to 12), labelled "- your edit as written, + after formatting". In the smoke test Claude blamed the formatter for a space its own edit had dropped; with the labelled diff it attributed the change correctly.
- Post-edit: a clean SwiftLint run says "no issues", and an excluded file says so. Before, both were silent, and Claude told the user that SwiftLint had not run.
- `lintBlocking`: the blocking message says what to do with errors on lines that were already there (leave them, say so, the turn ends as failed) and, for a broken SwiftLint configuration, not to change `.swiftlint.yml` unless the task covers it.
- `swift-format`: setup now generates `.swift-format` (4 spaces, 160 columns, like the swiftformat template). SessionStart warns when `format` is `swift-format` and the file is missing, because swift-format then re-indents every edited file with 2 spaces.
- Hooks: `SWIFT_HARNESS_EXTRA_PATH` overrides the folders appended to `PATH` (default `/opt/homebrew/bin:/usr/local/bin`).
- Checked again in Claude Code 2.1.318 (3 scenarios): correct attribution of formatter changes, "SwiftLint found no issues" reported, pre-existing errors left alone with the turn ending as failed.
- Tests: 77 checks. The missing-SwiftLint check now uses a minimal `PATH`: since Homebrew is appended to `PATH`, it had been finding the real SwiftLint on machines that have it.

## swift-harness 1.0.2 (2026-11-05)

Fixes. No configuration changes needed.

- Post-edit: formatter failures (`swiftformat`, `swift-format`) were discarded. They are now reported to Claude with the tool's error output.
- Post-edit: SwiftLint failures without violations (crash, unreadable config) and configuration problems that SwiftLint only reports on stderr while exiting 0 (invalid rule configuration or regex, which silently disables the rule) are now reported. A file excluded by `.swiftlint.yml` is not treated as an error.
- `lintBlocking: true` now also blocks on those SwiftLint failures, and the Stop check lints the blocked files again: the turn cannot be recorded as passed while they still fail, even when the build passes.
- Post-edit: Swift files outside the project are no longer formatted or linted.
- Guard: a `protectedPaths` entry that is itself a symlink now protects its target too.
- Hooks: Homebrew folders are appended to `PATH` only when missing, instead of being put in front of the caller's `PATH`.
- Tests: post-edit, lintBlocking at the Stop check, symlinked protected entries, files outside the repository and worktree state isolation (70 checks). Test helpers now always send valid hook JSON.
- Checked in real Claude Code sessions (2.1.318, SwiftLint 0.65.1, Apple swift-format): guard, formatter and lint feedback, lintBlocking at edit and at Stop, failing verification.

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
