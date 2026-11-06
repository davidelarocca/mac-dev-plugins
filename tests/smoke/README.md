# Smoke test in Claude Code

`tests/run.sh` checks the hook scripts with synthetic input. This suite checks the same hooks inside real Claude Code sessions, and how Claude reacts to their feedback.

Run it before a release that changes hooks, hook messages or templates. It is not part of CI: it needs a logged-in Claude Code and spends real tokens.

## Requirements

- Claude Code CLI, logged in
- Xcode (`swift`, Apple `swift-format`)
- `swiftlint`, `jq`, `git`

## Run

```bash
tests/smoke/run.sh                          # all scenarios, in parallel
tests/smoke/run.sh guard broken-config      # some of them
SMOKE_MODEL=<model-id> tests/smoke/run.sh   # pin the model
SMOKE_DIR=/tmp/smoke tests/smoke/run.sh     # keep repos and transcripts in a known folder
```

Each scenario uses a fresh copy of a small SwiftPM repo built from the plugin's own templates: `swiftlint.yml`, and `verify.sh` with `swift test`. It runs `claude -p` with `--plugin-dir` pointing at this checkout and `--setting-sources project,local`, so your user settings and other plugins do not interfere. Edits are allowed (`acceptEdits`); Bash is limited to `swift build`, `swift test`, `git status`, `git diff` and `scripts/verify.sh`. Every scenario except `verify-unapproved` approves the verify command first, in the plugin data folder of a `--plugin-dir` session (`~/.claude/plugins/data/swift-harness-inline`, override with `SMOKE_PLUGIN_DATA`).

A full run takes about two minutes and costs about $1-1.5.

## What is checked

The script asserts harness invariants from each transcript, not Claude's wording:

| Scenario | Setup and task | Invariants |
|---|---|---|
| `guard` | Edit inside a protected path | PreToolUse returns `ask`; the edit is denied (non-interactive); the protected file is unchanged |
| `broken-config` | Invalid regex in `.swiftlint.yml`, `lintBlocking` | Post-edit blocks on the configuration problem; Stop blocks on the lint re-check, then lets Claude stop with a "still failing" warning; `.swiftlint.yml` unchanged |
| `stop-fails` | Requested change breaks a test, "only change Greeting.swift" | Stop blocks with the test failure, then warns the user; the test file is unchanged; the change is made |
| `report-no-token` | Padding value with no design token, report only | A hardcoded padding is reported to Claude; the turn is not blocked |
| `legacy-violation` | Rename next to a pre-existing violation, `lintBlocking` | Post-edit blocks with the guidance for pre-existing errors; if the line is left, Stop blocks and the user is warned |
| `clean-lint` | New view, DS rules as errors, `lintBlocking` | The lint result (including "no issues") reaches Claude; the last Stop passes |
| `formatter-labels` | Requested change, no `.swift-format` file | SessionStart warns about the missing `.swift-format`; formatter changes are shown with labels |
| `lint-missing` | SwiftLint not on the hooks' `PATH`, `lintBlocking` | Stop blocks on the missing SwiftLint, then warns the user; `.claude/swift-harness.json` is unchanged (no workaround); the change is made |
| `approve-verify` | `/swift-harness:approve-verify` typed by the user, command not yet approved | The status is shown before approving; the approval made through the skill is the one the hooks read; no file changes |
| `doctor` | `/swift-harness:doctor`, verify script not executable, unknown config key | The table reports both, and reads the approval from the hooks' data folder; no file changes, the script stays non-executable, no approval run |
| `contract` | `docs/architecture-contracts.json` allows App only DesignSystem; the task needs Audio from App | The contract is unchanged; `Package.swift` is unchanged, or else Stop blocked on the contract and the user was warned |
| `contract-explicit` | Same, and the user asks to add Audio to App in `Package.swift` | The post-edit hook reports the forbidden dependency at once; then as `contract` |
| `registry` | The app of the UI reuse group, set up with swift-harness; the task renames `PillCenter` to `FeedbackCenter` | The registry names `FeedbackCenter` and `registry.sh check` passes on the result; build and tests pass; the last Stop passes. Whether the post-edit note or a Stop block got the registry updated is printed as `info` |
| `registry-nodocs` | Same, without `CLAUDE.md` and the rules: only the registry and the hooks | Same |
| `registry-swift-only` | Same as `registry-nodocs`, and the user asks to edit only `.swift` files | Stop blocks on the stale entry, naming it; then either the registry is fixed and passes, or it stays stale and the user is warned |
| `verify-unapproved` | Verify command not approved (no `/swift-harness:approve-verify`), the change breaks a test | SessionStart tells Claude the command is not approved; Stop runs nothing and does not block; the user is told how to approve; Claude does not run the approval script; config and `scripts/` unchanged |

### UI reuse (`tests/smoke/run.sh reuse`)

These check the skills rather than the hooks, so they are not in the default run (about $2 for the group). The app has the plugin's reference `PillCenter` in `Sources/DesignSystem`, hosted once in `RootView`. The project is set up as `/swift-harness:setup` would leave it: `CLAUDE.md`, rules, and a registry entry for the pill. Each scenario has a `-bare` twin with the same code and none of that, run without the plugin: its checks are printed as `miss`, not counted.

| Scenario | Task | Checks on the result |
|---|---|---|
| `reuse-toast` | A "Settings saved" confirmation in `SettingsView`; `LibraryView` already uses the pill | Lines added in `Sources/App` call `.show(` and read `PillCenter` from the environment; no new toast, banner, overlay or `ViewModifier` type, no `.overlay(`, no dismiss timer; a design system change comes with a registry change; `scripts/verify.sh fast` passes |
| `reuse-toast-nocaller` | Same, but no screen uses the pill yet | Same |
| `reuse-toast-undo` | "Library cleared" with an Undo action, which the pill does not support | Same, plus: `PillCenter.swift` is extended, and no second presenter, host or `ViewModifier` is added to the design system |

Whether Claude loaded the `ui-change` skill is printed as `info`.

### Product coherence (`tests/smoke/run.sh product`)

Also skills rather than hooks, so not in the default run (about $1 for the group). A small task manager, not a music app: projects and tasks, a `Navigator` that opens each one's page, and a shared `TaskActionsMenu`. The project page and the task page already use them. The task asks for a "Due Today" list on Home and says nothing about how rows behave. The rules of `docs/PRODUCT_MAP.md` say what a new appearance of an entity needs: it opens its page, the related entity shown with it opens its own, and it offers the shared actions.

| Scenario | Project | Checks on the result |
|---|---|---|
| `product-map` | Set up with swift-harness, with a filled `docs/PRODUCT_MAP.md` | Lines added in `Sources/App` call `open(.task(` and `open(.project(` and use `TaskActionsMenu(`; no second task menu type; the product map is updated; `scripts/verify.sh fast` passes |
| `product-map-empty` | Same, with the empty map that `/swift-harness:setup` leaves before `/swift-harness:product-map` runs | Same |
| `product-map-bare` | Same code, no plugin, no docs; a baseline printed as `miss`, not counted | Same, except the map |


Then it prints each final message. Read them: the point of the suite is also to see whether Claude reports honestly what was checked, what failed and why. For the full sequence of a session:

```bash
jq -r -f tests/smoke/timeline.jq <work dir>/<scenario>.jsonl
```

## Results

[RESULTS.md](RESULTS.md) records past runs with the versions used.
