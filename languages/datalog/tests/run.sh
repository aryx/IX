#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-datalog's tests by text (docs/plans/plan_prolog.md, stage 7), on
# dune's build and on mini-ml's when it is there: each case's output
# (and what it says of mistakes, and its exit) against the .out file
# kept here; and, for each program, every tuple found the semi-naive
# way against every tuple found the naive way.
#   graph       paths in a graph with a cycle, a negation, two queries
#   liveness    a backward dataflow with a negation in its recursion's stratum below
#   dominators  three strata of negation, a comparison of numbers
#   refused     what is not Datalog, each said with its line
#   pointer     the author's pointer analysis of 2014 (analyses/pointer.dl)
#               on facts written by hand
# The .out files were read, not made by another Datalog (none is here).
# usage: languages/datalog/tests/run.sh [-5] [-dune] [-mini] [-record]   (dune build, and mini-mk in languages/datalog, first)
# MINIDATALOG: mini-ml's build, if not _mk's.
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
T=languages/datalog/tests
NATIVE=_build/default/languages/datalog/Main.exe
MINI=${MINIDATALOG:-_mk/$O/languages/datalog/mini-datalog}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
cases="graph liveness dominators refused pointer"
refused() {
  local n=0
  while IFS= read -r line; do
    n=$((n + 1)); echo "$line" | sed 's/;;/\n/g' > $W/refused$n.dl
    echo "-- $line"
    "$@" $W/refused$n.dl 2>&1 | sed "s|$W/||"
  done <<'R'
p(X) :- q(X), \+ p(X). ;;q(a).
p(X, Y) :- q(X). ;;q(a).
p(X) :- q(X), \+ r(Y). ;;q(a). ;;r(b).
p(X) :- q(X), X < Y. ;;q(a).
p(f(a)).
p(X).
p(a) :- q(a ;;q(a).
p(X) :- q(X), nope(X). ;;q(a). ;;?- p(X).
R
}
all() {
  local name
  for name in graph liveness dominators; do
    "$@" -all $T/$name.dl > $W/$name.out 2>&1; echo "exit $?" >> $W/$name.out
    "$@" -naive -all $T/$name.dl > $W/$name.naive 2>&1; echo "exit $?" >> $W/$name.naive
    cmp -s $W/$name.out $W/$name.naive || echo "the naive way finds other tuples" >> $W/$name.out
  done
  refused "$@" > $W/refused.out 2>&1
  "$@" -q 'call_edge(I, F)' languages/datalog/analyses/pointer.dl $T/pointer_facts.dl 2>&1 | grep -v '^warning' > $W/pointer.out
}
check() {
  local what=$1 name; shift
  [ -x "${@: -1}" ] || { echo "skipped: $what is not built"; return; }
  all "$@"
  for name in $cases; do
    if [ -n "$record" ]; then cp $W/$name.out $T/$name.out; echo "recorded $name"
    elif cmp -s $W/$name.out $T/$name.out; then echo "ok mini-datalog $name, by $what"
    else echo "FAIL mini-datalog $name, by $what"; diff $T/$name.out $W/$name.out | head -10; failures=$((failures + 1)); fi
  done
}
if [ -n "$record" ]; then check dune $NATIVE; exit 0; fi
[ -z "$RUN" ] && [ "$only" != mini ] && check dune $NATIVE
[ "$only" != dune ] && check "mini-ml ($O)" $RUN $MINI
exit $failures
