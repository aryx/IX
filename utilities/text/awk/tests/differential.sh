#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The differential tests of mini-awk: the same programs through mini-awk
# and principia's awk (reference.sh builds it), like editors/ed/'s.
#
#   differential.sh record [case.awk ...]  write case.out from principia's awk
#   differential.sh check  [case.awk ...]  compare mini-awk with case.out
#                                          (or case.mini.out, where mini-awk
#                                          differs from awk on purpose)
#   differential.sh live   [case.awk ...]  compare both, live
#
# A case is case.awk, the program (run with -f), and case.in, its
# standard input if there is one; or a case.args, awk's arguments, for
# what the command line does (run in the corpus's directory). Recorded
# are stdout and stderr and the exit status. Of an error's text, what
# mini-awk does not say as awk is taken out: the line of an error
# while the program runs, and what awk says after a first error in the
# program's text (CLI.mli).

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
CORPUS=$ROOT/utilities/text/awk/tests/corpus
MINIAWK=${MINIAWK:-$ROOT/_build/default/utilities/text/awk/Main.exe}
AWK=${AWK:-/tmp/ix-awk-reference/awk}

mode=${1:-check}
[ $# -gt 0 ] && shift
cases=${*:-$CORPUS/*.awk}

if [ $mode != check ] && [ ! -x $AWK ]; then
  $ROOT/utilities/text/awk/tests/reference.sh $(dirname $AWK) > /dev/null || { echo "skipped: no awk at $AWK"; exit 0; }
fi

run_case() {
  prog=$1 file=$(basename "$2")
  (
    cd "$(dirname "$2")" || exit 1
    in=/dev/null; [ -f "${file%.awk}.in" ] && in=${file%.awk}.in
    if [ -f "${file%.awk}.args" ]; then
      eval "timeout -s KILL 10 $prog $(cat "${file%.awk}.args")" < $in 2>&1; echo "[exit $?]"
    else
      timeout -s KILL 10 $prog -f $file < $in 2>&1; echo "[exit $?]"
    fi
  ) | sed -e "s|$prog|awk|g" -e 's/^ source line [0-9]*$/ source line N/' \
    | awk '/^awk: .* at (line [0-9]+|[^ ]+:[0-9]+)( in function [^ ]+)?$/ { if (seen++) next } { print }'
}

status=0
for case in $cases; do
  name=$(basename "$case" .awk)
  out=${case%.awk}.out
  case $mode in
    record) run_case "$AWK" "$case" > "$out"; echo "recorded $name";;
    check)
      [ -f "${case%.awk}.mini.out" ] && out=${case%.awk}.mini.out
      if run_case "$MINIAWK" "$case" | diff -u "$out" - > /tmp/$$.diff; then echo "ok   $name"
      else echo "FAIL $name"; cat /tmp/$$.diff; status=1; fi;;
    live)
      if [ -f "${case%.awk}.mini.out" ]; then echo "apart $name"; continue; fi
      run_case "$AWK" "$case" > /tmp/$$.awk
      run_case "$MINIAWK" "$case" > /tmp/$$.mini
      if cmp -s /tmp/$$.awk /tmp/$$.mini; then echo "same  $name"
      else echo "DIFF  $name"; diff /tmp/$$.awk /tmp/$$.mini | head -20; status=1; fi;;
  esac
done
rm -f /tmp/$$.*
exit $status
