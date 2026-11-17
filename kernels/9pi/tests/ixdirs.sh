#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The top mkfile's order: a directory whose mkfile takes another's
# objects ($B/dir/Unit.$O) is built after it. The libraries and the
# assembler are built before every program; for another directory the
# top mkfile must say so (linker/tools.dir:V: linker.dir). A tree built
# before hides a missing line, its _mk has the objects: make self-mix
# in GitHub's fresh tree stopped on languages/dotnet, built before
# the assembler (2026-11-03). Static, a second.
# usage: kernels/9pi/tests/ixdirs.sh
cd "$(dirname "$0")/../../.."
# (a list of the mkfile: its lines up to one that does not end with \)
list() { sed -n "/^$1=/,/[^\\\\]\$/p" mkfile | sed "s/^$1=//; s/\\\\\$//; s/\\\${[^}]*}//g"; }
first=" $(list LIBS | tr '\n' ' ') assembler "
dirs=$(list BOTH; list LINUX; list PLAN9)
[ -n "$dirs" ] || { echo "FAIL no BOTH, LINUX or PLAN9 read in the top mkfile"; exit 1; }
bad=0
for d in $dirs; do
  for u in $(grep -ho '\$B/[A-Za-z0-9_/]*/[A-Za-z0-9_]*\.\$O' $d/mkfile | sed 's|^\$B/||; s|/[^/]*$||' | sort -u); do
    [ "$u" = "$d" ] && continue
    case "$first" in *" $u "*) continue;; esac
    grep -q "^[^#]*$d\.dir.*:V:.* $u\.dir" mkfile || { echo "FAIL $d takes $u's objects, and the top mkfile does not build it after: $d.dir:V: $u.dir"; bad=1; }
  done
done
[ $bad = 0 ] && echo "ok the top mkfile's order: $(echo $dirs | wc -w | tr -d " ") directories, each after those whose objects it takes"
exit $bad
