#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The rules' liveness against the compiler's own, on ix's own C
# (docs/plans/plan_prolog.md, stage 9's check): for mini-ml's runtime
# and each file of lib_core's libc, mini-cc -flow and -dflow, then
# mini-datalog with languages/datalog/analyses/liveness.dl and
# tests/flow_check.dl; a line for each of the two (its files,
# functions, instructions, facts, the tuples the rules find, those that
# differ from Opti's liveness, the seconds of mini-cc and of
# mini-datalog), a line per file that differs or is not compiled.
# usage: languages/c/facts/tests/ix.sh   (dune build first)
# CC, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../../../.."
T=languages/c/facts/tests
A=languages/datalog/analyses
CC=${CC:-_build/default/languages/c/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
L=lib_core/libc
INC="-I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm64 -Darm64 -Dlinux"
now() { date +%s.%N; }
total=0
printf "%-28s %5s %6s %7s %8s %8s %7s %7s %7s\n" what files funcs points facts tuples differ mini-cc datalog
group() {   # $1: its name, the rest: its files
  local what=$1 f; shift
  files=0; funcs=0; points=0; facts=0; tuples=0; differ=0; tcc=0; tdl=0
  for f in "$@"; do
    t0=$(now)
    if ! { $CC -m 7 $INC -flow $f > $W/f.dl && $CC -m 7 $INC -dflow $f > $W/own.dl; } 2> $W/err; then echo "  not compiled: $f: $(head -1 $W/err | cut -c1-90)"; continue; fi
    t1=$(now)
    $DATALOG -s -q 'differs(Who, V, P)' $A/liveness.dl $T/flow_check.dl $W/f.dl $W/own.dl > $W/out 2> $W/stats
    t2=$(now)
    n=$(wc -l < $W/out); [ $n != 0 ] && echo "  DIFFERS: $f: $n tuples, the first: $(head -1 $W/out)"
    files=$((files + 1)); funcs=$((funcs + $(grep -c '^function' $W/f.dl))); points=$((points + $(grep -c '^point' $W/f.dl)))
    facts=$((facts + $(wc -l < $W/f.dl))); differ=$((differ + n))
    tuples=$((tuples + $(sed -n 's/.* \([0-9]*\) new tuples.*/\1/p' $W/stats)))
    tcc=$(echo "$tcc + $t1 - $t0" | bc); tdl=$(echo "$tdl + $t2 - $t1" | bc)
  done
  printf "%-28s %5d %6d %7d %8d %8d %7d %6.1fs %6.1fs\n" "$what" $files $funcs $points $facts $tuples $differ $tcc $tdl
  total=$((total + differ))
}
group "mini-ml's runtime" languages/ml/runtime/runtime.c
# (arm64's files: not arm's own)
group "lib_core's libc" $(find $L -name '*.c' -not -path '*/tests/*' | grep -v -E '_arm\.c$|/arm/' | sort)
[ $total = 0 ]
