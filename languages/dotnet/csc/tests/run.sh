#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-csc's tests (docs/plans/done/plan_dotnet.md, stage 6): the seven of the
# survey's programs decision 11 keeps (hello fib queens shapes exceptions
# collections, and strings as tests/strings.cs writes it, without its
# interpolation and its switch) and tests/features.cs, compiled by
# mini-csc and run by mini-dotnet, against what Microsoft's runtime
# printed for Microsoft's compiler's assemblies (the survey's .expected,
# features.expected); Microsoft's dotnet runs them too with -ms (not in
# make test: it needs the SDK). And the programs it refuses (vec,
# generic, closures, the survey's strings.cs), each with its message
# (refused.expected).
# By dune's builds, and by mini-ml's (_mk/7; -5: mini-dotnet on arm
# under mini-5i) when they are there.
# usage: languages/dotnet/csc/tests/run.sh [-5] [-dune] [-mini] [-ms] [-jit] [-record]
# -jit: each assembly run with mini-dotnet's -jit (its code where mini-ml
# built it: arm64's, Plan 9's arm; the interpreter elsewhere)
cd "$(dirname "$0")/../../../.."
O=7; RUN=; record=; only=; ms=
for a in "$@"; do
  case $a in
    -5) O=5; RUN=_build/default/machine/Main.exe;;
    -record) record=1;;
    -dune) only=dune;;
    -mini) only=mini;;
    -ms) ms=1;;
    -jit) jit="-jit -tier 0";;
  esac
done
T=languages/dotnet/csc/tests
P=languages/dotnet/survey/programs
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
ok() { echo "ok $*"; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
# each program: its source, what it must print
progs="$P/hello.cs:$P/hello.expected $P/fib.cs:$P/fib.expected $P/queens.cs:$P/queens.expected
$P/shapes.cs:$P/shapes.expected $P/exceptions.cs:$P/exceptions.expected
$P/collections.cs:$P/collections.expected $T/strings.cs:$P/strings.expected
$T/features.cs:$T/features.expected"
check() {
  local what=$1 csc=$2; shift 2
  [ -x $csc ] && [ -x "${@: -1}" ] || { echo "skipped: $what is not built"; return; }
  for x in $progs; do
    src=${x%%:*}; want=${x#*:}; p=$(basename $src .cs)
    if ! $csc -o $W/$p.dll $src 2> $W/$p.err; then fail "mini-csc $p, by $what"; head -3 $W/$p.err; continue; fi
    # (its assembly verified by dune's mini-dotnet: every method passes)
    case "$(_build/default/languages/dotnet/Main.exe -verify $W/$p.dll | tail -1)" in
      *" 0 refused") ;; *) fail "mini-csc $p, verified"; _build/default/languages/dotnet/Main.exe -verify $W/$p.dll | head -3;; esac
    "$@" $jit $W/$p.dll > $W/$p.out 2> $W/$p.err
    if cmp -s $W/$p.out $want; then ok "mini-csc $p, run by $what"
    else fail "mini-csc $p, run by $what"; diff $want $W/$p.out | head -5; head -3 $W/$p.err; fi
  done
  for p in vec generic closures strings; do
    $csc -o $W/$p.dll $P/$p.cs > $W/$p.msg 2>&1; s=$?
    sed "s|$P/||" $W/$p.msg; echo "exit $s"
  done > $W/refused.out
  if [ -n "$record" ]; then cp $W/refused.out $T/refused.expected
  elif cmp -s $W/refused.out $T/refused.expected; then ok "mini-csc: what it refuses, by $what"
  else fail "mini-csc: what it refuses, by $what"; diff $T/refused.expected $W/refused.out | head -5; fi
}
CSC=_build/default/languages/dotnet/csc/Main.exe
DOTNET=_build/default/languages/dotnet/Main.exe
MCSC=_mk/$O/languages/dotnet/csc/mini-csc
MDOTNET=_mk/$O/languages/dotnet/mini-dotnet
if [ -n "$record" ]; then check dune $CSC $DOTNET; exit 0; fi
if [ -z "$RUN" ] && [ "$only" != mini ]; then
  check "dune's mini-dotnet" $CSC $DOTNET
  if [ -n "$ms" ]; then
    if command -v dotnet > /dev/null; then check "Microsoft's dotnet" $CSC $(command -v dotnet)
    else echo "skipped: Microsoft's dotnet (none here)"; fi
  fi
fi
[ "$only" != dune ] && check "mini-ml's mini-csc and mini-dotnet ($O)" $MCSC $RUN $MDOTNET
exit $failures
