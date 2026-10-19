#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyLibStd.ml: TinyLibStd_tests/std.ml calls each of its
# functions and prints the result. OCaml runs the program on its own
# standard library, which says what to expect (std.expected, recorded
# by RECORD=1 with the ocaml that is in the PATH); tiny-ml builds it
# with TinyLibStd.ml before it, and tiny-cpu runs it (linked as
# TinyML_test.sh's programs): the same lines.
# usage: TinyLibStd_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
. $ROOT/tiny/tests/link.sh
L=$ROOT/tiny/TinyCRuntime
T=$ROOT/tiny/tests/TinyLibStd_tests
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT

[ -n "${RECORD:-}" ] && ocaml $T/std.ml > $T/std.expected
cat > $W/main.c <<END
#include "$ROOT/tiny/TinyMLRuntime/core.c"
static value vstack[32768];
static value space0[65536];
static value space1[65536];
void main(void) { ml_run(vstack, space0, space1, 65536, 64); flush(); exit(0); }
END
printf 'exit:\n\tldw\tr1, 0(sp)\n\tsys\t0\n' > $W/exit.tm
$TC -o $W/main.tm $W/main.c || { echo "FAIL the runtime: tiny-c"; exit 1; }
$TML -o $W/std.tm $ROOT/tiny/TinyLibStd.ml $T/std.ml || { echo "FAIL std: tiny-ml"; exit 1; }
link_tm $W/std.img $L/start.tm $L/udivmod.tm $W/exit.tm $W/std.tm $W/main.tm || { echo "FAIL std: linking"; exit 1; }
timeout 60 $CPU $W/std.img > $W/std.out 2>&1
if diff $T/std.expected $W/std.out; then echo "ok std: OCaml's lines"; else echo "FAIL std"; exit 1; fi
