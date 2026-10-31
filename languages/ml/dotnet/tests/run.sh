#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml -dotnet's tests (docs/plans/plan_dotnet_languages.md, stages
# 1a to 1d): each program here compiled to an assembly, verified by
# mini-dotnet (-verify: every method passes), run, against what OCaml
# prints for it (the .expected files, made by ocaml file.ml, then read);
# by dune's mini-ml and mini-dotnet, and by mini-ml's own (_mk/7);
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
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
progs="fib arith strings loops variants records exceptions equality closures generics generic_types tuples_lists arrays"
# what is refused: a program a line, and the stage that will have it
refused() {
  local ml=$1 n=0
  while IFS= read -r line; do
    n=$((n + 1)); echo "$line" > $W/r$n.ml
    echo "-- $line"
    $ml -L lib_core -dotnet -o $W/r$n.dll $W/r$n.ml 2>&1 | sed "s|$W/||"
  done <<'R'
let a = Array.make 3 0
let twice f x = f (f x) let g = twice
type t = { a : int } let b = { a = 1 } < { a = 2 }
let () = let rec even n = n = 0 || odd (n - 1) and odd n = n <> 0 && even (n - 1) in print_int (if even 4 then 1 else 0)
let id x = x
let twice_all f l = let g x = f (f x) in g l
let () = print_float 1.5
let x = 1 + (try 2 with Not_found -> 3)
type t = A of { a : int } let v = A { a = 1 }
R
}
check() {
  local what=$1 ml=$2 dotnet=$3
  [ -x $ml ] && [ -x $dotnet ] || { echo "skipped: $what is not built"; return; }
  for p in $progs; do
    if ! $ml -L lib_core -dotnet -o $W/$p.dll $T/$p.ml 2> $W/$p.err; then fail "mini-ml -dotnet $p, by $what"; head -3 $W/$p.err; continue; fi
    case "$($DOTNET -verify $W/$p.dll | tail -1)" in
      *" 0 refused") ;; *) fail "mini-ml -dotnet $p, verified"; $DOTNET -verify $W/$p.dll | head -3;; esac
    $dotnet $W/$p.dll > $W/$p.out 2> $W/$p.err
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
}
ML=${DUNEML:-_build/default/languages/ml/Main.exe}
DOTNET=${DUNEDOTNET:-_build/default/languages/dotnet/Main.exe}
if [ -n "$record" ]; then check dune $ML $DOTNET; exit 0; fi
if [ "$only" != mini ]; then
  check "dune's mini-ml and mini-dotnet" $ML $DOTNET
  if [ -n "$ms" ]; then
    if command -v dotnet > /dev/null; then check "dune's mini-ml, Microsoft's dotnet" $ML $(command -v dotnet); interop $ML
    else echo "skipped: Microsoft's dotnet (none here)"; fi
  fi
fi
[ "$only" != dune ] && check "mini-ml's mini-ml and mini-dotnet" ${MINIML:-_mk/7/languages/ml/mini-ml} ${MINIDOTNET:-_mk/7/languages/dotnet/mini-dotnet}
exit $failures
