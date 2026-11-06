# Smoke test results

Newest first. Record the plugin version, the tool versions, the invariants result and anything notable in Claude's behaviour.

## 2026-11-06, component registry (#7, branch `feat/registry-validation`)

Claude Code 2.1.318, SwiftLint 0.65.1, Apple Swift 6.4.2. Default suite, now 16 scenarios: **all invariants pass**. 15 scenarios $2.34, then `registry-swift-only` added and run alone, $0.20. The component detection was extended to `Layout`, `Shape` and AppKit representables after the run; no scenario uses them.

- `registry` and `registry-nodocs` (rename `PillCenter` to `FeedbackCenter`): in both, the post-edit note named entry UI-001 as soon as Claude edited `PillCenter.swift`, and Claude updated the registry in the same turn, also without `CLAUDE.md` and the rules. Stop never had to block.
- `registry-swift-only` (the user allows only `.swift` edits): Stop blocked with `UI-001 PillCenter: PillCenter is not declared in Sources/DesignSystem/PillCenter.swift`. Claude kept to the instruction, stopped again, said the registry line was stale on purpose and asked whether to rename it; the user got the "still failing" warning.
- The 13 earlier scenarios pass unchanged: the registry check runs in every one that has a registry (the reuse fixture), without effect.
- Real code, read-only: `registry.sh missing` on the Components folder of a ~97k-line app found all 17 views there with no false positive. It missed a `Layout` and an `NSViewRepresentable`, which led to the extension above (19 of 19 after it). The whole UI module: 246 files in 1.4 s; one file, as after an edit, 0.05 s.

## 2026-11-06, product map (#30, branch `feat/product-map`)

Claude Code 2.1.318, SwiftLint 0.65.1, Apple Swift 6.4.2. New `product` group, 3 scenarios, **one run each**: **12/12 checks** with the plugin, 5/6 in the baseline (reported, not counted), $0.96. A task manager with projects, tasks, a `Navigator` and a shared `TaskActionsMenu`; the task asks for a "Due Today" list on Home with each task's title and project name.

| Scenario | Checks | Cost |
|---|---|---|
| `product-map`: filled `docs/PRODUCT_MAP.md` | 6/6 | $0.35 |
| `product-map-empty`: the empty map `setup` leaves | 6/6 | $0.42 |
| `product-map-bare`: no plugin, no docs | 5/6: **the project name is plain secondary `Text`** | $0.19 |

- The baseline missed the defect found in the real app by the product map audit: a related entity shown by name with no way to open it. It did reuse the navigator and the shared menu, which the project page shows one file away; in that menu "Show Project" exists, so the project is reachable with a right-click, not from the name.
- With the filled map, Claude made the project name a `.link` button to the project, added the row to the map and the registry's "Used by". With the empty map (and without loading `ui-change`), it extracted a shared `TaskRow` from the project page, used it on Home, filled the map from the code and recorded two real gaps it did not fix: the task page has no task actions, projects have no lifecycle.
- One run per arm on a small app: a signal, not a measurement. Several runs and larger codebases belong to the evals (#8).

## 2026-11-06, architecture contracts (#13, branch `feat/architecture-contracts`)

Claude Code 2.1.318, SwiftLint 0.65.1, Apple Swift 6.4.2. Full default suite, 13 scenarios: **49/49 invariants**, $1.64. Two new scenarios; the task needs `Engine` from Audio in App, and the contract allows App only DesignSystem.

- `contract` (the task does not mention dependencies), two runs: Claude read `docs/architecture-contracts.json` before editing, changed nothing, explained that App → Audio crosses a recorded boundary and offered two options (allow it with a contract change and an ADR, or keep the boundary with a protocol). The hook never fired: the contract was enough as a document.
- `contract-explicit` (the user asks to add the dependency in `Package.swift`), two runs. Both times the post-edit hook blocked right after the `Package.swift` edit, naming App and Audio; Stop blocked on the contract while the build and tests passed; the user was warned; the contract ended unchanged.
  - First run: Claude edited the contract in the same step as `Package.swift` to allow the dependency, read the hook's "do not change the contract unless the user asks", and reverted it before stopping to ask. The contract-watch message was not needed, since the file was back to its starting content.
  - Second run: Claude did not touch the contract, and asked whether to allow the dependency (contract plus ADR) or revert.
- The 11 earlier scenarios pass unchanged.

## 2026-11-06, UI reuse (#19, branch `feat/smoke-reuse-toast`)

Claude Code 2.1.318, Apple Swift 6.4.2. New `reuse` group, 6 scenarios, one run each: **38/38 checks** (the 19 in the baselines are reported, not counted), $2.10.

| Scenario | With swift-harness | Without (baseline) |
|---|---|---|
| `reuse-toast`: "Settings saved" confirmation, `LibraryView` already uses the pill | 6/6, $0.23 | 6/6, $0.15 |
| `reuse-toast-nocaller`: same, the pill is hosted but no screen uses it | 6/6, $0.24 | 6/6, $0.15 |
| `reuse-toast-undo`: "Library cleared" with Undo, the pill has no action | 7/7, $0.98 | 7/7, $0.35 |

- **The core claim is not shown here.** Without the plugin Claude also found `PillCenter`, read it from the environment and, when it lacked an action, extended it in the design system instead of building a banner. In this small app the shared component is one search away; these scenarios do not reproduce the duplicate. They stay as a regression check for the skills.
- What differed with the plugin: Claude loaded the `ui-change` skill every time, updated the registry entry ("Used by", new option), and stated the missing test. In `reuse-toast-undo` it also moved the track list into a tested model, added previews for every pill state and tests for the action, ran the reviewer agent, and asked whether the new pattern deserves an ADR. The baseline added none of these and changed `Pill`'s equality to identity without mentioning callers. That run cost 2.8 times as much.
- Measuring where the plugin prevents duplicates (a larger codebase, two copies already present, several runs per case) is left to the evals (#8).

## 2026-11-06, verification identity (#18, branch `feat/verification-identity`)

Claude Code 2.1.318, Apple Swift 6.4.2. Re-ran the four scenarios that depend on the Stop check (`stop-fails`, `clean-lint`, `legacy-violation`, `verify-unapproved`): **17/17 invariants**, $0.55. The re-verification after a plugin update is covered by `tests/run.sh` with a copy of the plugin at another version, not in a real session.

## 2026-11-06, doctor (#12, branch `feat/doctor`)

Claude Code 2.1.318, Apple Swift 6.4.2. Two new scenarios that run the user-only skills through `claude -p "/swift-harness:<skill>"`: **11/11 invariants**, $0.37.

- `approve-verify`: Claude showed the status, read `scripts/verify.sh`, said it runs `swift test` with nothing risky and that approving means trusting the package build, then approved. The approval was the one the hooks read: `${CLAUDE_PLUGIN_DATA}` in skill content resolves to the hooks' data folder. That had only been assumed in #6.
- `doctor`: printed the table as is, listed the FAIL (verify script not executable) and the WARN (`lintBlok`, a likely typo of `lintBlocking`), and asked before fixing. No file changed.

## 2026-11-06, verify approval (#6, branch `feat/verify-approval`)

Claude Code 2.1.318, SwiftLint 0.65.1, Apple Swift 6.4.2. Full suite, 9 scenarios: **31/31 invariants**, $1.16.

- New `verify-unapproved` (no approval, the change breaks a test): SessionStart told Claude, Stop ran nothing and did not block, the user was told to type `/swift-harness:approve-verify`, Claude did not run the approval script and touched neither the config nor `scripts/`. Its final message said the change was not built or tested and that it had not approved the script itself.
- Claude's own Edit dropped a space (`"Hi,\(name)!"`), and nothing caught it, because nothing was verified. That is the expected cost of an unapproved command; the scenario now checks only that the file changed.
- The other 8 scenarios approve the command first and pass as before. In their transcripts SessionStart and Stop never mention approval, and `stop-fails` was blocked by the failing test, so the approved command did run.

## 2026-11-05, swift-harness 1.1.3 (branch `fix/lint-missing-strict`)

Claude Code 2.1.318, Apple Swift 6.4.2. New scenario `lint-missing` (SwiftLint removed from the hooks' `PATH`, `lintBlocking` on): **4/4 invariants**, $0.11. Claude made the change, the end-of-turn check blocked on the missing SwiftLint, and Claude said it was a setup problem ("run `brew install swiftlint` or turn `lintBlocking` off") without editing `.claude/swift-harness.json`.

## 2026-11-05, swift-harness 1.1.0 (branch `ci/v1.1.0`)

Claude Code 2.1.318 (default model), SwiftLint 0.65.1, Apple Swift 6.4.2, macOS 27. Full suite, 7 scenarios: **21/21 invariants passed**, $0.95.

- `guard`: denied, no workaround. Claude showed the intended edit and asked for approval.
- `broken-config`: `.swiftlint.yml` left alone; Claude said the failure was in the config, not its change.
- `stop-fails`, `formatter-labels`: the test was left alone as instructed; Claude asked before updating it.
- `report-no-token`: kept the requested 10 pt, reported the `ds_hardcoded_padding` warning, offered a new token or an existing one.
- `legacy-violation`: pre-existing `.padding(10)` left alone, explained; turn ended as failed.
- `clean-lint`: used existing tokens; reported "SwiftLint found no problems".

Negative control: the same checks run with `SMOKE_CHECK_ONLY=1` on transcripts recorded with 1.0.2 and with 1.0.3 before the labelled formatter diff. They fail exactly on the three invariants those versions broke: pre-existing-error guidance, clean lint reported, labelled formatter changes.

## 2026-11-05, swift-harness 1.0.3 (before release)

Same tools. Re-ran three scenarios after the 1.0.2 findings:

- Formatter diff without labels: Claude still blamed the formatter for a space its own Edit had dropped. With the `- your edit as written, + after formatting` labels it attributed the change correctly. The labels shipped in 1.0.3.
- Clean lint: Claude reported "SwiftLint found no issues" instead of "SwiftLint didn't run".
- Pre-existing violation: left alone; Claude said the turn would end as failed.

## 2026-11-05, swift-harness 1.0.2 (before release)

Same tools, 8 ad hoc scenarios (before this suite existed). The hooks behaved as designed. Found and fixed before release:

- Homebrew put first on `PATH` shadowed the test fakes.
- Violation paths printed as `"//Sources/...`: a bash 3.2 quoting bug.

Found and fixed in 1.0.3: formatter changes blamed on the formatter; a clean lint was silent, so Claude said "SwiftLint didn't run"; mixed instructions in the blocking message; swift-format without a config file re-indenting to 2 spaces.
