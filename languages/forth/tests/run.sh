#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-forth's tests by text, on dune's build and on mini-ml's when it
# is there: each case's output (and what it says of mistakes, and its
# exit) against the .out file kept here. The one by mini-ml runs as it
# is (arm64), or under mini-5i (-5: arm, a Pi1's integers of 31 bits).
#   core       the words, a group a line
#   classics   Euclid's, Fibonacci's, BYTE's sieve, Hanoi, a word that defines words
#   see        what the compiler made: SEE's threaded code
#   trace      each word the inner interpreter runs
#   prompt     lines typed: ok, compiled, the mistakes
#   errors     a file with a mistake: said with its line
# No other Forth is asked: the .out files were read, not made by one.
# usage: languages/forth/tests/run.sh [-5] [-dune] [-mini] [-record]   (dune build, and mini-mk O=7 or O=5 in languages/forth, first)
# -dune, -mini: that build only. MINIFORTH: mini-ml's build, if not _mk's. -record: the .out files made again, by dune's.
cd "$(dirname "$0")/../../.."
O=7; RUN=; record=; only=
for a in "$@"; do
  case $a in
    -5) O=5; RUN=_build/default/machine/Main.exe;;
    -record) record=1;;
    -dune) only=dune;;
    -mini) only=mini;;
  esac
done
T=languages/forth/tests
NATIVE=_build/default/languages/forth/Main.exe
MINI=${MINIFORTH:-_mk/$O/languages/forth/mini-forth}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
# a case: its name, then the command's arguments; its input is $T/name.in if there is one
one() {
  local prog=$1 name=$2; shift 2
  local in=/dev/null; [ -f $T/$name.in ] && in=$T/$name.in
  $prog "$@" < $in > $W/$name.out 2>&1
  echo "exit $?" >> $W/$name.out
}
all() {
  one "$1" core $T/core.fs
  one "$1" classics $T/classics.fs
  one "$1" see $T/see.fs
  one "$1" trace -trace -e ': SQUARE DUP * ;' -e ': SUM-OF-SQUARES SQUARE SWAP SQUARE + ;' -e '3 4 SUM-OF-SQUARES .'
  one "$1" prompt
  one "$1" errors $T/errors.fs -e '.( after )'
}
check() {
  local what=$1; shift
  [ -x "${@: -1}" ] || { echo "skipped: $what is not built"; return; }
  all "$*"
  for name in core classics see trace prompt errors; do
    if [ -n "$record" ]; then cp $W/$name.out $T/$name.out; echo "recorded $name"
    elif cmp -s $W/$name.out $T/$name.out; then echo "ok mini-forth $name, by $what"
    else echo "FAIL mini-forth $name, by $what"; diff $T/$name.out $W/$name.out | head -10; failures=$((failures + 1)); fi
  done
}
if [ -n "$record" ]; then check dune $NATIVE; exit 0; fi
[ -z "$RUN" ] && [ "$only" != mini ] && check dune $NATIVE
[ "$only" != dune ] && check "mini-ml ($O)" $RUN $MINI
exit $failures
