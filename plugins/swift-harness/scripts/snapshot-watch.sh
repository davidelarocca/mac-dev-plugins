#!/bin/bash
# Stop: tell the user when snapshot baselines changed in this session without
# /swift-harness:approve-snapshots (#9). The tests compare the UI with these images, so a
# baseline replaced to make a test pass must not go unnoticed. The guard asks before Claude
# edits the folder with Edit or Write; this also catches shell commands (cp, mv, rm).
# Never blocks. The session-start list is taken by session-start.sh; approvals are recorded
# by snapshots.sh.

. "$(dirname "$0")/lib.sh"
sh_init || exit 0
export LC_ALL=C
state="$(sh_state_dir)" || exit 0
sess="$(sh_session_path "$state")"
start="$sess/snapshots-start"
[ -f "$start" ] || exit 0 # no list for this session

folder="$(sh_snapshots)"
now="$(mktemp -t swift-harness-snapshots.XXXXXX)"
sh_snapshot_list "$folder" >"$now"

# Lines "<sha> <path>" present now and not at the start (added or changed), minus approved
# ones; paths present at the start and gone now (deleted).
changed="$(comm -13 "$start" "$now" | { if [ -f "$sess/snapshots-approved" ]; then grep -vxF -f "$sess/snapshots-approved"; else cat; fi; } | cut -d' ' -f2-)"
deleted="$(comm -23 <(cut -d' ' -f2- "$start" | sort -u) <(cut -d' ' -f2- "$now" | sort -u))"
rm -f "$now"
[ -n "$changed$deleted" ] || exit 0

report="$(
  [ -n "$changed" ] && printf '%s\n' "$changed" | sed 's/^/  changed: /'
  [ -n "$deleted" ] && printf '%s\n' "$deleted" | sed 's/^/  deleted: /'
)"
sum="$(printf '%s' "$report" | shasum | cut -d' ' -f1)"
[ "$sum" = "$(cat "$sess/snapshots-warned" 2>/dev/null)" ] && exit 0
printf '%s' "$sum" >"$sess/snapshots-warned"

msg="swift-harness: snapshot baselines in $folder/ changed in this session without /swift-harness:approve-snapshots:
$(printf '%s\n' "$report" | head -20)
The snapshot tests compare the UI with these images: check the changes (git diff --stat -- $folder/), and restore any you did not approve (git checkout -- <file>)."
jq -n --arg msg "$msg" '{systemMessage: $msg}'
exit 0
