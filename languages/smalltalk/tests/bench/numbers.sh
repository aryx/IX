#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-smalltalk as a benchmark of mini-ml's code against ocamlopt's
# (docs/plans/plan_system_squeak.md, stages 1 and 2;
# plan_mini_toolchain_optimization.md): the instructions each takes for
# three things the machine does, each another kind of OCaml:
#   the start    the Blue Book's system's text compiled: a lexer, a
#                parser, a compiler, hash tables
#   fib          20 benchFib after it: the interpreter's loop, sends,
#                contexts made and dropped
#   the world    Squeak's start and three cycles of its world: objects,
#                closures, BitBlt, the collector (-all: 8 minutes)
# mini-ml's are the guest's, under mini-5i (arm64; O=5: arm), the same
# at every run; ocamlopt's are this machine's, counted by valgrind
# (x86-64: another instruction set, so the ratio is a rough one).
# usage: languages/smalltalk/tests/bench/numbers.sh [-all]   (dune build, and mini-mk in languages/smalltalk, first)
cd "$(dirname "$0")/../../../.."
O=${O:-7}
all=0; [ "${1:-}" = -all ] && all=1
NATIVE=_build/default/languages/smalltalk/Main.exe
MINI=_mk/$O/languages/smalltalk/mini-smalltalk
FIVE=_build/default/machine/Main.exe
FIB=languages/smalltalk/tests/bench/fib.st
mini() { $FIVE -s $MINI -s "$@" 2>&1 > /dev/null | awk '/bytecodes/ { b = $1 } /^mini-5i:/ { i = $2 } END { print i, b }'; }
native() { command -v valgrind > /dev/null && valgrind --tool=callgrind --callgrind-out-file=/dev/null $NATIVE "$@" 2>&1 > /dev/null | awk '/Collected/ { print $4 }'; }
row() {  # name, mini-ml's instructions and bytecodes, ocamlopt's instructions, those before (the start's, to take off)
  local i=$(($2 - ${5:-0})) b=$(($3 - ${6:-0})) n=$(( ${4:-0} - ${7:-0} ))
  printf "%-10s %14d %10d %8d" "$1" $i $b $((i / b))
  [ $n -gt 0 ] && printf " %14d %6.1f" $n $(echo "$i / $n" | bc -l)
  echo
}
printf "%-10s %14s %10s %8s %14s %6s\n" "" "mini-ml" bytecodes "a one" ocamlopt ratio
set -- $(mini $FIB -e nil); si=$1; sb=$2; sn=$(native $FIB -e nil)
row "the start" $si $sb $sn
set -- $(mini $FIB -e '20 benchFib'); row fib $1 $2 "$(native $FIB -e '20 benchFib')" $si $sb $sn
[ $all = 1 ] && { set -- $(mini -k squeak -world 3); row "the world" $1 $2 "$(native -k squeak -world 3)"; }
exit 0
