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
  printf '%s' "$p"
}

# Run a hook script with a JSON input. $1 script, $2 cwd, $3 extra JSON fields (object).
hook() {
  jq -nc --arg cwd "$2" --argjson extra "${3:-{\}}" '{cwd: $cwd, session_id: "test"} + $extra' |
    CLAUDE_PLUGIN_DATA="$TMP/data" CLAUDE_PROJECT_DIR="$2" "$SCRIPTS/$1"
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
  out="$(FAKE_VERIFY_LOG="$LOG" hook stop-verify.sh "$P" "${1:-{\}}" 2>&1)"
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

# ---------- verify.sh template ----------

FAKES="$TMP/fakes"
mkdir -p "$FAKES"
printf '#!/bin/bash\nexit "${FAKE_XCODEBUILD_EXIT:-0}"\n' >"$FAKES/xcodebuild"
printf '#!/bin/bash\nexit "${FAKE_SWIFT_EXIT:-0}"\n' >"$FAKES/swift"
chmod +x "$FAKES/xcodebuild" "$FAKES/swift"

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
  local exit_ok=false
  if [ "$2" = 0 ]; then [ "$code" = 0 ] && exit_ok=true; else [ "$code" != 0 ] && exit_ok=true; fi
  if $exit_ok && grep -qE "$3" <<<"$4"; then
    ok "$1"
  else
    nok "$1" "$4"
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

# ---------- summary ----------

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
