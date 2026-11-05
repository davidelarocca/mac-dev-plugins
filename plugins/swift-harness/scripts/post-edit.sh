#!/bin/bash
# PostToolUse (Edit|Write|MultiEdit): format the edited Swift file, lint it, and give
# Claude the lint result next to the tool output.

. "$(dirname "$0")/lib.sh"
sh_init || exit 0

file="$(sh_in '.tool_input.file_path')"
[[ "$file" == *.swift ]] || exit 0
[ -f "$file" ] || exit 0
rel="$(sh_relpath "$file")"
rel="${rel:-$file}"

notes=""

# ---- Format ----
formatter="$(sh_cfg '.format' 'swiftformat')"
before="$(shasum "$file" | cut -d' ' -f1)"
case "$formatter" in
  swiftformat)
    command -v swiftformat >/dev/null 2>&1 && (cd "$SH_ROOT" && swiftformat --quiet "$file" >/dev/null 2>&1)
    ;;
  swift-format)
    if xcrun --find swift-format >/dev/null 2>&1; then
      (cd "$SH_ROOT" && xcrun swift-format format --in-place "$file" >/dev/null 2>&1)
    elif command -v swift-format >/dev/null 2>&1; then
      (cd "$SH_ROOT" && swift-format format --in-place "$file" >/dev/null 2>&1)
    fi
    ;;
esac
after="$(shasum "$file" | cut -d' ' -f1)"
if [ "$before" != "$after" ]; then
  notes="The formatter rewrote $rel. Re-read it before editing it again."
fi

# ---- Lint ----
if [ "$(sh_cfg '.lint' 'swiftlint')" = "swiftlint" ] && command -v swiftlint >/dev/null 2>&1; then
  lint_out="$(cd "$SH_ROOT" && swiftlint lint --quiet --force-exclude "$file" 2>/dev/null)"
  lint_status=$?
  if [ -n "$lint_out" ]; then
    count="$(printf '%s\n' "$lint_out" | grep -cE ': (warning|error):')"
    shown="$(printf '%s\n' "$lint_out" | sed "s|$SH_ROOT/||" | head -20)"
    if [ "$(sh_cfg '.lintBlocking' 'false')" = "true" ] && [ "$lint_status" -ne 0 ]; then
      printf 'SwiftLint errors in %s:\n%s\nFix these before continuing.\n' "$rel" "$shown" >&2
      exit 2
    fi
    lint_note="SwiftLint: $count issue(s) in $rel. Fix the ones on lines you wrote or changed; leave pre-existing ones unless the task covers them.
$shown"
    notes="${notes:+$notes
}$lint_note"
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
