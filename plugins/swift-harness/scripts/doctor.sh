#!/bin/bash
# Read-only diagnosis of a swift-harness setup (#12). Run by /swift-harness:doctor.
#
#   doctor.sh [project-dir]
#
# Prints a Markdown table, one row per check: PASS, WARN, FAIL or INFO, with one fix per
# problem. Exits 1 if any check fails. Changes no file: it does not create the state
# folder, and git runs without optional locks so the index is not refreshed.

export GIT_OPTIONAL_LOCKS=0
dir="${1:-$PWD}"
here="$(cd "$(dirname "$0")" && pwd -P)"
fails=0

row() { # $1 status, $2 check, $3 detail
  local detail="${3//|/\\|}"
  printf '| %s | %s | %s |\n' "$1" "$2" "$detail"
  [ "$1" != FAIL ] || fails=$((fails + 1))
}

. "$here/lib.sh" </dev/null

printf '| Status | Check | Detail |\n|---|---|---|\n'
row PASS swift-harness "plugin ${SH_VERSION:-unknown version}"

# ---------- tools ----------

if ! sh_has_jq; then
  row FAIL jq "not installed: every swift-harness hook is inactive. Fix: brew install jq"
  exit 1
fi
row PASS jq "$(jq --version 2>/dev/null)"

SH_INPUT="$(jq -nc --arg cwd "$dir" '{cwd: $cwd}')"
SH_ROOT="$(sh_root)"
SH_CONFIG="$SH_ROOT/.claude/swift-harness.json"

developer_dir="$(xcode-select -p 2>/dev/null)"
if [ -z "$developer_dir" ]; then
  row WARN Xcode "no developer tools selected: xcodebuild and swift are unavailable. Fix: install Xcode, then sudo xcode-select -s /Applications/Xcode.app"
elif [[ "$developer_dir" == *CommandLineTools* ]]; then
  row WARN Xcode "only the Command Line Tools are selected ($developer_dir): xcodebuild cannot build app targets. Fix: sudo xcode-select -s /Applications/Xcode.app"
else
  row PASS Xcode "$(xcodebuild -version 2>/dev/null | head -1), $(swift --version 2>/dev/null | head -1 | sed 's/ (.*//')"
fi

# ---------- configuration ----------

if git -C "$SH_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  in_git=true
  row PASS Git "$SH_ROOT"
else
  in_git=false
  row FAIL Git "$SH_ROOT is not a git repository: the end-of-turn check needs git to see what changed. Fix: git init"
fi

if [ ! -f "$SH_CONFIG" ]; then
  row FAIL Config "no .claude/swift-harness.json: the hooks are off in this project. Fix: run /swift-harness:setup"
  exit 1
fi
if ! jq -e 'type == "object"' "$SH_CONFIG" >/dev/null 2>&1; then
  row FAIL Config ".claude/swift-harness.json is not a valid JSON object: the hooks fall back to defaults for every value. Fix: $(jq . "$SH_CONFIG" 2>&1 >/dev/null | head -1)"
  exit 1
fi

unknown="$(jq -r '
  (keys - ["format", "lint", "lintBlocking", "guardPbxproj", "protectedPaths", "verify", "registry"])[],
  (if (.verify | type) == "object" then (.verify | keys - ["enabled", "command", "maxAttempts", "inputs"])[] | "verify." + . else empty end),
  (if (.registry | type) == "object" then (.registry | keys - ["enabled", "path", "sources"])[] | "registry." + . else empty end)
' "$SH_CONFIG" | paste -sd, - | sed 's/,/, /g')"
if [ -n "$unknown" ]; then
  row WARN "Config keys" "unknown, ignored by the hooks (typo?): $unknown"
else
  row PASS "Config keys" "all known"
fi

problems="$(jq -r '
  def check(path; ok; msg): if (getpath(path) != null) and (getpath(path) | ok | not) then msg else empty end;
  check(["format"]; . == "swiftformat" or . == "swift-format" or . == "none"; "format must be swiftformat, swift-format or none"),
  check(["lint"]; . == "swiftlint" or . == "none"; "lint must be swiftlint or none"),
  check(["lintBlocking"]; type == "boolean"; "lintBlocking must be true or false"),
  check(["guardPbxproj"]; type == "boolean"; "guardPbxproj must be true or false"),
  check(["protectedPaths"]; type == "array" and all(.[]; type == "string"); "protectedPaths must be a list of paths"),
  check(["verify"]; type == "object"; "verify must be an object"),
  (if (.verify | type) == "object" then
    check(["verify", "enabled"]; type == "boolean"; "verify.enabled must be true or false"),
    check(["verify", "command"]; type == "string" and length > 0; "verify.command must be a non-empty string"),
    check(["verify", "maxAttempts"]; type == "number" and . >= 1 and floor == .; "verify.maxAttempts must be a whole number, 1 or more"),
    check(["verify", "inputs"]; type == "array" and all(.[]; type == "string"); "verify.inputs must be a list of paths")
  else empty end),
  check(["registry"]; type == "object"; "registry must be an object"),
  (if (.registry | type) == "object" then
    check(["registry", "enabled"]; type == "boolean"; "registry.enabled must be true or false"),
    check(["registry", "path"]; type == "string" and length > 0; "registry.path must be a path"),
    check(["registry", "sources"]; type == "array" and all(.[]; type == "string"); "registry.sources must be a list of folders")
  else empty end)
' "$SH_CONFIG" | paste -sd ';' - | sed 's/;/; /g')"
if [ -n "$problems" ]; then
  row FAIL Config "$problems. Fix: edit .claude/swift-harness.json (see the README, Configuration)"
else
  row PASS Config ".claude/swift-harness.json"
fi

format="$(sh_cfg '.format' 'swiftformat')"
lint="$(sh_cfg '.lint' 'swiftlint')"
lint_blocking="$(sh_cfg '.lintBlocking' 'false')"
verify_enabled="$(sh_cfg '.verify.enabled' 'true')"
command_line="$(sh_cfg '.verify.command' 'scripts/verify.sh fast')"

# ---------- formatter and linter ----------

case "$format" in
  swiftformat)
    if command -v swiftformat >/dev/null 2>&1; then
      row PASS Formatter "swiftformat $(swiftformat --version 2>/dev/null | head -1)"
    else
      row WARN Formatter "swiftformat not installed: edited files are not formatted. Fix: brew install swiftformat"
    fi
    ;;
  swift-format)
    if xcrun --find swift-format >/dev/null 2>&1 || command -v swift-format >/dev/null 2>&1; then
      row PASS Formatter "swift-format (Xcode)"
    else
      row WARN Formatter "swift-format not found: edited files are not formatted. Fix: install Xcode 16 or later, or brew install swift-format"
    fi
    if [ -f "$SH_ROOT/.swift-format" ]; then
      row PASS "Formatter config" ".swift-format"
    else
      row WARN "Formatter config" "no .swift-format: swift-format applies 2-space indentation to every edited file. Fix: copy the template from /swift-harness:setup"
    fi
    ;;
  none) row INFO Formatter "off (format is none)" ;;
esac

if [ "$lint" = swiftlint ]; then
  if command -v swiftlint >/dev/null 2>&1; then
    row PASS SwiftLint "$(swiftlint version 2>/dev/null | head -1)${lint_blocking:+, lintBlocking $lint_blocking}"
  elif [ "$lint_blocking" = true ]; then
    row FAIL SwiftLint "not installed and lintBlocking is on: the end-of-turn check fails after every code change. Fix: brew install swiftlint, or set lintBlocking to false"
  else
    row WARN SwiftLint "not installed: edits are not linted. Fix: brew install swiftlint"
  fi
else
  row INFO SwiftLint "off (lint is none)"
fi

# ---------- placeholders and protected paths ----------

with_placeholders=""
for f in CLAUDE.md .claude/rules/*.md docs/ARCHITECTURE.md docs/DESIGN_SYSTEM.md docs/COMPONENT_REGISTRY.md \
  .swiftlint.yml .swiftformat .claude/swift-harness.json scripts/verify.sh; do
  [ -f "$SH_ROOT/$f" ] && grep -qE '\{\{[A-Z_]+\}\}' "$SH_ROOT/$f" && with_placeholders="$with_placeholders${with_placeholders:+, }$f"
done
if [ -n "$with_placeholders" ]; then
  row WARN Placeholders "unfilled {{...}} in: $with_placeholders. Fix: replace them with the project's values, or run /swift-harness:setup again"
else
  row PASS Placeholders "none left in the generated files"
fi

missing_paths=""
while IFS= read -r p; do
  [ -n "$p" ] && [[ "$p" != *"{{"* ]] || continue
  [ -e "$SH_ROOT/${p#./}" ] || missing_paths="$missing_paths${missing_paths:+, }$p"
done < <(jq -r '.protectedPaths[]? | strings' "$SH_CONFIG" 2>/dev/null)
if [ -n "$missing_paths" ]; then
  row WARN "Protected paths" "not found, so nothing is protected there (typo or moved?): $missing_paths"
else
  row PASS "Protected paths" "$(jq -r '[.protectedPaths[]? | strings | select(contains("{{") | not)] | if length == 0 then "none" else join(", ") end' "$SH_CONFIG")"
fi

# ---------- verification ----------

state="$(sh_state_path)"
verify_bin="${command_line%% *}"
if [ "$verify_enabled" != true ]; then
  row WARN "Verify script" "verify.enabled is false: code changes are not built or tested at the end of a turn"
elif [[ "$verify_bin" == */* ]] && [ ! -f "$SH_ROOT/$verify_bin" ]; then
  row FAIL "Verify script" "$verify_bin does not exist: the end-of-turn check fails. Fix: run /swift-harness:setup, or fix verify.command"
elif [[ "$verify_bin" == */* ]] && [ ! -x "$SH_ROOT/$verify_bin" ]; then
  row FAIL "Verify script" "$verify_bin is not executable: the end-of-turn check fails. Fix: chmod +x $verify_bin"
elif [ -f "$SH_ROOT/$verify_bin" ] && grep -q '^PACKAGES=(' "$SH_ROOT/$verify_bin" && grep -q '^SCHEME=' "$SH_ROOT/$verify_bin"; then
  # The script generated by /swift-harness:setup: read its settings without running it.
  settings="$(sed -n -e 's/^XCODE_CONTAINER="\([^"]*\)".*/\1/p' -e 's/^SCHEME="\([^"]*\)".*/\1/p' -e 's/^PACKAGES=(\(.*\)).*/\1/p' "$SH_ROOT/$verify_bin")"
  scheme="$(sed -n 's/^SCHEME="\([^"]*\)".*/\1/p' "$SH_ROOT/$verify_bin")"
  # Quoted or bare words, read as text (SH130-05): doctor never runs the script.
  package_list="$(sed -n 's/^PACKAGES=(\([^)]*\)).*/\1/p' "$SH_ROOT/$verify_bin")"
  packages_unreadable=false
  case "$package_list" in *'$'* | *'`'* | *'\'*) packages_unreadable=true ;; esac
  package_paths="$(printf '%s' "$package_list" | grep -oE "\"[^\"]*\"|'[^']*'|[^[:space:]\"']+" | sed -E "s/^[\"'](.*)[\"']\$/\1/")"
  packages="$(printf '%s' "$package_paths" | paste -sd, - | sed 's/,/, /g')"
  missing_packages=""
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    [ -f "$SH_ROOT/$pkg/Package.swift" ] || missing_packages="$missing_packages${missing_packages:+, }$pkg"
  done <<<"$package_paths"
  if [[ "$settings" == *"{{"* ]]; then
    row FAIL "Verify script" "$verify_bin still has {{...}} placeholders in its settings: it reports NOT CONFIGURED. Fix: set XCODE_CONTAINER, SCHEME and PACKAGES at the top"
  elif [ "$packages_unreadable" = true ]; then
    row WARN "Verify script" "$verify_bin: its PACKAGES list ($package_list) cannot be read without running the script, so the package folders were not checked"
  elif [ -z "$scheme" ] && [ -z "$packages" ]; then
    row FAIL "Verify script" "$verify_bin sets no scheme and no package: it reports NOT CONFIGURED. Fix: set SCHEME or PACKAGES at the top"
  elif [ -n "$missing_packages" ]; then
    row FAIL "Verify script" "$verify_bin lists packages with no Package.swift: $missing_packages. Fix: correct PACKAGES at the top"
  else
    row PASS "Verify script" "$verify_bin: ${scheme:+scheme $scheme}${scheme:+${packages:+, }}${packages:+packages $packages}"
  fi
else
  row PASS "Verify script" "custom command '$command_line', not inspected"
fi

if [ "$verify_enabled" = true ]; then
  if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
    row WARN "Verify approval" "unknown: run this check through /swift-harness:doctor so it can read the plugin data folder"
  elif sh_verify_approved "$command_line" "$state" && sh_verify_partial "$command_line"; then
    row WARN "Verify approval" "'$command_line' approved, partial coverage: it has quotes or shell syntax, so the files it runs may change without a new approval. Fix: list them in verify.inputs, then type /swift-harness:approve-verify"
  elif sh_verify_approved "$command_line" "$state"; then
    row PASS "Verify approval" "'$command_line' approved for this path"
  else
    row FAIL "Verify approval" "'$command_line' is not approved (new, or it or a file it runs changed): the end-of-turn check does not run it. Fix: review it, then type /swift-harness:approve-verify"
  fi
fi

# ---------- project structure ----------

packages_found="$(cd "$SH_ROOT" && find . -maxdepth 3 -name Package.swift -not -path '*/.build/*' 2>/dev/null |
  sed 's|^\./||' | sort | paste -sd, - | sed 's/,/, /g')"
containers="$(cd "$SH_ROOT" && find . -maxdepth 2 \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) -not -path '*/.build/*' \
  -not -path '*.xcodeproj/*' 2>/dev/null | sed 's|^\./||' | sort | paste -sd, - | sed 's/,/, /g')"
if [ -n "$packages_found" ]; then
  row INFO "Project structure" "SwiftPM packages: $packages_found${containers:+; Xcode: $containers}"
else
  row INFO "Project structure" "${containers:-no Xcode project found}, no SwiftPM package"
fi

# Architecture contracts (#13). Checked without running any manifest: doctor runs nothing
# from the repository.
if [ -f "$SH_ROOT/$SH_CONTRACT" ]; then
  if summary="$("$here/contracts.sh" --validate "$SH_ROOT" 2>&1)"; then
    if [ "$verify_enabled" = true ] && [ -n "${CLAUDE_PLUGIN_DATA:-}" ] && sh_verify_approved "$command_line" "$state"; then
      row PASS "Architecture contracts" "$SH_CONTRACT: $summary, checked at the end of each turn and when Package.swift is edited"
    else
      row WARN "Architecture contracts" "$SH_CONTRACT: $summary, but not checked: reading the dependency graph runs Package.swift, so it happens only with the verify command enabled and approved"
    fi
  else
    row FAIL "Architecture contracts" "${summary#Architecture contracts ($SH_CONTRACT): }"
  fi
elif [ -n "$packages_found" ]; then
  row INFO "Architecture contracts" "none: add $SH_CONTRACT to fail the end-of-turn check when a target gains a dependency the contract does not allow"
else
  row INFO "Architecture contracts" "not available: they check the dependencies between SwiftPM targets, and this project has no SwiftPM package"
fi

# Component registry (#7). Reads Markdown and Swift files only.
registry="$(sh_registry)"
if [ "$(sh_cfg '.registry.enabled' 'true')" != true ]; then
  row INFO "Component registry" "off (registry.enabled is false)"
elif [ ! -f "$SH_ROOT/$registry" ]; then
  row INFO "Component registry" "none: $registry lists the shared components Claude must reuse; /swift-harness:setup creates it, and the end-of-turn check keeps it true"
else
  registry_out="$("$here/registry.sh" check "$SH_ROOT" 2>&1)"
  case $? in
    0)
      summary="$("$here/registry.sh" summary "$SH_ROOT")"
      missing="$("$here/registry.sh" missing "$SH_ROOT" | awk -F'\t' '{printf "%s%s (%s)", (NR > 1 ? ", " : ""), $1, $2}')"
      if [ -n "$missing" ]; then
        row WARN "Component registry" "$summary; not listed: $missing. Fix: add them, or list them under Internal"
      elif [ -z "$(jq -r '.registry.sources[]? | strings' "$SH_CONFIG" 2>/dev/null | grep -v '{{')" ]; then
        row PASS "Component registry" "$summary, checked at the end of each turn; set registry.sources to also find components it does not list"
      else
        row PASS "Component registry" "$summary, checked at the end of each turn"
      fi
      ;;
    3) row WARN "Component registry" "${registry_out#Component registry ($registry): }" ;;
    *) row FAIL "Component registry" "$(printf '%s\n' "$registry_out" | grep '^- ' | head -3 | sed 's/^- //' | paste -sd ';' - | sed 's/;/; /g'). Fix: update $registry" ;;
  esac
fi

# ---------- last verification ----------

if [ "$in_git" = true ] && [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  fp="$(sh_identity)"
  if [ "$fp" = "$(cat "$state/passed" 2>/dev/null)" ]; then
    row PASS "Last verification" "the verify command passed on the current code"
  elif [ "$fp" = "$(head -1 "$state/checked" 2>/dev/null)" ]; then
    row WARN "Last verification" "only $(sed -n 2p "$state/checked") passed on the current code; build and tests were not run, because the verify command is disabled or not approved"
  elif [ "$fp" = "$(cat "$state/failed" 2>/dev/null)" ]; then
    row WARN "Last verification" "failed on the current code and has not passed since. Fix: ask Claude to fix it, or run $command_line"
  else
    row INFO "Last verification" "no result for the current code: the check runs at the end of the next turn that changes build inputs"
  fi
  if [ "$lint_blocking" = true ] && [ -s "$state/lint-pending" ]; then
    row WARN "Lint pending" "failed SwiftLint at the last check: $(head -5 "$state/lint-pending" | paste -sd, - | sed 's/,/, /g')"
  fi
fi

[ "$fails" -eq 0 ]
