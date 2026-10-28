#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyML.ml: each program of languages/ml/tests/tiny/
# compiled by tiny-ml, linked by tiny-cpu with the runtime (core.c and
# a main giving it tiny-cpu's memory, by tiny-c), run by tiny-cpu, and
# its output and exit status compared with the recorded ones (prog.out,
# or prog.tiny-ml.out where tiny-ml's own behavior is another: an index
# out of bounds a fatal error, the order of a.(i) <- v's operands,
# max_int of 31 bits). They were ocaml-light's ocamlopt's; RECORD=1
# records them again, from the ocamlfind ocamlopt in the PATH (OCaml's:
# what TinyML_fuzz.py's programs need, make test-ocaml). Then the
# collector's law: each program again with a heap of 64 words, where it
# collects all the time, the same output. Not gc (its lists are deeper
# than tiny-cpu's 1 MB holds). A program with an integer beyond 31 bits
# is refused (TinyCPU is 32 bits), and said so. Last, what tiny-ml reads
# and forgets (TinyML_tests/forgotten.ml: a capability's type, a
# coercion to one): the same code as a program without it.
# usage: TinyML_test.sh [prog.ml...]

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
. $ROOT/tiny/tests/link.sh
W=${W:-$(mktemp -d)}; mkdir -p $W
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
progs=("$@")

# the runtime: core.c, its memory a main's (the heap from 4096 words,
# or from 64), exit tiny-cpu's call
L=$ROOT/tiny/TinyCRuntime
for h in 4096 64; do
  cat > $W/main$h.c <<EOC
#include "$ROOT/tiny/TinyMLRuntime/core.c"
static value vstack[32768];
static value space0[65536];
static value space1[65536];
void main(void) { ml_run(vstack, space0, space1, 65536, $h); flush(); exit(0); }
EOC
  $TC -o $W/main$h.tm $W/main$h.c || { echo "FAIL the runtime: tiny-c"; exit 1; }
done
printf 'exit:\n\tldw\tr1, 0(sp)\n\tsys\t0\n' > $W/exit.tm
ml_lib $W/lib || { echo "FAIL the library: tiny-ml"; exit 1; }

# (SLOW: tiny-cpu's seconds for a program, 60; more for tiny-cpu built
# by mini-ml, whose code is slower: SLOW=300)
T=$ROOT/languages/ml/tests/tiny
[ ${#progs[@]} = 0 ] && progs=($T/*.ml)
# a program a job, all at once; its lines in $W/$b.log, printed after,
# in the programs' order
one() {
  local ml=$1 b out want got h
  ml=$(realpath $ml); b=$(basename $ml .ml)
  [ $b = gc ] && return
  out=${ml%.ml}.out
  if [ -n "${RECORD:-}" ]; then
    (cd $W && mkdir -p $b.ref && cp $ml $b.ref/$b.ml && cd $b.ref && ocamlfind ocamlopt -o $b $b.ml 2>/dev/null) || { echo "FAIL $b: ocamlopt"; return; }
    (cd $W/$b.ref && timeout 10 ./$b 2>&1; echo "exit $?") > $out
  fi
  if ! $TML -L $W/lib -o $W/$b.tm $ml 2> $W/$b.err; then
    if grep -q "beyond 31 bits" $W/$b.err; then echo "refused $b"; else echo "FAIL $b: $(cat $W/$b.err)"; fi
    return
  fi
  [ -f ${ml%.ml}.tiny-ml.out ] && out=${ml%.ml}.tiny-ml.out
  want=$(cat $out)
  for h in 4096 64; do
    # the program before main.tm, whose arrays a jal would not jump over
    link_tm $W/$b.$h $L/start.tm $L/udivmod.tm $W/exit.tm $W/$b.tm $W/main$h.tm $LIB_O || { echo "FAIL $b: linking"; return; }
    got=$(timeout ${SLOW:-60} $CPU $W/$b.$h 2>&1; echo "exit $?")
    local tag=; [ $h = 64 ] && tag=" heap 64"
    if [ "$want" = "$got" ]; then echo "ok $b$tag"; else echo "FAIL $b$tag"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; fi
  done
}
for ml in "${progs[@]}"; do one $ml > $W/$(basename $ml .ml).log 2>&1 & done
wait
for ml in "${progs[@]}"; do cat $W/$(basename $ml .ml).log; done
failures=$(cat $W/*.log | grep -c '^FAIL')
refused=($(cat $W/*.log | sed -n 's/^refused //p' | sort))
# what is read and forgotten (ix's capabilities; TinyML_tests/forgotten.ml
# says what): the same code as without it
F=$ROOT/tiny/tests/TinyML_tests
# (each as x.ml: a unit's name is in its symbols)
mkdir -p $W/f $W/p; cp $F/forgotten.ml $W/f/x.ml; cp $F/plain.ml $W/p/x.ml
if $TML -L $W/lib -o $W/forgotten.out $W/f/x.ml && $TML -L $W/lib -o $W/plain.out $W/p/x.ml && cmp -s $W/forgotten.out $W/plain.out
then echo "ok forgotten: the code of plain.ml"; else echo "FAIL forgotten"; failures=$((failures + 1)); fi
# a program of units compiled apart (TinyML_tests/units/: Shapes, with
# its .mli, then Main), each by tiny-ml -c, its main by tiny-ml of the
# interfaces, linked: Main.out's output, as when compiled whole; and
# Shapes's unused function left out by tiny-linker
UT=$F/units; mkdir -p $W/units
if $TML -L $W/lib -c -o $W/units/Shapes.tm $UT/Shapes.ml && $TML -L $W/lib -c -o $W/units/Main.tm $W/units/Shapes.tmi $UT/Main.ml \
   && $TML -L $W/lib -o $W/units/main.tm $W/units/Shapes.tmi $W/units/Main.tmi \
   && link_tm $W/units/prog $L/start.tm $L/udivmod.tm $W/exit.tm $W/units/main.tm $W/units/Shapes.tm $W/units/Main.tm $W/main4096.tm $LIB_O \
   && [ "$(timeout 60 $CPU $W/units/prog 2>&1; echo "exit $?")" = "$(cat $UT/Main.out)" ] \
   && $TML -L $W/lib -o $W/units/whole.tm $UT/Shapes.ml $UT/Main.ml && link_tm $W/units/whole $L/start.tm $L/udivmod.tm $W/exit.tm $W/units/whole.tm $W/main4096.tm $LIB_O \
   && [ "$(timeout 60 $CPU $W/units/whole 2>&1; echo "exit $?")" = "$(cat $UT/Main.out)" ]
then echo "ok units: Shapes and Main compiled apart, and whole, Main.out's output"; else echo "FAIL units"; failures=$((failures + 1)); fi
# a unit's names are M.x in the units after it, x after open M only
printf 'let () = print_int (Shapes.area Dot)\n' > $W/units/Q.ml; printf 'let () = print_int (area Dot)\n' > $W/units/U.ml
if $TML -L $W/lib -c -o $W/units/Q.tm $W/units/Shapes.tmi $W/units/Q.ml && [ "$($TML -L $W/lib -c -o $W/units/U.tm $W/units/Shapes.tmi $W/units/U.ml 2>&1)" = "$W/units/U.ml: line 1: unbound area" ]
then echo "ok units: Shapes.area, and area unbound without open Shapes"; else echo "FAIL units: the scopes"; failures=$((failures + 1)); fi
# a name defined twice, the later is the one the units after see
printf 'let f x = x + 1\nlet f x = x * 10\n' > $W/units/Twice.ml; printf 'let () = print_int (Twice.f 3)\n' > $W/units/R.ml
if $TML -L $W/lib -c -o $W/units/Twice.tm $W/units/Twice.ml && $TML -L $W/lib -c -o $W/units/R.tm $W/units/Twice.tmi $W/units/R.ml \
   && $TML -L $W/lib -o $W/units/rmain.tm $W/units/Twice.tmi $W/units/R.tmi \
   && link_tm $W/units/twice $L/start.tm $L/udivmod.tm $W/exit.tm $W/units/rmain.tm $W/units/Twice.tm $W/units/R.tm $W/main4096.tm $LIB_O \
   && [ "$(timeout 60 $CPU $W/units/twice 2>&1)" = 30 ]
then echo "ok units: a name defined twice, the later"; else echo "FAIL units: a name defined twice"; failures=$((failures + 1)); fi
TL="$TL -map" link_tm $W/units/prog $L/start.tm $L/udivmod.tm $W/exit.tm $W/units/main.tm $W/units/Shapes.tm $W/units/Main.tm $W/main4096.tm $LIB_O
if grep -q "Shapes.f[0-9]*_area$" $W/units/prog.map && ! grep -q "_unused" $W/units/prog.map; then echo "ok units: what nothing uses left out"
else echo "FAIL units: the sweep"; failures=$((failures + 1)); fi
[ ${#refused[@]} = 0 ] || echo "refused (an integer beyond 31 bits): ${refused[*]}"
echo "$failures failure(s)"
[ $failures = 0 ]
