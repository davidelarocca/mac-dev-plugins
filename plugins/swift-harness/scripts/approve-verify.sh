#!/bin/bash
# Approve the project's verify command for the Stop hook (#6). Run by the user-only skill
# /swift-harness:approve-verify, never by a hook.
#
#   approve-verify.sh --status [project-dir]          show what would be approved, and its digest
#   approve-verify.sh --approve DIGEST [project-dir]  approve, only if DIGEST is still current
#   approve-verify.sh --revoke [project-dir]          remove the approval
#
# The digest check makes the approval cover exactly what --status showed.

usage() {
  echo "usage: approve-verify.sh --status | --approve DIGEST | --revoke [project-dir]" >&2
  exit 64
}

action="${1:-}"
digest=""
case "$action" in
  --status | --revoke) shift ;;
  --approve)
    digest="${2:-}"
    [ -n "$digest" ] || usage
    shift 2
    ;;
  *) usage ;;
esac
dir="${1:-$PWD}"

# The approval must land where the hooks look for it, in the plugin's data folder.
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  echo "swift-harness: CLAUDE_PLUGIN_DATA is not set. Run this through /swift-harness:approve-verify." >&2
  exit 1
fi

. "$(dirname "$0")/lib.sh" </dev/null
SH_INPUT="$(jq -nc --arg cwd "$dir" '{cwd: $cwd}' 2>/dev/null)"
if ! sh_init; then
  echo "swift-harness: no .claude/swift-harness.json in $dir (or jq is missing). Nothing to approve." >&2
  exit 1
fi
state="$(sh_state_dir)" || {
  echo "swift-harness: cannot create the state folder under $CLAUDE_PLUGIN_DATA." >&2
  exit 1
}

command_line="$(sh_cfg '.verify.command' 'scripts/verify.sh fast')"

status() {
  local kind word sha
  printf 'Project: %s\nCommand: %s\n' "$SH_ROOT" "$command_line"
  while read -r kind word sha; do
    [ "$kind" = file ] && printf 'File: %s (sha256 %s)\n' "$word" "$sha"
  done < <(sh_verify_manifest "$command_line")
  [ "$(sh_cfg '.verify.enabled' 'true')" = "true" ] ||
    echo "Note: verify.enabled is false, so the Stop hook does not run this command."
  if sh_verify_approved "$command_line" "$state"; then
    echo "Status: approved"
  else
    echo "Status: not approved"
  fi
  printf 'Digest: %s\n' "$(sh_verify_digest "$command_line")"
}

case "$action" in
  --status) status ;;
  --revoke)
    rm -f "$state/verify-approved"
    status
    ;;
  --approve)
    if [ "$digest" != "$(sh_verify_digest "$command_line")" ]; then
      echo "swift-harness: the verify command or its files changed since they were shown. Nothing approved; check the status again."
      status
      exit 1
    fi
    printf '%s' "$digest" >"$state/verify-approved"
    status
    ;;
esac
