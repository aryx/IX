#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml -dotnet's tests (docs/plans/plan_dotnet_languages.md, stages
# 1a to 1d): each program here compiled to an assembly, verified by
# mini-dotnet (-verify: every method passes), run, against what OCaml
# prints for it (the .expected files, made by ocaml file.ml, then read);
# by dune's mini-ml and mini-dotnet, and by mini-ml's own (_mk/7), and
# its mini-dotnet's JIT (arm64);
# Microsoft's dotnet too with -ms (not in make test: it needs the SDK).
# And what is refused, each with its message (refused.expected); with
# -ms, C# using an ML unit (interop.cs on shapes.ml), by Microsoft's
# compiler and runtime (mini-dotnet runs one assembly: stage 7).
#   fib       recursion, a unit's function called by its toplevel
#   arith     int64's arithmetic as OCaml's, floats by conversions, the
#             comparisons (a float's NaN unordered)
#   strings   ^, String.length, comparisons by the text, chars printed
#   loops     for up and down, && and || short, a value of the unit
#   variants  constructors, a recursive type, match, guards, or-patterns,
#             ranges, a function of several cases
#   records   fields read, set, copied by with, matched
#   exceptions  raise, try, handlers' cases, failwith, Not_found, a
#             division by zero (.NET's own exception), one let through
#   equality  = on records and variants by their contents (Equals), ==
#   closures  lambdas, captures, partial application, functions as
#             values, a local let rec, curried, unit arguments
#   generics  polymorphic functions as generic methods, each call its
#             instantiation; = on a type variable
#   generic_types  types of parameters as generic classes (a tree, a
#             record), ref and option, = and < on their values
#   tuples_lists  tuples and lists (Stdlib.tuple`n, Stdlib.list`1):
#             built, matched, given to generic functions, compared
#   arrays    T[]: literals, a.(i), a.(i) <- v, Array.length, a sort
#   generic_closures  closures inside polymorphic functions (generic
#             classes), local polymorphic functions at their use's type,
#             polymorphic functions partly applied, a library function
#             as a value
#   tails     tail calls: loops of a hundred thousand turns as tail
#             recursions (direct, mutual, over a list, through a Func)
#   externals  externals naming .NET members (decision 7): String's,
#             Console's; int32 and char converted (externals.expected
#             written by hand: ocaml has no .NET)
#   c_externals  the runtime unit (lib_core/dotnet/Runtime.ml): the math
#             functions, frexp, modf, int_of_string, float_of_string,
#             format_int, format_float (c_externals.expected: C's printf
#             and strtod, by Python's; .NET's int64 where they differ)
#   channels  the runtime unit's channels over .NET's Streams: the
#             console's, a file written, read, sought, appended to (in
#             the scratch directory, where the programs run), sys_open's
#             errors, the standard input (channels.in); bytes a byte[]
#   library   lib_core's units compiled with the program (stage 3c): List,
#             String, Bytes, Buffer, Printf (literal formats compiled),
#             Hashtbl, Array, Char, Option; compare's structural order
#   formats   formats as values: a literal compiled to a function of where
#             its text goes, Printf's and Format's over it (lib_core/dotnet/
#             *_dotnet.ml), ix's Logs (formats.expected: OCaml's for the
#             lines before Logs, ix's own)
#   frontend  what mini-cc's front end asked: a local function at
#             several types, compare a polymorphic value, %a %t %h %S %C,
#             |> and @@, a polymorphic toplevel value, int64 and float
#             patterns, a primitive partly applied, a unit matched
#   units/    three units in one assembly (geometry, counter, main): one
#             unit's values, functions, types, constructors, exception
#             from another; the toplevels in link order (what OCaml's
#             own compiler's program prints: program.expected)
# usage: languages/ml/dotnet/tests/run.sh [-dune] [-mini] [-ms] [-record]
#   (dune build, and mini-mk in languages/ml and languages/dotnet, first)
# MINIML, MINIDOTNET: mini-ml's builds, if not _mk/7's (ix built by
# ix: its own); DUNEML, DUNEDOTNET: dune's, if not _build's.
cd "$(dirname "$0")/../../../.."
record=; only=; ms=
for a in "$@"; do
  case $a in
    -record) record=1;;
    -dune) only=dune;;
    -mini) only=mini;;
    -ms) ms=1;;
  esac
done
T=languages/ml/dotnet/tests
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
ok() { echo "ok $*"; }
abs() { case $1 in /*) echo $1;; *) echo $PWD/$1;; esac; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
progs="fib arith strings loops variants records exceptions equality closures generics generic_types tuples_lists arrays tails generic_closures externals c_externals channels library formats frontend"
# what is refused: a program a line, and the stage that will have it
refused() {
  local ml=$1 n=0
  while IFS= read -r line; do
    n=$((n + 1)); echo "$line" > $W/r$n.ml
    echo "-- $line"
    $ml -L lib_core -dotnet -o $W/r$n.dll $W/r$n.ml 2>&1 | sed "s|$W/||"
  done <<'R'
type t = A of { a : int } let v = A { a = 1 }
let () = Printf.printf "%a" (fun oc () -> output_string oc "x") ()
let f () = Obj.size (Obj.repr 1)
R
}
check() {
  local what=$1 ml=$2 dotnet=$3
  [ -x $ml ] && [ -x $dotnet ] || { echo "skipped: $what is not built"; return; }
  for p in $progs; do
    if ! $ml -L lib_core -dotnet -o $W/$p.dll $T/$p.ml 2> $W/$p.err; then fail "mini-ml -dotnet $p, by $what"; head -3 $W/$p.err; continue; fi
    case "$($DOTNET -verify $W/$p.dll | tail -1)" in
      *" 0 refused") ;; *) fail "mini-ml -dotnet $p, verified"; $DOTNET -verify $W/$p.dll | head -3;; esac
    in=/dev/null; [ -f $T/$p.in ] && in=$PWD/$T/$p.in
    run=$(abs $dotnet)
    (cd $W && $run $p.dll < $in) > $W/$p.out 2> $W/$p.err
    if cmp -s $W/$p.out $T/$p.expected; then ok "mini-ml -dotnet $p, run by $what"
    else fail "mini-ml -dotnet $p, run by $what"; diff $T/$p.expected $W/$p.out | head -5; head -3 $W/$p.err; fi
  done
  local U=$T/units
  if $ml -L lib_core -dotnet -o $W/program.dll $U/geometry.ml $U/counter.ml $U/main.ml 2> $W/units.err &&
     $dotnet $W/program.dll > $W/units.out 2>&1 && cmp -s $W/units.out $U/program.expected; then
    ok "mini-ml -dotnet: three units in one assembly, run by $what"
  else fail "mini-ml -dotnet: three units in one assembly, run by $what"; head -3 $W/units.err; diff $U/program.expected $W/units.out | head -5; fi
  refused $ml > $W/refused.out
  if [ -n "$record" ]; then cp $W/refused.out $T/refused.expected
  elif cmp -s $W/refused.out $T/refused.expected; then ok "mini-ml -dotnet: what it refuses, by $what"
  else fail "mini-ml -dotnet: what it refuses, by $what"; diff $T/refused.expected $W/refused.out | head -5; fi
}
# C# using an ML unit: Microsoft's csc against shapes.dll, run by its dotnet
interop() {
  local ml=$1 sdk rt refs=
  sdk=$(dotnet --list-sdks 2>/dev/null | tail -1 | sed 's/ \[\(.*\)\]/ \1/' | awk '{print $2 "/" $1}')
  rt=$(dotnet --list-runtimes 2>/dev/null | grep NETCore.App | tail -1 | sed 's/ \[\(.*\)\]/ \1/' | awk '{print $3 "/" $2}')
  [ -f "$sdk/Roslyn/bincore/csc.dll" ] || { echo "skipped: C# using an ML unit (no SDK)"; return; }
  for a in System.Runtime System.Console System.Private.CoreLib; do refs="$refs -r:$rt/$a.dll"; done
  $ml -L lib_core -dotnet -o $W/shapes.dll $T/shapes.ml &&
  dotnet $sdk/Roslyn/bincore/csc.dll -nologo -nostdlib -debug- $refs -r:$W/shapes.dll -out:$W/interop.dll $T/interop.cs > $W/csc.out 2>&1 &&
  cp $W/shapes.runtimeconfig.json $W/interop.runtimeconfig.json &&
  (cd $W && dotnet interop.dll) > $W/interop.out 2>&1
  if cmp -s $W/interop.out $T/interop.expected; then ok "C# using an ML unit (shapes.ml): Microsoft's csc and dotnet"
  else fail "C# using an ML unit (shapes.ml)"; head -5 $W/csc.out; diff $T/interop.expected $W/interop.out | head -5; fi
  # (two assemblies in mini-dotnet: interop.dll's reference to shapes.dll
  # loaded from beside it, stage 7)
  (cd $W && $(abs $DOTNET) interop.dll) > $W/interop.mini.out 2>&1
  if cmp -s $W/interop.mini.out $T/interop.expected; then ok "C# using an ML unit, two assemblies run by mini-dotnet"
  else fail "C# using an ML unit, run by mini-dotnet"; diff $T/interop.expected $W/interop.mini.out | head -5; fi
}
# mini-cc's own front end compiled to .NET (plan's stage 8 begun): mini-cc
# whole, its units in its mkfile's order (the parser and lexer
# mini-yacc's and mini-lex's, ix's build's), its -facts and -flow of
# languages/c/facts/tests/' programs what the native mini-cc writes
front_end() {
  local ml=$1 run=$2 what=$3 C=languages/c P=_mk/7/languages/c u f files=
  [ -f $P/Parser.ml ] && [ -f $P/Lexer.ml ] || { echo "skipped: mini-cc to .NET ($P's Parser.ml not built)"; return; }
  for u in Asm Show_asm $(sed -n '/^SRC=/,/[^\\]$/p' $C/mkfile | sed 's/^SRC=//; s/\\$//'); do
    # (the first there, in this order: ls would sort them)
    for f in $C/$u.ml $C/*/$u.ml lib_code/$u.ml assembler/$u.ml languages/dotnet/assembly/$u.ml $P/$u.ml; do [ -f $f ] && break; done
    files="$files $(realpath $f)"
  done
  local mla=$(abs $ml)
  if ! (cd $C && $mla -L ../../lib_core -I . -I ../../assembler -I debug -I compat -I simple -I opti -I ssa -I facts -I dotnet -I ../dotnet/assembly \
          -I ../../lib_code -I ../../$P -dotnet -o $W/mini-cc.dll $files) > $W/cc.err 2>&1; then
    fail "mini-cc compiled to .NET, by $what"; head -3 $W/cc.err; return
  fi
  local r=$(abs $run) T=$PWD/$C/facts/tests
  for t in "facts pointers" "flow flow"; do
    set -- $t
    (cd $W && $r mini-cc.dll -m 7 -$1 $T/$2.c) > $W/cc.out 2>&1
    if cmp -s $W/cc.out $T/$2.facts; then ok "mini-cc compiled to .NET: -$1 $2.c as the native mini-cc, run by $what"
    else fail "mini-cc compiled to .NET: -$1 $2.c, run by $what"; diff $T/$2.facts $W/cc.out | head -5; fi
  done
}
# the analysis's pipeline on .NET: mini-datalog compiled too, and
# languages/c/facts/tests/run.sh with both assemblies (CC, DATALOG): its
# facts and the pointer analysis's and liveness's answers the native's
# (with -ms: Microsoft's dotnet, 18 s; mini-dotnet's interpreter takes 81)
pipeline() {
  local ml=$(abs $1) run=$2 D=languages/datalog P=_mk/7/languages/datalog u f files=
  [ -f $W/mini-cc.dll ] || { echo "skipped: the pipeline (mini-cc not compiled)"; return; }
  for u in $(sed -n '/^SRC=/,/[^\\]$/p' $D/mkfile | sed 's/^SRC=//; s/\\$//'); do
    for f in $D/$u.ml $D/dotnet/$u.ml languages/prolog/$u.ml languages/dotnet/assembly/$u.ml $P/$u.ml; do [ -f $f ] && break; done
    files="$files $(realpath $f)"
  done
  if ! (cd $D && $ml -L ../../lib_core -I . -I ../prolog -I dotnet -I ../dotnet/assembly -I ../../$P -dotnet -o $W/mini-datalog.dll $files) > $W/dl.err 2>&1; then
    fail "mini-datalog compiled to .NET"; head -3 $W/dl.err; return
  fi
  if CC="$run $W/mini-cc.dll" DATALOG="$run $W/mini-datalog.dll" languages/c/facts/tests/run.sh > $W/pipeline.out 2>&1; then
    ok "the facts pipeline on .NET: mini-cc's facts, mini-datalog's pointer analysis and liveness, the native's, by $3"
  else fail "the facts pipeline on .NET, by $3"; grep -v '^ok' $W/pipeline.out | head -5; fi
}
ML=${DUNEML:-_build/default/languages/ml/Main.exe}
DOTNET=${DUNEDOTNET:-_build/default/languages/dotnet/Main.exe}
if [ -n "$record" ]; then check dune $ML $DOTNET; exit 0; fi
if [ "$only" != mini ]; then
  check "dune's mini-ml and mini-dotnet" $ML $DOTNET
  if [ -n "$ms" ]; then
    if command -v dotnet > /dev/null; then check "dune's mini-ml, Microsoft's dotnet" $ML $(command -v dotnet); interop $ML
      front_end $ML $(command -v dotnet) "Microsoft's dotnet"
      pipeline $ML $(command -v dotnet) "Microsoft's dotnet"
    else echo "skipped: Microsoft's dotnet (none here)"; fi
  fi
fi
[ "$only" != dune ] && check "mini-ml's mini-ml and mini-dotnet" ${MINIML:-_mk/7/languages/ml/mini-ml} ${MINIDOTNET:-_mk/7/languages/dotnet/mini-dotnet}
[ "$only" != dune ] && front_end $ML ${MINIDOTNET:-_mk/7/languages/dotnet/mini-dotnet} "mini-ml's mini-dotnet"
# the same by mini-dotnet's JIT (mini-ml's build has one on arm64: an
# int64 the code's own, Jit's L), where there is one
MD=$(abs ${MINIDOTNET:-_mk/7/languages/dotnet/mini-dotnet})
if [ "$only" != dune ] && [ -x $MD ] && $MD -jit -tier 0 -s languages/dotnet/tests/jit/zero.dll 2>&1 >/dev/null | grep -q "methods compiled"; then
  printf '#!/bin/sh\nexec %s -jit "$@"\n' $MD > $W/jit.sh; chmod +x $W/jit.sh
  check "mini-ml's mini-ml and mini-dotnet's JIT" ${MINIML:-_mk/7/languages/ml/mini-ml} $W/jit.sh
fi
exit $failures
