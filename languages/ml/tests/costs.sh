#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What one operation costs in mini-ml's code on arm, in instructions
# (docs/plans/plan_playground_speed.md): bench/costs.ml built as run.sh
# builds a program (the stdlib, the runtime, linked by mini-ld), then
# each of its loops run by mini-5i -s 100 times and 1,100: the
# difference by 1,000, less the empty loop's. No clock: the same
# numbers on any host. ML_FLAGS=-calls: with the runtime's calls (a
# float's arithmetic, a block made, a byte stored, a function of
# another unit an argument at a time), what they were before.
# usage: costs.sh workdir
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
W=$(realpath -m $1)
$ROOT/languages/ml/tests/run.sh 5 $W $ROOT/languages/ml/tests/bench/costs.ml > /dev/null 2>&1
[ -x $W/costs ] || { echo "costs.sh: $W/costs not built (run.sh 5)"; exit 1; }
count() { $ROOT/bin/mini-5i -s $W/costs $1 $2 2>&1 > /dev/null | sed -n 's/.*mini-5i: \([0-9]*\) instructions.*/\1/p'; }
each() { echo $(( ($(count $1 1100) - $(count $1 100)) / 1000 )); }
loop=$(each loop)
echo "the loop itself: $loop instructions a turn"
for op in float_mul float_add float_neg float_less float_of_int int_of_float float_floor float_min tuple cons byte_set byte_set_checked buffer_add_char call_other_unit_2 call_other_unit_3 divide string_compare; do
  printf "%-20s %5d\n" $op $(( $(each $op) - loop ))
done
