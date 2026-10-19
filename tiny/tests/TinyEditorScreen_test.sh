#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyEditorScreen.ml, the editor with no screen and no file under
# it: TinyEditorScreen_tests/Keys.ml types keys at it and prints its screen
# after each scene (moving, C-k and C-y, Backspace, the search, a quit
# refused, a text longer and wider than the screen, tabs). Built by
# OCaml (dune), its lines against keys.expected (RECORD=1 records them:
# read them first); then built by tiny-ml with TinyLibStd.ml and
# TinyLibPlayground.ml (its shapes; the kernel's calls under it are the
# host's stand-in, TinyKernel/host/stub/TinyCalls.ml) and run by tiny-cpu,
# linked as TinyML_test.sh's programs: the same lines.
# usage: TinyEditorScreen_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyEditorScreen_tests/Keys.exe}
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
. $ROOT/tiny/tests/link.sh
L=$ROOT/tiny/TinyCRuntime
T=$ROOT/tiny/tests/TinyEditorScreen_tests
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST > $W/host.out 2>&1 || { echo "FAIL keys: the run by OCaml"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/host.out $T/keys.expected
if diff $T/keys.expected $W/host.out > $W/host.diff; then echo "ok keys: by OCaml"; else echo "FAIL keys: by OCaml"; head -10 $W/host.diff; failures=$((failures + 1)); fi

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
if $TC -o $W/main.tm $W/main.c && $TC -o $W/data.tm $W/data.c && $TML -o $W/keys.tm $ROOT/tiny/TinyLibStd.ml $ROOT/tiny/TinyKernel/host/stub/TinyCalls.ml $ROOT/tiny/TinyLibDraw.ml $ROOT/tiny/TinyLibPlayground.ml $ROOT/tiny/TinyEditorScreen.ml $T/Keys.ml \
   && link_tm $W/keys.img $L/start.tm $L/udivmod.tm $W/exit.tm $W/main.tm $W/keys.tm $W/data.tm \
   && timeout 120 $CPU $W/keys.img > $W/tm.out 2>&1 && diff $T/keys.expected $W/tm.out > $W/tm.diff
then echo "ok keys: by tiny-ml, on tiny-cpu"; else echo "FAIL keys: by tiny-ml, on tiny-cpu"; head -10 $W/tm.diff $W/tm.out 2>/dev/null | head -20; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]
