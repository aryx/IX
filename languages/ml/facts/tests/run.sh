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
# And mini-ml -facts (stage 10): closures/'s two units as the facts of
# the author's pointer analysis against closures.facts; with pointer.dl
# and calls.dl, who calls whom, what is never called, what no toplevel
# reaches, what is given one argument only, against closures.out.
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
for u in Kit Use; do $ML -m 7 -facts $I -I $T/closures $T/closures/$u.ml; done > $W/closures.facts 2>&1
grep -v '^point_to(A,B)?' $A/pointer.dl > $W/pointer.dl
{ $DATALOG -q "calls(F, G)" $W/pointer.dl $A/calls.dl $W/closures.facts | grep -v "'prim:"
  $DATALOG -q 'never_called(F)' -q 'unreached(F)' -q 'half_called(F)' -q 'hole(I, F)' $W/pointer.dl $A/calls.dl $W/closures.facts
} 2>&1 | grep -v '^warning' > $W/closures.out
for n in flow.facts flow.out closures.facts closures.out; do
  if [ "${1:-}" = -record ]; then cp $W/$n $T/$n; echo "recorded $n"
  elif cmp -s $W/$n $T/$n; then echo "ok mini-ml -flow, -facts: $n"
  else echo "FAIL mini-ml -flow, -facts: $n"; diff $T/$n $W/$n | head -10; failures=$((failures + 1)); fi
done
exit $failures
