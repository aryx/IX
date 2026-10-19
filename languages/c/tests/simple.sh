#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-cc -simple (plan_cc.md, decision 8) against 5c and 7c by
# behavior: all of goken's libc compiled by -simple (libc.sh, MINICC=1
# MINICC_FLAGS=-simple), each program too, linked by mini-ld, run; its
# output and exit status compared with the reference's. The reference
# on arm is 5c -O0 and 5l with goken's 5c -O0 libc; on arm64 it is
# 7c -O0 -S, and libc by 7c -S (libc.sh 7's, in workdir/ref), assembled
# by mini-asm and linked by mini-ld (which libc.sh checks against 7l
# byte for byte), since goken's 7l writes the section table inside the
# data, which misprints (%d% for a number: bugs/goken.md 1,
# notes_fuzzing_techniques.md 7)
# (old: assembled and linked by tiny/TinyAssembler.ml, gone with t-ix's
# arm64, plan_tiny_self_hosting.md). A fuzzer's program can also differ
# by 7c's bug 5d (a narrowing cast in a condition), where -simple is
# right. Programs: goken's
# hello_libc, tiny/tests/TinyC_tests, and TinyC_fuzz.py's (--32 on arm).
# The libc is built once per workdir: remove it to rebuild.
# SIMPLE_FLAGS=-O: libc and the programs with Opti's passes too.
# usage: simple.sh 5|7 workdir prog.c...   (needs goken, and dune build)
set -u
export PATH=$HOME/goken/bin:$HOME/goken/ROOT/arch/boot-gcc/bin:$PATH
ROOT=$(cd $(dirname $0)/../../.. && pwd)
IX=$ROOT/_build/default
O=$1; W=$2; shift 2
progs=("$@")
case $O in 5) OBJ=arm;; 7) OBJ=arm64;; esac
incs="-I$HOME/goken/include -I$HOME/goken/include/ALL -I$HOME/goken/include/arch/$OBJ"
[ -f $W/t/libc.a ] || MINICC=1 MINICC_FLAGS="-simple ${SIMPLE_FLAGS:-}" $ROOT/linker/tests/libc.sh $O $W > /dev/null
[ $O = 7 ] && [ ! -f $W/ref/t/libc.a ] && $ROOT/linker/tests/libc.sh 7 $W/ref > /dev/null
mkdir -p $W/p $W/g1 $W/t1
ok=0; failures=0
for c in "${progs[@]}"; do
  b=$(basename $c .c)
  if [ $O = 7 ]; then
    (cd $(dirname $c) && 7c -O0 $incs -S -o $W/p/$b.g.7 $b.c 2>/dev/null | grep '^	' > $W/p/$b.ref.s) || { echo "7c-FAIL $b"; continue; }
    $IX/assembler/Main.exe -m 7 -o $W/p/$b.ref.7 $W/p/$b.ref.s || { echo "MINIASM-FAIL $b"; continue; }
    $IX/linker/Main.exe -m 7 -H7 -o $W/g1/$b $W/p/$b.ref.7 $W/ref/t/libc.a || { echo "MINILD-FAIL $b"; continue; }
  else
    (cd $(dirname $c) && 5c -O0 $incs -o $W/p/$b.g.5 $b.c > /dev/null 2>&1) || { echo "5c-FAIL $b"; continue; }
    (cd $HOME/goken/lib_core/libc && 5l -f -H7 -s -o $W/g1/$b $W/p/$b.g.5 $W/g/libc.a) > /dev/null 2>&1 || { echo "5l-FAIL $b"; continue; }
  fi
  (cd $(dirname $c) && $IX/languages/c/Main.exe -simple ${SIMPLE_FLAGS:-} -m $O $incs -o $W/p/$b.$O $b.c) || { echo "FAIL $b: mini-cc"; failures=$((failures + 1)); continue; }
  $IX/linker/Main.exe -m $O -H7 -o $W/t1/$b $W/p/$b.$O $W/t/libc.a || { echo "FAIL $b: mini-ld"; failures=$((failures + 1)); continue; }
  # the same name in two directories, for argv[0]; SIGKILL after, for
  # a program that catches SIGTERM
  want=$(cd $W/g1 && timeout -k 2 10 ./$b one two 2>&1; echo "exit $?")
  got=$(cd $W/t1 && timeout -k 2 10 ./$b one two 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then ok=$((ok + 1)); else echo "FAIL $b"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -6; failures=$((failures + 1)); fi
done
echo "$ok the same, $failures failure(s)"
[ $failures = 0 ]
