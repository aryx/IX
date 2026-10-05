#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyCPUArm.ml that need nothing but ix: each program of
# TinyCPUArm_tests/ assembled by TinyAssembler into an executable, then
# run on this machine's CPU (when it is an arm64 Linux: skipped
# otherwise), under machine/'s mini-5i and under tiny-arm, with
# arguments and a line on its standard input: the outputs and the exit
# statuses the same. outside.s is the law of the subset: a word
# tiny-arm does not know stops it, with the word and its address.
#
# The larger test is TinyC_test.sh's and TinyML_test.sh's (which need
# goken): every program of theirs, with goken's libc, run under
# tiny-arm too.
#
# Usage: TinyCPUArm_test.sh

ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=${T:-$ROOT/_build/default/tiny/TinyCPUArm.exe}
A=${A:-$ROOT/_build/default/tiny/TinyAssembler.exe}
M=$ROOT/_build/default/machine/Main.exe
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
run() { (cd $W && echo "hello tiny-arm" | "$@" one two 2>&1; echo "exit $?"); }

for s in $ROOT/tiny/TinyCPUArm_tests/*.s; do
  p=$(basename $s .s)
  $A -e _start -o $W/$p $s || { fail "$p: not assembled"; continue; }
  [ $p = outside ] && continue
  mini=$(run $M ./$p)
  tiny=$(run $T ./$p)
  if [ "$mini" = "$tiny" ]; then echo "ok $p: as under mini-5i"; else fail "$p: mini-5i's and tiny-arm's differ: $(diff <(echo "$mini") <(echo "$tiny") | head -3)"; fi
  if [ "$(uname -sm)" = "Linux aarch64" ]; then
    real=$(run ./$p)
    if [ "$real" = "$tiny" ]; then echo "ok $p: as on the CPU"; else fail "$p: the CPU's and tiny-arm's differ: $(diff <(echo "$real") <(echo "$tiny") | head -3)"; fi
  fi
done
[ "$(uname -sm)" = "Linux aarch64" ] || echo "skipped: on the CPU (not an arm64 Linux)"

got=$(run $T ./outside)
case $got in
  "tiny-arm: unimplemented instruction 1e602821 at 0x400078"*"exit 1") echo "ok outside: stopped at the word";;
  *) fail "outside: $got";;
esac

echo "TinyCPUArm_test: $failures failures"
exit $((failures > 0))
