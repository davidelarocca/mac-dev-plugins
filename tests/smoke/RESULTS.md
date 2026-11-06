# Smoke test results

Newest first. Record the plugin version, the tool versions, the invariants result and anything notable in Claude's behaviour.

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
