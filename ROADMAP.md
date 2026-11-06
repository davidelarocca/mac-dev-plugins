# Roadmap

Where swift-harness is going, and why. Live status is in the [milestones](https://github.com/davidelarocca/swift-harness/milestones) and [issues](https://github.com/davidelarocca/swift-harness/issues). This page is updated with every release.

_Last updated: 6 November 2026, after v1.3.0._

**Guiding principle:** every check the harness claims to run must actually run, and must be backed by a test. New features come after the existing gates are reliable, and claims about impact come with measurements.

## Now: v1.4.0, visual coherence

Screens that hold up at every window size, reviewed as they look, not only as they are written.

| | What you get | Issue |
|---|---|---|
| 🪟 | **Window behavior.** Minimum, default and maximum sizes per main screen, rendered and checked at each size; popovers and secondary windows that stay inside a small window. | [#34](https://github.com/davidelarocca/swift-harness/issues/34) |
| 👁️ | **Design review on screenshots.** The reviewer looks at the rendered UI (snapshots, previews, the running app) against the design system and the product map. | [#35](https://github.com/davidelarocca/swift-harness/issues/35) |
| 🖼️ | **Visual regression for shared components.** Gallery and snapshot tests on a pinned macOS version; baselines change only with explicit approval. | [#9](https://github.com/davidelarocca/swift-harness/issues/9) |

## Later

| | What you get | Issue |
|---|---|---|
| ♿ | **Accessibility audit in UI tests** with Apple's `performAccessibilityAudit()`: missing labels, contrast, hit areas. | [#36](https://github.com/davidelarocca/swift-harness/issues/36) |
| 🧵 | **Ratchet on concurrency escape hatches.** New `@unchecked Sendable`, `nonisolated(unsafe)` and similar need a reason. | [#37](https://github.com/davidelarocca/swift-harness/issues/37) |
| 🧭 | **Context recovery after compaction.** A short checkpoint of the current task restored after Claude compacts its context. | [#10](https://github.com/davidelarocca/swift-harness/issues/10) |
| 🔐 | **Entitlements contract.** Sandbox, hardened runtime and capabilities read from the real entitlements and build settings; any change fails verification until you approve it. | [#32](https://github.com/davidelarocca/swift-harness/issues/32) |
| ⏱️ | **Performance budget.** Key operations measured against recorded baselines in the full check; a regression fails with the numbers. Later, a skill that explains slowness with a trace. | [#33](https://github.com/davidelarocca/swift-harness/issues/33) |
| 🔎 | **Detect protected-path changes made through Bash**, at the end-of-turn check. | [#11](https://github.com/davidelarocca/swift-harness/issues/11) |
| 📊 | **v2.0.0: a measured harness.** Repeatable evals of Claude with and without swift-harness: reuse, regressions, build passes, cost. Published with method and raw data. | [#8](https://github.com/davidelarocca/swift-harness/issues/8) |

## Shipped

| Version | Highlights |
|---|---|
| [1.3.0](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.3.0) | Architecture you can enforce: SwiftPM architecture contracts checked from the real dependency graph, a component registry checked against the code, `/swift-harness:product-map` for navigation and lifecycle gaps, security settings proposed as protected paths, and real-session tests for reuse and product coherence. |
| [1.2.1](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.2.1) | Fixes from an external audit: `verify.inputs` and a warning for verify commands with quotes, Xcode project paths with spaces, docs on re-verification after an update. |
| [1.2.0](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.2.0) | Trust and onboarding: the repository's verify command runs only after you approve it (`/swift-harness:approve-verify`), `/swift-harness:doctor` diagnoses the setup, and results are tied to the plugin version so an update re-verifies once. |
| [1.1.3](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.1.3) | Strict lint means strict: with `lintBlocking`, a missing SwiftLint fails the end-of-turn check instead of passing unlinted code. |
| [1.1.2](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.1.2) | Verification fixes from an external review: lint alone never passes `verify.sh full`, design-system colors checked at runtime, blocking plugin validation. |
| [1.1.1](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.1.1) | Repository and marketplace renamed to swift-harness. Public roadmap, security policy, contribution guide, demo. |
| [1.1.0](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.1.0) | CI on every pull request: hook tests with macOS bash 3.2, ShellCheck, compiled Swift references. Claude Code smoke test suite with 7 scenarios checked automatically. |
| [1.0.3](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.0.3) | Clearer feedback to Claude: labelled formatter changes, "no issues" when lint passes, explicit guidance when lint blocks. `.swift-format` template. |
| [1.0.2](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.0.2) | No silent formatter or SwiftLint failures, including invalid SwiftLint configurations. `lintBlocking` enforced at the end of the turn. |
| [1.0.1](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.0.1) | Never PASS without a real check. Protected paths resolved through symlinks. Every build input triggers verification. |
| [1.0.0](https://github.com/davidelarocca/swift-harness/releases/tag/swift-harness--v1.0.0) | First release: six skills, UI reviewer, four hooks, project templates. |

## Have an idea?

Start a thread in [Discussions](https://github.com/davidelarocca/swift-harness/discussions) or open a [feature request](https://github.com/davidelarocca/swift-harness/issues/new?template=feature_request.yml). Concrete examples of where Claude goes wrong on your Swift project are the most useful input.
