#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-cc's benchmarks' instructions (bench/: the libc's formatting and
# strings, a program's loops over memory, sorts), as mini-ml's
# tests/bench.sh: goken's libc and each program compiled by mini-cc
# with CC_FLAGS (none: compat's, 5c -O0's code; -O3: ssa/'s), linked
# by mini-ld, run and counted by mini-5i -s on arm (5) or arm64 (7),
# its output checked against its .out. The libc is built once per
# workdir (linker/tests/libc.sh): a workdir for each CC_FLAGS.
# usage: bench.sh 5|7 workdir
#   bench.sh 5 /tmp/bc; CC_FLAGS=-O3 bench.sh 5 /tmp/b3
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
IX=$ROOT/_build/default
O=$1; W=$(realpath -m $2)
B=$ROOT/languages/c/tests/bench
case $O in 5) A=arm;; 7) A=arm64;; esac
G=$HOME/goken/include
[ -f $W/t/libc.a ] || MINICC=1 MINICC_FLAGS="${CC_FLAGS:-}" $ROOT/linker/tests/libc.sh $O $W > /dev/null
for p in fmt copy sorts; do
  $IX/languages/c/Main.exe -m $O ${CC_FLAGS:-} -I$G -I$G/ALL -I$G/arch/$A -o $W/$p.$O $B/$p.c &&
    $IX/linker/Main.exe -m $O -H7 -o $W/$p $W/$p.$O $W/t/libc.a || { echo "FAIL $p: build"; continue; }
  n=$(cd $W && $IX/machine/Main.exe -s ./$p 2> $W/$p.err > $W/$p.got; grep -o '^mini-5i: [0-9]*' $W/$p.err | cut -d' ' -f2)
  cmp -s $W/$p.got $B/$p.out || echo "FAIL $p: its output"
  printf "%-6s %12s\n" $p "$n"
done
