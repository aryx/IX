#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The benchmarks' instructions (bench/: loops over bytes, integers and
# floats, calls, allocation), mini-ml's code alone: each built by
# run.sh (its output checked against its .out), then counted by
# mini-5i -s, on arm (5) or arm64 (7). ML_FLAGS: mini-ml's flags, as
# run.sh's (-O, -ssa). For variants/ssa.md's numbers, each step of the
# back end measured against the one before.
# usage: bench.sh 5|7 workdir
#   ML_FLAGS="-O -ssa" bench.sh 5 /tmp/b
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
O=$1; W=$(realpath -m $2)
B=$ROOT/languages/ml/tests/bench
progs="pixels limbs samples floats sha fib tak maps sched interp matrix"
$ROOT/languages/ml/tests/run.sh $O $W $(for p in $progs; do echo $B/$p.ml; done) | grep -v "^ok"
for p in $progs; do
  printf "%-8s %11s\n" $p "$($ROOT/_build/default/machine/Main.exe -s $W/$p 2>&1 >/dev/null | grep -o '^mini-5i: [0-9]*' | cut -d' ' -f2)"
done
