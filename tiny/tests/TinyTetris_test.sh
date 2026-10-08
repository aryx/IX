#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyTetris.ml on the host, built by OCaml, with no
# machine: TinyTetris_tests/Host.ml plays three games by the game's own
# functions, each from a seed and a script of keys and frames, and
# prints the well as text where the script says (a piece falling by the
# clock, moved to the sides and stopped by them, turned, dropped; a
# well filled, the game over, another one; a row filled and removed):
# its rules, against tetris.expected. Then the last model's picture, by
# TinyPlayground.ml and TinyGraphics.ml: the screen against
# tetris.cksum (a PPM's sum, as tiny-machine -screen's). The game on
# the machine, in a window, is TinyKernel's check (tetris.events).
# RECORD=1 records both (look at the picture first: KEEP=1 W=dir).
# usage: TinyTetris_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyTetris_tests/Host.exe}
E=$ROOT/tiny/tests/TinyTetris_tests/tetris
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

$HOST $ROOT/kernels/lib_machine/font1.bin $W/tetris.ppm > $W/tetris.out 2>&1 || fail "tetris: the run"
[ -n "${RECORD:-}" ] && { cp $W/tetris.out $E.expected; cksum < $W/tetris.ppm > $E.cksum; }
if [ "$(cat $W/tetris.out)" = "$(cat $E.expected)" ]; then echo "ok tetris: its lines"; else fail "tetris: its lines"; diff $E.expected $W/tetris.out | head -10; fi
if [ "$(cksum < $W/tetris.ppm)" = "$(cat $E.cksum)" ]; then echo "ok tetris: its screen"; else fail "tetris: its screen: $(cksum < $W/tetris.ppm)"; fi

echo "$failures failure(s)"
[ $failures = 0 ]
