#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyOffice.ml, the office with no screen and no file under
# it: TinyOffice_tests/Pages.ml works at a page with the keys and the
# mouse, and prints its view after each scene (a new box typed into,
# the text filled, moved, resized, undone, saved; two boxes from a file,
# overlapping, edited, removed; a sheet, a drawing; the menus; a box
# moved and resized by its tab and its corner). Built by OCaml (dune), its lines
# against pages.expected (RECORD=1 records them: read them first); then
# built by tiny-ml with TinyLibPlayground.ml (its
# shapes; the kernel's calls under it are the host's stand-in,
# TinyKernel/host/stub/TinyCalls.ml) and TinyLibGUI.ml (its menus) and run
# by tiny-cpu: the same lines.
# usage: TinyOffice_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyOffice_tests/Pages.exe}
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
. $ROOT/tiny/tests/link.sh
L=$ROOT/tiny/TinyCRuntime
T=$ROOT/tiny/tests/TinyOffice_tests
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST > $W/host.out 2>&1 || { echo "FAIL pages: the run by OCaml"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/host.out $T/pages.expected
if diff $T/pages.expected $W/host.out > $W/host.diff; then echo "ok pages: by OCaml"; else echo "FAIL pages: by OCaml"; head -10 $W/host.diff; failures=$((failures + 1)); fi

# (the runtime's memory, 640 KB, in a file of its own, linked last: a
# call reaches 128 KB, and the code on either side of it would be too
# far apart, _start from main or main from the ML code)
cat > $W/main.c <<END
#include "$ROOT/tiny/TinyMLRuntime/core.c"
extern value vstack[];
extern value space0[];
extern value space1[];
void main(void) { ml_run(vstack, space0, space1, 65536, 64); flush(); exit(0); }
END
printf 'typedef int value;\nvalue vstack[32768];\nvalue space0[65536];\nvalue space1[65536];\n' > $W/data.c
printf 'exit:\n\tldw\tr1, 0(sp)\n\tsys\t0\n' > $W/exit.tm
if ml_lib $W/lib && $TC -o $W/main.tm $W/main.c && $TC -o $W/data.tm $W/data.c \
   && $TML -L $W/lib -o $W/pages.tm $ROOT/tiny/TinyKernel/host/stub/TinyCalls.ml $ROOT/tiny/TinyLibDraw.ml $ROOT/tiny/TinyLibPlayground.ml $ROOT/tiny/TinyLibGUI.ml $ROOT/tiny/TinyOffice.ml $T/Pages.ml \
   && link_tm $W/pages.img $L/start.tm $L/udivmod.tm $W/exit.tm $W/main.tm $W/pages.tm $W/data.tm $LIB_O \
   && timeout 120 $CPU $W/pages.img > $W/tm.out 2>&1 && diff $T/pages.expected $W/tm.out > $W/tm.diff
then echo "ok pages: by tiny-ml, on tiny-cpu"; else echo "FAIL pages: by tiny-ml, on tiny-cpu"; head -10 $W/tm.diff $W/tm.out 2>/dev/null | head -20; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]
