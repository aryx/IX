#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml -dotnet's tests (docs/plans/plan_dotnet_languages.md, stage
# 1a): each program here compiled to an assembly, verified by
# mini-dotnet (-verify: every method passes), run, against what OCaml
# prints for it (the .expected files, made by ocaml file.ml, then read);
# by dune's mini-ml and mini-dotnet, and by mini-ml's own (_mk/7);
# Microsoft's dotnet too with -ms (not in make test: it needs the SDK).
# And what stage 1a refuses, each with its message (refused.expected).
#   fib       recursion, a unit's function called by its toplevel
#   arith     int64's arithmetic as OCaml's, floats by conversions, the
#             comparisons (a float's NaN unordered)
#   strings   ^, String.length, comparisons by the text, chars printed
#   loops     for up and down, && and || short, a value of the unit
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
progs="fib arith strings loops"
# what stage 1a refuses: a program a line, and the stage that will have it
refused() {
  local ml=$1 n=0
  while IFS= read -r line; do
    n=$((n + 1)); echo "$line" > $W/r$n.ml
    echo "-- $line"
    $ml -L lib_core -dotnet -o $W/r$n.dll $W/r$n.ml 2>&1 | sed "s|$W/||"
  done <<'R'
let pair = (1, "one")
type point = { x : int; y : int } let p = { x = 1; y = 2 }
let f x = match x with 0 -> "zero" | _ -> "many"
let twice f x = f (f x)
let () = let add x y = x + y in print_int (add 1 2)
let add x y = x + y let inc = add 1
exception Stop let () = raise Stop
let id x = x
let () = print_float 1.5
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
  refused $ml > $W/refused.out
  if [ -n "$record" ]; then cp $W/refused.out $T/refused.expected
  elif cmp -s $W/refused.out $T/refused.expected; then ok "mini-ml -dotnet: what stage 1a refuses, by $what"
  else fail "mini-ml -dotnet: what stage 1a refuses, by $what"; diff $T/refused.expected $W/refused.out | head -5; fi
}
ML=${DUNEML:-_build/default/languages/ml/Main.exe}
DOTNET=${DUNEDOTNET:-_build/default/languages/dotnet/Main.exe}
if [ -n "$record" ]; then check dune $ML $DOTNET; exit 0; fi
if [ "$only" != mini ]; then
  check "dune's mini-ml and mini-dotnet" $ML $DOTNET
  if [ -n "$ms" ]; then
    if command -v dotnet > /dev/null; then check "dune's mini-ml, Microsoft's dotnet" $ML $(command -v dotnet)
    else echo "skipped: Microsoft's dotnet (none here)"; fi
  fi
fi
[ "$only" != dune ] && check "mini-ml's mini-ml and mini-dotnet" ${MINIML:-_mk/7/languages/ml/mini-ml} ${MINIDOTNET:-_mk/7/languages/dotnet/mini-dotnet}
exit $failures
