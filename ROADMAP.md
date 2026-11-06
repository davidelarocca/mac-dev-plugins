# Roadmap

Where swift-harness is going, and why. Live status is in the [milestones](https://github.com/davidelarocca/swift-harness/milestones) and [issues](https://github.com/davidelarocca/swift-harness/issues). This page is updated with every release.

_Last updated: 6 November 2026, after v1.2.0._

**Guiding principle:** every check the harness claims to run must actually run, and must be backed by a test. New features come after the existing gates are reliable, and claims about impact come with measurements.

## Now: v1.3.0, architecture you can enforce

Turn the architecture written in your docs into checks.

| | What you get | Issue |
|---|---|---|
| 🧱 | **Architecture contracts for SwiftPM projects.** Declare which modules may depend on which; adding an undeclared dependency to `Package.swift` fails verification. It reads the real dependency graph, with no guessing from source text. | [#13](https://github.com/davidelarocca/swift-harness/issues/13) |
| 🧪 | **Test the problem itself.** A real-session scenario where Claude must reuse an existing toast instead of building a second one. | [#19](https://github.com/davidelarocca/swift-harness/issues/19) |
| 🧭 | **A product map Claude works from.** `/swift-harness:product-map` maps entities, their pages, where each one appears, relations and actions from the code, and lists the gaps: items you cannot open from where they are shown, related items shown as plain text, lists you cannot rename or reorder. The map then guides every UI change and review. | [#30](https://github.com/davidelarocca/swift-harness/issues/30) |
| 🗂️ | **A component registry that stays true.** Stale paths, missing entries and removed components are caught automatically. | [#7](https://github.com/davidelarocca/swift-harness/issues/7) |

## Later

| | What you get | Issue |
|---|---|---|
| 🖼️ | **Visual regression for shared components.** Gallery and snapshot tests on a pinned macOS version; baselines change only with explicit approval. | [#9](https://github.com/davidelarocca/swift-harness/issues/9) |
| 🧭 | **Context recovery after compaction.** A short checkpoint of the current task restored after Claude compacts its context. | [#10](https://github.com/davidelarocca/swift-harness/issues/10) |
| 🔐 | **Entitlements contract.** Sandbox, hardened runtime and capabilities read from the real entitlements and build settings; any change fails verification until you approve it. | [#32](https://github.com/davidelarocca/swift-harness/issues/32) |
| ⏱️ | **Performance budget.** Key operations measured against recorded baselines in the full check; a regression fails with the numbers. Later, a skill that explains slowness with a trace. | [#33](https://github.com/davidelarocca/swift-harness/issues/33) |
| 🔎 | **Detect protected-path changes made through Bash**, at the end-of-turn check. | [#11](https://github.com/davidelarocca/swift-harness/issues/11) |
| 📊 | **v2.0.0: a measured harness.** Repeatable evals of Claude with and without swift-harness: reuse, regressions, build passes, cost. Published with method and raw data. | [#8](https://github.com/davidelarocca/swift-harness/issues/8) |

## Shipped

| Version | Highlights |
|---|---|
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
