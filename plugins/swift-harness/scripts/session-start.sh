#!/bin/bash
# SessionStart (startup|resume|clear): record the current code state as the session
# baseline, so the Stop hook only verifies what changes during the session, and report
# missing tools. The baseline is a starting point, not a verification result: if the last
# check failed on this exact code, say so.

. "$(dirname "$0")/lib.sh"

if ! sh_has_jq; then
  [ -f "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/swift-harness.json" ] &&
    echo "swift-harness: jq is not installed, so its quality hooks are inactive. Tell the user to run: brew install jq"
  exit 0
fi
sh_init || exit 0

verify_cmd="$(sh_cfg '.verify.command' 'scripts/verify.sh fast')"

if git -C "$SH_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  state="$(sh_state_dir)" && {
    fp="$(sh_identity)"
    printf '%s' "$fp" > "$state/baseline"
    printf '0' > "$state/failures"
    rm -f "$state/verified" # pre-1.0.1 name of the baseline file
    # The contract as it was at session start, for contract-watch.sh (#13).
    rm -f "$state/contract-start.json" "$state/contract-start.none" "$state/contract-warned"
    if [ -f "$SH_ROOT/$SH_CONTRACT" ]; then
      cp "$SH_ROOT/$SH_CONTRACT" "$state/contract-start.json"
    else
      : >"$state/contract-start.none"
    fi
    # The snapshot baselines as they were at session start, for snapshot-watch.sh (#9).
    rm -f "$state/snapshots-warned" "$state/snapshots-approved"
    sh_snapshot_list "$(sh_snapshots)" >"$state/snapshots-start"
    if [ -n "$fp" ] && [ "$fp" = "$(cat "$state/failed" 2>/dev/null)" ]; then
      echo "swift-harness: the last verification ('$verify_cmd') failed on the current code and has not passed since. Treat the project as not verified."
    fi
    if [ "$(sh_cfg '.verify.enabled' 'true')" = "true" ] && ! sh_verify_approved "$verify_cmd" "$state"; then
      echo "swift-harness: the verify command '$verify_cmd' is not approved for this project (it is new, or it or a file it runs changed since the last approval). The end-of-turn check does not run it, so code changes are not verified. Ask the user to review it and type /swift-harness:approve-verify. Do not run the approval yourself."
    fi
    # Files blocked by lintBlocking are re-linted when the code changes; say so now, since
    # unchanged code is not re-checked.
    if [ "$(sh_cfg '.lintBlocking' 'false')" = "true" ] && [ -s "$state/lint-pending" ]; then
      pending="$(head -5 "$state/lint-pending" | paste -sd, - | sed 's/,/, /g')"
      echo "swift-harness: lintBlocking is on and these files failed SwiftLint at the last check: $pending. They are linted again at the end of the next turn that changes code."
    fi
  }
fi

missing=()
case "$(sh_cfg '.format' 'swiftformat')" in
  swiftformat) command -v swiftformat >/dev/null 2>&1 || missing+=("swiftformat") ;;
  swift-format) xcrun --find swift-format >/dev/null 2>&1 || command -v swift-format >/dev/null 2>&1 || missing+=("swift-format") ;;
esac
[ "$(sh_cfg '.lint' 'swiftlint')" = "swiftlint" ] && { command -v swiftlint >/dev/null 2>&1 || missing+=("swiftlint"); }

verify_bin="${verify_cmd%% *}"
if [ "$(sh_cfg '.verify.enabled' 'true')" = "true" ] && [[ "$verify_bin" == */* ]] && [ ! -x "$SH_ROOT/$verify_bin" ]; then
  echo "swift-harness: verify command '$verify_bin' is missing or not executable. The Stop check will fail until it exists."
fi

# swift-format without a config file uses 2-space indentation and rewrites whole files.
if [ "$(sh_cfg '.format' 'swiftformat')" = "swift-format" ] && [ ! -f "$SH_ROOT/.swift-format" ]; then
  echo "swift-harness: format is swift-format but the project has no .swift-format file, so swift-format applies its defaults (2-space indentation) to every file Claude edits. Tell the user; /swift-harness:setup ships a template with 4 spaces."
fi

if [ "${#missing[@]}" -gt 0 ]; then
  echo "swift-harness: not installed: ${missing[*]}. Those checks are skipped. Install with: brew install ${missing[*]}"
  if [ "$(sh_cfg '.lintBlocking' 'false')" = "true" ] && [[ " ${missing[*]} " == *" swiftlint "* ]]; then
    echo "swift-harness: lintBlocking is on, so the end-of-turn check fails after code changes until SwiftLint is installed."
  fi
fi
exit 0
