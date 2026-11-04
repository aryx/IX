#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The toy programs of docs/tutorials/notes_analysis.md, each run by
# mini-datalog against expected.out: what the tutorial says they answer.
# usage: analyzers/datalog/tests/tutorial/run.sh [-record]   (dune build first)
# DATALOG: the program, if not dune's.
cd "$(dirname "$0")/../../../.."
T=analyzers/datalog/tests/tutorial
D=analyzers/datalog/points_to
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
run() {
  echo "== unify.facts by andersen.dl, then steensgaard.dl"
  $DATALOG -q 'pt(V, H)' $D/instructions.dl $D/andersen.dl $T/unify.facts
  $DATALOG -q 'pt(V, H)' $D/instructions.dl $D/steensgaard.dl $T/unify.facts
  echo "== flow_insensitive.facts, then flow_ssa.facts, by andersen.dl"
  $DATALOG -q 'pt(q, H)' $D/instructions.dl $D/andersen.dl $T/flow_insensitive.facts
  $DATALOG -q 'pt(q, H)' $D/instructions.dl $D/andersen.dl $T/flow_ssa.facts
  echo "== liveness.facts by liveness.dl"
  $DATALOG -q 'live_in(V, P)' -q 'across_call(V, P)' analyzers/datalog/liveness.dl $T/liveness.facts
  echo "== paths.dl"
  $DATALOG $T/paths.dl
  echo "== taint.dl"
  $DATALOG $T/taint.dl
}
out=$(run 2> /dev/null)
if [ "${1:-}" = -record ]; then echo "$out" > $T/expected.out; echo "recorded $T/expected.out"
elif [ "$out" = "$(cat $T/expected.out)" ]; then echo "ok the tutorial's toy analyses"
else echo "FAIL the tutorial's toy analyses"; diff $T/expected.out <(echo "$out") | head -10; exit 1; fi
