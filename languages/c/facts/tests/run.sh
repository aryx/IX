#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-cc -facts, then the author's pointer analysis by mini-datalog
# (docs/plans/plan_prolog.md, stage 8): pointers.c's facts against
# pointers.facts, and, by languages/datalog/analyses/pointer.dl, who is
# called from where and what the named pointers of main point to, against
# pointers.out. Both read, not made by another analysis.
# And mini-cc -flow (stage 9): flow.c's stack code as facts against
# flow.facts; what languages/datalog/analyses/liveness.dl finds live
# after each call against flow.out, with the rules' liveness against
# the compiler's own (-dflow: Opti's), no difference expected, and
# that this check sees one: the rule that a write ends a life taken
# out, differences are found.
# usage: languages/c/facts/tests/run.sh [-record]   (dune build first)
# CC, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../../../.."
T=languages/c/facts/tests
CC=${CC:-_build/default/languages/c/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
RULES=languages/datalog/analyses/pointer.dl
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
$CC -m 7 -facts $T/pointers.c > $W/pointers.facts 2>&1
# (the rules' own query, every point_to, is not what is kept: the calls, and main's variables)
grep -v '^point_to(A,B)?' $RULES > $W/rules.dl
$DATALOG -q 'call_edge(I, F)' $W/rules.dl $W/pointers.facts 2>&1 | grep -v '^warning' > $W/pointers.out
for v in p q r pp l s; do $DATALOG -q "point_to(main__$v, L)" $W/rules.dl $W/pointers.facts 2> /dev/null; done >> $W/pointers.out
$DATALOG -q 'point_to(gp, L)' -q "point_to('_fld__next', L)" -q "point_to('_fld__visit', L)" $W/rules.dl $W/pointers.facts 2> /dev/null >> $W/pointers.out
$CC -m 7 -flow $T/flow.c > $W/flow.facts 2>&1
$CC -m 7 -dflow $T/flow.c > $W/own.dl 2>&1
A=languages/datalog/analyses
{ $DATALOG -q 'across_call(V, P)' $A/liveness.dl $W/flow.facts
  echo "differences: $($DATALOG -q 'differs(Who, V, P)' $A/liveness.dl $T/flow_check.dl $W/flow.facts $W/own.dl | wc -l)"
  sed 's/, \\+ def(V, P)//' $A/liveness.dl > $W/broken.dl
  echo "without the writes: $($DATALOG -q 'differs(Who, V, P)' $W/broken.dl $T/flow_check.dl $W/flow.facts $W/own.dl | wc -l)"
} 2>&1 | grep -v '^warning' > $W/flow.out
for n in pointers.facts pointers.out flow.facts flow.out; do
  if [ "${1:-}" = -record ]; then cp $W/$n $T/$n; echo "recorded $n"
  elif cmp -s $W/$n $T/$n; then echo "ok mini-cc -facts, -flow: $n"
  else echo "FAIL mini-cc -facts, -flow: $n"; diff $T/$n $W/$n | head -10; failures=$((failures + 1)); fi
done
exit $failures
