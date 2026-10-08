#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyPlayground.ml on the host, built by OCaml, with no
# machine: TinyPlayground_tests/Square.ml, a game of a page, its model
# after some keys and frames, shown; the messages TinyPlayground.ml
# made are drawn by TinyGraphics.ml. The lines it prints (where the
# square is; random numbers from a seed) against square.expected, the
# screen against square.cksum (a PPM's sum, as tiny-machine -screen's).
# The game on the machine, in a window, is TinyKernel's check
# (play.events).
# RECORD=1 records both (look at the picture first: KEEP=1 W=dir).
# usage: TinyPlayground_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyPlayground_tests/Host.exe}
E=$ROOT/tiny/tests/TinyPlayground_tests/square
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

$HOST $ROOT/kernels/lib_machine/font1.bin $W/square.ppm > $W/square.out 2>&1 || fail "square: the run"
[ -n "${RECORD:-}" ] && { cp $W/square.out $E.expected; cksum < $W/square.ppm > $E.cksum; }
if [ "$(cat $W/square.out)" = "$(cat $E.expected)" ]; then echo "ok square: its lines"; else fail "square: its lines"; diff $E.expected $W/square.out | head -10; fi
if [ "$(cksum < $W/square.ppm)" = "$(cat $E.cksum)" ]; then echo "ok square: its screen"; else fail "square: its screen: $(cksum < $W/square.ppm)"; fi

echo "$failures failure(s)"
[ $failures = 0 ]
