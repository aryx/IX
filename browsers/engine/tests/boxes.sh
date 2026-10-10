#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A page's boxes (Boxes.ml) against pages/*.expected: each page read,
# styled and laid out 400 wide, its boxes printed. The expected files
# are OCaml's build's; mini-ml's must say the same (the same floats,
# to a tenth).
#
# usage: boxes.sh [-u] [dir]
#   -u   the expected files written from this run
#   dir  where boxes is (mini-mk's: _mk/7/browsers/engine/tests); default: dune's

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../../.. && pwd)
update=; [ "${1:-}" = -u ] && { update=1; shift; }
if [ $# -ge 1 ]; then BOXES=$(realpath $1)/boxes; else BOXES=$ROOT/_build/default/browsers/engine/tests/Boxes.exe; fi
fail=0
for page in $HERE/pages/*.html; do
  if [ -n "$update" ]; then $BOXES -w 400 $page > ${page%.html}.expected 2> /dev/null; continue; fi
  $BOXES -w 400 $page 2> /dev/null | cmp -s - ${page%.html}.expected ||
    { echo "FAIL $(basename $page): $($BOXES -w 400 $page 2> /dev/null | diff - ${page%.html}.expected | head -4)"; fail=1; }
done
[ -n "$update" ] && { echo "expected files written"; exit 0; }
[ $fail = 0 ] && echo "ok: the pages' boxes"
exit $fail
