#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Checks that an edit changed only comments. For each .ml or .mli file
# that differs from a git revision, it parses the old and the new file
# and compares their parse trees, with the source locations taken out.
# Comments are not in a parse tree, so the two trees are the same when
# only comments changed. A doc comment, (** ... *), is in the tree as
# an attribute, so a change to one is reported.
#
# It is useful after a pass over the comments, such as a rewrite of the
# header comments, where a stray edit to the code would be hard to see
# in a long diff.
#
# Usage: scripts/comments_only.sh [revision] [path...]
#   revision: what to compare with, HEAD when not given
#   path: the files or directories to look at, all of them when not given
# It prints "same" or "CODE" and the file's name, one line for each
# file, and exits with 1 when a file's code changed.

rev=${1:-HEAD}
[ $# -gt 0 ] && shift
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
for f in $(git diff --name-only "$rev" -- "${@:-.}" | grep -E '\.mli?$'); do
  [ -f "$f" ] || continue
  ext=${f##*.}
  for side in old new; do
    if [ $side = old ]; then
      git show "$rev:$f" > "$tmp/x.$ext" 2>/dev/null || : > "$tmp/x.$ext"
    else
      cp "$f" "$tmp/x.$ext"
    fi
    (cd "$tmp" && ocamlfind ocamlc -stop-after parsing -dparsetree -c "x.$ext" 2>&1) \
      | sed -E 's/\(x\.mli?\[[^)]*\)//g' > "$tmp/$side.txt"
  done
  if cmp -s "$tmp/old.txt" "$tmp/new.txt"; then
    echo "same  $f"
  else
    echo "CODE  $f"
    status=1
  fi
done
exit $status
