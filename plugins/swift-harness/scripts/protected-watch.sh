#!/bin/bash
# Stop: tell the user when files under the protected paths changed in this session outside
# the Edit and Write tools (#11). The guard asks before Claude edits them with those tools;
# a shell command (sed, cp, mv, rm, a script, a build step) is not asked about. This reports
# it afterwards: detection, not prevention. Claude Code permission rules are the way to block
# writes. Never blocks. The session-start list is taken by session-start.sh; edits made
# through the guarded tools are recorded by post-edit.sh.

. "$(dirname "$0")/lib.sh"
sh_init || exit 0
export LC_ALL=C
state="$(sh_state_dir)" || exit 0
start="$state/protected-start"
[ -f "$start" ] || exit 0 # no list for this session

now="$(mktemp -t swift-harness-protected.XXXXXX)"
sh_protected_list >"$now"

# Lines "<sha> <path>" present now and not at the start (added or changed), minus the states
# left by a guarded edit; paths present at the start and gone now (deleted).
changed="$(comm -13 "$start" "$now" | { if [ -f "$state/protected-edited" ]; then grep -vxF -f "$state/protected-edited"; else cat; fi; } | cut -d' ' -f2-)"
deleted="$(comm -23 <(cut -d' ' -f2- "$start" | sort -u) <(cut -d' ' -f2- "$now" | sort -u))"
rm -f "$now"
[ -n "$changed$deleted" ] || exit 0

report="$(
  [ -n "$changed" ] && printf '%s\n' "$changed" | sed 's/^/  changed: /'
  [ -n "$deleted" ] && printf '%s\n' "$deleted" | sed 's/^/  deleted: /'
)"
sum="$(printf '%s' "$report" | shasum | cut -d' ' -f1)"
[ "$sum" = "$(cat "$state/protected-warned" 2>/dev/null)" ] && exit 0
printf '%s' "$sum" >"$state/protected-warned"

msg="swift-harness: protected files changed in this session without going through Edit or Write, so you were not asked first:
$(printf '%s\n' "$report" | head -20)
Check them (git diff -- <file>) and restore any change you did not ask for (git checkout -- <file>)."
jq -n --arg msg "$msg" '{systemMessage: $msg}'
exit 0
