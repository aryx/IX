#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-datalog -dotnet's tests (docs/plans/done/plan_dotnet_languages.md,
# stage 6): each case's rules compiled to an assembly with its queries,
# verified by mini-dotnet (every method), run on its facts by
# mini-dotnet (Microsoft's dotnet too with -ms: not in make test, the
# SDK), its answers the interpreter's (mini-datalog on the same files).
# The runtime, datalog_rt.dll beside it, is mini-datalog's relations
# compiled by mini-ml -dotnet (Datalog_rt and its units).
#   graph       tests/graph.dl: a recursion, negations on two strata,
#               comparisons, constants, p(X, X), a query in the text
#   pointer     lib_code/datalog/pointer.dl on mini-cc -facts of
#               languages/c/facts/tests/pointers.c: the calls, point_to
#   liveness    liveness.dl on mini-cc -flow of flow.c; without its
#               writes, with flow_check.dl and -dflow's facts, the
#               differences (none with the writes)
#   points_to/  each of the eleven analyses on mini-analyze -facts of
#               lib_code/datalog/tests/contexts.c: pt or pts, reach; with
#               -ms, call1 on contexts.ml's (mini-ml's, lib_core's too)
# usage: languages/datalog/dotnet/tests/run.sh [-ms]   (dune build first)
# DUNEML, DUNEDATALOG, DUNEDOTNET, DUNECC, DUNEANALYZE: if not _build's.
cd "$(dirname "$0")/../../../.."
ms=; [ "${1:-}" = -ms ] && ms=1
B=_build/default
ML=${DUNEML:-$B/languages/ml/Main.exe}
DL=${DUNEDATALOG:-$B/languages/datalog/Main.exe}
DN=${DUNEDOTNET:-$B/languages/dotnet/Main.exe}
CC=${DUNECC:-$B/languages/c/Main.exe}
AN=${DUNEANALYZE:-$B/analyzers/Main.exe}
T=languages/datalog/dotnet/tests
A=lib_code/datalog
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
# (each case a job: a mini-dotnet run is 2 s at least, the runtime's
# units initialized by its interpreter; their lines printed in order)
n=0
job() { n=$((n + 1)); "$@" > $W/job$n.log 2>&1 & }
abs() { case $1 in /*) echo $1;; *) echo $PWD/$1;; esac; }

# the runtime: Datalog_rt over mini-datalog's units (Parallel: its
# one-domain file, as the mkfile chooses for mini-ml)
cp lib_core/parallel/Parallel.mli $W/Parallel.mli
cp lib_core/parallel/host/single.ml.in $W/Parallel.ml
files=
for u in Prolog Prolog_read Parallel Tuples Btree Relset Hash_index Tree_index Index Datalog Datalog_eval Datalog_rt; do
  for f in languages/datalog/$u.ml languages/datalog/dotnet/$u.ml languages/prolog/$u.ml $W/$u.ml; do [ -f $f ] && break; done
  files="$files $(abs $f)"
done
mla=$(abs $ML)
if ! (cd languages/datalog && $mla -L ../../lib_core -I . -I dotnet -I ../prolog -I $W -dotnet -o $W/datalog_rt.dll $files) > $W/rt.err 2>&1; then
  echo "FAIL datalog_rt.dll by mini-ml -dotnet"; head -3 $W/rt.err; exit 1
fi

# a case: its name, its rules' files, its facts' files, its queries
case_() {
  local name=$1 rules=$2 facts=$3; shift 3
  local qs=() q
  for q in "$@"; do qs+=(-q "$q"); done
  $DL "${qs[@]}" $rules $facts > $W/$name.want 2> /dev/null
  if ! $DL -dotnet -o $W/$name.dll "${qs[@]}" $rules 2> $W/$name.err; then
    fail "mini-datalog -dotnet $name"; head -3 $W/$name.err; return
  fi
  case "$($DN -verify $W/$name.dll | tail -1)" in
    *" 0 refused") ;; *) fail "mini-datalog -dotnet $name, verified"; $DN -verify $W/$name.dll | head -3;; esac
  local f fs=
  for f in $facts; do fs="$fs $(abs $f)"; done
  run() { # what, runtime
    (cd $W && $2 $name.dll $fs) > $W/$name.got 2>&1
    if [ -s $W/$name.want ] && cmp -s $W/$name.want $W/$name.got; then
      echo "ok mini-datalog -dotnet $name: $(wc -l < $W/$name.want) answers, the interpreter's, by $1"
    else fail "mini-datalog -dotnet $name, by $1"; diff $W/$name.want $W/$name.got | head -5; fi
  }
  [ -z "${ms_only:-}" ] && run mini-dotnet $(abs $DN)
  [ -n "$ms" ] && run "Microsoft's dotnet" dotnet
}

job case_ graph $T/graph.dl $T/graph_facts.dl 'apart(X, Y)' 'loop(X)' 'before(X, Y)' 'heavy(X)' 'both(X, Y)' 'lonely(X)'
$CC -m 7 -facts languages/c/facts/tests/pointers.c > $W/pointers.facts
grep -v '^point_to(A,B)?' $A/pointer.dl > $W/pointer.dl
job case_ pointer $W/pointer.dl $W/pointers.facts 'call_edge(I, F)' 'point_to(V, L)'
$CC -m 7 -flow languages/c/facts/tests/flow.c > $W/flow.facts
$CC -m 7 -dflow languages/c/facts/tests/flow.c > $W/own.dl
job case_ liveness $A/liveness.dl $W/flow.facts 'across_call(V, P)'
# (the liveness without its writes: the differences none would show)
sed 's/, \\+ def(V, P)//' $A/liveness.dl > $W/broken.dl
job case_ liveness_check "$W/broken.dl languages/c/facts/tests/flow_check.dl" "$W/flow.facts $W/own.dl" 'differs(Who, V, P)'
P=$A/points_to
if [ -x $AN ]; then
  $AN -facts $A/tests/contexts.c > $W/c.facts 2>&1
  job case_ steensgaard "$P/instructions.dl $P/steensgaard.dl" $W/c.facts 'pt(V, H)'
  job case_ andersen "$P/instructions.dl $P/andersen.dl" $W/c.facts 'pt(V, H)'
  for a in insensitive call1 call1_heap1 call2_heap1 object1 object2_heap1 type2_heap1 hybrid selective; do
    job case_ $a "$P/instructions.dl $P/andersen.dl $P/contexts.dl $P/$a.dl" $W/c.facts 'pts(V, H)' 'reach(F)'
  done
  # mini-ml's facts, lib_core's with contexts.ml's: by Microsoft's dotnet
  # only (mini-dotnet 38 s, most of it the facts read: Prolog_read by
  # mini-ml -dotnet, 4.8 s of Microsoft's 5.5)
  if [ -n "$ms" ]; then
    $AN -facts -L lib_core $A/tests/contexts.ml > $W/ml.facts 2>&1
    ms_only=1 job case_ call1_ml "$P/instructions.dl $P/andersen.dl $P/contexts.dl $P/call1.dl" $W/ml.facts 'pts(V, H)' 'reach(F)'
  fi
else echo "skipped: the points_to analyses (no $AN)"; fi
wait
for i in $(seq 1 $n); do cat $W/job$i.log; done
failures=$((failures + $(cat $W/job*.log | grep -c '^FAIL')))
echo "$failures failure(s)"
[ $failures = 0 ]
