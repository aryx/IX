#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The differential tests of mini-bc, like editors/ed/'s. There is no bc to
# compare with as it is: principia's bc.y refuses if, while and for
# (bugs/goken.md), and 9base's bc, which is Plan 9's, dies on a string
# and pipes to a dc of 64-bit longs. So: what mini-bc compiles (-c)
# against what 9base's bc compiles, and what it prints against that
# through principia's dc (../../dc/tests/reference.sh builds it).
#
#   differential.sh record [case.bc ...]  write case.out from 9base's bc and principia's dc
#   differential.sh check  [case.bc ...]  compare mini-bc with case.out
#                                         (or case.mini.out, where mini-bc
#                                         differs on purpose: a string)
#   differential.sh live   [case.bc ...]  compare both, live
#
# A case is case.bc; with a case.args, bc's flags (-l: the reference is
# given principia's bclib as its first file). Recorded: the dc commands
# compiled, then what running them prints.

ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
CORPUS=$ROOT/utilities/calc/bc/tests/corpus
MINIBC=${MINIBC:-$ROOT/_build/default/utilities/calc/bc/Main.exe}
BC=${BC:-/usr/lib/plan9/bin/bc}
DC=${DC:-/tmp/ix-dc-reference/dc}
BCLIB=${PRINCIPIA:-$HOME/principia}/utilities/calc/misc/bclib

mode=${1:-check}
[ $# -gt 0 ] && shift
cases=${*:-$CORPUS/*.bc}

if [ $mode != check ]; then
  [ -x $BC ] || { echo "skipped: no bc at $BC"; exit 0; }
  [ -x $DC ] || $ROOT/utilities/calc/dc/tests/reference.sh $(dirname $DC) > /dev/null || { echo "skipped: no dc at $DC"; exit 0; }
fi

# (9base's bc says an error as [message:line, file]; principia's, and
# mini-bc, as [file:line message]; the library's name is its file's)
theirs() {
  file=$(basename "$1"); args=; lib=
  [ -f "${1%.bc}.args" ] && args=$(cat "${1%.bc}.args")
  case "$args" in *-l*) lib=$BCLIB; args=$(echo "$args" | sed 's/-l//');; esac
  (
    cd "$(dirname "$1")" || exit 1
    timeout -s KILL 10 $BC -c $args $lib $file < /dev/null 2>&1 | sed -e 's/c\[\([^:]*\):\([0-9]*\), \([^]]*\)\]pc/c[\3:\2 \1]pc/' -e "s|$BCLIB|/sys/lib/bclib|" > /tmp/$$.code
    cat /tmp/$$.code; echo; echo "[run]"
    timeout -s KILL 20 $DC < /tmp/$$.code 2>&1
  )
}
ours() {
  file=$(basename "$1"); args=
  [ -f "${1%.bc}.args" ] && args=$(cat "${1%.bc}.args")
  (
    cd "$(dirname "$1")" || exit 1
    timeout -s KILL 10 $MINIBC -c $args $file < /dev/null 2>&1; echo; echo "[run]"
    timeout -s KILL 20 $MINIBC $args $file < /dev/null 2>&1
  )
}

status=0
for case in $cases; do
  name=$(basename "$case" .bc)
  out=${case%.bc}.out
  case $mode in
    record) theirs "$case" > "$out"; echo "recorded $name";;
    check)
      [ -f "${case%.bc}.mini.out" ] && out=${case%.bc}.mini.out
      if ours "$case" | diff -u "$out" - > /tmp/$$.diff; then echo "ok   $name"
      else echo "FAIL $name"; cat /tmp/$$.diff; status=1; fi;;
    live)
      if [ -f "${case%.bc}.mini.out" ]; then echo "apart $name"; continue; fi
      theirs "$case" > /tmp/$$.bc
      ours "$case" > /tmp/$$.mini
      if cmp -s /tmp/$$.bc /tmp/$$.mini; then echo "same  $name"
      else echo "DIFF  $name"; diff /tmp/$$.bc /tmp/$$.mini | head -20; status=1; fi;;
  esac
done
rm -f /tmp/$$.*
exit $status
