#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyKernelGraphics.ml: TinyKernelGraphics_tests/Picture.ml, a picture
# drawn by messages (rectangles, texts, lines, images off the screen,
# a pattern, masks, an image drawn on itself, an image freed) and the
# answers to bad ones; with font1.bin, then with grey.font (its text's
# edges mixed: picture-grey.*). The same two files run twice, for the
# same lines (picture.expected) and the same screen (picture.cksum, a
# PPM's sum):
# - on the host, built by OCaml: TinyMemory.ml's array the memory;
# - on tiny-machine, built by tiny-ml: the rows TinyKernel/draw.tm's
#   loops, the runtime TinyKernel's, the screen what -screen writes.
# RECORD=1 records the lines and the sum, from the host's (look at the
# picture first: KEEP=1 W=dir leaves picture-host.ppm and
# picture-machine.ppm there, and picture-grey-*).
# -window: no test, font1.bin's picture in tiny-machine's window (the machine's
# program, not halting after it: the window closed is its end).
# usage: TinyKernelGraphics_test.sh [-window]

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
B=$ROOT/_build/default/tiny
TML=${TML:-$B/TinyML.exe}
TC=${TC:-$B/TinyC.exe}
MACHINE=${MACHINE:-$B/TinyMachine.exe}
. $ROOT/tiny/tests/link.sh
HOST=${HOST:-$B/tests/TinyKernelGraphics_tests/Host.exe}
T=$ROOT/tiny
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# the machine's program, but for the font: the runtime, the program
$TC -o $W/runtime.tm $T/TinyKernel/runtime.c || fail "machine: tiny-c runtime.c"
# (-window: without the exit, the program ends in start.tm's loop)
sed -e 's/; exit 0$//' $T/tests/TinyKernelGraphics_tests/machine.ml > $W/machine.ml
[ "${1:-}" = -window ] || cp $T/tests/TinyKernelGraphics_tests/machine.ml $W/machine.ml
ml_lib $W/lib || fail "the library: tiny-ml"
$TML -L $W/lib -o $W/picture.tm $T/TinyKernel/TinyMemory.ml $T/TinyKernel/TinyKernelGraphics.ml $T/TinyLibDraw.ml $T/tests/TinyKernelGraphics_tests/Picture.ml $W/machine.ml || fail "machine: tiny-ml"

# [picture name font]: the picture with that font, on the host and on
# the machine, against name.expected and name.cksum
picture() {
  local E=$T/tests/TinyKernelGraphics_tests/$1 FONT=$2 R=$W/$1

  # what a run said and drew, against the recorded
  check() {
    if [ "$(cat $R-$1.out)" = "$(cat $E.expected)" ]; then echo "ok $1: its lines"; else fail "$1: its lines"; diff $E.expected $R-$1.out | head -10; fi
    if [ "$(cksum < $R-$1.ppm)" = "$(cat $E.cksum)" ]; then echo "ok $1: its screen"; else fail "$1: its screen: $(cksum < $R-$1.ppm)"; fi
  }

  [ "${WINDOW:-}" = 1 ] || {
  $HOST $FONT $R-host.ppm > $R-host.out 2>&1 || fail "host: the run"
  [ -n "${RECORD:-}" ] && { cp $R-host.out $E.expected; cksum < $R-host.ppm > $E.cksum; }
  check host
  }

  # the machine's: start.tm first (the machine starts at 0), the font's
  # bytes at its label, the runtime, the rows, the program
  (cat $T/tests/TinyKernelGraphics_tests/start.tm; echo 'font:'; od -An -v -tu1 $FONT | awk 'NF { printf "\t.byte\t%s", $1; for (i = 2; i <= NF; i++) printf ", %s", $i; print "" }'; printf 'font_end:\n\t.align\t4\n') > $R-start.tm
  link_tm $R.img $R-start.tm $T/TinyCRuntime/udivmod.tm $W/runtime.tm $T/TinyKernel/draw.tm $W/picture.tm $LIB_O || fail "machine: the link"
  [ "${WINDOW:-}" = 1 ] && { $MACHINE -window $R.img; exit; }
  timeout ${SLOW:-60} $MACHINE -screen $R-machine.ppm $R.img > $R-machine.out 2>&1 || fail "machine: the run"
  check machine
}

[ "${1:-}" = -window ] && WINDOW=1
picture picture $ROOT/kernels/lib_machine/font1.bin
picture picture-grey $T/TinyKernel/fonts/grey.font

echo "$failures failure(s)"
[ $failures = 0 ]
