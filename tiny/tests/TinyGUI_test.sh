#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyGUI.ml, TinyAppCalculator.ml and TinyAppTemperature.ml on
# the host, built by OCaml, with no machine: TinyGUI_tests/Host.ml
# gives the calculator keys (its arithmetic: an operation done when the
# next is asked, a division by 0, nine digits) and a mouse at its
# buttons' boxes (a click, a press taken back), the converter clicks
# and keys in its two fields, and says what a press draws; its lines
# against calc.expected. Then their picture, a button held and a field
# with its caret, by TinyGraphics.ml: the screen against calc.cksum (a
# PPM's sum, as tiny-machine -screen's). The programs on the machine,
# in a window, are TinyKernel's check (calc.events, temp.events).
# RECORD=1 records both (look at the picture first: KEEP=1 W=dir).
# usage: TinyGUI_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyGUI_tests/Host.exe}
E=$ROOT/tiny/tests/TinyGUI_tests/calc
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

$HOST $ROOT/kernels/lib_machine/font1.bin $W/calc.ppm > $W/calc.out 2>&1 || fail "calc: the run"
[ -n "${RECORD:-}" ] && { cp $W/calc.out $E.expected; cksum < $W/calc.ppm > $E.cksum; }
if [ "$(cat $W/calc.out)" = "$(cat $E.expected)" ]; then echo "ok calc: its lines"; else fail "calc: its lines"; diff $E.expected $W/calc.out | head -10; fi
if [ "$(cksum < $W/calc.ppm)" = "$(cat $E.cksum)" ]; then echo "ok calc: its screen"; else fail "calc: its screen: $(cksum < $W/calc.ppm)"; fi

echo "$failures failure(s)"
[ $failures = 0 ]
