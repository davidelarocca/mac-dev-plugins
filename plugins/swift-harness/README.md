# swift-harness

Claude Code plugin for native macOS apps in Swift/SwiftUI. It keeps Claude consistent as a project grows: a reuse-first design system workflow, a project bootstrap (`/swift-harness:setup`), a read-only audit (`/swift-harness:audit`), a UI reviewer subagent, and opt-in hooks that format, lint and verify Swift code automatically. Hooks only act in projects that contain `.claude/swift-harness.json`.

Install (Claude Code 2.1.275 or later):

```
/plugin install swift-harness --marketplace davidelarocca/swift-harness
```

Or in two steps, on any version with plugin support:

```
/plugin marketplace add davidelarocca/swift-harness
/plugin install swift-harness@swift-harness
```

Use it on projects you trust: the end-of-turn check runs the verify command configured in the project. See [SECURITY.md](../../SECURITY.md).

Full documentation and configuration: see the [repository README](../../README.md).
