#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyAppOrrery.ml on the host, built by OCaml, with no
# machine: TinyAppOrrery_tests/Host.ml prints dates (a leap day among
# them), each planet's place on 2000-01-01, a quarter of its period
# later and a whole period later, and the model after keys and frames,
# against orrery.expected. Then a model's picture, by
# TinyLibPlayground.ml and KGraphics.ml: the screen against
# orrery.cksum (a PPM's sum, as tiny-machine -screen's).
# RECORD=1 records both (look at the picture first: KEEP=1 W=dir).
# usage: TinyAppOrrery_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyAppOrrery_tests/Host.exe}
E=$ROOT/tiny/tests/TinyAppOrrery_tests/orrery
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

$HOST $ROOT/kernels/lib_machine/font1.bin $W/orrery.ppm > $W/orrery.out 2>&1 || fail "orrery: the run"
[ -n "${RECORD:-}" ] && { cp $W/orrery.out $E.expected; cksum < $W/orrery.ppm > $E.cksum; }
if [ "$(cat $W/orrery.out)" = "$(cat $E.expected)" ]; then echo "ok orrery: its lines"; else fail "orrery: its lines"; diff $E.expected $W/orrery.out | head -10; fi
if [ "$(cksum < $W/orrery.ppm)" = "$(cat $E.cksum)" ]; then echo "ok orrery: its screen"; else fail "orrery: its screen: $(cksum < $W/orrery.ppm)"; fi

echo "$failures failure(s)"
[ $failures = 0 ]
