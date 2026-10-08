#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The differential tests of mini-hoc: the same programs through mini-hoc
# and hoc, principia's as goken builds it for this machine (the same
# sources; 9base's hoc is a later one, which prints 17 digits), like
# editors/ed/'s.
#
#   differential.sh record [case.hoc ...]  write case.out from goken's hoc
#   differential.sh check  [case.hoc ...]  compare mini-hoc with case.out
#                                          (or case.mini.out, where mini-hoc
#                                          differs from hoc on purpose)
#   differential.sh live   [case.hoc ...]  compare both, live
#
# A case is case.hoc, run three ways: as the standard input from the
# file, through a pipe, and as an argument (an error then names it);
# and if there is a case.args, with those arguments instead (in the
# corpus's directory, case.hoc the standard input). Recorded are stdout
# and stderr and the exit status of each. Not in the corpus: log(0),
# which is the C library's (an infinity for this machine's, a NaN for
# Plan 9's and so for ix's).

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
CORPUS=$ROOT/utilities/calc/hoc/tests/corpus
MINIHOC=${MINIHOC:-$ROOT/_build/default/utilities/calc/hoc/Main.exe}
HOC=${HOC:-${GOKEN:-$HOME/goken}/ROOT/arch/boot-gcc/bin/hoc}

mode=${1:-check}
[ $# -gt 0 ] && shift
cases=${*:-$CORPUS/*.hoc}

run_case() {
  prog=$1 file=$(basename "$2")
  (
    cd "$(dirname "$2")" || exit 1
    if [ -f "${file%.hoc}.args" ]; then
      eval "timeout -s KILL 10 $prog $(cat "${file%.hoc}.args")" < $file 2>&1; echo "[exit $?]"
    else
      timeout -s KILL 10 $prog < $file 2>&1; echo "[exit $?]"
      cat $file | timeout -s KILL 10 $prog 2>&1; echo "[exit $?]"
      timeout -s KILL 10 $prog $file 2>&1 < /dev/null; echo "[exit $?]"
    fi
  # (hoc names the temporary file it makes of -e's text)
  ) | sed -e "s|$prog|hoc|g" -e 's|in /tmp/hoc[A-Za-z0-9]*|in -e|'
}

status=0
for case in $cases; do
  name=$(basename "$case" .hoc)
  out=${case%.hoc}.out
  case $mode in
    record) run_case "$HOC" "$case" > "$out"; echo "recorded $name";;
    check)
      [ -f "${case%.hoc}.mini.out" ] && out=${case%.hoc}.mini.out
      if run_case "$MINIHOC" "$case" | diff -u "$out" - > /tmp/$$.diff; then echo "ok   $name"
      else echo "FAIL $name"; cat /tmp/$$.diff; status=1; fi;;
    live)
      [ -x "$HOC" ] || { echo "skipped: no hoc at $HOC"; exit 0; }
      if [ -f "${case%.hoc}.mini.out" ]; then echo "apart $name"; continue; fi
      run_case "$HOC" "$case" > /tmp/$$.hoc
      run_case "$MINIHOC" "$case" > /tmp/$$.mini
      if cmp -s /tmp/$$.hoc /tmp/$$.mini; then echo "same  $name"
      else echo "DIFF  $name"; diff /tmp/$$.hoc /tmp/$$.mini | head -20; status=1; fi;;
  esac
done
rm -f /tmp/$$.*
exit $status
