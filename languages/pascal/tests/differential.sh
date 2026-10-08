#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-pascal by mini-ml against mini-pascal by dune
# (docs/plans/plan_pascal.md, stage 1): each program of the disk
# (Pascal_disk: the queens, Hanoi, the sieve...; the one that asks is
# answered 1 to 100) run by both, and its P-code listed by both; and
# the programs of tests/*.pas, which fail: the compiler's errors, the
# machine's (a range, a division by zero, the stack), an integer past
# maxint. What the two say must be the same, and their exits. The one
# by mini-ml runs as it is (arm64), or under mini-5i (-5: arm, where an
# OCaml int has 31 bits).
# usage: languages/pascal/tests/differential.sh [-5]   (dune build, and mini-mk O=7 or O=5 here, first)
cd "$(dirname "$0")/../../.."
O=7; RUN=; [ "${1:-}" = -5 ] && { O=5; RUN=_build/default/machine/Main.exe; }
NATIVE=_build/default/languages/pascal/Main.exe
MINI=_mk/$O/languages/pascal/mini-pascal
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
seq 1 100 > $W/answers
# a case: its name, then mini-pascal's arguments
both() {
  local name=$1; shift
  $NATIVE "$@" < $W/answers > $W/native 2>&1; echo "exit $?" >> $W/native
  $RUN $MINI "$@" < $W/answers > $W/mini 2>&1; echo "exit $?" >> $W/mini
  if cmp -s $W/native $W/mini; then echo "ok mini-pascal $name, by mini-ml ($O) as by dune: $(wc -l < $W/native) lines said"
  else echo "FAIL mini-pascal $name"; diff $W/native $W/mini | head -10; failures=$((failures + 1)); fi
}
disk=$($NATIVE -disk)
both "the disk's programs" -s $disk
both "their P-code" -S $disk
for f in languages/pascal/tests/*.pas; do both "$(basename $f)" $f; done
exit $failures
