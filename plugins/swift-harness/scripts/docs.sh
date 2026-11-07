#!/bin/bash
# Docs references (#70): check that the project docs point at things that exist.
#
# Reads Markdown files as text and tests paths for existence; runs no code from the
# repository, so the hooks call it without the verify approval. Fenced code blocks and HTML
# comments are skipped, and so is anything with a {{placeholder}}.
#
# Checked in the docs (docs.paths: CLAUDE.md, AGENTS.md and docs/ by default):
# - a Markdown link to a file that does not exist, or to a heading the file does not have;
# - a repository path in backticks that does not exist: two or more parts, ending with a file
#   extension or a slash (`Sources/App/Player.swift`, `docs/adr/`), whose first folder exists
#   (so a path inside a module, on the user's disk or in another repository is left alone).
#   Not in records of the past (docs.history: docs/adr, docs/audit, docs/archive,
#   docs/HISTORY.md and CHANGELOG.md by default), not for files git ignores, and
#   not under folders the harness creates later (docs.ignore: the snapshots folder and
#   docs/audit by default);
# - a section named in quotes beside a doc, `"Presented UI" in docs/LAYOUT_CONTRACT.md` or
#   `docs/LAYOUT_CONTRACT.md, "Presented UI"` (path in backticks or a link), that the doc does
#   not have: as a heading (or the start of one, before a parenthesis, comma or colon), a bold
#   label leading a line or list item, or the first cell of a table row;
# - the files read into every session: CLAUDE.md, .claude/CLAUDE.md, CLAUDE.local.md and the
#   files they import with @path, recursively. An import of a missing file is reported, and
#   their total size must stay within docs.budget bytes (20000 by default, about 5000 tokens).
#
# Usage: docs.sh check   <project root>
#          Exit 0: no problem. Exit 1: problems, one "- <file>:<line>: <message>" per line.
#        docs.sh summary <project root>    one line for doctor.sh

set -u

mode="${1:-}"
root="${2:?usage: docs.sh check|summary <project root>}"
root="${root%/}"
config="$root/.claude/swift-harness.json"

cfg() { # $1 jq path, $2 default
  local v
  v="$(jq -r "$1 | if . == null then empty else . end" "$config" 2>/dev/null)"
  printf '%s' "${v:-$2}"
}
cfg_list() { # $1 jq path, $2 default lines; an empty list in the config means none
  local v
  if jq -e "$1 | type == \"array\"" "$config" >/dev/null 2>&1; then
    v="$(jq -r "$1[]" "$config" 2>/dev/null)"
  else
    v="$2"
  fi
  printf '%s\n' "$v" | sed -e 's#^\./##' -e 's#/$##' | grep -v '^$'
}

budget="$(cfg '.docs.budget' '20000')"
case "$budget" in '' | *[!0-9]*) budget=20000 ;; esac
history="$(cfg_list '.docs.history' 'docs/adr
docs/audit
docs/archive
docs/HISTORY.md
CHANGELOG.md')"
# Folders the harness creates later (approved snapshots, audits): named before they exist.
snapshots="$(cfg '.snapshots.path' 'snapshots')"
snapshots="${snapshots#./}"
later="$(cfg_list '.docs.ignore' "${snapshots%/}
docs/audit")"

tmp="$(mktemp -d -t swift-harness-docs.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT

# The Markdown files to check, relative to the root.
cfg_list '.docs.paths' 'CLAUDE.md
AGENTS.md
docs' | while IFS= read -r p; do
  if [ -f "$root/$p" ]; then
    printf '%s\n' "$p"
  elif [ -d "$root/$p" ]; then
    (cd "$root" && find "$p" -type f -name '*.md' -not -path '*/.build/*' -not -path '*/node_modules/*' -not -path '*DerivedData/*')
  fi
done | LC_ALL=C sort -u >"$tmp/docs"

# One reference per line, tab-separated: <kind> <file> <line> <target> [<section>]
#   L a link target as written   P a path in backticks   S a section beside a doc   I an @import
# $1: history prefixes, one per line; files: absolute paths.
scan() {
  local hist
  hist="$(printf '%s' "$1" | tr '\n' '|')"
  shift
  [ $# -gt 0 ] || return 0
  awk -v root="$root" -v hist="$hist" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function blank(n,   s) { s = ""; while (n-- > 0) s = s " "; return s }
    function emit(kind, a, b) { printf "%s\t%s\t%d\t%s%s\n", kind, rel, FNR, a, (b == "" ? "" : "\t" b) }
    function path(t) {
      t = trim(t); sub(/^@/, "", t); sub(/^\.\//, "", t)
      if (t ~ /[ \t*?<>{}$|;&()\047"=\[\]\\]/) return
      if (t ~ /^(-|~|\/|[A-Za-z][A-Za-z0-9+.-]*:)/) return
      if (t ~ /^[A-Za-z0-9-]+\.(com|org|net|io|ai|dev|app)\//) return
      if (t !~ /\//) return
      sub(/#L?[0-9].*$/, "", t); sub(/:[0-9]+(-[0-9]+)?$/, "", t)
      if (t !~ /[^\/]\/[^\/]/) return
      if (t ~ /\/$/ || t ~ /[^\/.]\.[A-Za-z0-9]+$/) emit("P", t)
    }
    # The doc a reference names: `x.md` or [..](x.md), with no anchor.
    function docref(s) {
      if (s ~ /^`/) { s = substr(s, 2); sub(/`.*$/, "", s); return s }
      sub(/^[^(]*\(/, "", s); sub(/\).*$/, "", s); return s
    }
    FNR == 1 {
      rel = substr(FILENAME, length(root) + 2)
      infence = 0; incomment = 0; past = 0
      n = split(hist, h, "|")
      for (i = 1; i <= n; i++) if (h[i] != "" && (rel == h[i] || index(rel, h[i] "/") == 1)) past = 1
    }
    /^[ \t]*(```|~~~)/ { infence = !infence; next }
    infence { next }
    incomment { if (index($0, "-->")) incomment = 0; next }
    {
      line = $0
      gsub(/\{\{[^}]*\}\}/, "", line)
      while ((c = index(line, "<!--")) > 0) {
        e = index(substr(line, c), "-->")
        if (e == 0) { line = substr(line, 1, c - 1); incomment = 1; break }
        line = substr(line, 1, c - 1) blank(e + 2) substr(line, c + e + 2)
      }
      gsub(/“|”/, "\"", line)

      # Code spans: paths in them are references; links in them are code.
      rest = line; nocode = ""
      while (match(rest, /`[^`]+`/)) {
        if (!past) path(substr(rest, RSTART + 1, RLENGTH - 2))
        nocode = nocode substr(rest, 1, RSTART - 1) blank(RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
      }
      nocode = nocode rest

      s = nocode
      while (match(s, /\]\([^)]*\)/)) { emit("L", substr(s, RSTART + 2, RLENGTH - 3)); s = substr(s, RSTART + RLENGTH) }
      if (match(nocode, /^[ ]*\[[^]]+\]:[ \t]+[^ \t]+/)) { d = substr(nocode, RSTART, RLENGTH); sub(/^[^]]*\]:[ \t]+/, "", d); emit("L", d) }

      s = " " nocode
      while (match(s, /[ \t(]@[A-Za-z0-9._~\/-]+/)) {
        t = substr(s, RSTART + 2, RLENGTH - 2); sub(/[.,;:]+$/, "", t)
        if (t ~ /\// || t ~ /\.md$/) emit("I", t)
        s = substr(s, RSTART + RLENGTH)
      }

      if (past) next
      ref = "(`[^`]*\\.md`|\\[[^]]*\\]\\([^)#]*\\.md\\))"
      s = line
      while (match(s, "\"[^\"]+\" (section )?(in|of) (the )?" ref)) {
        m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        name = substr(m, 2); sub(/".*$/, "", name)
        r = substr(m, index(substr(m, 2), "\"") + 2); sub(/^[^`[]*/, "", r)
        emit("S", docref(r), name)
      }
      s = line
      while (match(s, ref "[,:]? (section |under )?\"[^\"]+\"")) {
        m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        name = m; sub(/"$/, "", name); sub(/^.*"/, "", name)
        emit("S", docref(m), name)
      }
    }
  ' "$@"
}

# "A <anchor>" and "N <normalized heading>" lines for a Markdown file, cached.
headings() { # $1 absolute path
  local key
  key="$tmp/h.$(printf '%s' "$1" | shasum | cut -c1-16)"
  [ -f "$key" ] || awk '
    function norm(s) { gsub(/[`*]/, "", s); s = tolower(s); gsub(/[ \t]+/, " ", s); gsub(/^ | $/, "", s); sub(/[.:]$/, "", s); return s }
    # A name, without a parenthesis at its end, and its lead before a parenthesis, comma or colon.
    function names(t,   n, m) {
      n = norm(t); print "N\t" n
      m = n; sub(/ \([^()]*\)$/, "", m); if (m != n) print "N\t" m
      if (match(n, / \(|, |: | - | — /)) print "N\t" substr(n, 1, RSTART - 1)
    }
    /^[ \t]*(```|~~~)/ { infence = !infence; next }
    infence { next }
    /^#{1,6}[ \t]/ {
      t = $0; sub(/^#+[ \t]+/, "", t); sub(/[ \t]+#+[ \t]*$/, "", t)
      while (match(t, /\[[^]]*\]\([^)]*\)/)) { l = substr(t, RSTART + 1); sub(/\].*$/, "", l); t = substr(t, 1, RSTART - 1) l substr(t, RSTART + RLENGTH) }
      names(t)
      a = tolower(t); gsub(/[][!"#$%&\047()*+,.\/:;<=>?@\\^`{|}~]/, "", a); gsub(/ /, "-", a)
      if (a in seen) { seen[a]++; a = a "-" seen[a] } else seen[a] = 0
      print "A\t" a
    }
    # Other names a doc gives a part of itself: a bold label leading a line or a list item,
    # and the first cell of a table row.
    /^[ \t]*([-*+][ \t]+)?\*\*[^*]+\*\*/ { l = $0; sub(/^[^*]*\*\*/, "", l); sub(/\*\*.*$/, "", l); names(l) }
    /^[ \t]*\|/ && !/^[ \t]*\|[ \t:-]*\|/ { l = $0; sub(/^[ \t]*\|/, "", l); sub(/\|.*$/, "", l); names(l) }
    { s = $0; while (match(s, /<a (id|name)="[^"]+"/)) { m = substr(s, RSTART, RLENGTH); sub(/^[^"]*"/, "", m); sub(/"$/, "", m); print "A\t" m; s = substr(s, RSTART + RLENGTH) } }
  ' "$1" >"$key" 2>/dev/null
  cat "$key"
}

has_heading() { # $1 absolute path, $2 kind (A|N), $3 value
  headings "$1" | grep -qxF "$2	$3"
}

ignored() { # $1 path relative to the root
  local p
  case "$1" in .build/* | */.build/* | *DerivedData/*) return 0 ;; esac
  while IFS= read -r p; do
    case "${1%/}/" in "$p"/*) return 0 ;; esac
  done <<EOF2
$later
EOF2
  git -C "$root" check-ignore -q -- "$1" 2>/dev/null
}

# The file a reference resolves to, printed relative to the root when it exists: first from
# the root, then from the doc's folder. Returns 1 when neither exists.
resolve() { # $1 doc (relative), $2 target
  local dir
  dir="$(dirname "$1")"
  if [ -e "$root/$2" ]; then
    printf '%s' "$2"
  elif [ "$dir" != . ] && [ -e "$root/$dir/$2" ]; then
    printf '%s' "$dir/$2"
  else
    return 1
  fi
}

# Normalized like the headings, for sections.
norm() { printf '%s' "$1" | tr -d '`*' | tr '[:upper:]' '[:lower:]' | tr -s ' \t' '  ' | sed 's/^ //; s/ $//'; }

problems="$tmp/problems"
: >"$problems"
refs=0
files="$(wc -l <"$tmp/docs" | tr -d ' ')"

if [ -s "$tmp/docs" ]; then
  set --
  while IFS= read -r f; do set -- "$@" "$root/$f"; done <"$tmp/docs"
  scan "$history" "$@" >"$tmp/refs"
  while IFS="$(printf '\t')" read -r kind doc line target section; do
    case "$kind" in
      L)
        refs=$((refs + 1))
        t="$target"
        t="${t#<}"; t="${t%%>*}"; t="${t%% \"*}"; t="${t%% \'*}"
        case "$t" in '' | *://* | mailto:* | tel:* | data:*) continue ;; esac
        case "$t" in [A-Za-z]*:*) case "${t%%:*}" in *[!A-Za-z0-9+.-]*) ;; *) continue ;; esac ;; esac
        p="${t%%#*}"
        anchor=""
        case "$t" in *'#'*) anchor="${t#*#}" ;; esac
        p="$(printf '%s' "$p" | sed 's/%20/ /g')"
        if [ -z "$p" ]; then
          resolved="$doc"
        else
          case "$p" in
            /*) resolved="${p#/}" ;;
            *) d="$(dirname "$doc")"; [ "$d" = . ] && resolved="$p" || resolved="$d/$p" ;;
          esac
          # Collapse "a/../" segments.
          while :; do
            n="$(printf '%s' "$resolved" | sed -E 's#(^|/)[^/]+/\.\./#\1#; s#^\./##; s#/\./#/#g')"
            [ "$n" = "$resolved" ] && break
            resolved="$n"
          done
          if [ ! -e "$root/$resolved" ]; then
            ignored "$resolved" || printf -- '- %s:%s: link to %s, which does not exist\n' "$doc" "$line" "$p" >>"$problems"
            continue
          fi
        fi
        if [ -n "$anchor" ] && [ -f "$root/$resolved" ]; then
          case "$resolved" in
            *.md | *.markdown)
              a="$(printf '%s' "$anchor" | tr '[:upper:]' '[:lower:]')"
              has_heading "$root/$resolved" A "$a" ||
                printf -- '- %s:%s: link to #%s, which is not a heading of %s\n' "$doc" "$line" "$anchor" "$resolved" >>"$problems"
              ;;
          esac
        fi
        ;;
      P)
        # A path whose first folder is nowhere in the project is not a project path (a path
        # inside a module, on the user's disk, or in another repository).
        top="${target%%/*}"
        d="$(dirname "$doc")"
        [ -e "$root/$top" ] || { [ "$d" != . ] && [ -e "$root/$d/$top" ]; } || continue
        refs=$((refs + 1))
        resolve "$doc" "$target" >/dev/null && continue
        ignored "$target" && continue
        printf -- '- %s:%s: `%s` does not exist\n' "$doc" "$line" "$target" >>"$problems"
        ;;
      S)
        refs=$((refs + 1))
        r="$(resolve "$doc" "$target")" || continue # the path itself is reported above
        [ -f "$root/$r" ] || continue
        has_heading "$root/$r" N "$(norm "$section")" ||
          printf -- '- %s:%s: "%s" is not a section of %s\n' "$doc" "$line" "$section" "$r" >>"$problems"
        ;;
    esac
  done <"$tmp/refs"
fi

# Files read into every session: the CLAUDE.md files and their imports, breadth first.
: >"$tmp/session"
for f in CLAUDE.md .claude/CLAUDE.md CLAUDE.local.md; do
  [ -f "$root/$f" ] && printf '%s\n' "$f" >>"$tmp/session"
done
depth=0
: >"$tmp/seen"
cp "$tmp/session" "$tmp/queue"
while [ -s "$tmp/queue" ] && [ "$depth" -le 5 ]; do
  cat "$tmp/queue" >>"$tmp/seen"
  : >"$tmp/next"
  while IFS= read -r f; do
    scan "" "$root/$f" | awk -F'\t' '$1 == "I"' | while IFS="$(printf '\t')" read -r _ doc line target _; do
      case "$target" in '~'*) continue ;; esac
      d="$(dirname "$doc")"
      [ "$d" = . ] && p="$target" || p="$d/$target"
      if [ -f "$root/$p" ]; then
        grep -qxF "$p" "$tmp/seen" "$tmp/next" 2>/dev/null || printf '%s\n' "$p" >>"$tmp/next"
      elif [ -f "$root/$target" ]; then
        grep -qxF "$target" "$tmp/seen" "$tmp/next" 2>/dev/null || printf '%s\n' "$target" >>"$tmp/next"
      else
        printf -- '- %s:%s: @%s imports a file that does not exist\n' "$doc" "$line" "$target" >>"$problems"
      fi
    done
  done <"$tmp/queue"
  mv "$tmp/next" "$tmp/queue"
  depth=$((depth + 1))
done
total=0
sizes=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  b="$(wc -c <"$root/$f" | tr -d ' ')"
  total=$((total + b))
  sizes="${sizes:+$sizes, }$f $b"
done <"$tmp/seen"
first="$(head -1 "$tmp/seen")"
if [ "$total" -gt "$budget" ]; then
  printf -- '- %s:1: the files read into every session are %s bytes (about %s tokens), over the budget of %s (docs.budget): %s\n' \
    "$first" "$total" "$((total / 4))" "$budget" "$sizes" >>"$problems"
fi

case "$mode" in
  check)
    [ -s "$problems" ] || exit 0
    printf 'Docs references (%s docs):\n' "$files"
    LC_ALL=C sort -u "$problems" | sort -t: -k1,1 -k2,2n
    exit 1
    ;;
  summary)
    session="no CLAUDE.md"
    [ -n "$first" ] && session="every session reads $total of $budget bytes (about $((total / 4)) tokens)"
    printf '%s docs, %s references; %s' "$files" "$refs" "$session"
    ;;
  *)
    echo "usage: docs.sh check|summary <project root>" >&2
    exit 2
    ;;
esac
