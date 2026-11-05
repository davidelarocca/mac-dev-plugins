#!/bin/bash
# PostToolUse (Edit|Write|MultiEdit): format the edited Swift file, lint it, and give
# Claude the result next to the tool output. The edit has already happened: this hook
# reports problems, it cannot undo them. With lintBlocking, failing files are also
# recorded so the Stop check re-lints them before the turn can end.

. "$(dirname "$0")/lib.sh"
sh_init || exit 0

file="$(sh_in '.tool_input.file_path')"
[[ "$file" == *.swift ]] || exit 0
[ -f "$file" ] || exit 0
# Only files inside this project: never format or lint a file elsewhere on disk.
rel="$(sh_relpath "$file")"
[ -n "$rel" ] || exit 0
path="$SH_ROOT/$rel"

notes=""
add_note() { notes="${notes:+$notes

}$1"; }

# ---- Format ----
# A missing formatter is reported once by SessionStart, not on every edit.
formatter="$(sh_cfg '.format' 'swiftformat')"
fmt_cmd=()
case "$formatter" in
  swiftformat)
    command -v swiftformat >/dev/null 2>&1 && fmt_cmd=(swiftformat --quiet "$path")
    ;;
  swift-format)
    if xcrun --find swift-format >/dev/null 2>&1; then
      fmt_cmd=(xcrun swift-format format --in-place "$path")
    elif command -v swift-format >/dev/null 2>&1; then
      fmt_cmd=(swift-format format --in-place "$path")
    fi
    ;;
esac
if [ "${#fmt_cmd[@]}" -gt 0 ]; then
  before="$(shasum "$path" | cut -d' ' -f1)"
  fmt_err="$(mktemp -t swift-harness-format.XXXXXX)"
  (cd "$SH_ROOT" && "${fmt_cmd[@]}" >/dev/null 2>"$fmt_err")
  fmt_status=$?
  after="$(shasum "$path" | cut -d' ' -f1)"
  if [ "$before" != "$after" ]; then
    add_note "The formatter rewrote $rel. Re-read it before editing it again."
  fi
  if [ "$fmt_status" -ne 0 ]; then
    add_note "$formatter failed on $rel (exit $fmt_status), so the file may not be formatted. Usually a syntax error in the edit:
$(grep -v '^[[:space:]]*$' "$fmt_err" | head -10)"
  fi
  rm -f "$fmt_err"
fi

# ---- Lint ----
blocking="$(sh_cfg '.lintBlocking' 'false')"
if [ "$(sh_cfg '.lint' 'swiftlint')" = "swiftlint" ]; then
  sh_swiftlint "$path"

  case "$SH_LINT_RESULT" in
    warnings | errors)
      count="$(printf '%s\n' "$SH_LINT_OUTPUT" | grep -cE ': (warning|error):')"
      add_note "SwiftLint: $count issue(s) in $rel. Fix the ones on lines you wrote or changed; leave pre-existing ones unless the task covers them.
$SH_LINT_OUTPUT"
      ;;
  esac
  if [ "$SH_LINT_RESULT" = broken ] && [ "$SH_LINT_STATUS" -eq 0 ]; then
    add_note "SwiftLint reported a configuration problem while linting $rel, so some rules were not applied. Check .swiftlint.yml:
$SH_LINT_ERRORS"
  elif [ "$SH_LINT_RESULT" = broken ]; then
    add_note "SwiftLint did not run correctly on $rel (exit $SH_LINT_STATUS), so its rules were not fully applied. Check .swiftlint.yml:
${SH_LINT_ERRORS:-no error output}${SH_LINT_OUTPUT:+
$SH_LINT_OUTPUT}"
  fi

  if [ "$blocking" = "true" ]; then
    state="$(sh_state_dir)"
    case "$SH_LINT_RESULT" in
      errors | broken)
        [ -z "$state" ] || sh_lint_pending_add "$state" "$rel"
        printf '%s\n\nThe edit is applied but %s does not pass SwiftLint. Fix this before continuing.\n' "$notes" "$rel" >&2
        exit 2
        ;;
      clean | warnings | excluded)
        [ -z "$state" ] || sh_lint_pending_remove "$state" "$rel"
        ;;
    esac
  fi
fi

[ -n "$notes" ] || exit 0

jq -n --arg ctx "$notes" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
exit 0
