#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-dotnet's tests (docs/plans/plan_dotnet.md), on dune's build and on
# mini-ml's when it is there (_mk/7: arm64, or -5: arm under mini-5i, a
# Pi1's integers of 31 bits). The assemblies are the survey's, written by
# Microsoft's C# compiler and kept in the tree (survey/programs/*.dll,
# decision 2), so no SDK is needed here:
#   listings   each assembly's types and IL (-S) against expected/*.S
#   run        each program run, what it prints against what Microsoft's
#              runtime printed: the survey's ten (survey/programs/
#              *.expected), and ours (programs/*.expected, their exit too;
#              programs/build.sh makes them where there is an SDK)
# -sdk: Microsoft's own library read whole, its types, methods and bytes
# of IL (each body decoded) against what System.Reflection.Metadata says
# (survey/Survey.cs): needs a .NET SDK, so not in make test.
# usage: languages/dotnet/tests/run.sh [-5] [-dune] [-mini] [-record] [-sdk]
cd "$(dirname "$0")/../../.."
O=7; RUN=; record=; only=; sdk=
for a in "$@"; do
  case $a in
    -5) O=5; RUN=_build/default/machine/Main.exe;;
    -record) record=1;;
    -dune) only=dune;;
    -mini) only=mini;;
    -sdk) sdk=1;;
  esac
done
T=languages/dotnet/tests
P=languages/dotnet/survey/programs
NATIVE=_build/default/languages/dotnet/Main.exe
MINI=${MINIDOTNET:-_mk/$O/languages/dotnet/mini-dotnet}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
progs="hello fib queens shapes exceptions strings vec generic collections closures"
ok() { echo "ok $*"; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
check() {
  local what=$1; shift
  [ -x "${@: -1}" ] || { echo "skipped: $what is not built"; return; }
  for p in $progs; do
    "$@" -S $P/$p.dll > $W/$p.S 2>&1
    if [ -n "$record" ]; then cp $W/$p.S $T/expected/$p.S
    elif cmp -s $W/$p.S $T/expected/$p.S; then ok "mini-dotnet -S $p, by $what"
    else fail "mini-dotnet -S $p, by $what"; diff $T/expected/$p.S $W/$p.S | head -10; fi
  done
  [ -n "$record" ] && return
  for p in $progs; do
    "$@" $P/$p.dll > $W/$p.out 2> $W/$p.err
    if cmp -s $W/$p.out $P/$p.expected; then ok "mini-dotnet $p, by $what"
    else fail "mini-dotnet $p, by $what"; diff $P/$p.expected $W/$p.out | head -5; head -3 $W/$p.err; fi
  done
  for f in $T/programs/*.dll; do
    p=$(basename $f .dll)
    { "$@" $f 2> $W/$p.err; echo "exit $?"; } > $W/$p.out
    if cmp -s $W/$p.out $T/programs/$p.expected; then ok "mini-dotnet $p, by $what"
    else fail "mini-dotnet $p, by $what"; diff $T/programs/$p.expected $W/$p.out | head -5; head -3 $W/$p.err; fi
  done
}
if [ -n "$sdk" ]; then
  command -v dotnet > /dev/null || { echo "skipped: no dotnet"; exit 0; }
  RT=$(dotnet --list-runtimes | grep '^Microsoft.NETCore.App ' | tail -1 |
       sed 's/ \[\(.*\)\]/ \1/' | awk '{print $3 "/" $2}')
  SDK=$(dotnet --list-sdks | tail -1 | sed 's/ \[\(.*\)\]/ \1/' | awk '{print $2 "/" $1}')
  refs=""
  for a in System.Runtime System.Console System.Collections System.Linq \
           System.Reflection.Metadata System.Reflection.Primitives \
           System.Collections.Immutable System.Private.CoreLib; do
    refs="$refs -r:$RT/$a.dll"
  done
  dotnet $SDK/Roslyn/bincore/csc.dll -nologo -nostdlib -optimize+ -debug- \
    -deterministic $refs -out:$W/Survey.dll languages/dotnet/survey/Survey.cs > /dev/null || exit 1
  echo '{"runtimeOptions":{"tfm":"net8.0","framework":{"name":"Microsoft.NETCore.App","version":"'$(basename $RT)'"}}}' > $W/Survey.runtimeconfig.json
  for a in System.Private.CoreLib System.Console System.Collections System.Linq System.Runtime; do
    want=$(dotnet $W/Survey.dll -size $RT/$a.dll)
    for b in $NATIVE $MINI; do
      [ -x $b ] || continue
      got=$($b -size $RT/$a.dll)
      [ "$got" = "$want" ] && ok "$got, by $b" || fail "$a: $got, Survey.cs: $want"
    done
  done
  exit $failures
fi
if [ -n "$record" ]; then check dune $NATIVE; exit 0; fi
[ -z "$RUN" ] && [ "$only" != mini ] && check dune $NATIVE
[ "$only" != dune ] && check "mini-ml ($O)" $RUN $MINI
exit $failures
