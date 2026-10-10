#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-prolog's two machines timed (docs/plans/plan_prolog.md, stage 5):
# naive reverse of 30 elements 20,000 times (9,920,000 inferences: the
# logical inferences a second, LIPS, are that over the time), and the
# eight queens' 92 answers by permutations, each by the first machine
# and by the WAM (-wam), on dune's build and on mini-ml's if it is there.
# usage: languages/prolog/tests/bench.sh [n]   (MINIPROLOG: mini-ml's build, if not _mk/7's)
cd "$(dirname "$0")/../../.."
N=${1:-20000}
T=languages/prolog/tests
# a command's time, in milliseconds
ms() {
  local t0 t1
  t0=$(date +%s%N); "$@" > /dev/null 2>&1 || echo "failed: $*" >&2; t1=$(date +%s%N)
  echo $(( (t1 - t0) / 1000000 + 1 ))
}
for build in dune mini-ml; do
  P=_build/default/languages/prolog/Main.exe
  [ $build = mini-ml ] && P=${MINIPROLOG:-_mk/7/languages/prolog/mini-prolog}
  [ -x $P ] || { echo "skipped: $build's is not built"; continue; }
  for flag in "" -wam; do
    nrev=$(ms $P $flag $T/bench.pl -g "bench($N)")
    queens=$(ms $P $flag $T/bench.pl -g 'all_queens(8, 92)')
    printf "%-8s %-5s nrev30 x %d: %5d ms, %5d K LIPS   queens(8), all: %5d ms\n" $build "${flag:-first}" $N $nrev $(( 496 * N / nrev )) $queens
  done
done
