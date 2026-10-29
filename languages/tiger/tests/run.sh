#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-tiger's tests (docs/plans/plan_dotnet.md, stage 5): fork-tiger's
# programs (programs/*.tig, from ~/github/tiger/tests: their input
# .in, what they print .out, as fork-tiger's compiler made them print on
# x86), each compiled by mini-tiger and run by mini-dotnet, and by
# Microsoft's dotnet with -ms (not in make test: it needs the SDK); and
# Appel's 49 test programs
# (appel/), each compiled, its error or what it prints against
# appel.expected.
# By dune's builds, and by mini-ml's (_mk/7, or -5: mini-dotnet on arm
# under mini-5i) when they are there.
# usage: languages/tiger/tests/run.sh [-5] [-dune] [-mini] [-ms] [-record]
cd "$(dirname "$0")/../../.."
O=7; RUN=; record=; only=; ms=
for a in "$@"; do
  case $a in
    -5) O=5; RUN=_build/default/machine/Main.exe;;
    -record) record=1;;
    -dune) only=dune;;
    -mini) only=mini;;
    -ms) ms=1;;
  esac
done
T=languages/tiger/tests
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
ok() { echo "ok $*"; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
# check what tiger dotnet...: the compiler and the runtime ($RUN before it, for -5)
check() {
  local what=$1 tiger=$2; shift 2
  [ -x $tiger ] && [ -x "${@: -1}" ] || { echo "skipped: $what is not built"; return; }
  for f in $T/programs/*.tig; do
    p=$(basename $f .tig)
    in=/dev/null; [ -f $T/programs/$p.in ] && in=$T/programs/$p.in
    if ! $tiger -o $W/$p.dll $f 2> $W/$p.err; then fail "mini-tiger $p, by $what"; head -3 $W/$p.err; continue; fi
    # (its assembly verified by dune's mini-dotnet: every method passes)
    case "$(_build/default/languages/dotnet/Main.exe -verify $W/$p.dll | tail -1)" in
      *" 0 refused") ;; *) fail "mini-tiger $p, verified"; _build/default/languages/dotnet/Main.exe -verify $W/$p.dll | head -3;; esac
    "$@" $W/$p.dll < $in > $W/$p.out 2> $W/$p.err
    if cmp -s $W/$p.out $T/programs/$p.out; then ok "mini-tiger $p, run by $what"
    else fail "mini-tiger $p, run by $what"; diff $T/programs/$p.out $W/$p.out | head -5; head -3 $W/$p.err; fi
  done
  # Appel's: a line each, the error or the output
  for f in $(ls $T/appel/*.tig | sort -V); do
    p=$(basename $f .tig)
    if $tiger -o $W/$p.dll $f 2> $W/$p.err; then
      echo "$p: $( { "$@" $W/$p.dll < /dev/null 2> /dev/null; echo "exit $?"; } | tr '\n' ' ')"
    else
      echo "$p: $(sed "s|$T/appel/||" $W/$p.err)"
    fi
  done > $W/appel.out
  if [ -n "$record" ]; then cp $W/appel.out $T/appel.expected
  elif cmp -s $W/appel.out $T/appel.expected; then ok "mini-tiger: Appel's 49, by $what"
  else fail "mini-tiger: Appel's 49, by $what"; diff $T/appel.expected $W/appel.out | head -10; fi
}
TIGER=_build/default/languages/tiger/Main.exe
DOTNET=_build/default/languages/dotnet/Main.exe
MTIGER=_mk/$O/languages/tiger/mini-tiger
MDOTNET=_mk/$O/languages/dotnet/mini-dotnet
if [ -n "$record" ]; then check dune $TIGER $DOTNET; exit 0; fi
if [ -z "$RUN" ] && [ "$only" != mini ]; then
  check "dune's mini-dotnet" $TIGER $DOTNET
  if [ -n "$ms" ]; then
    if command -v dotnet > /dev/null; then check "Microsoft's dotnet" $TIGER $(command -v dotnet)
    else echo "skipped: Microsoft's dotnet (none here)"; fi
  fi
fi
[ "$only" != dune ] && check "mini-ml's mini-tiger and mini-dotnet ($O)" $MTIGER $RUN $MDOTNET
exit $failures
