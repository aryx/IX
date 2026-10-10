#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml -flow, then liveness and dominators by mini-datalog
# (docs/plans/plan_prolog.md, stage 9): flow.ml's facts against
# flow.facts; what the rules of languages/datalog/analyses/ find (the
# loops' headers, each block's immediate dominator, what is live round
# triangle's loop) against flow.out; the rules' liveness and dominators
# against the compiler's own (-dflow: Alloc's and Ssa_build's), tuple
# by tuple, no difference expected; and that this check sees one: the
# rule for a phi's operands taken out, differences are found.
# usage: languages/ml/facts/tests/run.sh [-record]   (dune build first)
# ML, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../../../.."
T=languages/ml/facts/tests
A=languages/datalog/analyses
ML=${ML:-_build/default/languages/ml/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
I=$(for u in $(grep -v '^#' lib_core/units.txt); do echo "-I lib_core/$(dirname $u)"; done | sort -u)
$ML -m 7 -flow $I $T/flow.ml > $W/flow.facts 2>&1
$ML -m 7 -dflow $I $T/flow.ml > $W/own.dl 2>&1
rules="$A/liveness_ssa.dl $A/dominators.dl $T/check.dl"
{ $DATALOG -q 'back_edge(M, N)' -q 'idom(D, B)' $rules $W/flow.facts $W/own.dl
  $DATALOG -q "live_in(V, 'f1_triangle<>:b1')" -q "live_out(V, 'f1_triangle<>:b2')" $rules $W/flow.facts $W/own.dl
  echo "differences: $($DATALOG -q 'differs(What, Who, V, B)' $rules $W/flow.facts $W/own.dl | wc -l)"
  grep -v 'phi_arg' $A/liveness_ssa.dl > $W/broken.dl
  echo "without the phis' operands: $($DATALOG -q 'differs(What, Who, V, B)' $W/broken.dl $A/dominators.dl $T/check.dl $W/flow.facts $W/own.dl | wc -l)"
} 2>&1 | grep -v '^warning' > $W/flow.out
for n in facts out; do
  if [ "${1:-}" = -record ]; then cp $W/flow.$n $T/flow.$n; echo "recorded flow.$n"
  elif cmp -s $W/flow.$n $T/flow.$n; then echo "ok mini-ml -flow: flow.$n"
  else echo "FAIL mini-ml -flow: flow.$n"; diff $T/flow.$n $W/flow.$n | head -10; failures=$((failures + 1)); fi
done
exit $failures
