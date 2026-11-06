#!/bin/bash
# Security settings contract (#32): sandbox, hardened runtime, capabilities and App Transport
# Security, read from the real files, compared with the state the user approved.
#
#   security.sh state     [--project DIR]            the current state, one line per setting
#   security.sh check     [--project DIR]            exit 1 with the changes since the approval
#   security.sh --status  [--project DIR]            the changes and a digest (for the user)
#   security.sh --approve DIGEST [--project DIR]     record the current state as approved
#   security.sh --record  [--project DIR]            record it only if nothing is recorded yet
#
# Sources, read without running project code: every *.entitlements plist (plutil), the
# NSAppTransportSecurity dictionary of *Info.plist files, and code-signing and capability build
# settings in project.pbxproj and *.xcconfig files (each value with how many configurations set
# it). The approved state lives in the plugin data folder, outside the project, so a change in
# the repository cannot approve itself. Approving is for the user, through
# /swift-harness:approve-security.

usage() {
  echo "usage: security.sh state|check|--status|--record [--project DIR] | --approve DIGEST [--project DIR]" >&2
  exit 2
}
action="${1:-}"
digest=""
case "$action" in
  state | check | --status | --record) shift ;;
  --approve)
    digest="${2:-}"
    [ -n "$digest" ] || usage
    shift 2
    ;;
  *) usage ;;
esac
dir="$PWD"
if [ "${1:-}" = "--project" ]; then
  [ -n "${2:-}" ] || usage
  dir="$2"
  shift 2
fi
[ $# -eq 0 ] || usage

. "$(dirname "$0")/lib.sh" </dev/null
export LC_ALL=C
SH_INPUT="$(jq -nc --arg cwd "$dir" '{cwd: $cwd}' 2>/dev/null)"
sh_init || { echo "swift-harness: no .claude/swift-harness.json in $dir (or jq is missing)." >&2; exit 2; }

EXCLUDE=(':!.build/*' ':!*/.build/*' ':!*DerivedData/*' ':!Pods/*' ':!Carthage/*' ':!*/checkouts/*')
files() { git -C "$SH_ROOT" ls-files -co --exclude-standard -- "$@" "${EXCLUDE[@]}" 2>/dev/null; }
SETTINGS='ENABLE_HARDENED_RUNTIME|ENABLE_APP_SANDBOX|CODE_SIGN_ENTITLEMENTS|CODE_SIGN_INJECT_BASE_ENTITLEMENTS|OTHER_CODE_SIGN_FLAGS|ENABLE_USER_SELECTED_FILES|ENABLE_INCOMING_NETWORK_CONNECTIONS|ENABLE_OUTGOING_NETWORK_CONNECTIONS|ENABLE_FILE_ACCESS_[A-Z_]+|ENABLE_RESOURCE_ACCESS_[A-Z_]+|RUNTIME_EXCEPTION_[A-Z_]+|AUTOMATION_APPLE_EVENTS|ENABLE_LIBRARY_VALIDATION|DISABLE_LIBRARY_VALIDATION'

# One line per setting: "<file>: <key> = <value>", sorted.
current_state() {
  local f json
  {
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if json="$(plutil -convert json -o - "$SH_ROOT/$f" 2>/dev/null)"; then
        printf '%s' "$json" | jq -r --arg f "$f" \
          'paths(scalars) as $p | "\($f): \($p | map(tostring) | join(".")) = \(getpath($p))"'
        [ "$json" != "{}" ] || printf '%s: (no entitlements)\n' "$f"
      else
        printf '%s: (not a readable plist)\n' "$f"
      fi
    done <<<"$(files '*.entitlements')"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      json="$(plutil -extract NSAppTransportSecurity json -o - "$SH_ROOT/$f" 2>/dev/null)" || continue
      printf '%s' "$json" | jq -r --arg f "$f" \
        'paths(scalars) as $p | "\($f): NSAppTransportSecurity.\($p | map(tostring) | join(".")) = \(getpath($p))"'
    done <<<"$(files '*Info.plist')"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      grep -oE "^[[:space:]]*($SETTINGS)(\\[[^]]*\\])?[[:space:]]*=[^;]*" "$SH_ROOT/$f" |
        sed -E -e 's/^[[:space:]]+//' -e 's/[[:space:]]*=[[:space:]]*/ = /' -e 's/[[:space:]]+$//' -e 's/"//g' |
        sort | uniq -c | awk -v f="$f" '{ c = $1; $1 = ""; sub(/^ /, ""); printf "%s: %s%s\n", f, $0, (c > 1 ? " (" c " configurations)" : "") }'
    done <<<"$(files '*.pbxproj' '*.xcconfig')"
  } | sort
}

state_dir="$(sh_state_path)"
approved="$state_dir/security-approved"
changes() { # "+ line" for added or changed, "- line" for removed
  diff "$approved" <(current_state) | sed -n -e 's/^> /+ /p' -e 's/^< /- /p'
}
digest_of() { { cat "$approved" 2>/dev/null; printf -- '--\n'; current_state; } | shasum -a 256 | cut -d' ' -f1; }

case "$action" in
  state)
    current_state
    ;;
  check)
    [ -f "$approved" ] || exit 0 # nothing recorded yet: session start records it
    out="$(changes)"
    [ -z "$out" ] && exit 0
    printf 'Security settings changed since the user approved them:\n%s\n' "$(printf '%s\n' "$out" | head -30)"
    printf 'If you relaxed a setting to make something work, revert it and find another way. If the change is needed, stop and tell the user why: only they approve it, by typing /swift-harness:approve-security. Do not run it yourself.\n'
    exit 1
    ;;
  --record)
    [ -f "$approved" ] && exit 0
    mkdir -p "$state_dir" && current_state >"$approved"
    ;;
  --status | --approve)
    [ -n "${CLAUDE_PLUGIN_DATA:-}" ] || {
      echo "swift-harness: CLAUDE_PLUGIN_DATA is not set. Run this through /swift-harness:approve-security." >&2
      exit 1
    }
    if [ ! -f "$approved" ]; then
      out="$(current_state | sed 's/^/+ /')"
    else
      out="$(changes)"
    fi
    if [ "$action" = "--status" ]; then
      if [ -z "$out" ]; then
        printf 'No change since the last approval (%s setting(s) recorded).\n' "$(grep -c . "$approved" 2>/dev/null || echo 0)"
      else
        printf 'Changes since the last approval (+ added or new value, - removed or old value):\n%s\n' "$out"
      fi
      printf 'Digest: %s\n' "$(digest_of)"
      exit 0
    fi
    if [ "$digest" != "$(digest_of)" ]; then
      echo "Nothing approved: the security settings changed since the list was shown. List them again." >&2
      exit 1
    fi
    mkdir -p "$state_dir" && current_state >"$approved"
    printf 'Approved: %s setting(s) recorded as the security baseline.\n' "$(grep -c . "$approved")"
    ;;
esac
