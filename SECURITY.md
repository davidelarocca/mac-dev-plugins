# Security

## Reporting a vulnerability

Please report security problems privately, not in a public issue: use **[Report a vulnerability](https://github.com/davidelarocca/swift-harness/security/advisories/new)** in this repository's Security tab.

Include the plugin version, your Claude Code and macOS versions, and the smallest `.claude/swift-harness.json` or repository layout that reproduces the problem. The maintainer aims to reply within a week. Fixes are released as a patch version and credited in the CHANGELOG unless you prefer otherwise.

## Supported versions

Only the latest release receives fixes.

## Trust model

swift-harness runs local commands on your machine through Claude Code hooks. Know what it does before you enable it:

| What runs | When | Where it comes from |
|---|---|---|
| `jq`, `git`, `shasum` | Every hook | Your system |
| `swiftformat` or `swift-format`, `swiftlint` | After Claude edits a Swift file | Your system |
| `verify.command` (default `scripts/verify.sh fast`) | Before Claude ends a turn, when build inputs changed | **The repository**: `.claude/swift-harness.json` and the script it points to |

The hooks do nothing in a repository that has no `.claude/swift-harness.json`.

**Repository commands.** Until [#6](https://github.com/davidelarocca/swift-harness/issues/6) ships (planned for v1.2.0), `verify.command` runs without asking you first. A repository you clone can therefore run its own commands when Claude ends a turn. Enable the plugin only in projects you trust. Planned fix: the command runs only after you approve it, and the approval is stored outside the repository and tied to the exact command and script.

**Protected paths are not a sandbox.** `protectedPaths` and the `project.pbxproj` guard ask for approval before the Edit, Write and MultiEdit tools change a file. A shell command run through Bash can still change those files. For hard limits use Claude Code [permission rules](https://code.claude.com/docs/en/permissions) (`deny`) and, for untrusted code, an isolated environment.

**What the plugin never does:** it sends no data anywhere, installs no tools, and changes no files outside the project, except its own state in the plugin data folder.
