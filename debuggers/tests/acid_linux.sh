#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-acid on Linux (plan_debugger.md, stage 8a): dune's mini-acid,
# ptrace's side (debuggers/acid/linux), on programs of this machine
# (arm64) with ix's library and arm64.acid:
#   acid/linux/*.acid      gcc's (acid/linux/target.c): new, a
#                          breakpoint, stk by the frame pointers, step,
#                          cont, values by mini-cc -m 7 -a's declarations
#                          of the same file; lines.acid by DWARF's lines
#   acid/linux/cc/*.acid   the same file by mini-cc -g and mini-ld -g -H7:
#                          its names, lines and types in its sections
#   acid/linux/ml/*.acid   acid/mlvalues/Values.ml by mini-ml -g: its
#                          values by their types, its stack
#   acid/linux/asm/*.acid  linker/tests/golden/hello_linux_arm64.s by
#                          mini-asm: steps, each instruction's line
# The addresses are left out of the comparison (gcc's version moves
# them), the pid and the directory too.
#   record: the outputs written as acid/linux/.../NAME.out
# usage: debuggers/tests/acid_linux.sh [record]

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
T=$ROOT/debuggers/tests/acid/linux
LIB=$ROOT/debuggers/acid/lib
[ "$(uname -s)/$(uname -m)" = Linux/aarch64 ] || { echo "skipped: not arm64 Linux"; exit 0; }
command -v gcc > /dev/null || { echo "skipped: no gcc"; exit 0; }
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
M=$ROOT/_mk/7
LC=$ROOT/lib_core
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/7/lib_core (mini-mk in lib_core)"; exit 0; }
mkdir $W/gcc $W/cc $W/ml $W/asm
cp $T/target.c $W/gcc/
cp $T/target.c $W/cc/
cp $ROOT/debuggers/tests/acid/mlvalues/Values.ml $W/ml/
cp $ROOT/linker/tests/golden/hello_linux_arm64.s $W/asm/
I="-I . -I $LC/core -I $LC/base -I $LC/collections -I $LC/printing -I $LC/parsing -I $LC/system -I $LC/concurrency -I $LC/commons"
U=$($ROOT/bin/mini-ar t $M/lib_core/lib_core.a | sed 's,.*/,,; s,\.ml$,,' | tr '\n' ' ')
( (cd $W/gcc && gcc -g -O0 -o target target.c && $IX/languages/c/Main.exe -m 7 -a target.c > target.acid) &&
  (cd $W/cc && $IX/languages/c/Main.exe -m 7 -g -o target.7 target.c && $IX/linker/Main.exe -m 7 -g -H7 -o target target.7 $M/lib_core/libc.a) &&
  (cd $W/ml && $IX/languages/ml/Main.exe -m 7 -O3 -g $I -o Values.7 Values.ml \
     && $IX/languages/ml/Main.exe -m 7 -O3 -start $U Values Std_exit -o Values.start.7 \
     && $IX/linker/Main.exe -m 7 -g -H7 -nofollow -o target Values.start.7 $M/lib_core/lib_core.a Values.7 \
          $M/lib_core/std_exit.7 $M/lib_core/runtime.7 $M/lib_core/libc.a) &&
  (cd $W/asm && $IX/assembler/Main.exe -m 7 -o hello.7 hello_linux_arm64.s && $IX/linker/Main.exe -m 7 -g -H7 -E _start -o target hello.7)
) > $W/err 2>&1 || { echo "FAIL the targets' build: $(head -2 $W/err)"; exit 1; }
norm() { sed -E "s|$W|W|g" | sed -E 's/[0-9]{4,8}: /PID: /g; s/0x[0-9a-f]{12,16}/ADDR/g; s/pid=[0-9]+/pid=PID/g; s/^kill [0-9]+/kill PID/'; }
n=0; failures=0
for d in gcc:. cc:cc ml:ml asm:asm; do
  # (gcc's program its types from mini-cc -a's file; the others' their own)
  decls=; [ ${d%:*} = gcc ] && decls="-l target.acid"
  for f in $T/${d#*:}/*.acid; do
    name=${d#*:}/$(basename $f .acid)
    n=$((n + 1))
    (cd $W/${d%:*} && timeout -s KILL 30 $IX/debuggers/acid/Main.exe -l $LIB/port.acid -l $LIB/arm64.acid $decls ./target < $f > $W/out 2>&1)
    norm < $W/out > $W/got
    [ "$1" = record ] && cp $W/got $T/$name.out
    cmp -s $T/$name.out $W/got || { failures=$((failures + 1)); echo "FAIL linux/$name"; diff -a $T/$name.out $W/got | head -6; }
  done
done
echo "acid_linux: $n sessions, $failures failure(s)"
[ $failures = 0 ]
