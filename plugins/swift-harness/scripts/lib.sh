#!/bin/bash
# Shared helpers for swift-harness hooks. Sourced, not executed.
# Every hook is a no-op unless the project contains .claude/swift-harness.json.

# GUI-launched sessions often miss Homebrew on PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SH_INPUT="$(cat)"

sh_has_jq() { command -v jq >/dev/null 2>&1; }

# Read a field from the hook input JSON. Empty string when missing.
sh_in() { printf '%s' "$SH_INPUT" | jq -r "$1 // empty" 2>/dev/null; }

# Project root: git top level of the hook's cwd (follows worktrees), else CLAUDE_PROJECT_DIR.
# Always a physical path (symlinks resolved), like the output of sh_realpath.
sh_root() {
  local cwd root
  cwd="$(sh_in '.cwd')"
  [ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || root="${CLAUDE_PROJECT_DIR:-$cwd}"
  (cd "$root" 2>/dev/null && pwd -P) || printf '%s' "$root"
}

# Remove ".", ".." and repeated slashes from an absolute path without touching the disk,
# the same way Claude Code's file tools resolve a path before writing.
sh_normpath() {
  local part
  local -a parts out=()
  IFS=/ read -ra parts <<<"$1"
  for part in ${parts[@]+"${parts[@]}"}; do
    case "$part" in
      "" | .) ;;
      ..) [ "${#out[@]}" -eq 0 ] || unset "out[$((${#out[@]} - 1))]" ;;
      *) out+=("$part") ;;
    esac
  done
  local IFS=/
  printf '/%s' "${out[*]-}"
}

# Physical absolute path of a file that may not exist yet: normalise the path, resolve the
# deepest existing folder with pwd -P, and follow a symlink in the last component.
sh_realpath() {
  local path dir rest link hops=0
  case "$1" in /*) path="$1" ;; *) path="$SH_ROOT/$1" ;; esac
  while :; do
    path="$(sh_normpath "$path")"
    dir="$path"
    rest=""
    while [ "$dir" != "/" ] && [ ! -d "$dir" ]; do
      rest="/${dir##*/}$rest"
      dir="${dir%/*}"
      [ -n "$dir" ] || dir="/"
    done
    dir="$(cd "$dir" 2>/dev/null && pwd -P)" || dir="/"
    path="${dir%/}$rest"
    [ -L "$path" ] && [ "$hops" -lt 16 ] || break
    link="$(readlink "$path")"
    case "$link" in /*) path="$link" ;; *) path="${path%/*}/$link" ;; esac
    hops=$((hops + 1))
  done
  printf '%s' "$path"
}

# Path relative to the project root, symlinks resolved. Empty when outside the project.
sh_relpath() {
  local path
  path="$(sh_realpath "$1")"
  case "$path" in
    "$SH_ROOT"/*) printf '%s' "${path#"$SH_ROOT"/}" ;;
  esac
}

# Read a value from the project config, with a default.
sh_cfg() {
  local value
  value="$(jq -r "$1 | if . == null then empty else . end" "$SH_CONFIG" 2>/dev/null)"
  [ -n "$value" ] && printf '%s' "$value" || printf '%s' "$2"
}

# Per-project state directory (survives plugin updates).
sh_state_dir() {
  local base key
  base="${CLAUDE_PLUGIN_DATA:-$HOME/.cache/swift-harness}"
  key="$(printf '%s' "$SH_ROOT" | shasum | cut -c1-16)"
  mkdir -p "$base/state/$key" && printf '%s' "$base/state/$key"
}

# Files that can change the result of a build or test run. Git pathspecs: "*" also matches "/".
SH_BUILD_INPUTS=(
  '*.swift' '*Package.resolved'
  '*.pbxproj' '*.xcconfig' '*.xcscheme' '*.xctestplan' '*.plist' '*.entitlements'
  '*.xcassets/*' '*.xcstrings' '*.strings' '*.stringsdict' '*.xib' '*.storyboard'
  '*.xcdatamodeld/*' '*.xcmappingmodel/*' '*.metal' '*.h' '*.m' '*.mm' '*.c'
  '*/Resources/*' '*__Snapshots__/*'
  '.swiftlint.yml' '.swiftformat' '.swift-format' '.claude/swift-harness.json' 'scripts/*'
  ':!.build/*' ':!*/.build/*' ':!*DerivedData/*'
)

# Fingerprint of the code state: HEAD, uncommitted changes to build inputs (including
# deletions), and the content of untracked build inputs.
sh_fingerprint() {
  {
    git -C "$SH_ROOT" rev-parse HEAD 2>/dev/null
    git -C "$SH_ROOT" diff HEAD -- "${SH_BUILD_INPUTS[@]}" 2>/dev/null
    git -C "$SH_ROOT" ls-files -z --others --exclude-standard -- "${SH_BUILD_INPUTS[@]}" 2>/dev/null |
      while IFS= read -r -d '' f; do shasum "$SH_ROOT/$f" 2>/dev/null; done
  } | shasum | cut -d' ' -f1
}

# Lint one file with SwiftLint and classify the result in SH_LINT_RESULT:
#   clean | warnings | errors | broken | excluded | missing
# "errors" means serious violations (SwiftLint exits 2). "broken" means SwiftLint did not
# apply its rules correctly: a non-zero exit without violations, or a configuration problem
# on stderr (SwiftLint skips a rule with an invalid configuration or regex and exits 0).
# "excluded" is a file left out by the `excluded` list (--force-exclude finds no files).
# Also sets SH_LINT_STATUS, SH_LINT_OUTPUT (violations, root-relative) and SH_LINT_ERRORS
# (stderr), both bounded.
sh_swiftlint() {
  local err
  SH_LINT_STATUS=0
  SH_LINT_OUTPUT=""
  SH_LINT_ERRORS=""
  if ! command -v swiftlint >/dev/null 2>&1; then
    SH_LINT_RESULT=missing
    return
  fi
  err="$(mktemp -t swift-harness-lint.XXXXXX)"
  SH_LINT_OUTPUT="$(cd "$SH_ROOT" && swiftlint lint --quiet --force-exclude "$1" 2>"$err")"
  SH_LINT_STATUS=$?
  SH_LINT_ERRORS="$(grep -v '^[[:space:]]*$' "$err" | head -20)"
  rm -f "$err"
  SH_LINT_OUTPUT="$(printf '%s\n' "$SH_LINT_OUTPUT" | grep -E ': (warning|error):' | head -20)"
  SH_LINT_OUTPUT="${SH_LINT_OUTPUT//"$SH_ROOT/"/}"

  if [ "$SH_LINT_STATUS" -ne 0 ] && grep -q 'No lintable files found' <<<"$SH_LINT_ERRORS"; then
    SH_LINT_RESULT=excluded
  elif [ "$SH_LINT_STATUS" -ne 0 ] && ! grep -q ': error:' <<<"$SH_LINT_OUTPUT"; then
    SH_LINT_RESULT=broken
  elif grep -qiE 'invalid|error:|fatal|could not' <<<"$SH_LINT_ERRORS"; then
    SH_LINT_RESULT=broken
  elif [ "$SH_LINT_STATUS" -ne 0 ]; then
    SH_LINT_RESULT=errors
  elif [ -n "$SH_LINT_OUTPUT" ]; then
    SH_LINT_RESULT=warnings
  else
    SH_LINT_RESULT=clean
  fi
}

# Files that failed SwiftLint under lintBlocking. The Stop check re-lints them, so a
# blocked edit cannot end the turn as verified.
sh_lint_pending_add() {
  local list="$1/lint-pending"
  grep -qxF -- "$2" "$list" 2>/dev/null || printf '%s\n' "$2" >>"$list"
}
sh_lint_pending_remove() {
  local list="$1/lint-pending"
  [ -f "$list" ] || return 0
  grep -vxF -- "$2" "$list" >"$list.tmp"
  mv "$list.tmp" "$list"
}

# Initialise SH_ROOT and SH_CONFIG. Returns 1 when the project has not opted in.
sh_init() {
  sh_has_jq || return 1
  SH_ROOT="$(sh_root)"
  SH_CONFIG="$SH_ROOT/.claude/swift-harness.json"
  [ -f "$SH_CONFIG" ]
}
