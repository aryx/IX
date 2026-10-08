#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyGraphics.ml: TinyGraphics_tests/Picture.ml, a picture
# drawn by messages (rectangles, texts, lines, images off the screen,
# a pattern, masks, an image drawn on itself, an image freed) and the
# answers to bad ones. The same two files run twice, for the same lines
# (picture.expected) and the same screen (picture.cksum, a PPM's sum):
# - on the host, built by OCaml: TinyMemory.ml's array the memory;
# - on tiny-machine, built by tiny-ml -tm: the rows TinyKernel/draw.tm's
#   loops, the runtime TinyKernel's, the screen what -screen writes.
# RECORD=1 records the lines and the sum, from the host's (look at the
# picture first: KEEP=1 W=dir leaves host.ppm and machine.ppm there).
# -window: no test, the picture in tiny-machine's window (the machine's
# program, not halting after it: the window closed is its end).
# usage: TinyGraphics_test.sh [-window]

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
B=$ROOT/_build/default/tiny
TML=${TML:-$B/TinyML.exe}
TC=${TC:-$B/TinyC.exe}
MACHINE=${MACHINE:-$B/TinyMachine.exe}
HOST=${HOST:-$B/tests/TinyGraphics_tests/Host.exe}
T=$ROOT/tiny
E=$T/tests/TinyGraphics_tests/picture
FONT=$ROOT/kernels/lib_machine/font1.bin
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# what a run said and drew, against the recorded
check() {
  if [ "$(cat $W/$1.out)" = "$(cat $E.expected)" ]; then echo "ok $1: its lines"; else fail "$1: its lines"; diff $E.expected $W/$1.out | head -10; fi
  if [ "$(cksum < $W/$1.ppm)" = "$(cat $E.cksum)" ]; then echo "ok $1: its screen"; else fail "$1: its screen: $(cksum < $W/$1.ppm)"; fi
}

[ "${1:-}" = -window ] || {
$HOST $FONT $W/host.ppm > $W/host.out 2>&1 || fail "host: the run"
[ -n "${RECORD:-}" ] && { cp $W/host.out $E.expected; cksum < $W/host.ppm > $E.cksum; }
check host
}

# the machine's: start.tm first (the machine starts at 0), the font's
# bytes at its label, the runtime, the rows, the program
(cat $T/tests/TinyGraphics_tests/start.tm; echo 'font:'; od -An -v -tu1 -w16 $FONT | sed -e 's/^ */\t.byte\t/' -e 's/  */, /g'; printf '\t.align\t4\n') > $W/start.tm
$TC -tm -o $W/runtime.tm $T/TinyKernel/runtime.c || fail "machine: tiny-c -tm runtime.c"
# (-window: without the exit, the program ends in start.tm's loop)
sed -e 's/; exit 0$//' $T/tests/TinyGraphics_tests/machine.ml > $W/machine.ml
[ "${1:-}" = -window ] || cp $T/tests/TinyGraphics_tests/machine.ml $W/machine.ml
$TML -tm -o $W/picture.tm $T/TinyKernel/memory.ml $T/TinyGraphics.ml $T/TinyDraw.ml $T/tests/TinyGraphics_tests/Picture.ml $W/machine.ml || fail "machine: tiny-ml -tm"
[ "${1:-}" = -window ] && { $MACHINE -window $W/start.tm $T/tiny-os/libc/udivmod.tm $W/runtime.tm $T/TinyKernel/draw.tm $W/picture.tm; exit; }
timeout ${SLOW:-60} $MACHINE -screen $W/machine.ppm $W/start.tm $T/tiny-os/libc/udivmod.tm $W/runtime.tm $T/TinyKernel/draw.tm $W/picture.tm > $W/machine.out 2>&1 || fail "machine: the run"
check machine

echo "$failures failure(s)"
[ $failures = 0 ]
