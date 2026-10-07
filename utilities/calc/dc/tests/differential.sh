#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The differential tests of mini-dc: the same commands through mini-dc
# and principia's dc (reference.sh builds it), like editor/'s.
#
#   differential.sh record [case.dc ...]  write case.out from principia's dc
#   differential.sh check  [case.dc ...]  compare mini-dc with case.out
#   differential.sh live   [case.dc ...]  compare both, live
#
# A case is case.dc, the commands, given as the standard input and then
# as the file of the command line. Recorded are stdout and stderr and
# the exit status of each.

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
CORPUS=$ROOT/utilities/calc/dc/tests/corpus
MINIDC=${MINIDC:-$ROOT/_build/default/utilities/calc/dc/Main.exe}
DC=${DC:-/tmp/ix-dc-reference/dc}

mode=${1:-check}
[ $# -gt 0 ] && shift
cases=${*:-$CORPUS/*.dc}

if [ $mode != check ] && [ ! -x $DC ]; then
  $ROOT/utilities/calc/dc/tests/reference.sh $(dirname $DC) > /dev/null || { echo "skipped: no dc at $DC"; exit 0; }
fi

run_case() {
  prog=$1 file=$(basename "$2")
  (
    cd "$(dirname "$2")" || exit 1
    timeout -s KILL 10 $prog < $file 2>&1 | cat -v; echo "[exit $?]"
    timeout -s KILL 10 $prog $file < /dev/null 2>&1 | cat -v; echo "[exit $?]"
  ) | sed -e "s|$prog|dc|g"
}

status=0
for case in $cases; do
  name=$(basename "$case" .dc)
  out=${case%.dc}.out
  case $mode in
    record) run_case "$DC" "$case" > "$out"; echo "recorded $name";;
    check)
      if run_case "$MINIDC" "$case" | diff -u "$out" - > /tmp/$$.diff; then echo "ok   $name"
      else echo "FAIL $name"; cat /tmp/$$.diff; status=1; fi;;
    live)
      run_case "$DC" "$case" > /tmp/$$.dc
      run_case "$MINIDC" "$case" > /tmp/$$.mini
      if cmp -s /tmp/$$.dc /tmp/$$.mini; then echo "same  $name"
      else echo "DIFF  $name"; diff /tmp/$$.dc /tmp/$$.mini | head -20; status=1; fi;;
  esac
done
rm -f /tmp/$$.*
exit $status
