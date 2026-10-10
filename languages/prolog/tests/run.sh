#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-prolog's tests by text (docs/plans/plan_prolog.md, decision 7),
# on dune's build and on mini-ml's when it is there: each case's output
# (and what it says of mistakes, and its exit) against the .out file
# kept here. The one by mini-ml runs as it is (arm64), or under mini-5i
# (-5: arm, a Pi1's integers of 31 bits).
#   classics   the classical programs (the family, the queens, naive
#              reverse, Warren's derivative, the zebra, a grammar, Prolog
#              in three clauses, Hanoi with a counter)
#   language   197 checks of the language, each a goal that must hold
#   trace      the four ports
#   prompt     goals typed at the prompt, ; for the next answer, read/1
#   errors     a file with mistakes: each said with its line
#   control    the database changed while it is read, catch/3, the cut in a disjunction, call/N
#   code       the WAM's instructions for a small file (-S)
# Then the same cases but trace by the WAM (-wam), against the same .out
# files (a variable's number, _G881, is not the same by the two machines:
# taken out of both).
# No other Prolog is asked: the .out files were read, not made by one.
# usage: languages/prolog/tests/run.sh [-5] [-dune] [-mini] [-record]   (dune build, and mini-mk O=7 or O=5 in languages/prolog, first)
# -dune, -mini: that build only. MINIPROLOG: mini-ml's build, if not _mk's. -record: the .out files made again, by dune's.
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
T=languages/prolog/tests
NATIVE=_build/default/languages/prolog/Main.exe
MINI=${MINIPROLOG:-_mk/$O/languages/prolog/mini-prolog}
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
  one "$1" classics $T/classics.pl -g main
  one "$1" language $T/language.pl -g main
  one "$1" trace -trace $T/classics.pl -g 'grandparent(tom, X), X == pat' -g 'catch(nope, _, fail)'
  one "$1" prompt $T/classics.pl
  one "$1" errors $T/errors.pl -g 'findall(X, ok(X), L), print(L), nl'
  one "$1" control $T/control.pl -g main
  one "$1" code -S $T/code.pl
}
wam() {
  one "$1" classics -wam $T/classics.pl -g main
  one "$1" language -wam $T/language.pl -g main
  one "$1" prompt -wam $T/classics.pl
  one "$1" errors -wam $T/errors.pl -g 'findall(X, ok(X), L), print(L), nl'
  one "$1" control -wam $T/control.pl -g main
}
check() {
  local what=$1; shift
  [ -x "${@: -1}" ] || { echo "skipped: $what is not built"; return; }
  all "$*"
  for name in classics language trace prompt errors control code; do
    if [ -n "$record" ]; then cp $W/$name.out $T/$name.out; echo "recorded $name"
    elif cmp -s $W/$name.out $T/$name.out; then echo "ok mini-prolog $name, by $what"
    else echo "FAIL mini-prolog $name, by $what"; diff $T/$name.out $W/$name.out | head -10; failures=$((failures + 1)); fi
  done
  [ -n "$record" ] && return
  wam "$*"
  for name in classics language prompt errors control; do
    if diff <(sed -E 's/_G[0-9]+/_G/g' $T/$name.out) <(sed -E 's/_G[0-9]+/_G/g' $W/$name.out) > $W/diff; then echo "ok mini-prolog $name, by $what, -wam"
    else echo "FAIL mini-prolog $name, by $what, -wam"; head -10 $W/diff; failures=$((failures + 1)); fi
  done
}
if [ -n "$record" ]; then check dune $NATIVE; exit 0; fi
[ -z "$RUN" ] && [ "$only" != mini ] && check dune $NATIVE
[ "$only" != dune ] && check "mini-ml ($O)" $RUN $MINI
exit $failures
