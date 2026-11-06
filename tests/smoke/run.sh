#!/bin/bash
# Smoke test of swift-harness inside real Claude Code sessions.
#
# Builds a disposable SwiftPM repo from the plugin's own templates, runs each scenario
# with `claude -p --plugin-dir`, then checks the harness invariants from the transcript
# (hook exit codes and messages, permission denials, files that must not change).
# Claude's wording is not asserted: final messages are printed for review.
#
# Needs: claude (logged in), Xcode (swift, swift-format), swiftlint, jq, git.
# Costs real tokens: about $0.10-0.25 per scenario.
#
# Usage: tests/smoke/run.sh [scenario ...]     (default: all)
#   SMOKE_DIR=<dir>    where repos and transcripts go (default: a new temp dir)
#   SMOKE_MODEL=<id>   model for the sessions (default: Claude Code's default)
#   SMOKE_CHECK_ONLY=1 only re-check the transcripts and repos already in SMOKE_DIR
#   SMOKE_PLUGIN_DATA=<dir> plugin data folder of a --plugin-dir session, where scenarios
#                      approve the verify command (default: ~/.claude/plugins/data/swift-harness-inline)

set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$HERE/../.." && pwd -P)"
PLUGIN="$REPO/plugins/swift-harness"
TEMPLATES="$PLUGIN/skills/setup/templates"
WORK="${SMOKE_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/swift-harness-smoke.XXXXXX")}"
WORK="$(mkdir -p "$WORK" && cd "$WORK" && pwd -P)"

ALL_SCENARIOS="guard broken-config stop-fails report-no-token legacy-violation clean-lint formatter-labels lint-missing verify-unapproved approve-verify doctor"
PLUGIN_DATA="${SMOKE_PLUGIN_DATA:-$HOME/.claude/plugins/data/swift-harness-inline}"

for tool in claude swift swiftlint jq git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "smoke: $tool not found" >&2; exit 2; }
done

# ---------- fixture ----------

build_base() {
  local b="$WORK/base"
  rm -rf "$b"
  mkdir -p "$b/Sources/DesignSystem" "$b/Sources/App" "$b/Sources/Audio" "$b/Tests/AppTests" "$b/scripts" "$b/.claude"
  cat >"$b/Package.swift" <<'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Smoke",
    platforms: [.macOS(.v14)],
    products: [.library(name: "App", targets: ["App"])],
    targets: [
        .target(name: "DesignSystem"),
        .target(name: "Audio"),
        .target(name: "App", dependencies: ["DesignSystem"]),
        .testTarget(name: "AppTests", dependencies: ["App"]),
    ]
)
EOF
  cat >"$b/Sources/DesignSystem/Tokens.swift" <<'EOF'
import CoreGraphics

public enum Spacing {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
}

public enum Radius {
    public static let small: CGFloat = 6
    public static let medium: CGFloat = 8
}
EOF
  cat >"$b/Sources/App/Greeting.swift" <<'EOF'
public func greeting(for name: String) -> String {
    "Hello, \(name)!"
}
EOF
  cat >"$b/Sources/Audio/Engine.swift" <<'EOF'
public struct Engine {
    public var isRunning = false

    public init() {}
}
EOF
  cat >"$b/Tests/AppTests/GreetingTests.swift" <<'EOF'
@testable import App
import Testing

@Test func greetsByName() {
    #expect(greeting(for: "Ada") == "Hello, Ada!")
}
EOF
  sed 's#{{DS_EXCLUDED_REGEX}}#Sources/DesignSystem/|Tests/#' "$TEMPLATES/swiftlint.yml" >"$b/.swiftlint.yml"
  sed -e 's|{{XCODE_CONTAINER_FLAG}}||' -e 's|{{SCHEME}}||' -e 's|{{LOCAL_PACKAGES}}|"."|' \
    "$TEMPLATES/verify.sh" >"$b/scripts/verify.sh"
  chmod +x "$b/scripts/verify.sh"
  printf '.build/\n' >"$b/.gitignore"
  git -C "$b" init -q
  git -C "$b" add -A
  git -C "$b" -c user.email=smoke@example.com -c user.name=smoke commit -qm "smoke fixture"
  (cd "$b" && scripts/verify.sh fast >/dev/null 2>&1) || { echo "smoke: fixture does not verify" >&2; exit 2; }
}

# ---------- scenarios ----------
# Each scenario_<name> sets CONFIG (swift-harness.json), TASK (prompt) and SETUP (shell
# run in the repo before the session), APPROVE=0 to leave the verify command unapproved,
# and EXTRA_TOOLS for more allowed tools. Each check_<name> asserts invariants.

BASE_CONFIG='"format":"swift-format","lint":"swiftlint","verify":{"command":"scripts/verify.sh fast","maxAttempts":3}'
FOUR_SPACES="printf '{\"version\":1,\"indentation\":{\"spaces\":4}}\n' > .swift-format"
DS_ERRORS="sed -i '' 's/severity: warning/severity: error/' .swiftlint.yml"
BADGE_TASK='Add a SwiftUI view `GreetingBadge` in Sources/App/GreetingBadge.swift that shows `greeting(for: name)` for a `name: String` property, with 12 points of padding and a rounded rectangle background with corner radius 8.'
GREETING_TASK='Change greeting(for:) so it returns "Hi, <name>!" instead of "Hello, <name>!". Only change Sources/App/Greeting.swift.'

scenario_guard() {
  CONFIG="{$BASE_CONFIG,\"protectedPaths\":[\"Sources/Audio/\"]}"
  TASK='Add a `volume` property of type Float with default value 1.0 to the Engine struct in Sources/Audio/Engine.swift.'
  SETUP="$FOUR_SPACES"
}
check_guard() {
  expect "guard asked for approval" has_hook PreToolUse 0 '"permissionDecision": "ask"'
  expect "edit was denied by the hook" has_denial 'protected area'
  expect "protected file unchanged" unchanged Sources/Audio
}

scenario_broken_config() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK='Add a function `farewell(for name: String) -> String` that returns "Goodbye, <name>!" in Sources/App/Greeting.swift.'
  SETUP="$FOUR_SPACES; printf '  ds_broken_rule:\n    regex: \"(unclosed\"\n    message: \"broken on purpose\"\n' >> .swiftlint.yml"
}
check_broken_config() {
  expect "post-edit blocked on the SwiftLint configuration" has_hook PostToolUse 2 'configuration problem'
  expect "Stop blocked on the SwiftLint re-check" has_hook Stop 2 'SwiftLint \(lintBlocking\)'
  expect "user warned that the check is still failing" has_hook Stop 0 'still failing'
  expect ".swiftlint.yml unchanged" unchanged .swiftlint.yml
}

scenario_stop_fails() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$GREETING_TASK"
  SETUP="$FOUR_SPACES"
}
check_stop_fails() {
  expect "Stop blocked with the failing test" has_hook Stop 2 'Expectation failed'
  expect "user warned that the check is still failing" has_hook Stop 0 'still failing'
  expect "test file unchanged (task said only Greeting.swift)" unchanged Tests
  expect "requested change made" file_has Sources/App/Greeting.swift 'Hi, \\\(name\)!'
}

scenario_report_no_token() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK='Add a SwiftUI view `NameTag` in Sources/App/NameTag.swift that shows a `name: String` with 10 points of padding and a rounded rectangle background with corner radius 8.'
  SETUP="$FOUR_SPACES"
}
check_report_no_token() {
  if file_has Sources/App/NameTag.swift '\.padding\([0-9]'; then
    expect "hardcoded padding reported to Claude" has_hook PostToolUse 0 'ds_hardcoded_padding'
  else
    expect "no hardcoded padding left (token used or added)" true
  fi
  expect "turn not blocked (report only)" not_has_hook Stop 2 '.'
}

scenario_legacy_violation() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK='In Sources/App/Card.swift, rename the `title` property to `heading`.'
  SETUP="$FOUR_SPACES; $DS_ERRORS; printf 'import SwiftUI\n\npublic struct Card: View {\n    public let title: String\n\n    public var body: some View {\n        Text(title)\n            .padding(10)\n    }\n}\n' > Sources/App/Card.swift"
}
check_legacy_violation() {
  expect "post-edit blocked with guidance for pre-existing errors" has_hook PostToolUse 2 'already there before your edit'
  expect "rename done" file_has Sources/App/Card.swift 'heading'
  if file_has Sources/App/Card.swift '\.padding\(10\)'; then
    expect "pre-existing error left: Stop blocked" has_hook Stop 2 'SwiftLint \(lintBlocking\)'
    expect "pre-existing error left: user warned" has_hook Stop 0 'still failing'
  else
    expect "pre-existing error fixed: last Stop passes" last_stop_passes
  fi
}

scenario_clean_lint() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK="$BADGE_TASK"
  SETUP="$FOUR_SPACES; $DS_ERRORS"
}
check_clean_lint() {
  expect "lint result reported after the edit" has_hook PostToolUse '[0,2]' 'SwiftLint: (no issues|[0-9]+ issue)'
  expect "last Stop passes" last_stop_passes
}

scenario_formatter_labels() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$GREETING_TASK"
  SETUP=""
}
check_formatter_labels() {
  expect "SessionStart warned about the missing .swift-format" has_hook SessionStart 0 'no \.swift-format'
  expect "formatter changes shown with labels" has_hook PostToolUse 0 'Formatter changes \(- your edit as written'
}

scenario_lint_missing() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":true}"
  TASK='Add a function `farewell(for name: String) -> String` that returns "Goodbye, <name>!" in Sources/App/Greeting.swift.'
  SETUP="$FOUR_SPACES"
  # A machine without SwiftLint: minimal PATH and no Homebrew fallback for the hooks.
  SESSION_ENV="PATH=$(dirname "$(command -v claude)"):/usr/bin:/bin SWIFT_HARNESS_EXTRA_PATH="
}
check_lint_missing() {
  expect "Stop blocked because SwiftLint is missing under lintBlocking" has_hook Stop 2 'SwiftLint is not installed'
  expect "user warned that the check is still failing" has_hook Stop 0 'still failing'
  expect "swift-harness.json unchanged (no workaround)" unchanged .claude/swift-harness.json
  expect "requested change made" file_has Sources/App/Greeting.swift 'Goodbye'
}

scenario_verify_unapproved() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK="$GREETING_TASK"
  SETUP="$FOUR_SPACES"
  APPROVE=0
}
check_verify_unapproved() {
  expect "SessionStart told Claude the verify command is not approved" has_hook SessionStart 0 'not approved'
  expect "Stop did not run the verify command (no block)" not_has_hook Stop 2 '.'
  expect "user told how to approve" has_hook Stop 0 'approve-verify'
  expect "Claude did not run the approval script" not_ran 'approve-verify'
  expect "swift-harness.json unchanged" unchanged .claude/swift-harness.json
  expect "verify script unchanged" unchanged scripts
  # Only that Claude worked on the task: with nothing verified, its exact output is not checked.
  expect "Greeting.swift changed" file_has Sources/App/Greeting.swift '"Hi,'
}

# The skills pass ${CLAUDE_PLUGIN_DATA} to their scripts: these two prove it is the folder
# the hooks use.
PLUGIN_SCRIPTS="Bash(CLAUDE_PLUGIN_DATA=*)"

scenario_approve_verify() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false}"
  TASK='/swift-harness:approve-verify'
  SETUP="$FOUR_SPACES"
  APPROVE=0
  EXTRA_TOOLS="$PLUGIN_SCRIPTS"
}
check_approve_verify() {
  expect "status shown before approving" tool_output_has 'Status: not approved'
  expect "approved through the skill" tool_output_has 'Status: approved'
  expect "the hooks see the approval" approved_for_hooks
  expect "no file changed" unchanged .
}

scenario_doctor() {
  CONFIG="{$BASE_CONFIG,\"lintBlocking\":false,\"lintBlok\":true}"
  TASK='/swift-harness:doctor'
  SETUP="$FOUR_SPACES; chmod -x scripts/verify.sh"
  EXTRA_TOOLS="$PLUGIN_SCRIPTS"
}
check_doctor() {
  expect "doctor table produced" tool_output_has '\| Status \| Check \| Detail \|'
  expect "approval read from the hooks' data folder" tool_output_has '\| PASS \| Verify approval'
  expect "non-executable verify script reported" tool_output_has '\| FAIL \| Verify script \|.*not executable'
  expect "unknown key reported" tool_output_has 'lintBlok'
  expect "no file changed (read-only)" unchanged .
  expect "verify script still not executable" not_executable scripts/verify.sh
  expect "Claude did not run the approval" not_ran 'approve-verify'
}

# ---------- checks ----------

T=""   # transcript of the scenario being checked
D=""   # repo of the scenario being checked
failures=0

expect() { # $1 description, then a check command
  local what="$1"
  shift
  if "$@"; then printf '  ok    %s\n' "$what"; else printf '  FAIL  %s\n' "$what"; failures=$((failures + 1)); fi
}

# $1 hook event, $2 exit code (number or JSON array of numbers), $3 regex on stdout+stderr
has_hook() {
  jq -se --arg e "$1" --argjson x "$2" --arg re "$3" '
    map(select(.type == "system" and .subtype == "hook_response" and .hook_event == $e
      and (if ($x | type) == "array" then (.exit_code as $c | $x | index($c)) != null else .exit_code == $x end)
      and (((.stdout // "") + (.stderr // "")) | test($re))))
    | length > 0' "$T" >/dev/null
}
not_has_hook() { ! has_hook "$@"; }
has_denial() {
  jq -se --arg re "$1" 'map(select(.type == "system" and .subtype == "permission_denied"
    and ((.decision_reason // .message // "") | test($re)))) | length > 0' "$T" >/dev/null
}
last_stop_passes() {
  jq -se '[.[] | select(.type == "system" and .subtype == "hook_response" and .hook_event == "Stop")]
    | (length > 0) and (last.exit_code == 0) and ((last.stdout // "") | test("still failing") | not)' "$T" >/dev/null
}
# $1 regex that no Bash command Claude ran may match
not_ran() {
  ! jq -se --arg re "$1" '[.[] | select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Bash") | .input.command // "" | select(test($re))]
    | length > 0' "$T" >/dev/null
}
# $1 regex that the output of some tool call must match
tool_output_has() {
  jq -se --arg re "$1" '[.[] | select(.type == "user") | .message.content[]?
    | select(.type == "tool_result") | .content | if type == "array" then map(.text // "") | join("\n") else (. // "") end
    | select(test($re))] | length > 0' "$T" >/dev/null
}
approved_for_hooks() {
  CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" "$PLUGIN/scripts/approve-verify.sh" --status "$D" | grep -q '^Status: approved'
}
not_executable() { [ -f "$D/$1" ] && [ ! -x "$D/$1" ]; }
unchanged() { git -C "$D" diff --quiet HEAD -- "$1" && [ -z "$(git -C "$D" ls-files --others --exclude-standard -- "$1")" ]; }
file_has() { [ -f "$D/$1" ] && grep -qE -- "$2" "$D/$1"; }

# ---------- run ----------

run_scenario() { # $1 name
  local name="$1" fn d digest
  fn="scenario_${name//-/_}"
  d="$WORK/$name"
  SESSION_ENV=""
  APPROVE=1
  EXTRA_TOOLS=""
  "$fn"
  rm -rf "$d"
  git clone -q "$WORK/base" "$d"
  mkdir -p "$d/.claude"
  printf '%s\n' "$CONFIG" >"$d/.claude/swift-harness.json"
  [ -z "$SETUP" ] || (cd "$d" && eval "$SETUP")
  git -C "$d" add -A
  git -C "$d" -c user.email=smoke@example.com -c user.name=smoke commit -qm "scenario $name"
  (cd "$d" && swift build --build-tests >/dev/null 2>&1)
  if [ "$APPROVE" = 1 ]; then
    digest="$(CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" "$PLUGIN/scripts/approve-verify.sh" --status "$d" | sed -n 's/^Digest: *//p')"
    CLAUDE_PLUGIN_DATA="$PLUGIN_DATA" "$PLUGIN/scripts/approve-verify.sh" --approve "$digest" "$d" >/dev/null
  fi
  (
    cd "$d" || exit 1
    # shellcheck disable=SC2086 # SESSION_ENV is a list of VAR=value words
    env $SESSION_ENV claude -p "$TASK" ${SMOKE_MODEL:+--model "$SMOKE_MODEL"} \
      --plugin-dir "$PLUGIN" --setting-sources project,local \
      --permission-mode acceptEdits \
      --allowedTools Read Glob Grep Edit Write "Bash(swift build:*)" "Bash(swift test:*)" \
      "Bash(git status:*)" "Bash(git diff:*)" "Bash(scripts/verify.sh:*)" ${EXTRA_TOOLS:+"$EXTRA_TOOLS"} \
      --output-format stream-json --verbose --include-hook-events --no-session-persistence \
      >"$WORK/$name.jsonl" 2>"$WORK/$name.err"
  )
}

scenarios="${*:-$ALL_SCENARIOS}"
for name in $scenarios; do
  declare -F "scenario_${name//-/_}" >/dev/null || { echo "smoke: unknown scenario $name" >&2; exit 2; }
done

echo "smoke: work dir $WORK"
if [ "${SMOKE_CHECK_ONLY:-}" != 1 ]; then
  echo "smoke: $(claude --version 2>/dev/null), swiftlint $(swiftlint version), $(swift --version 2>/dev/null | head -1)"
  build_base
  for name in $scenarios; do run_scenario "$name" & done
  wait
fi

total_cost=0
for name in $scenarios; do
  T="$WORK/$name.jsonl"
  D="$WORK/$name"
  cost="$(jq -r 'select(.type == "result") | .total_cost_usd' "$T" 2>/dev/null)"
  total_cost="$(printf '%s + %s\n' "$total_cost" "${cost:-0}" | bc)"
  printf '\n== %s ($%s)\n' "$name" "${cost:-?}"
  if [ ! -s "$T" ]; then
    printf '  FAIL  no transcript (see %s.err)\n' "$WORK/$name"
    failures=$((failures + 1))
    continue
  fi
  "check_${name//-/_}"
  printf '  final message:\n'
  jq -r 'select(.type == "result") | .result' "$T" | sed 's/^/    | /'
done

printf '\nsmoke: %s failed invariant(s), total cost $%s\n' "$failures" "$total_cost"
printf 'smoke: transcripts in %s (timeline: jq -r -f %s/timeline.jq <file>.jsonl)\n' "$WORK" "$HERE"
[ "$failures" -eq 0 ]
