# mac-dev-plugins

A Claude Code plugin marketplace for native macOS development. It ships one plugin, **swift-harness**: a reusable working method that keeps Claude Code consistent on Swift/SwiftUI projects as they grow.

[Leggi in italiano](README.it.md)

## Why

Step-by-step plans keep each Claude Code session focused, but they don't stop drift between steps. As a project grows, the same UI pattern (a top notification pill, a hover button, a popover) gets rebuilt slightly differently in each feature, raw values spread across views, and visual and structural bugs follow.

swift-harness fixes this on three levels:

1. **The design system lives in code**, not in docs: tokens and shared components in a local Swift package.
2. **Claude knows where to look**: a short `CLAUDE.md`, path-scoped rules, a component registry and ADRs, loaded only when relevant.
3. **Checks are automatic**, not requests: hooks format, lint and verify, so "please don't hardcode values" becomes something Claude cannot skip.

## What's inside

| Type | Name | What it does |
|---|---|---|
| Skill (you run it) | `/swift-harness:setup` | Bootstraps or retrofits a project: `CLAUDE.md`, `.claude/rules/`, `docs/` (architecture hub, design system, component registry, ADR template), `.swiftlint.yml`, formatter config, `scripts/verify.sh`, hook config. Never overwrites existing files. |
| Skill (you run it) | `/swift-harness:audit` | Read-only audit of architecture, UI consistency and code health. Produces a prioritized report and an incremental migration plan. |
| Skill (automatic) | `ui-change` | Reuse-first procedure for any UI change: search the registry and the code, decide reuse, extend or create, implement with tokens, preview every state, update the registry. |
| Skill (automatic) | `design-system` | Local package layout, tokens, a shared presenter for pills and toasts, button styles, component gallery, snapshot tests, migration plan from hardcoded values. Includes Swift reference files. |
| Skill (automatic) | `feature` | Discover, plan, implement, verify, record: the loop for every feature or roadmap step. |
| Skill (automatic) | `adr` | Records an architecture decision and indexes it. |
| Subagent | `ui-reviewer` | Read-only review of a UI diff against the design system, the registry and the architecture rules. |
| Hook | SessionStart | Records the starting code state as a baseline (not as verified), warns if the last check failed on the same code, and reports missing tools. |
| Hook | PreToolUse | Asks for confirmation before Claude edits `project.pbxproj` or a protected path with the Edit or Write tools. Not a sandbox: see [Limitations](#limitations). |
| Hook | PostToolUse | Formats and lints the Swift file just edited (only files inside the project); lint results, formatter failures and SwiftLint configuration errors go back to Claude. |
| Hook | Stop | Runs your fast verification before Claude ends a turn, only when build inputs changed (Swift code, project and build settings, resources). |

Always-on context cost is about 770 tokens per session. Skills load their full instructions only when used.

### Hooks are opt-in per project

Every hook is a no-op unless the project contains `.claude/swift-harness.json` (created by `/swift-harness:setup`). Your other projects are untouched.

### How the end-of-turn check behaves

- Code unchanged since the session started or since the last successful check: nothing runs. The starting state is a baseline, not a pass: if it was already broken, the first change in the session runs the check and shows it.
- Code changed and the check fails: Claude is blocked and receives the last 60 lines of output.
- Claude tries to stop again without changing anything: it may stop, and you get a warning.
- After `maxAttempts` consecutive failures (default 3): Claude stops and you decide.
- With `lintBlocking: true`, files that failed SwiftLint after an edit are linted again here. The edit itself cannot be undone by a hook, so this is where it is caught: the turn is not recorded as passed until those files are clean.
- "Changed" means any build input: Swift files, `Package.resolved`, `.pbxproj`, `.xcconfig`, plists, entitlements, asset and string catalogs, `Resources/` folders, snapshot baselines, `scripts/`, lint and harness config. `.build` and DerivedData are ignored.
- A failure survives a new session: on startup or resume, Claude is told if the last check failed on the current code.
- Works per git worktree, so parallel agents each verify their own checkout.

### The SwiftLint design system rules

The generated `.swiftlint.yml` adds six custom rules that flag raw visual values outside the design system and tests:

| Rule | Flags |
|---|---|
| `ds_hardcoded_color` | `Color(red:…)`, `NSColor(calibratedRed:…)`, color literals |
| `ds_hardcoded_font_size` | `.system(size:)`, `NSFont.systemFont(ofSize: 12)`, `.custom(_, size:)` |
| `ds_hardcoded_padding` | `.padding(12)`, `.padding(.horizontal, 8)` |
| `ds_hardcoded_spacing` | `VStack(spacing: 8)` (zero is allowed) |
| `ds_hardcoded_radius` | `cornerRadius: 8`, `.cornerRadius(6)` |
| `ds_hardcoded_animation` | `.easeInOut(duration: 0.3)`, `.spring(response: 0.4…)` |

They start as warnings, which double as the migration to-do list. Switch a rule to `error` once its count reaches zero.

## Requirements

- macOS with Xcode (Swift toolchain, `xcodebuild`)
- Claude Code with plugin support
- `jq` (required by the hooks), `swiftlint` and `swiftformat` (recommended)

```bash
brew install jq swiftlint swiftformat
```

Apple's `swift-format`, bundled with Xcode, is supported as an alternative formatter.

## Install

In Claude Code:

```
/plugin marketplace add davidelarocca/mac-dev-plugins
/plugin install swift-harness@mac-dev-plugins
```

Recommended companion, for type diagnostics after every edit:

```
/plugin install swift-lsp@claude-plugins-official
```

## Use

1. Open your project in Claude Code and commit any pending work.
2. Run `/swift-harness:setup`. It detects the project structure, asks at most four questions (design system location, formatter, protected paths, verify commands) and generates the files on a `chore/swift-harness-setup` branch.
3. For an existing codebase, switch to plan mode and run `/swift-harness:audit`.
4. From then on, `ui-change`, `feature`, `design-system` and `adr` trigger on their own when relevant, and the hooks run automatically.

## Configuration

`.claude/swift-harness.json` in your project:

```json
{
  "format": "swiftformat",
  "lint": "swiftlint",
  "lintBlocking": false,
  "verify": {
    "enabled": true,
    "command": "scripts/verify.sh fast",
    "maxAttempts": 3
  },
  "protectedPaths": ["Sources/Audio/"],
  "guardPbxproj": true
}
```

| Key | Values | Default |
|---|---|---|
| `format` | `swiftformat`, `swift-format` (needs a `.swift-format` file, see below), `none` | `swiftformat` |
| `lint` | `swiftlint`, `none` | `swiftlint` |
| `lintBlocking` | `true` blocks Claude on SwiftLint errors and on SwiftLint failing to run or reporting an invalid configuration, and re-checks those files at the end of the turn; `false` only reports | `false` |
| `verify.enabled` | run the Stop check | `true` |
| `verify.command` | any shell command, exit 0 means pass | `scripts/verify.sh fast` |
| `verify.maxAttempts` | consecutive failures before Claude may stop | `3` |
| `protectedPaths` | path prefixes relative to the repo root that require approval before an Edit or Write (`../` and symlinks are resolved, also when the entry itself is a symlink) | `[]` |
| `guardPbxproj` | ask before edits to `*.pbxproj` | `true` |

With `swift-format`, keep a `.swift-format` file in the repository root (setup creates one). Without it, swift-format applies its defaults, including 2-space indentation, to every file Claude edits, and SessionStart warns about it.

After each Swift edit Claude gets one short line per tool: what the formatter changed (the changed lines, up to 12), and the SwiftLint result, including "no issues" or "excluded", so it can report what was actually checked.

The hooks append `/opt/homebrew/bin` and `/usr/local/bin` to `PATH` when missing, for sessions started from the GUI. Set `SWIFT_HARNESS_EXTRA_PATH` (colon-separated, empty for none) to change that list.

The generated `scripts/verify.sh` runs `swift test` on local packages and an incremental `xcodebuild build` in `fast` mode, and `xcodebuild test` plus strict SwiftLint in `full` mode. It uses a separate DerivedData folder so it never fights with an open Xcode. It never reports PASS without running at least one check: with no scheme and no package it fails with `NOT CONFIGURED`, and a listed package that does not exist is a failure.

## What the setup generates in your project

```
CLAUDE.md                      short, imports docs/ARCHITECTURE.md
.claude/
  swift-harness.json           turns the hooks on
  rules/
    ui-features.md             loads when Claude touches feature UI files
    design-system.md           loads when Claude touches the design system
    architecture.md            loads for any Swift file
docs/
  ARCHITECTURE.md              hub: modules, data flow, protected areas, links
  DESIGN_SYSTEM.md             principles, tokens, interaction patterns
  COMPONENT_REGISTRY.md        one row per shared component, plus "To consolidate"
  adr/0000-template.md
.swiftlint.yml
.swiftformat or .swift-format    formatter config (4 spaces, 160 columns)
scripts/verify.sh
```

## Repository layout

```
.claude-plugin/marketplace.json
plugins/swift-harness/
  .claude-plugin/plugin.json
  skills/        setup, audit, ui-change, design-system, feature, adr
  agents/        ui-reviewer
  hooks/         hooks.json
  scripts/       hook scripts (bash + jq)
tests/run.sh     tests for the hooks and the verify.sh template (bash, git, jq)
```

## Updating

Edit the plugin, bump `version` in `plugins/swift-harness/.claude-plugin/plugin.json`, push, then in Claude Code run `/plugin marketplace update mac-dev-plugins`.

Run `tests/run.sh` before pushing. It needs only bash, git and jq: `xcodebuild` and `swift` are faked.

To try local changes without reinstalling:

```bash
claude --plugin-dir ./plugins/swift-harness
```

## Limitations

- The Swift reference files in the `design-system` skill are examples to adapt, not a library.
- Snapshot tests render differently across macOS versions. Record and run them on the same OS, and re-record after major updates.
- The Stop check runs on your machine and takes as long as your fast verification. Keep `fast` under about two minutes.
- The protected-path guard covers the Edit, Write and MultiEdit tools only. A shell command run through Bash can still change a protected file. For hard limits use Claude Code [permission rules](https://code.claude.com/docs/en/permissions) (`deny`), and treat the guard as a check against accidental edits, not a sandbox.
- `verify.command` runs as a shell command in your project. Enabling the plugin means any repository that contains `.claude/swift-harness.json` can run its own commands when Claude ends a turn. Use it on projects you trust.

## License

[MIT](LICENSE)
