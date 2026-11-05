#!/bin/bash
# SessionStart (startup|resume|clear): accept the current code state as the baseline,
# so the Stop hook only verifies what changes during the session, and report missing tools.

. "$(dirname "$0")/lib.sh"

if ! sh_has_jq; then
  [ -f "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/swift-harness.json" ] &&
    echo "swift-harness: jq is not installed, so its quality hooks are inactive. Tell the user to run: brew install jq"
  exit 0
fi
sh_init || exit 0

if git -C "$SH_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  state="$(sh_state_dir)" && {
    sh_fingerprint > "$state/verified"
    printf '0' > "$state/failures"
    rm -f "$state/failed"
  }
fi

missing=()
case "$(sh_cfg '.format' 'swiftformat')" in
  swiftformat) command -v swiftformat >/dev/null 2>&1 || missing+=("swiftformat") ;;
  swift-format) xcrun --find swift-format >/dev/null 2>&1 || command -v swift-format >/dev/null 2>&1 || missing+=("swift-format") ;;
esac
[ "$(sh_cfg '.lint' 'swiftlint')" = "swiftlint" ] && { command -v swiftlint >/dev/null 2>&1 || missing+=("swiftlint"); }

verify_cmd="$(sh_cfg '.verify.command' 'scripts/verify.sh fast')"
verify_bin="${verify_cmd%% *}"
if [ "$(sh_cfg '.verify.enabled' 'true')" = "true" ] && [[ "$verify_bin" == */* ]] && [ ! -x "$SH_ROOT/$verify_bin" ]; then
  echo "swift-harness: verify command '$verify_bin' is missing or not executable. The Stop check will fail until it exists."
fi

if [ "${#missing[@]}" -gt 0 ]; then
  echo "swift-harness: not installed: ${missing[*]}. Those checks are skipped. Install with: brew install ${missing[*]}"
fi
exit 0
