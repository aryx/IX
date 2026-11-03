#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze -facts of a C file, then the author's pointer analysis
# by mini-datalog
# (docs/plans/plan_prolog.md, stage 8): pointers.c's facts against
# pointers.facts, and, by analyzers/datalog/pointer.dl, who is
# called from where and what the named pointers of main point to, against
# pointers.out. Both read, not made by another analysis.
# And mini-analyze -flow (stage 9): flow.c's stack code as facts against
# flow.facts; what analyzers/datalog/liveness.dl finds live
# after each call against flow.out, with the rules' liveness against
# the compiler's own (-dflow: Opti's), no difference expected, and
# that this check sees one: the rule that a write ends a life taken
# out, differences are found.
# (Was mini-cc -facts and -flow until 2026-11-02: C_front, C_flow.)
# usage: analyzers/c/tests/run.sh [-record]   (dune build first)
# ANALYZE, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../../.."
T=analyzers/c/tests
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
RULES=analyzers/datalog/pointer.dl
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
$ANALYZE -facts $T/pointers.c > $W/pointers.facts 2>&1
# (the rules' own query, every point_to, is not what is kept: the calls, and main's variables)
grep -v '^point_to(A,B)?' $RULES > $W/rules.dl
$DATALOG -q 'call_edge(I, F)' $W/rules.dl $W/pointers.facts 2>&1 | grep -v '^warning' > $W/pointers.out
for v in p q r pp l s; do $DATALOG -q "point_to(main__$v, L)" $W/rules.dl $W/pointers.facts 2> /dev/null; done >> $W/pointers.out
$DATALOG -q 'point_to(gp, L)' -q "point_to('_fld__next', L)" -q "point_to('_fld__visit', L)" $W/rules.dl $W/pointers.facts 2> /dev/null >> $W/pointers.out
$ANALYZE -flow $T/flow.c > $W/flow.facts 2>&1
$ANALYZE -dflow $T/flow.c > $W/own.dl 2>&1
A=analyzers/datalog
{ $DATALOG -q 'across_call(V, P)' $A/liveness.dl $W/flow.facts
  echo "differences: $(($($DATALOG -q 'differs(Who, V, P)' $A/liveness.dl $T/flow_check.dl $W/flow.facts $W/own.dl | wc -l)))"
  sed 's/, \\+ def(V, P)//' $A/liveness.dl > $W/broken.dl
  echo "without the writes: $(($($DATALOG -q 'differs(Who, V, P)' $W/broken.dl $T/flow_check.dl $W/flow.facts $W/own.dl | wc -l)))"
} 2>&1 | grep -v '^warning' > $W/flow.out
for n in pointers.facts pointers.out flow.facts flow.out; do
  if [ "${1:-}" = -record ]; then cp $W/$n $T/$n; echo "recorded $n"
  elif cmp -s $W/$n $T/$n; then echo "ok mini-analyze -facts, -flow of C: $n"
  else echo "FAIL mini-analyze -facts, -flow of C: $n"; diff $T/$n $W/$n | head -10; failures=$((failures + 1)); fi
done
exit $failures
