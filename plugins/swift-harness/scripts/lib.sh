#!/bin/bash
# Shared helpers for swift-harness hooks. Sourced, not executed.
# Every hook is a no-op unless the project contains .claude/swift-harness.json.

# GUI-launched sessions often miss Homebrew on PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

SH_INPUT="$(cat)"

sh_has_jq() { command -v jq >/dev/null 2>&1; }

# Read a field from the hook input JSON. Empty string when missing.
sh_in() { printf '%s' "$SH_INPUT" | jq -r "$1 // empty" 2>/dev/null; }

# Project root: git top level of the hook's cwd (follows worktrees), else CLAUDE_PROJECT_DIR.
sh_root() {
  local cwd
  cwd="$(sh_in '.cwd')"
  [ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "${CLAUDE_PROJECT_DIR:-$cwd}"
}

# Read a value from the project config, with a default.
sh_cfg() {
  local value
  value="$(jq -r "$1 | if . == null then empty else . end" "$SH_CONFIG" 2>/dev/null)"
  [ -n "$value" ] && printf '%s' "$value" || printf '%s' "$2"
}

# Per-project state directory (survives plugin updates).
sh_state_dir() {
  local base key
  base="${CLAUDE_PLUGIN_DATA:-$HOME/.cache/swift-harness}"
  key="$(printf '%s' "$SH_ROOT" | shasum | cut -c1-16)"
  mkdir -p "$base/state/$key" && printf '%s' "$base/state/$key"
}

# Fingerprint of the code state: HEAD plus uncommitted changes to Swift sources,
# package manifests, asset catalogs and the project file.
sh_fingerprint() {
  {
    git -C "$SH_ROOT" rev-parse HEAD 2>/dev/null
    git -C "$SH_ROOT" diff HEAD -- '*.swift' '*Package.swift' '*Package.resolved' '*.xcassets/*' '*.pbxproj' 2>/dev/null
    git -C "$SH_ROOT" ls-files --others --exclude-standard -- '*.swift' 2>/dev/null |
      while IFS= read -r f; do shasum "$SH_ROOT/$f" 2>/dev/null; done
  } | shasum | cut -d' ' -f1
}

# Initialise SH_ROOT and SH_CONFIG. Returns 1 when the project has not opted in.
sh_init() {
  sh_has_jq || return 1
  SH_ROOT="$(sh_root)"
  SH_CONFIG="$SH_ROOT/.claude/swift-harness.json"
  [ -f "$SH_CONFIG" ]
}
