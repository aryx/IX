#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Tests tiny-prof (TinyProfiler.ml) on profiles whose counts are known:
# - spin.tm on tiny-cpu (tiny-cpu -prof): a loop that calls a function
#   100 times, its counts worked out by hand in its comment, a label of a
#   compiler's kind (ml.L1) counted as the function's;
# - tiny-machine's first step, v0 (tiny-machine -prof): the kernel's
#   functions by name (-k), and its four programs by their window's base.
# Each output is compared with its .expected; RECORD=1 records them again
# (check them first).
# usage: TinyProfiler_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
MACHINE=${MACHINE:-$ROOT/_build/default/tiny/TinyMachine.exe}
PROF=${PROF:-$ROOT/_build/default/tiny/TinyProfiler.exe}
T=$ROOT/tiny/tests/TinyProfiler_tests
V=$ROOT/tiny/TinyKernel/steps/v0
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
check() { # name
  [ -n "${RECORD:-}" ] && cp $W/$1.out $T/$1.expected
  if cmp -s $W/$1.out $T/$1.expected; then echo "ok $1"; else fail "$1"; diff $T/$1.expected $W/$1.out | head -10; fi
}

$CPU -prof $W/spin.prof $T/spin.tm || fail "spin: the run"
$PROF $W/spin.prof -u $T/spin.tm > $W/spin.out
check spin

$MACHINE -prof $W/v0.prof $V/kernel.tm $V/a.tm $V/b.tm $V/c.tm $V/d.tm > /dev/null
$PROF $W/v0.prof -k $V/kernel.tm $V/a.tm $V/b.tm $V/c.tm $V/d.tm > $W/v0.out
check v0

# -diff: a profile less itself is nothing
$PROF -diff $W/spin.prof $W/spin.prof -u $T/spin.tm | head -1 > $W/diff.out
check diff

echo "$failures failure(s)"
[ $failures = 0 ]
