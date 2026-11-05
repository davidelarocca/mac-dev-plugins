#!/bin/bash
# Stop: run the project's fast verification before Claude ends a turn, but only when
# build inputs changed since the session started and since the last successful run. On failure, block the stop and
# hand the output to Claude. If Claude tries to stop again without changing anything,
# or after maxAttempts failures, let it stop and warn the user instead.

. "$(dirname "$0")/lib.sh"
sh_init || exit 0

[ "$(sh_cfg '.verify.enabled' 'true')" = "true" ] || exit 0
git -C "$SH_ROOT" rev-parse --git-dir >/dev/null 2>&1 || exit 0

command_line="$(sh_cfg '.verify.command' 'scripts/verify.sh fast')"
max_attempts="$(sh_cfg '.verify.maxAttempts' '3')"
state="$(sh_state_dir)" || exit 0

fp="$(sh_fingerprint)"
[ "$fp" = "$(cat "$state/passed" 2>/dev/null)" ] && exit 0
[ "$fp" = "$(cat "$state/baseline" 2>/dev/null)" ] && exit 0

failed_fp="$(cat "$state/failed" 2>/dev/null)"
failures="$(cat "$state/failures" 2>/dev/null)"
failures="${failures:-0}"

warn_user() {
  jq -n --arg msg "$1" '{systemMessage: $msg}'
}

# Nothing changed since the last failed run: never re-run on the same code.
# If this stop follows a block, Claude chose to stop: tell the user.
if [ "$fp" = "$failed_fp" ]; then
  if [ "$(sh_in '.stop_hook_active')" = "true" ]; then
    printf '0' > "$state/failures"
    warn_user "swift-harness: '$command_line' is still failing. Claude stopped without fixing it."
  fi
  exit 0
fi

out="$(mktemp -t swift-harness-verify.XXXXXX)"
(cd "$SH_ROOT" && bash -c "$command_line") >"$out" 2>&1
status=$?

if [ "$status" -eq 0 ]; then
  printf '%s' "$fp" > "$state/passed"
  printf '0' > "$state/failures"
  rm -f "$state/failed" "$out"
  exit 0
fi

failures=$((failures + 1))
printf '%s' "$fp" > "$state/failed"

if [ "$failures" -ge "$max_attempts" ]; then
  printf '0' > "$state/failures"
  rm -f "$out"
  warn_user "swift-harness: '$command_line' failed $max_attempts times in a row. Stopping so you can decide."
  exit 0
fi
printf '%s' "$failures" > "$state/failures"

{
  printf 'Verification failed (attempt %s of %s): %s\n\n' "$failures" "$max_attempts" "$command_line"
  tail -n 60 "$out"
  printf '\nFix the failures caused by your changes, then finish. If a failure is unrelated to your work, or you stopped on purpose to ask the user something, say so in one line and stop again without editing: the check will not block twice on the same code.\n'
} >&2
rm -f "$out"
exit 2
