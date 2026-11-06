#!/bin/bash
# Architecture contracts on a real SwiftPM package (#13, SH130-08). Read-only: works on a
# copy in a temp folder, never on the given folder. It runs `swift package dump-package`,
# which evaluates Package.swift: use it only on a package you trust.
#
# Usage: tests/real-app/contracts.sh <folder with Package.swift>
#
# 1. Generates the contract from the real graph, as /swift-harness:setup proposes it, and
#    checks that the unchanged package passes.
# 2. Removes one allowed dependency from the contract: the package must now fail, naming
#    the target and the dependency (the same edge as adding it to Package.swift).
# 3. Removes one target from the contract: it must fail as "not in the contract".
# Prints the toolchain, the sizes and the timings, for tests/smoke/RESULTS.md.

set -u
src="$(cd "${1:?usage: contracts.sh <folder with Package.swift>}" && pwd -P)"
[ -f "$src/Package.swift" ] || { echo "no Package.swift in $src" >&2; exit 2; }
CONTRACTS="$(cd "$(dirname "$0")/../../plugins/swift-harness/scripts" && pwd -P)/contracts.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/swift-harness-real.XXXXXX")"
trap 'rm -rf "$work"' EXIT
rsync -a --exclude .build --exclude .git "$src/" "$work/pkg/"
cd "$work/pkg" || exit 2
mkdir -p docs
contract=docs/architecture-contracts.json

echo "toolchain: $(swift --version 2>/dev/null | head -1)"
start=$(date +%s)
swift package dump-package >"$work/dump.json" || { echo "dump-package failed" >&2; exit 2; }
jq '{version: 1, packages: {".": ([.targets[] | select(.type == "regular" or .type == "executable")
  | {key: .name, value: [.dependencies[] | (.byName[0]? // .target[0]?
      // (if .product then "\(.product[1])/\(.product[0])" else empty end))]}] | from_entries)}}' \
  "$work/dump.json" >"$contract"
echo "targets in the contract: $(jq '.packages["."] | length' "$contract"), dump-package $(($(date +%s) - start)) s"

failures=0
check() { # $1 description, $2 expected exit, $3 regex the output must match
  local out code t0
  t0=$(date +%s)
  out="$("$CONTRACTS" "$work/pkg" 2>&1)"
  code=$?
  if [ "$code" = "$2" ] && grep -qE -- "$3" <<<"$out"; then
    printf 'ok    %s (%s s)\n' "$1" "$(($(date +%s) - t0))"
  else
    printf 'FAIL  %s (exit %s)\n%s\n' "$1" "$code" "$out"
    failures=$((failures + 1))
  fi
}

check "the package matches the contract generated from it" 0 '.*'
cp "$contract" "$work/contract.json"
read -r target dep < <(jq -r '.packages["."] | to_entries[] | select(.value | length > 0) | "\(.key) \(.value[0])"' "$contract" | head -1)
if [ -n "${target:-}" ]; then
  jq --arg t "$target" --arg d "$dep" '.packages["."][$t] -= [$d]' "$work/contract.json" >"$contract"
  check "an edge the contract does not allow fails: $target -> $dep" 1 "target \"$target\" depends on \"$dep\""
fi
last="$(jq -r '.packages["."] | keys | last' "$work/contract.json")"
jq --arg t "$last" 'del(.packages["."][$t])' "$work/contract.json" >"$contract"
check "a target missing from the contract fails: $last" 1 "target \"$last\" is not in the contract"
exit "$failures"
