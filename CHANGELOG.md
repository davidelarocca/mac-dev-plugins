# Changelog

## Unreleased

- Smoke suite: a `reuse` group of 6 scenarios for the problem swift-harness exists for, a second copy of an existing UI component ([#19](https://github.com/davidelarocca/swift-harness/issues/19)). The app has a shared pill presenter; Claude is asked for a confirmation on another screen, then for one with an Undo action the pill does not support. Each scenario also runs without the plugin as a baseline. Result: with this model and this small app, Claude reused or extended the pill in every run, with and without swift-harness. The differences were in the registry, previews, tests and cost, recorded in `tests/smoke/RESULTS.md`. Run with `tests/smoke/run.sh reuse`; not part of the default run.

## swift-harness 1.2.0 (2026-11-06)

Trust and onboarding. **Upgrading:** the end-of-turn check runs nothing from the repository until you type `/swift-harness:approve-verify` once in each project (and each worktree). Claude is told at session start, and `/swift-harness:doctor` shows it.

- **Breaking for existing projects:** the end-of-turn check runs the repository's `verify.command` only after you approve it ([#6](https://github.com/davidelarocca/swift-harness/issues/6)). Type `/swift-harness:approve-verify` once per project (and per worktree) after updating. Until then nothing from the repository runs, Claude is told at session start, and you get one warning per code state. The approval is stored in the plugin data folder, outside the repository, and covers the project path, the command and the content of each file it names: change any of them and the check asks again. `/swift-harness:approve-verify revoke` removes it. `lintBlocking` keeps working without the approval, but a clean lint alone is not recorded as a passed verification.
- `/swift-harness:setup` ends by asking you to approve the generated verify command.
- New `/swift-harness:doctor` ([#12](https://github.com/davidelarocca/swift-harness/issues/12)): a read-only diagnosis of the project's setup, one PASS / WARN / FAIL / INFO row per check with the fix. It checks jq, Xcode, the formatter and SwiftLint, unknown or invalid config keys, `{{...}}` placeholders left in generated files, protected paths that do not exist, the verify script (present, executable, scheme or packages set, packages that exist) and its approval, `.swift-format` with swift-format, the SwiftPM layout (for the planned architecture contracts) and the last verification of the current code. It changes no file and creates no state folder.
- A verification result now belongs to the code and to the plugin version ([#18](https://github.com/davidelarocca/swift-harness/issues/18)). Before, a pass recorded by an older version still counted after an update that made the checks stricter. Now unchanged code is verified again once after an update. The project's policy (`lintBlocking`, `verify.command`) was already part of the code state.
- More build inputs count as changes: workspaces (`contents.xcworkspacedata`), and every file under a SwiftPM `Sources/` or `Tests/` folder, so resources outside `Resources/` and test fixtures trigger the check. Xcode per-user state (`xcuserdata`) and `.DS_Store` are ignored.
- SECURITY.md describes what the approval covers and what it does not: files the command reads without naming them, the build itself (Run Script phases, SwiftPM manifests and plugins), and Claude Code's own project hooks. The "never does" guarantee now covers only the plugin's own scripts: an approved verify command runs with your permissions, and even the generated `verify.sh` downloads dependencies and writes SwiftPM and Xcode caches outside the project.
- Smoke suite: 11 scenarios. New: `verify-unapproved`, `approve-verify` and `doctor`.

## swift-harness 1.1.3 (2026-11-05)

- `lintBlocking`: strict mode now means strict ([#17](https://github.com/davidelarocca/swift-harness/issues/17)). If SwiftLint is not installed, the end-of-turn check fails after code changes, with a message telling Claude to ask the user to install it or turn `lintBlocking` off. Before, unlinted code could be recorded as passed. SessionStart says so up front. The usual `maxAttempts` limit still applies. No change without `lintBlocking`, or with `lint` set to `none`.
- Smoke suite: new `lint-missing` scenario. In a real session Claude reported the setup problem and did not touch `.claude/swift-harness.json`.

## swift-harness 1.1.2 (2026-11-05)

Verification fixes from an external engineering review. No configuration changes needed.

- `verify.sh` template: in `full` mode SwiftLint no longer counts as a verification. With no scheme and no package, `full` now reports `NOT CONFIGURED` like `fast`, instead of PASS after linting alone. Regenerate or patch `scripts/verify.sh` in existing projects.
- SessionStart: with `lintBlocking`, it lists the files that still failed SwiftLint at the last check. Unchanged code is not re-checked, by design, so this is now said explicitly.
- Design-system fixture: the six semantic colorsets had wrong folder names and empty components (generated by a zsh loop that did not split words), so CI compiled them without checking anything. They are fixed, and CI now resolves every color at runtime.
- Found by the new runtime test: with Xcode 26 (Swift 6.3), `swift build` and `swift test` copy a package's `Colors.xcassets` without compiling it, so named design-system colors do not resolve; Xcode 27 compiles it. CI checks the colors with `xcodebuild test`, and the `design-system` skill and README say so.
- CI: `claude plugin validate` is now a blocking check. The plugin has an icon, and its README has install lines; the validator reports nothing.
- README: one-step install for Claude Code 2.1.275 or later, and a "projects you trust" note next to the install commands.

## swift-harness 1.1.1 (2026-11-05)

The repository and the marketplace are now both called **swift-harness**. The plugin's behaviour is unchanged.

- New install commands:
  ```
  /plugin marketplace add davidelarocca/swift-harness
  /plugin install swift-harness@swift-harness
  ```
- If you added the marketplace under its old name, switch once:
  ```
  /plugin marketplace remove mac-dev-plugins
  /plugin marketplace add davidelarocca/swift-harness
  /plugin install swift-harness@swift-harness
  ```
  Old GitHub URLs redirect to the new repository.
- New documentation: public [roadmap](ROADMAP.md), [security policy and trust model](SECURITY.md), [contribution guide](CONTRIBUTING.md), Code of Conduct, issue forms, and a redesigned README with a demo recorded in a real Claude Code session.

## swift-harness 1.1.0 (2026-11-05)

Automated validation. The plugin's behaviour is unchanged.

- CI (GitHub Actions) on every pull request and push to `main`:
  - `tests/run.sh` on macOS with `/bin/bash` 3.2, the version the hooks must support;
  - ShellCheck, `bash -n` and JSON validation of manifests and templates;
  - a build of the design-system reference files with their tests;
  - a check that the `.swift-format` template is accepted;
  - `claude plugin validate`, informational for now.
- `tests/fixtures/design-system`: SwiftPM package that compiles `Tokens.swift`, `PillCenter.swift` and `SnapshotTest.swift` straight from the skill's references, with swift-snapshot-testing pinned in `Package.resolved`. Snapshot tests are built, not run, because their baselines depend on the macOS version.
- `tests/smoke/`: Claude Code smoke test. It runs 7 scenarios in real sessions and checks the harness invariants from the transcripts: hook results, permission denials, files that must not change. `SMOKE_CHECK_ONLY=1` re-checks existing transcripts without spending tokens. Results are recorded in `tests/smoke/RESULTS.md`.

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
