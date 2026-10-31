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
# functions and lines only (the offsets are mini-ml's code of the day,
# runtime.c's lines its file's of the day).
# And an uncaught exception (stage 5a: fault/Raise.ml), its frames
# walked and named by the program's runtime from its own table
# (frames.c, the image's /proc/$pid/text: mini-5i's); its arguments
# by their types (stage 5: fault/Typed.ml by mini-ml -g, its
# descriptions in the program, typed.c), by their words without them,
# and a Unix_error by its message (fault/Missing.ml: Unix's printer);
# the raise's line of code (stage 5b: source.c), from this checkout as
# from the card's /src, none from a copy whose MD5 is not the unit's.
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
  # a unit linked with its tables: $W/its name in lower case (with
  # mini-ml's flags $2: -g)
  ml() {
    $IX/languages/ml/Main.exe -m 5 -O3 $2 $I -o $W/$1.5 $F/$1.ml \
     && (cd $W && $IX/languages/ml/Main.exe -m 5 -O3 -start $U $1 Std_exit -o $W/$1.start.5) \
     && $IX/linker/Main.exe -m 5 -g -H2 -nofollow -o $W/${1,,}ml $W/$1.start.5 \
          $M/lib_core/lib_core.a $W/$1.5 \
          $M/lib_core/std_exit.5 $M/lib_core/runtime.5 $M/lib_core/libc.a > $W/err 2>&1 \
     || { n=$((n + 1)); failures=$((failures + 1))
          echo "FAIL $1.ml's build: $(head -2 $W/err)"; return 1; }
  }
  if ml Deep; then
    same "a fault in ML: mini-ml's frames, the runtime's C, to _main" \
      "f2_down Deep.ml:5 < f2_down Deep.ml:5 < f2_down Deep.ml:5 < f2_down Deep.ml:5 < Deep.Init Deep.ml:7 < ml_program < main runtime.c < _main rt0.s:17" \
      "$($IX/machine/Main.exe $W/deepml 2>&1 | grep trace: | sed 's/^mini-5i: trace: //; s/+0x[0-9a-f]*//g; s/runtime.c:[0-9]*/runtime.c/')"
  fi
  if ml Raise; then
    same "an uncaught exception in ML: its frames named by the runtime, to _main" \
      "Fatal error: uncaught exception Deep(7)
raised at: f1_down Raise.ml:6 < f1_down Raise.ml:6 < f1_down Raise.ml:6 < f1_down Raise.ml:6 < Raise.Init Raise.ml:8 < ml_program < main runtime.c < _main rt0.s:17" \
      "$($IX/machine/Main.exe $W/raiseml 2>&1 | sed 's/+0x[0-9a-f]*//g; s/runtime.c:[0-9]*/runtime.c/')"
  fi
  if ml Typed -g; then
    same "an exception's arguments by their types: a variant, a record, a list, an option" \
      'Fatal error: uncaught exception Bad(Rect (3, -4), {x = 1; y = 2; name = "origin"}, [1; 2], Some "why")' \
      "$($IX/machine/Main.exe $W/typedml 2>&1 | head -1)"
    same "the raise's line of code, from ix's sources (\$ML_SRC: the card's /src), its MD5 the unit's" \
      'Typed.ml:10  let check n = if n > 2 then raise (Bad (Rect (3, -4), { x = 1; y...' \
      "$(ML_SRC=$ROOT $IX/machine/Main.exe $W/typedml 2>&1 | sed -n 3p)"
    mkdir -p $W/stale/debuggers/tests/fault
    (cat $F/Typed.ml; echo '(* changed *)') > $W/stale/debuggers/tests/fault/Typed.ml
    same "no line of code from a source of another day" "2" \
      "$(ML_SRC=$W/stale $IX/machine/Main.exe $W/typedml 2>&1 | wc -l)"
  fi
  if ml Typed; then
    same "an exception's arguments by their words, its unit without -g" \
      'Fatal error: uncaught exception Bad(#1(3, -4), (1, 2, "origin"), (1, (2, 0)), ("why"))' \
      "$($IX/machine/Main.exe $W/typedml 2>&1 | head -1)"
  fi
  if ml Missing; then
    same "a Unix_error by its message" \
      'Fatal error: uncaught exception Unix_error(file does not exist, "open", "/no/such/file")' \
      "$($IX/machine/Main.exe $W/missingml 2>&1 | head -1)"
  fi
else echo "skipped the ML case: no _mk/5-plan9/lib_core (mini-mk O=5 OS=plan9 in lib_core)"; fi
echo "walk: $n cases, $failures failure(s)"
[ $failures = 0 ]
