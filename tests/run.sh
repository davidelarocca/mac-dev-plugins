#!/bin/bash
# Tests for the swift-harness hook scripts and the verify.sh template.
# Needs only bash, git and jq: xcodebuild and swift are replaced by fakes.
# Usage: tests/run.sh

set -u

HERE="$(cd "$(dirname "$0")" && pwd -P)"
PLUGIN="$HERE/../plugins/swift-harness"
SCRIPTS="$PLUGIN/scripts"
TEMPLATE="$PLUGIN/skills/setup/templates/verify.sh"

# Physical path, so the symlink tests below control exactly where a symlink appears.
TMP="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/swift-harness-tests.XXXXXX")" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT

passed=0
failed=0
ok() { passed=$((passed + 1)); printf 'ok    %s\n' "$1"; }
nok() {
  failed=$((failed + 1))
  printf 'FAIL  %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/      /' | head -15
}

# $1 name, $2 expected exit code, $3 regex that must match the output,
# $4 output starting with "exit=<code>", $5 optional regex that must not match.
expect_result() {
  local code="${4%%$'\n'*}"
  code="${code#exit=}"
  if [ "$code" = "$2" ] && grep -qE -- "$3" <<<"$4" && { [ -z "${5:-}" ] || ! grep -qE -- "$5" <<<"$4"; }; then
    ok "$1"
  else
    nok "$1" "$4"
  fi
}

# ---------- fixtures ----------

# A git repo opted into swift-harness, with a protected Sources/Audio/ and a
# fake verify script driven by FAKE_VERIFY_EXIT and logging to FAKE_VERIFY_LOG.
new_project() {
  local p="$TMP/$1"
  mkdir -p "$p/.claude" "$p/Sources/Audio" "$p/Sources/AudioTools" "$p/scripts" "$p/App.xcodeproj"
  git -C "$p" init -q
  git -C "$p" config user.email test@example.com
  git -C "$p" config user.name test
  printf '%s\n' '{"verify":{"command":"scripts/verify.sh fast","maxAttempts":3},"protectedPaths":["Sources/Audio/"]}' \
    >"$p/.claude/swift-harness.json"
  echo 'let engine = 1' >"$p/Sources/Audio/Engine.swift"
  echo 'let tool = 1' >"$p/Sources/AudioTools/Tool.swift"
  echo 'let app = 1' >"$p/Sources/App.swift"
  echo 'A = 1' >"$p/Config.xcconfig"
  echo '<plist/>' >"$p/Info.plist"
  echo '# readme' >"$p/README.md"
  echo '// pbx' >"$p/App.xcodeproj/project.pbxproj"
  cat >"$p/scripts/verify.sh" <<'EOF'
#!/bin/bash
echo run >>"${FAKE_VERIFY_LOG:-/dev/null}"
echo "fake verify output"
exit "${FAKE_VERIFY_EXIT:-0}"
EOF
  chmod +x "$p/scripts/verify.sh"
  git -C "$p" add -A
  git -C "$p" commit -qm init
  approve "$p" >/dev/null
  printf '%s' "$p"
}

# Run a hook script with a JSON input. $1 script, $2 cwd, $3 extra JSON fields (object).
hook() {
  local extra="${3:-}"
  [ -n "$extra" ] || extra='{}'
  jq -nc --arg cwd "$2" --argjson extra "$extra" '{cwd: $cwd, session_id: "test"} + $extra' |
    CLAUDE_PLUGIN_DATA="$TMP/data" CLAUDE_PROJECT_DIR="$2" "$SCRIPTS/$1"
}

# The user's approval of a project's verify command (#6), as /swift-harness:approve-verify
# gives it: read the status, then approve the digest that was shown.
approval() { # $1 project, then approve-verify.sh arguments
  local dir="$1"
  shift
  CLAUDE_PLUGIN_DATA="$TMP/data" "$SCRIPTS/approve-verify.sh" "$@" "$dir"
}
approve() {
  local digest
  digest="$(approval "$1" --status | sed -n 's/^Digest: *//p')"
  approval "$1" --approve "$digest"
}

edit_input() { jq -nc --arg f "$1" '{tool_name: "Edit", tool_input: {file_path: $f}}'; }

fingerprint() {
  jq -nc --arg cwd "$1" '{cwd: $cwd}' |
    bash -c '. "$0"; sh_init && sh_fingerprint' "$SCRIPTS/lib.sh"
}

# ---------- guard.sh ----------

guard_asks() { hook guard.sh "$1" "$(edit_input "$2")" | grep -q '"permissionDecision": "ask"'; }

expect_ask() {
  if guard_asks "$1" "$2"; then ok "$3"; else nok "$3" "no approval request for $2"; fi
}
expect_no_ask() {
  if guard_asks "$1" "$2"; then nok "$3" "unexpected approval request for $2"; else ok "$3"; fi
}

P="$(new_project guard)"
expect_ask "$P" "$P/Sources/Audio/Engine.swift" "guard: edit inside a protected path asks"
expect_ask "$P" "$P/Sources/Audio/New/Thing.swift" "guard: new file in a new folder inside a protected path asks"
expect_no_ask "$P" "$P/Sources/AudioTools/Tool.swift" "guard: sibling folder sharing the prefix does not ask"
expect_no_ask "$P" "$P/Sources/App.swift" "guard: unprotected file does not ask"
expect_ask "$P" "$P/App.xcodeproj/project.pbxproj" "guard: project.pbxproj asks"
expect_ask "$P" "$P/Sources/AudioTools/../Audio/Engine.swift" "guard: ../ into a protected path asks"
expect_ask "$P" "$P/Sources/Missing/../Audio/Engine.swift" "guard: ../ through a missing folder asks"

ln -s "$P" "$TMP/guard-link"
expect_ask "$TMP/guard-link" "$TMP/guard-link/Sources/Audio/Engine.swift" "guard: project opened through a symlinked path asks"

ln -s Audio "$P/Sources/AudioAlias"
expect_ask "$P" "$P/Sources/AudioAlias/Engine.swift" "guard: symlinked folder pointing into a protected path asks"

ln -s Audio/Engine.swift "$P/Sources/EngineAlias.swift"
expect_ask "$P" "$P/Sources/EngineAlias.swift" "guard: symlinked file pointing into a protected path asks"

P="$(new_project 'My Café App')"
expect_ask "$P" "$P/Sources/Audio/Engine.swift" "guard: project path with spaces and accents asks"
expect_no_ask "$P" "$P/Sources/App.swift" "guard: project path with spaces and accents, unprotected file"

P="$(new_project guard-link-entry)"
ln -s Sources/Audio "$P/Audio"
printf '%s\n' '{"protectedPaths":["Audio/"]}' >"$P/.claude/swift-harness.json"
expect_ask "$P" "$P/Sources/Audio/Engine.swift" "guard: protected entry that is a symlink protects its target"
expect_ask "$P" "$P/Audio/Engine.swift" "guard: protected entry that is a symlink protects the link path"
expect_no_ask "$P" "$P/Sources/App.swift" "guard: protected symlink entry does not protect unrelated files"

mkdir -p "$TMP/elsewhere/Sources/Audio"
expect_no_ask "$P" "$TMP/elsewhere/Sources/Audio/x.swift" "guard: file outside the repository does not ask"
expect_no_ask "$P" "$P/../elsewhere/Sources/Audio/x.swift" "guard: ../ out of the repository does not ask"

mkdir -p "$TMP/plain/Sources/Audio"
git -C "$TMP/plain" init -q
expect_no_ask "$TMP/plain" "$TMP/plain/Sources/Audio/x.swift" "guard: project without swift-harness.json is untouched"

# ---------- fingerprint ----------

P="$(new_project fp)"
base="$(fingerprint "$P")"

fp_changes() { # $1 test name; the caller has already changed the project
  local now
  now="$(fingerprint "$P")"
  if [ "$now" != "$base" ]; then ok "$1"; else nok "$1" "fingerprint did not change"; fi
  git -C "$P" checkout -q -- . && git -C "$P" clean -qfd
}
fp_same() {
  local now
  now="$(fingerprint "$P")"
  if [ "$now" = "$base" ]; then ok "$1"; else nok "$1" "fingerprint changed"; fi
  git -C "$P" checkout -q -- . && git -C "$P" clean -qfd
}

echo 'let app = 2' >"$P/Sources/App.swift"; fp_changes "fingerprint: edited Swift file"
echo 'let x = 1' >"$P/Sources/New File.swift"; fp_changes "fingerprint: new untracked Swift file with a space in its name"
rm "$P/Sources/App.swift"; fp_changes "fingerprint: deleted Swift file"
echo 'A = 2' >"$P/Config.xcconfig"; fp_changes "fingerprint: edited .xcconfig"
echo '<plist>x</plist>' >"$P/Info.plist"; fp_changes "fingerprint: edited Info.plist"
mkdir -p "$P/Assets.xcassets/Accent.colorset"
echo '{}' >"$P/Assets.xcassets/Accent.colorset/Contents.json"; fp_changes "fingerprint: new untracked asset"
echo '{}' >"$P/Localizable.xcstrings"; fp_changes "fingerprint: new string catalog"
echo '{"verify":{"command":"true"}}' >"$P/.claude/swift-harness.json"; fp_changes "fingerprint: edited swift-harness.json"
echo '# changed' >"$P/README.md"; fp_same "fingerprint: README edit is ignored"
mkdir -p "$P/.build/DerivedData/Build"
echo '<plist/>' >"$P/.build/DerivedData/Build/Info.plist"
echo 'let gen = 1' >"$P/.build/DerivedData/Build/Gen.swift"; fp_same "fingerprint: build output in .build is ignored"

# ---------- session-start.sh / stop-verify.sh ----------

P="$(new_project stop)"
LOG="$TMP/stop-verify.log"
runs() { [ -f "$LOG" ] && wc -l <"$LOG" | tr -d ' ' || echo 0; }

stop() { # $1 extra JSON; prints "exit=<code>" then stdout+stderr
  local out code
  out="$(FAKE_VERIFY_LOG="$LOG" hook stop-verify.sh "$P" "${1:-}" 2>&1)"
  code=$?
  printf 'exit=%s\n%s' "$code" "$out"
}

hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
out="$(stop)"
if [ "$(runs)" = 0 ] && [[ "$out" == exit=0* ]]; then ok "stop: no change since session start runs nothing"
else nok "stop: no change since session start runs nothing" "$out"; fi

if [ ! -e "$TMP/data/state" ] || ! find "$TMP/data/state" -name verified -o -name passed | grep -q .; then
  ok "session-start: does not mark the starting state as verified or passed"
else
  nok "session-start: does not mark the starting state as verified or passed" "$(find "$TMP/data/state" -type f)"
fi

echo 'let app = 2' >"$P/Sources/App.swift"
out="$(FAKE_VERIFY_EXIT=1 stop)"
if [[ "$out" == exit=2* ]] && grep -q 'Verification failed (attempt 1 of 3)' <<<"$out"; then ok "stop: failing check blocks Claude"
else nok "stop: failing check blocks Claude" "$out"; fi

out="$(FAKE_VERIFY_EXIT=1 stop '{"stop_hook_active":true}')"
if [[ "$out" == exit=0* ]] && grep -q 'still failing' <<<"$out" && [ "$(runs)" = 1 ]; then
  ok "stop: second stop on the same failing code warns without re-running"
else nok "stop: second stop on the same failing code warns without re-running" "$out"; fi

out="$(hook session-start.sh "$P" '{"source":"resume"}')"
if grep -qi 'failed' <<<"$out"; then ok "session-start: resume reports the last failed check on unchanged code"
else nok "session-start: resume reports the last failed check on unchanged code" "output: ${out:-<empty>}"; fi

echo 'let app = 3' >"$P/Sources/App.swift"
out="$(FAKE_VERIFY_EXIT=0 stop)"
if [[ "$out" == exit=0* ]] && [ "$(runs)" = 2 ]; then ok "stop: passing check lets Claude stop"
else nok "stop: passing check lets Claude stop" "$out"; fi

out="$(FAKE_VERIFY_EXIT=1 stop)"
if [[ "$out" == exit=0* ]] && [ "$(runs)" = 2 ]; then ok "stop: unchanged code after a pass is not re-run"
else nok "stop: unchanged code after a pass is not re-run" "$out"; fi

hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
echo 'A = 9' >"$P/Config.xcconfig"
out="$(FAKE_VERIFY_EXIT=0 stop)"
if [ "$(runs)" = 3 ]; then ok "stop: .xcconfig change triggers verification"
else nok "stop: .xcconfig change triggers verification" "$out"; fi

# ---------- post-edit.sh ----------

PEFAKES="$TMP/pe-fakes"
NOLINT="$TMP/pe-fakes-nolint"
TOOLLOG="$TMP/tools.log"
mkdir -p "$PEFAKES" "$NOLINT"
cat >"$PEFAKES/swiftformat" <<'FAKE'
#!/bin/bash
for f; do :; done
echo "swiftformat $f" >>"$FAKE_TOOL_LOG"
case "${FAKE_FMT:-ok}" in
  rewrite) echo "// formatted" >>"$f" ;;
  fail) echo "error: Unexpected token ) at 1:1" >&2; exit 70 ;;
esac
exit 0
FAKE
cat >"$PEFAKES/xcrun" <<'FAKE'
#!/bin/bash
[ "$1" = --find ] && { echo /fake/swift-format; exit 0; }
for f; do :; done
echo "swift-format $f" >>"$FAKE_TOOL_LOG"
case "${FAKE_FMT:-ok}" in
  rewrite) echo "// formatted" >>"$f" ;;
  fail) echo "error: Unexpected token ) at 1:1" >&2; exit 1 ;;
esac
exit 0
FAKE
# Modes follow SwiftLint's real behaviour: serious violations exit 2; an invalid rule
# configuration only prints a warning on stderr and exits 0; a file excluded with
# --force-exclude fails with "No lintable files found".
cat >"$PEFAKES/swiftlint" <<'FAKE'
#!/bin/bash
for f; do :; done
echo "swiftlint $f" >>"$FAKE_TOOL_LOG"
case "${FAKE_LINT:-clean}" in
  warn) echo "$f:1:5: warning: Hardcoded Padding Violation: Use Spacing tokens (ds_hardcoded_padding)" ;;
  error) echo "$f:1:5: error: Force Unwrapping Violation: Avoid force unwrapping (force_unwrapping)"; exit 2 ;;
  badregex) echo "warning: Invalid regular expression pattern '(' used to configure 'ds_hardcoded_padding' rule." >&2 ;;
  crash) echo "Fatal error: Could not read configuration" >&2; exit 1 ;;
  excluded) echo "Error: No lintable files found at paths: '$f'" >&2; exit 1 ;;
esac
exit 0
FAKE
cp "$PEFAKES/swiftformat" "$NOLINT/swiftformat"
chmod +x "$PEFAKES"/* "$NOLINT"/*

# $1 project, $2 file, $3 optional fakes dir used with a minimal system PATH instead of the
# full one. Prints "exit=<code>" then stdout+stderr.
post_edit() {
  local out code path="$PEFAKES:$PATH"
  [ -z "${3:-}" ] || path="$3:/usr/bin:/bin"
  : >"$TOOLLOG"
  out="$(jq -nc --arg cwd "$1" --arg f "$2" '{cwd: $cwd, tool_name: "Edit", tool_input: {file_path: $f}}' |
    PATH="$path" FAKE_TOOL_LOG="$TOOLLOG" CLAUDE_PLUGIN_DATA="$TMP/data" CLAUDE_PROJECT_DIR="$1" \
      "$SCRIPTS/post-edit.sh" 2>&1)"
  code=$?
  printf 'exit=%s\n%s' "$code" "$out"
}
set_config() { printf '%s\n' "$2" >"$1/.claude/swift-harness.json"; }

P="$(new_project post-edit)"
F="$P/Sources/App.swift"

set_config "$P" '{"format":"swiftformat","lint":"swiftlint"}'
expect_result "post-edit: formatter rewrite asks Claude to re-read the file" 0 'Re-read' "$(FAKE_FMT=rewrite post_edit "$P" "$F")"
expect_result "post-edit: formatter note shows the lines it changed" 0 'Formatter changes \(- your edit as written, \+ after formatting[^)]*\):\\n[+]// formatted' "$(FAKE_FMT=rewrite post_edit "$P" "$F")"
expect_result "post-edit: swiftformat failure is reported" 0 'swiftformat failed.*Unexpected token' "$(FAKE_FMT=fail post_edit "$P" "$F")"
expect_result "post-edit: clean lint is reported as clean" 0 'SwiftLint: no issues in Sources/App\.swift' "$(post_edit "$P" "$F")" 'swiftformat|Re-read'
expect_result "post-edit: lint warnings are reported without blocking" 0 'SwiftLint: 1 issue' "$(FAKE_LINT=warn post_edit "$P" "$F")"
expect_result "post-edit: violation lines use project-relative paths" 0 '\\nSources/App\.swift:1:5: warning' "$(FAKE_LINT=warn post_edit "$P" "$F")" '"//|\\n/'
expect_result "post-edit: SwiftLint crash is reported" 0 'SwiftLint did not run correctly' "$(FAKE_LINT=crash post_edit "$P" "$F")"
expect_result "post-edit: invalid SwiftLint rule config (exit 0) is reported" 0 'Invalid regular expression' "$(FAKE_LINT=badregex post_edit "$P" "$F")"
expect_result "post-edit: file excluded by .swiftlint.yml is not an error" 0 'excluded by \.swiftlint\.yml' "$(FAKE_LINT=excluded post_edit "$P" "$F")" 'did not run|lintable'
expect_result "post-edit: missing swiftlint stays quiet on each edit" 0 '^exit=0$' "$(SWIFT_HARNESS_EXTRA_PATH='' post_edit "$P" "$F" "$NOLINT")" 'SwiftLint'

echo 'let v = 1' >"$P/Sources/My View.swift"
expect_result "post-edit: file name with spaces is reported by its project path" 0 'issue\(s\) in Sources/My View.swift' "$(FAKE_LINT=warn post_edit "$P" "$P/Sources/My View.swift")"

set_config "$P" '{"format":"swift-format","lint":"none"}'
expect_result "post-edit: swift-format failure is reported" 0 'swift-format failed.*Unexpected token' "$(FAKE_FMT=fail post_edit "$P" "$F")"

set_config "$P" '{"format":"none","lint":"none"}'
post_edit "$P" "$F" >/dev/null
if [ ! -s "$TOOLLOG" ]; then ok "post-edit: format and lint set to none run nothing"; else nok "post-edit: format and lint set to none run nothing" "$(cat "$TOOLLOG")"; fi

set_config "$P" '{"format":"swiftformat","lint":"swiftlint","lintBlocking":true}'
expect_result "post-edit: lintBlocking blocks on lint errors" 2 'Force Unwrapping' "$(FAKE_LINT=error post_edit "$P" "$F")"
expect_result "post-edit: lintBlocking message says what to do with pre-existing errors" 2 'already there before your edit' "$(FAKE_LINT=error post_edit "$P" "$F")" 'Fix this before continuing'
expect_result "post-edit: lintBlocking on a config problem says not to change the config on its own" 2 'do not change \.swiftlint\.yml' "$(FAKE_LINT=badregex post_edit "$P" "$F")"
expect_result "post-edit: lintBlocking blocks when SwiftLint crashes" 2 'did not run correctly' "$(FAKE_LINT=crash post_edit "$P" "$F")"
expect_result "post-edit: lintBlocking blocks on invalid SwiftLint rule config" 2 'Invalid regular expression' "$(FAKE_LINT=badregex post_edit "$P" "$F")"
expect_result "post-edit: lintBlocking does not block on warnings" 0 'SwiftLint: 1 issue' "$(FAKE_LINT=warn post_edit "$P" "$F")"
expect_result "post-edit: lintBlocking does not block on an excluded file" 0 '^exit=0$' "$(FAKE_LINT=excluded post_edit "$P" "$F")" 'did not run'
expect_result "post-edit: lintBlocking also reports a formatter failure" 2 'swiftformat failed' "$(FAKE_FMT=fail FAKE_LINT=error post_edit "$P" "$F")"

mkdir -p "$TMP/outside"
echo 'let o = 1' >"$TMP/outside/Other.swift"
out="$(FAKE_FMT=rewrite FAKE_LINT=error post_edit "$P" "$TMP/outside/Other.swift")"
if [[ "$out" == exit=0* ]] && [ ! -s "$TOOLLOG" ] && [ "$(cat "$TMP/outside/Other.swift")" = 'let o = 1' ]; then
  ok "post-edit: Swift file outside the project is not formatted or linted"
else
  nok "post-edit: Swift file outside the project is not formatted or linted" "$out / tools: $(cat "$TOOLLOG")"
fi

# ---------- lintBlocking at the Stop check ----------

LOG="$TMP/lint-gate.log"
gate_stop() { # $1 project, $2 optional extra JSON
  local out code
  local extra="${2:-}"
  [ -n "$extra" ] || extra='{}'
  out="$(jq -nc --arg cwd "$1" --argjson extra "$extra" '{cwd: $cwd, session_id: "test"} + $extra' |
    PATH="$PEFAKES:$PATH" FAKE_TOOL_LOG="$TOOLLOG" FAKE_VERIFY_LOG="$LOG" CLAUDE_PLUGIN_DATA="$TMP/data" \
      CLAUDE_PROJECT_DIR="$1" "$SCRIPTS/stop-verify.sh" 2>&1)"
  code=$?
  printf 'exit=%s\n%s' "$code" "$out"
}

P="$(new_project lint-gate)"
set_config "$P" '{"format":"none","lint":"swiftlint","lintBlocking":true,"verify":{"command":"scripts/verify.sh fast"}}'
git -C "$P" commit -qam "lintBlocking on"
hook session-start.sh "$P" '{"source":"startup"}' >/dev/null

echo 'let app = x!' >"$P/Sources/App.swift"
FAKE_LINT=error post_edit "$P" "$P/Sources/App.swift" >/dev/null
expect_result "stop: lintBlocking lint errors block the stop even when the build passes" 2 'Force Unwrapping' \
  "$(FAKE_LINT=error FAKE_VERIFY_EXIT=0 gate_stop "$P")"

echo 'let app = y!' >"$P/Sources/App.swift"
expect_result "stop: lintBlocking, SwiftLint broken at the stop check blocks" 2 'did not run correctly' \
  "$(FAKE_LINT=crash FAKE_VERIFY_EXIT=0 gate_stop "$P")"

echo 'let app = 4' >"$P/Sources/App.swift"
FAKE_LINT=clean post_edit "$P" "$P/Sources/App.swift" >/dev/null
expect_result "stop: lintBlocking, clean lint and passing build let Claude stop" 0 '^exit=0' "$(FAKE_LINT=clean FAKE_VERIFY_EXIT=0 gate_stop "$P")"
before="$(wc -l <"$LOG" | tr -d ' ')"
gate_stop "$P" >/dev/null
if [ "$(wc -l <"$LOG" | tr -d ' ')" = "$before" ]; then ok "stop: lintBlocking, a pass is recorded and not re-run"
else nok "stop: lintBlocking, a pass is recorded and not re-run"; fi

echo 'let app = z!' >"$P/Sources/App.swift"
FAKE_LINT=error post_edit "$P" "$P/Sources/App.swift" >/dev/null
echo 'let app = 5' >"$P/Sources/App.swift"
expect_result "stop: lintBlocking, a file fixed outside the Edit tool is re-checked and passes" 0 '^exit=0' \
  "$(FAKE_LINT=clean FAKE_VERIFY_EXIT=0 gate_stop "$P")"

P="$(new_project lint-off)"
set_config "$P" '{"format":"none","lint":"swiftlint","verify":{"command":"scripts/verify.sh fast"}}'
git -C "$P" commit -qam "lint report only"
hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
echo 'let app = x!' >"$P/Sources/App.swift"
FAKE_LINT=error post_edit "$P" "$P/Sources/App.swift" >/dev/null
expect_result "stop: without lintBlocking, lint errors do not block the stop" 0 '^exit=0' "$(FAKE_LINT=error FAKE_VERIFY_EXIT=0 gate_stop "$P")"

# ---------- lintBlocking without SwiftLint (#17) ----------

# A machine without SwiftLint: minimal PATH and no Homebrew fallback.
nolint_stop() { # $1 project
  local out code
  out="$(jq -nc --arg cwd "$1" '{cwd: $cwd, session_id: "test"}' |
    PATH="$NOLINT:/usr/bin:/bin" SWIFT_HARNESS_EXTRA_PATH='' FAKE_VERIFY_LOG="$TMP/nolint.log" FAKE_VERIFY_EXIT=0 \
      CLAUDE_PLUGIN_DATA="$TMP/data" CLAUDE_PROJECT_DIR="$1" "$SCRIPTS/stop-verify.sh" 2>&1)"
  code=$?
  printf 'exit=%s\n%s' "$code" "$out"
}

P="$(new_project nolint-strict)"
set_config "$P" '{"format":"none","lint":"swiftlint","lintBlocking":true,"verify":{"command":"scripts/verify.sh fast"}}'
git -C "$P" commit -qam "lintBlocking on"
hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
echo 'let app = 7' >"$P/Sources/App.swift"
expect_result "stop: lintBlocking with SwiftLint missing fails even when the build passes" 2 'SwiftLint is not installed' "$(nolint_stop "$P")"
out="$(jq -nc --arg cwd "$P" '{cwd: $cwd, source: "resume"}' | PATH="$NOLINT:/usr/bin:/bin" SWIFT_HARNESS_EXTRA_PATH='' CLAUDE_PLUGIN_DATA="$TMP/data" CLAUDE_PROJECT_DIR="$P" "$SCRIPTS/session-start.sh")"
if grep -q 'end-of-turn check fails' <<<"$out"; then ok "session-start: lintBlocking without SwiftLint says the check will fail"
else nok "session-start: lintBlocking without SwiftLint says the check will fail" "${out:-<empty>}"; fi

P="$(new_project nolint-report)"
set_config "$P" '{"format":"none","lint":"swiftlint","lintBlocking":false,"verify":{"command":"scripts/verify.sh fast"}}'
git -C "$P" commit -qam "report only"
hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
echo 'let app = 7' >"$P/Sources/App.swift"
expect_result "stop: without lintBlocking, missing SwiftLint does not block" 0 '^exit=0' "$(nolint_stop "$P")"

P="$(new_project nolint-off)"
set_config "$P" '{"format":"none","lint":"none","lintBlocking":true,"verify":{"command":"scripts/verify.sh fast"}}'
git -C "$P" commit -qam "lint none"
hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
echo 'let app = 7' >"$P/Sources/App.swift"
expect_result "stop: lint set to none never requires SwiftLint" 0 '^exit=0' "$(nolint_stop "$P")"

# ---------- verify command approval (#6) ----------

LOG="$TMP/approval.log"
appr_runs() { [ -f "$LOG" ] && wc -l <"$LOG" | tr -d ' ' || echo 0; }
appr_stop() { # $1 project, $2 optional extra JSON
  local out code
  out="$(FAKE_VERIFY_LOG="$LOG" FAKE_VERIFY_EXIT=0 hook stop-verify.sh "$1" "${2:-}" 2>&1)"
  code=$?
  printf 'exit=%s\n%s' "$code" "$out"
}

P="$(new_project approval)"
approval "$P" --revoke >/dev/null
out="$(approval "$P" --status)"
if grep -q '^Command: scripts/verify.sh fast' <<<"$out" && grep -q 'scripts/verify.sh' <<<"$(grep '^File' <<<"$out")" &&
  grep -q '^Status: not approved' <<<"$out"; then
  ok "approval: status shows the command, the files it runs and that it is not approved"
else nok "approval: status shows the command, the files it runs and that it is not approved" "$out"; fi

out="$(hook session-start.sh "$P" '{"source":"startup"}')"
if grep -q 'not approved' <<<"$out" && grep -q '/swift-harness:approve-verify' <<<"$out"; then
  ok "approval: session start tells Claude the verify command needs approval"
else nok "approval: session start tells Claude the verify command needs approval" "${out:-<empty>}"; fi

echo 'let app = 20' >"$P/Sources/App.swift"
out="$(appr_stop "$P")"
if [[ "$out" == exit=0* ]] && [ "$(appr_runs)" = 0 ] && grep -q 'systemMessage' <<<"$out" && grep -q 'approve-verify' <<<"$out"; then
  ok "approval: a fresh project runs nothing at the stop and tells the user how to approve"
else nok "approval: a fresh project runs nothing at the stop and tells the user how to approve" "runs=$(appr_runs) $out"; fi

expect_result "approval: the warning is not repeated on the same code" 0 '^exit=0' "$(appr_stop "$P")" 'systemMessage'

out="$(approval "$P" --approve 0000)"
if [ $? -ne 0 ] && grep -qi 'changed' <<<"$out" && grep -q '^Status: not approved' <<<"$(approval "$P" --status)"; then
  ok "approval: approving a digest that was not shown is refused"
else nok "approval: approving a digest that was not shown is refused" "$out"; fi

out="$(CLAUDE_PLUGIN_DATA='' "$SCRIPTS/approve-verify.sh" --status "$P" 2>&1)"
if [ $? -ne 0 ] && grep -q 'approve-verify' <<<"$out"; then ok "approval: the script refuses to run without the plugin data folder"
else nok "approval: the script refuses to run without the plugin data folder" "$out"; fi

approve "$P" >/dev/null
out="$(appr_stop "$P")"
if [[ "$out" == exit=0* ]] && [ "$(appr_runs)" = 1 ]; then ok "approval: once approved, the stop runs the verify command"
else nok "approval: once approved, the stop runs the verify command" "runs=$(appr_runs) $out"; fi
out="$(hook session-start.sh "$P" '{"source":"resume"}')"
if ! grep -q 'not approved' <<<"$out"; then ok "approval: session start is quiet once approved"
else nok "approval: session start is quiet once approved" "$out"; fi

printf '%s\n' 'echo extra' >>"$P/scripts/verify.sh"
out="$(appr_stop "$P")"
if [ "$(appr_runs)" = 1 ] && grep -q 'approve-verify' <<<"$out"; then ok "approval: a changed verify script needs a new approval"
else nok "approval: a changed verify script needs a new approval" "runs=$(appr_runs) $out"; fi

approve "$P" >/dev/null
cp "$P/scripts/verify.sh" "$P/scripts/check.sh"
set_config "$P" '{"verify":{"command":"bash scripts/check.sh fast"}}'
out="$(appr_stop "$P")"
if [ "$(appr_runs)" = 1 ] && grep -q 'approve-verify' <<<"$out"; then ok "approval: a changed verify command needs a new approval"
else nok "approval: a changed verify command needs a new approval" "runs=$(appr_runs) $out"; fi
if grep -q '^File.*scripts/check.sh' <<<"$(approval "$P" --status)"; then ok "approval: a script passed to an interpreter is covered"
else nok "approval: a script passed to an interpreter is covered" "$(approval "$P" --status)"; fi
approve "$P" >/dev/null
echo 'exit 1' >>"$P/scripts/check.sh"
echo 'let app = 21' >"$P/Sources/App.swift"
out="$(appr_stop "$P")"
if [ "$(appr_runs)" = 1 ] && grep -q 'approve-verify' <<<"$out"; then ok "approval: a changed script passed to an interpreter needs a new approval"
else nok "approval: a changed script passed to an interpreter needs a new approval" "runs=$(appr_runs) $out"; fi

Q="$TMP/approval-copy"
cp -R "$P" "$Q"
approve "$P" >/dev/null
hook session-start.sh "$Q" '{"source":"startup"}' >/dev/null
echo 'let app = 22' >"$Q/Sources/App.swift"
out="$(appr_stop "$Q")"
if [ "$(appr_runs)" = 1 ] && grep -q 'approve-verify' <<<"$out"; then ok "approval: an approval for one project path does not apply to another"
else nok "approval: an approval for one project path does not apply to another" "runs=$(appr_runs) $out"; fi

approval "$P" --revoke >/dev/null
if grep -q '^Status: not approved' <<<"$(approval "$P" --status)"; then ok "approval: revoke removes the approval"
else nok "approval: revoke removes the approval" "$(approval "$P" --status)"; fi

P="$(new_project approval-lint)"
approval "$P" --revoke >/dev/null
set_config "$P" '{"format":"none","lint":"swiftlint","lintBlocking":true,"verify":{"command":"scripts/verify.sh fast"}}'
git -C "$P" commit -qam "lintBlocking on"
hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
echo 'let app = x!' >"$P/Sources/App.swift"
FAKE_LINT=error post_edit "$P" "$P/Sources/App.swift" >/dev/null
out="$(PATH="$PEFAKES:$PATH" FAKE_TOOL_LOG="$TOOLLOG" FAKE_LINT=error appr_stop "$P")"
if [[ "$out" == exit=2* ]] && grep -q 'Force Unwrapping' <<<"$out" && grep -q 'not approved' <<<"$out" && [ "$(appr_runs)" = 1 ]; then
  ok "approval: without approval, lintBlocking still blocks on lint errors and says the build did not run"
else nok "approval: without approval, lintBlocking still blocks on lint errors and says the build did not run" "runs=$(appr_runs) $out"; fi
echo 'let app = 23' >"$P/Sources/App.swift"
out="$(PATH="$PEFAKES:$PATH" FAKE_TOOL_LOG="$TOOLLOG" FAKE_LINT=clean appr_stop "$P")"
if [[ "$out" == exit=0* ]] && grep -q 'approve-verify' <<<"$out" && [ "$(appr_runs)" = 1 ]; then
  ok "approval: without approval, a clean lint lets Claude stop with a warning"
else nok "approval: without approval, a clean lint lets Claude stop with a warning" "runs=$(appr_runs) $out"; fi
approve "$P" >/dev/null
out="$(PATH="$PEFAKES:$PATH" FAKE_TOOL_LOG="$TOOLLOG" FAKE_LINT=clean appr_stop "$P")"
if [ "$(appr_runs)" = 2 ]; then ok "approval: an unverified stop is not recorded as passed"
else nok "approval: an unverified stop is not recorded as passed" "runs=$(appr_runs) $out"; fi

# ---------- worktrees ----------

P="$(new_project wt-main)"
W="$TMP/wt-feature"
git -C "$P" worktree add -q "$W" -b feature
approve "$W" >/dev/null
LOG="$TMP/wt.log"
hook session-start.sh "$P" '{"source":"startup"}' >/dev/null
hook session-start.sh "$W" '{"source":"startup"}' >/dev/null
echo 'let app = 9' >"$W/Sources/App.swift"
FAKE_VERIFY_LOG="$LOG" FAKE_VERIFY_EXIT=1 hook stop-verify.sh "$W" >/dev/null 2>&1
code=$?
main_resume="$(hook session-start.sh "$P" '{"source":"resume"}')"
main_out="$(FAKE_VERIFY_LOG="$LOG" FAKE_VERIFY_EXIT=1 hook stop-verify.sh "$P" 2>&1)"
main_code=$?
if [ "$code" = 2 ] && [ "$main_code" = 0 ] && ! grep -qi 'failed' <<<"$main_resume" && [ "$(wc -l <"$LOG" | tr -d ' ')" = 1 ]; then
  ok "worktrees: a failure in one worktree does not affect the other"
else
  nok "worktrees: a failure in one worktree does not affect the other" "worktree exit=$code main exit=$main_code resume='$main_resume' $main_out"
fi
wt_resume="$(hook session-start.sh "$W" '{"source":"resume"}')"
if grep -qi failed <<<"$wt_resume"; then ok "worktrees: each worktree keeps its own failure state"
else nok "worktrees: each worktree keeps its own failure state" "${wt_resume:-<empty>}"; fi

# ---------- lintBlocking pending files at session start ----------

P="$(new_project pending-at-start)"
set_config "$P" '{"format":"none","lint":"swiftlint","lintBlocking":true}'
git -C "$P" commit -qam "lintBlocking on"
echo 'let app = x!' >"$P/Sources/App.swift"
FAKE_LINT=error post_edit "$P" "$P/Sources/App.swift" >/dev/null
out="$(hook session-start.sh "$P" '{"source":"resume"}')"
if grep -q 'Sources/App.swift' <<<"$out" && grep -qi 'swiftlint' <<<"$out"; then
  ok "session-start: lintBlocking files that still fail SwiftLint are reported"
else
  nok "session-start: lintBlocking files that still fail SwiftLint are reported" "${out:-<empty>}"
fi
set_config "$P" '{"format":"none","lint":"swiftlint","lintBlocking":false}'
out="$(hook session-start.sh "$P" '{"source":"resume"}')"
if ! grep -q 'Sources/App.swift' <<<"$out"; then ok "session-start: pending files are not reported without lintBlocking"
else nok "session-start: pending files are not reported without lintBlocking" "$out"; fi

# ---------- design-system fixture assets ----------

# Every Color("name", bundle: .module) in the reference Tokens.swift must exist as
# name.colorset in the fixture, with numeric color components.
REFS="$PLUGIN/skills/design-system/references/Tokens.swift"
ASSETS="$HERE/fixtures/design-system/Sources/DesignSystem/Resources/Colors.xcassets"
missing=""
for name in $(grep -oE 'Color\("[A-Za-z]+", bundle: \.module\)' "$REFS" | sed -E 's/Color\("([A-Za-z]+)".*/\1/'); do
  set_file="$ASSETS/$name.colorset/Contents.json"
  if [ ! -f "$set_file" ]; then
    missing="$missing $name(missing)"
  elif ! jq -e '[.colors[].color.components | .red, .green, .blue, .alpha | tonumber] | length > 0' "$set_file" >/dev/null 2>&1; then
    missing="$missing $name(invalid components)"
  fi
done
if [ -z "$missing" ] && [ -n "$(grep -oE 'Color\("[A-Za-z]+", bundle' "$REFS")" ]; then
  ok "fixture: every color referenced by Tokens.swift exists with numeric components"
else
  nok "fixture: every color referenced by Tokens.swift exists with numeric components" "$missing"
fi
unexpected=""
for set_dir in "$ASSETS"/*.colorset; do
  set_name="$(basename "$set_dir")"
  [[ "$set_name" =~ ^[A-Za-z]+\.colorset$ ]] || unexpected="$unexpected [$set_name]"
done
if [ -z "$unexpected" ]; then ok "fixture: colorset folder names are plain semantic names"
else nok "fixture: colorset folder names are plain semantic names" "$unexpected"; fi

# ---------- swift-format configuration ----------

P="$(new_project swift-format-config)"
set_config "$P" '{"format":"swift-format","lint":"none"}'
out="$(PATH="$PEFAKES:$PATH" hook session-start.sh "$P" '{"source":"startup"}')"
if grep -q 'no .swift-format' <<<"$out"; then ok "session-start: warns when swift-format has no .swift-format file"
else nok "session-start: warns when swift-format has no .swift-format file" "${out:-<empty>}"; fi
cp "$PLUGIN/skills/setup/templates/swift-format" "$P/.swift-format" 2>/dev/null
out="$(PATH="$PEFAKES:$PATH" hook session-start.sh "$P" '{"source":"startup"}')"
if [ -f "$P/.swift-format" ] && ! grep -q '.swift-format' <<<"$out"; then ok "session-start: no warning when .swift-format exists"
else nok "session-start: no warning when .swift-format exists" "${out:-<empty>}"; fi
set_config "$P" '{"format":"swiftformat","lint":"none"}'
rm -f "$P/.swift-format"
out="$(PATH="$PEFAKES:$PATH" hook session-start.sh "$P" '{"source":"startup"}')"
if ! grep -q '.swift-format' <<<"$out"; then ok "session-start: no swift-format warning when swiftformat is used"
else nok "session-start: no swift-format warning when swiftformat is used" "$out"; fi
if jq -e '.indentation.spaces == 4 and .lineLength == 160' "$PLUGIN/skills/setup/templates/swift-format" >/dev/null 2>&1; then
  ok "setup: swift-format template uses 4 spaces and 160 columns like the swiftformat template"
else
  nok "setup: swift-format template uses 4 spaces and 160 columns like the swiftformat template"
fi

# ---------- verify.sh template ----------

FAKES="$TMP/fakes"
mkdir -p "$FAKES"
printf '#!/bin/bash\nexit "${FAKE_XCODEBUILD_EXIT:-0}"\n' >"$FAKES/xcodebuild"
printf '#!/bin/bash\nexit "${FAKE_SWIFT_EXIT:-0}"\n' >"$FAKES/swift"
printf '#!/bin/bash\nexit "${FAKE_SWIFTLINT_EXIT:-0}"\n' >"$FAKES/swiftlint"
chmod +x "$FAKES/xcodebuild" "$FAKES/swift" "$FAKES/swiftlint"

# $1 name, $2 container flag, $3 scheme, $4 packages (bash array body). Prints the project dir.
verify_project() {
  local p="$TMP/verify-$1"
  mkdir -p "$p/scripts"
  if [ "$2" = RAW ]; then
    cp "$TEMPLATE" "$p/scripts/verify.sh"
  else
    sed -e "s|{{XCODE_CONTAINER_FLAG}}|$2|" -e "s|{{SCHEME}}|$3|" -e "s|{{LOCAL_PACKAGES}}|$4|" \
      "$TEMPLATE" >"$p/scripts/verify.sh"
  fi
  chmod +x "$p/scripts/verify.sh"
  printf '%s' "$p"
}

run_verify() { # $1 project, $2 mode; prints "exit=<code>" then output
  local out code
  out="$(PATH="$FAKES:/usr/bin:/bin" "$1/scripts/verify.sh" "${2:-fast}" 2>&1)"
  code=$?
  printf 'exit=%s\n%s' "$code" "$out"
}

expect_verify() { # $1 name, $2 expected exit (0 or nonzero), $3 regex in output, $4 output
  local code="${4%%$'\n'*}"
  code="${code#exit=}"
  if [ "$2" != 0 ] && [ "$code" != 0 ]; then
    expect_result "$1" "$code" "$3" "$4"
  else
    expect_result "$1" "$2" "$3" "$4"
  fi
}

V="$(verify_project scheme-only '-project App.xcodeproj' App '')"
expect_verify "verify.sh: Xcode project without local packages builds and passes" 0 'verify fast: PASS' "$(run_verify "$V")"

V="$(verify_project nothing '' '' '')"
expect_verify "verify.sh: no scheme and no package is NOT CONFIGURED, not PASS" 1 'NOT CONFIGURED' "$(run_verify "$V")"

V="$(verify_project missing-pkg '' '' '"Packages/Missing"')"
expect_verify "verify.sh: a listed package that does not exist fails" 1 'Packages/Missing' "$(run_verify "$V")"

V="$(verify_project pkg '' '' '"Packages/Core"')"
mkdir -p "$V/Packages/Core"
expect_verify "verify.sh: existing package with passing tests passes" 0 'verify fast: PASS' "$(run_verify "$V")"

V="$(verify_project build-fails '-project App.xcodeproj' App '')"
expect_verify "verify.sh: failing build fails" 1 'verify fast: FAIL' "$(FAKE_XCODEBUILD_EXIT=65 run_verify "$V")"

V="$(verify_project bad-mode '-project App.xcodeproj' App '')"
expect_verify "verify.sh: unknown mode is rejected" 1 'fsat' "$(run_verify "$V" fsat)"

V="$(verify_project raw RAW '' '')"
expect_verify "verify.sh: unfilled template placeholders are reported" 1 'placeholder' "$(run_verify "$V")"

V="$(verify_project full-lint-only '' '' '')"
expect_verify "verify.sh full: SwiftLint alone is not a verification" 1 'NOT CONFIGURED' "$(run_verify "$V" full)"

V="$(verify_project full-scheme '-project App.xcodeproj' App '')"
expect_verify "verify.sh full: tests plus lint pass" 0 'verify full: PASS' "$(run_verify "$V" full)"
expect_verify "verify.sh full: failing lint fails" 1 'verify full: FAIL' "$(FAKE_SWIFTLINT_EXIT=2 run_verify "$V" full)"

# ---------- summary ----------

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
