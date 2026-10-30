#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-acid on Linux (plan_debugger.md, stage 8a): dune's mini-acid,
# ptrace's side (debuggers/acid/linux), on a program of gcc's run on
# this machine (arm64), with ix's library and arm64.acid: new, a
# breakpoint, stk by the frame pointers, step, cont, values printed by
# mini-cc -m 7 -a's declarations of the same file (acid/linux/
# target.c). The addresses are left out of the comparison (gcc's
# version moves them), the pid too.
#   record: the outputs written as acid/linux/NAME.out
# usage: debuggers/tests/acid_linux.sh [record]

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
T=$ROOT/debuggers/tests/acid/linux
LIB=$ROOT/debuggers/acid/lib
[ "$(uname -s)/$(uname -m)" = Linux/aarch64 ] || { echo "skipped: not arm64 Linux"; exit 0; }
command -v gcc > /dev/null || { echo "skipped: no gcc"; exit 0; }
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
cp $T/target.c $W/
(cd $W && gcc -g -O0 -o target target.c && $IX/languages/c/Main.exe -m 7 -a target.c > target.acid) > $W/err 2>&1 \
  || { echo "FAIL the target's build: $(head -2 $W/err)"; exit 1; }
norm() { sed -E 's/[0-9]{4,8}: /PID: /g; s/0x[0-9a-f]{12,16}/ADDR/g; s/pid=[0-9]+/pid=PID/g; s/^kill [0-9]+/kill PID/'; }
n=0; failures=0
for f in $T/*.acid; do
  name=$(basename $f .acid)
  n=$((n + 1))
  (cd $W && timeout -s KILL 30 $IX/debuggers/acid/Main.exe -l $LIB/port.acid -l $LIB/arm64.acid -l target.acid ./target < $f > $W/out 2>&1)
  norm < $W/out > $W/got
  [ "$1" = record ] && cp $W/got $T/$name.out
  cmp -s $T/$name.out $W/got || { failures=$((failures + 1)); echo "FAIL linux/$name"; diff -a $T/$name.out $W/got | head -6; }
done
echo "acid_linux: $n sessions, $failures failure(s)"
[ $failures = 0 ]
