#!/bin/bash
# PreToolUse (Edit|Write|MultiEdit): ask the user before Claude edits project.pbxproj
# or a protected path listed in .claude/swift-harness.json.
# Scope: only the Edit, Write and MultiEdit tools. Shell commands run through Bash are not
# intercepted, so this is a guard against accidental edits, not a sandbox.

. "$(dirname "$0")/lib.sh"
sh_init || exit 0

file="$(sh_in '.tool_input.file_path')"
[ -n "$file" ] || exit 0
# Resolve ../ and symlinks, so an alias of a protected file is still protected.
real="$(sh_realpath "$file")"
rel="$(sh_relpath "$file")"

reason=""

if [ "$(sh_cfg '.guardPbxproj' 'true')" = "true" ] && { [[ "$file" == *.pbxproj ]] || [[ "$real" == *.pbxproj ]]; }; then
  reason="swift-harness: direct edits to project.pbxproj corrupt projects easily. Prefer adding files on disk (synchronized folders) or a local Swift package. Approve only if this edit is intended."
fi

if [ -z "$reason" ] && [ -n "$rel" ]; then
  while IFS= read -r protected; do
    [ -n "$protected" ] || continue
    [[ "$protected" == *"{{"* ]] && continue
    protected="${protected#./}"
    protected="${protected%/}"
    if [ "$rel" = "$protected" ] || [[ "$rel" == "$protected"/* ]]; then
      reason="swift-harness: $protected is a protected area. Approve only if this change was explicitly requested and planned."
      break
    fi
  done < <(jq -r '.protectedPaths[]? // empty' "$SH_CONFIG" 2>/dev/null)
fi

[ -n "$reason" ] || exit 0

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "ask",
    permissionDecisionReason: $reason
  }
}'
exit 0
