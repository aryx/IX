#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_core/libc/ against goken's libc, its origin (libc/README.md), as a
# diff but shorter: each file changed with its lines added and removed,
# each new one, and by directory how many of goken's are not taken;
# then the counts. -v: the diffs, and the names not taken.
# usage: diff_goken_libc.sh [-v]      (goken: ~/goken, or GOKEN=...)

D=$(cd "$(dirname "$0")" && pwd)
verbose=; [ "${1:-}" = -v ] && verbose=1
G=${GOKEN:-$HOME/goken}

same=0; changed=0; own=0
against() {   # ours (from lib_core/), its origin
  if [ ! -f "$2" ]; then own=$((own + 1)); echo "new:      $1"; return; fi
  if cmp -s "$D/$1" "$2"; then same=$((same + 1)); return; fi
  changed=$((changed + 1))
  echo "changed:  $1  (+$(diff "$2" "$D/$1" | grep -c "^>") -$(diff "$2" "$D/$1" | grep -c "^<"))"
  [ -n "$verbose" ] && diff -u "$2" "$D/$1"
}

# ours is goken's lib_core/libc/, and under include/ its include/ (os/posix is its os/unix)
origin() { case $1 in include/os/posix/*) echo $G/include/os/unix/${1##*/};; include/*) echo $G/$1;; *) echo $G/lib_core/libc/$1;; esac; }
for f in $(cd $D/libc && find . -type f -not -name LICENSE -not -name README.md | sed 's|^\./||' | sort); do against libc/$f $(origin $f); done
# goken's sources that are not here, by directory
not=0
for d in $(cd $G/lib_core/libc && find . -name '*.[chs]' | sed 's|^\./||' | xargs -n1 dirname | sort -u); do
  missing=$(cd $G/lib_core/libc && ls $d/*.[chs] 2>/dev/null | while read f; do [ -f $D/libc/$f ] || echo $(basename $f); done)
  n=$(echo $missing | wc -w); not=$((not + n))
  [ $n -gt 0 ] && echo "not taken: $d/: $n files$([ -n "$verbose" ] && echo " ($(echo $missing))")"
done
echo "$same files as goken's, $changed changed, $own new; $not of goken's libc not taken (its headers apart)"
