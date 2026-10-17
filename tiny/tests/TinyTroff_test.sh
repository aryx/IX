#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyTroff.ml: TinyTroff_tests/Print.ml prints a page of
# the four kinds (a text with its styles, a sheet with a formula and an
# error, a drawing, a paint) as text and as HTML, and a Markdown file as
# text. Built by OCaml (dune), its lines against print.expected
# (RECORD=1 records them: read them first); then built by tiny-ml -tm
# with TinyLibStd.ml, TinyLibDraw.ml, TinyLibPlayground.ml, TinyLibGUI.ml
# (which TinyOffice.ml is on; the kernel's calls under them the host's
# stand-in, TinyKernel/host/stub/TinyCalls.ml) and TinyOffice.ml, and run by
# tiny-cpu: the same lines.
# usage: TinyTroff_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyTroff_tests/Print.exe}
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
L=$ROOT/tiny/TinyCRuntime
T=$ROOT/tiny/tests/TinyTroff_tests
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST > $W/host.out 2>&1 || { echo "FAIL print: the run by OCaml"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/host.out $T/print.expected
if diff $T/print.expected $W/host.out > $W/host.diff; then echo "ok print: by OCaml"; else echo "FAIL print: by OCaml"; head -10 $W/host.diff; failures=$((failures + 1)); fi

# (the runtime's memory, 640 KB, in a file of its own, linked last: a
# call reaches 128 KB, and the code on either side of it would be too
# far apart)
cat > $W/main.c <<END
#include "$ROOT/tiny/TinyMLRuntime/core.c"
extern value vstack[];
extern value space0[];
extern value space1[];
void main(void) { ml_run(vstack, space0, space1, 65536, 64); flush(); exit(0); }
END
printf 'typedef int value;\nvalue vstack[32768];\nvalue space0[65536];\nvalue space1[65536];\n' > $W/data.c
printf 'exit:\n\tldw\tr1, 0(sp)\n\tsys\t0\n' > $W/exit.tm
if $TC -tm -o $W/main.tm $W/main.c && $TC -tm -o $W/data.tm $W/data.c \
   && $TML -tm -o $W/print.tm $ROOT/tiny/TinyLibStd.ml $ROOT/tiny/TinyKernel/host/stub/TinyCalls.ml $ROOT/tiny/TinyLibDraw.ml $ROOT/tiny/TinyLibPlayground.ml $ROOT/tiny/TinyLibGUI.ml $ROOT/tiny/TinyOffice.ml $ROOT/tiny/TinyTroff.ml $T/Print.ml \
   && $CPU -o $W/print.img $L/start.tm $L/udivmod.tm $W/exit.tm $W/main.tm $W/print.tm $W/data.tm \
   && timeout 120 $CPU $W/print.img > $W/tm.out 2>&1 && diff $T/print.expected $W/tm.out > $W/tm.diff
then echo "ok print: by tiny-ml, on tiny-cpu"; else echo "FAIL print: by tiny-ml, on tiny-cpu"; head -10 $W/tm.diff $W/tm.out 2>/dev/null | head -20; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]
