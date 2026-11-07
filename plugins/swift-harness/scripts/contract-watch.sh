#!/bin/bash
# Stop: tell the user when the architecture contract changed during the session (#13).
# The contract decides which module dependencies the end-of-turn check allows, so a change
# made by Claude must not pass silently. Nothing here can stop Claude from editing it (the
# guard is not a sandbox), but the user sees every allowed dependency added or removed.
# Never blocks. The session-start copy is taken by session-start.sh.

. "$(dirname "$0")/lib.sh"
sh_init || exit 0
state="$(sh_state_dir)" || exit 0
sess="$(sh_session_path "$state")"

current="$SH_ROOT/$SH_CONTRACT"
start="$sess/contract-start.json"
if [ -f "$start" ]; then
  had=true
elif [ -f "$sess/contract-start.none" ]; then
  had=false
else
  exit 0 # no baseline for this session
fi

sum="none"
[ -f "$current" ] && sum="$(shasum <"$current" | cut -d' ' -f1)"
[ "$sum" = "$(cat "$sess/contract-warned" 2>/dev/null)" ] && exit 0
if [ "$had" = true ] && [ -f "$current" ] && cmp -s "$start" "$current"; then exit 0; fi
[ "$had" = false ] && [ ! -f "$current" ] && exit 0

# One line per allowed dependency: "<target> -> <dependency>", prefixed by the package
# folder when it is not the root. A target with an empty list shows "(no dependencies)".
edges() {
  jq -r '.packages | to_entries[] | (if .key == "." then "" else "\(.key): " end) as $p
    | .value | to_entries[] | .key as $t
    | if (.value | length) == 0 then "\($p)\($t) (no dependencies)" else .value[] | "\($p)\($t) -> \(.)" end' \
    "$1" 2>/dev/null | sort -u
}

if [ ! -f "$current" ]; then
  msg="swift-harness: $SH_CONTRACT was deleted in this session, so the architecture contracts are no longer checked."
elif [ "$had" = false ]; then
  msg="swift-harness: $SH_CONTRACT was created in this session. Review the module dependencies it allows:
$(edges "$current" | head -30)"
elif ! jq empty "$current" >/dev/null 2>&1; then
  msg="swift-harness: $SH_CONTRACT changed in this session and is no longer valid JSON."
else
  old="$(mktemp -t swift-harness-contract.XXXXXX)"
  new="$(mktemp -t swift-harness-contract.XXXXXX)"
  edges "$start" >"$old"
  edges "$current" >"$new"
  changes="$(comm -13 "$old" "$new" | sed 's/^/+ /'; comm -23 "$old" "$new" | sed 's/^/- /')"
  rm -f "$old" "$new"
  [ -n "$changes" ] || exit 0
  msg="swift-harness: the architecture contract ($SH_CONTRACT) changed in this session. Allowed module dependencies (+ added, - removed):
$(printf '%s\n' "$changes" | head -30)
Check that you agree: the contract decides what the end-of-turn check accepts."
fi

printf '%s' "$sum" >"$sess/contract-warned"
jq -n --arg msg "$msg" '{systemMessage: $msg}'
exit 0
