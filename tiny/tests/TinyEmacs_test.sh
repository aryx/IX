#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyEmacs.ml, the editor with no screen and no file under
# it: TinyEmacs_tests/Keys.ml types keys at it and prints its screen
# after each scene (moving, C-k and C-y, Backspace, the search, a quit
# refused, a text longer and wider than the screen, tabs). Built by
# OCaml (dune), its lines against keys.expected (RECORD=1 records them:
# read them first); then built by tiny-ml -tm with TinyLibStd.ml and
# run by tiny-cpu, linked as TinyML_test.sh's programs: the same lines.
# usage: TinyEmacs_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyEmacs_tests/Keys.exe}
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
L=$ROOT/tiny/TinyCRuntime
T=$ROOT/tiny/tests/TinyEmacs_tests
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST > $W/host.out 2>&1 || { echo "FAIL keys: the run by OCaml"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/host.out $T/keys.expected
if diff $T/keys.expected $W/host.out > $W/host.diff; then echo "ok keys: by OCaml"; else echo "FAIL keys: by OCaml"; head -10 $W/host.diff; failures=$((failures + 1)); fi

cat > $W/main.c <<END
#include "$ROOT/tiny/TinyMLRuntime/core.c"
static value vstack[32768];
static value space0[65536];
static value space1[65536];
void main(void) { ml_run(vstack, space0, space1, 65536, 64); flush(); exit(0); }
END
printf 'exit:\n\tldw\tr1, 0(sp)\n\tsys\t0\n' > $W/exit.tm
if $TC -tm -o $W/main.tm $W/main.c && $TML -tm -o $W/keys.tm $ROOT/tiny/TinyLibStd.ml $ROOT/tiny/TinyEmacs.ml $T/Keys.ml \
   && $CPU -o $W/keys.img $L/start.tm $L/udivmod.tm $W/exit.tm $W/keys.tm $W/main.tm \
   && timeout 120 $CPU $W/keys.img > $W/tm.out 2>&1 && diff $T/keys.expected $W/tm.out > $W/tm.diff
then echo "ok keys: by tiny-ml, on tiny-cpu"; else echo "FAIL keys: by tiny-ml, on tiny-cpu"; head -10 $W/tm.diff $W/tm.out 2>/dev/null | head -20; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]
