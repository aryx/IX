#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The stack walked at a fault (plan_debugger.md's stage 3: lib_executable's
# Frames, by mini-5i): a Plan 9 program linked with its tables (mini-ld
# -g) that dies three calls deep, its trace line as recorded. In
# assembly (fault/deep.s: a frame of 5l's, a leaf), always; in ML
# (fault/Deep.ml: mini-ml's frames, read by their prologues, then the
# runtime's C to _main) when _mk/5-plan9's lib_core is built, its
# functions and lines only (the offsets are mini-ml's code of the day).
# usage: debuggers/tests/walk.sh

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
F=$ROOT/debuggers/tests/fault
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
n=0; failures=0
same() {   # what, expected, got
  n=$((n + 1))
  if [ "$2" != "$3" ]; then failures=$((failures + 1)); echo "FAIL $1"; diff <(echo "$2") <(echo "$3") | head -6; fi
}
cp $F/deep.s $W/
(cd $W && $IX/assembler/Main.exe -m 5 -o deep.5 deep.s && $IX/linker/Main.exe -m 5 -g -H2 -o deep deep.5) || { echo "FAIL the link"; exit 1; }
same "a fault in assembly: the leaf, its caller's frame, _main" \
  "mini-5i: trace: g+0x4 deep.s:17 < f+0xc deep.s:12 < _main+0x8 deep.s:6" \
  "$(cd $W && $IX/machine/Main.exe deep 2>&1 | grep trace:)"

M=$ROOT/_mk/5-plan9
if [ -f $M/lib_core/lib_core.a ]; then
  L=$ROOT/lib_core
  I="-I $F -I $L/system/plan9 -I $L/core -I $L/base -I $L/collections -I $L/printing -I $L/parsing -I $L/system -I $L/concurrency -I $L/commons"
  # (the start's units: lib_core's, as mkfiles/units.rc names them)
  U=$($ROOT/bin/mini-ar t $M/lib_core/lib_core.a | sed 's,.*/,,; s,\.ml$,,' | tr '\n' ' ')
  if $IX/languages/ml/Main.exe -m 5 -O3 $I -o $W/Deep.5 $F/Deep.ml \
     && (cd $W && $IX/languages/ml/Main.exe -m 5 -O3 -start $U Deep Std_exit -o $W/Deep.start.5) \
     && $IX/linker/Main.exe -m 5 -g -H2 -nofollow -o $W/deepml $W/Deep.start.5 $M/lib_core/lib_core.a $W/Deep.5 \
          $M/lib_core/std_exit.5 $M/lib_core/runtime.5 $M/lib_core/libc.a > $W/err 2>&1; then
    same "a fault in ML: mini-ml's frames, the runtime's C, to _main" \
      "f2_down Deep.ml:5 < f2_down Deep.ml:5 < f2_down Deep.ml:5 < f2_down Deep.ml:5 < Deep.Init < ml_program < main < _main" \
      "$($IX/machine/Main.exe $W/deepml 2>&1 | grep trace: | sed 's/^mini-5i: trace: //; s/+0x[0-9a-f]*//g')"
  else n=$((n + 1)); failures=$((failures + 1)); echo "FAIL the ML program's build: $(head -2 $W/err)"; fi
else echo "skipped the ML case: no _mk/5-plan9/lib_core (mini-mk O=5 OS=plan9 in lib_core)"; fi
echo "walk: $n cases, $failures failure(s)"
[ $failures = 0 ]
