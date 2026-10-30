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
#   writer     an assembly made by Writer (writer/Hello.ml), read back
#              (-S) and run, against writer/hello.S and writer/hello.out
#   verify     each assembly's methods verified (-verify): all of the
#              survey's, ours and the writer's; and writer/Broken.ml's,
#              each method broken in one way, refused with its offset and
#              why (writer/broken.verify)
#   jit        the JIT's code (-S -jit, arm's and arm64's: -m 7) for each
#              assembly assembled by mini-asm; its text for jit/fib.dll's
#              and jit/ints.dll's methods against jit/*.s (*7.s: arm64's);
#              that code linked with a C program (jit/*.c) that calls it:
#              arm's, where Plan 9's libc for arm is built (_mk/5-plan9),
#              run under mini-5i, and arm64's, on an arm64 machine where
#              Linux's libc is built (_mk/7), run there: what the
#              interpreter prints (fib.expected, ints.expected); each
#              program run with -jit too (its code run by mini-ml's build
#              on arm64, the interpreter elsewhere), and jit/*.dll's
#              (zero: a division by zero in the JIT's code caught by the
#              interpreter; bench, with -jit only, where it is compiled)
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
  # (the writer: by dune's build, its file run by each)
  _build/default/languages/dotnet/tests/writer/Hello.exe $W/hello.dll
  "$@" -S $W/hello.dll > $W/hello.S 2>&1
  "$@" $W/hello.dll > $W/hello.out 2>&1
  _build/default/languages/dotnet/tests/writer/Broken.exe $W/broken.dll
  "$@" -verify $W/broken.dll > $W/broken.verify 2>&1
  if [ -n "$record" ]; then
    cp $W/hello.S $W/hello.out $W/broken.verify $T/writer/
    "$@" -S -jit $P/fib.dll > $T/jit/fib.s; "$@" -S -jit $T/jit/ints.dll > $T/jit/ints.s
    "$@" -S -jit -m 7 $P/fib.dll > $T/jit/fib7.s; "$@" -S -jit -m 7 $T/jit/ints.dll > $T/jit/ints7.s
    return
  fi
  if cmp -s $W/broken.verify $T/writer/broken.verify; then ok "mini-dotnet -verify: Broken.ml's methods refused, by $what"
  else fail "mini-dotnet -verify: Broken.ml's methods refused, by $what"; diff $T/writer/broken.verify $W/broken.verify | head -5; fi
  # (the JIT's text: recorded for two, assembled for all)
  for m in 5 7; do
    for p in fib ints; do
      f=$P/$p.dll; [ $p = ints ] && f=$T/jit/ints.dll
      s=$p.s; [ $m = 7 ] && s=${p}7.s
      "$@" -S -jit -m $m $f > $W/$s 2>&1
      if cmp -s $W/$s $T/jit/$s; then ok "mini-dotnet -S -jit -m $m $p, by $what"
      else fail "mini-dotnet -S -jit -m $m $p, by $what"; diff $T/jit/$s $W/$s | head -5; fi
    done
    for f in $P/*.dll $T/programs/*.dll $T/jit/*.dll; do
      "$@" -S -jit -m $m $f > $W/jit.s 2>&1
      if _build/default/assembler/Main.exe -m $m -o $W/jit.$m $W/jit.s > $W/jit.err 2>&1; then
        ok "mini-dotnet -S -jit -m $m $(basename $f): $(tail -1 $W/jit.s | sed 's|^// [^:]*: ||'), assembled, by $what"
      else fail "mini-dotnet -S -jit -m $m $(basename $f): not assembled, by $what"; head -3 $W/jit.err; fi
    done
  done
  for f in $P/*.dll $T/programs/*.dll $W/hello.dll; do
    v=$("$@" -verify $f 2>&1 | tail -1)
    case "$v" in *" 0 refused") ok "mini-dotnet -verify $(basename $f), by $what";;
      *) fail "mini-dotnet -verify $(basename $f), by $what"; "$@" -verify $f | head -3;; esac
  done
  for x in S out; do
    if cmp -s $W/hello.$x $T/writer/hello.$x; then ok "mini-dotnet: Writer's hello.dll, its .$x, by $what"
    else fail "mini-dotnet: Writer's hello.dll, its .$x, by $what"; diff $T/writer/hello.$x $W/hello.$x | head -5; fi
  done
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
  # (with -jit: the JIT's code where it runs, the interpreter elsewhere;
  # bench's 400 million instructions only where the JIT compiles them)
  jit=; "$@" -jit -s $T/jit/zero.dll 2>&1 >/dev/null | grep -q 'methods compiled' && jit=1
  for f in $P/*.dll $T/programs/*.dll $T/jit/*.dll; do
    p=$(basename $f .dll); e=${f%.dll}.expected
    [ $p = bench ] && [ -z "$jit" ] && continue
    case $f in $T/programs/*) { "$@" -jit $f 2> $W/$p.err; echo "exit $?"; } > $W/$p.out;;
      *) "$@" -jit $f > $W/$p.out 2> $W/$p.err;; esac
    if cmp -s $W/$p.out $e; then ok "mini-dotnet -jit $p${jit:+, its code run}, by $what"
    else fail "mini-dotnet -jit $p, by $what"; diff $e $W/$p.out | head -5; head -3 $W/$p.err; fi
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
  # (the verifier over Microsoft's library: how many of its methods pass)
  $NATIVE -verify $RT/System.Private.CoreLib.dll | tail -1
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
# the JIT's code run: linked with a C program, under mini-5i
jit_run() {
  local p=$1 want=$2 IX=_build/default M=_mk/5-plan9 L=lib_core/libc
  [ -f $M/lib_core/libc.a ] || { echo "skipped: the JIT's code run (no $M/lib_core/libc.a)"; return; }
  if $IX/assembler/Main.exe -m 5 -o $W/${p}jit.5 $T/jit/$p.s &&
     $IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 \
       -o $W/${p}c.5 $T/jit/$p.c &&
     $IX/linker/Main.exe -m 5 -H2 -o $W/${p}jit $W/${p}c.5 $W/${p}jit.5 $M/lib_core/libc.a > $W/link.err 2>&1 &&
     timeout 60 $IX/machine/Main.exe $W/${p}jit > $W/${p}jit.out 2>&1 && cmp -s $W/${p}jit.out $want
  then ok "the JIT's code for $p's methods, called from C under mini-5i: what the interpreter prints"
  else fail "the JIT's code for $p's methods, called from C under mini-5i"; diff $want $W/${p}jit.out | head -5; fi
}
# and arm64's, linked with Linux's libc, run here on an arm64 machine
jit_run7() {
  local p=$1 want=$2 IX=_build/default M=_mk/7 L=lib_core/libc
  [ "$(uname -m)" = aarch64 ] || { echo "skipped: the JIT's arm64 code run (not an arm64 machine)"; return; }
  [ -f $M/lib_core/libc.a ] || { echo "skipped: the JIT's arm64 code run (no $M/lib_core/libc.a)"; return; }
  if $IX/assembler/Main.exe -m 7 -o $W/${p}jit.7 $T/jit/${p}7.s &&
     $IX/languages/c/Main.exe -m 7 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm64 -Darm64 \
       -o $W/${p}c.7 $T/jit/$p.c &&
     $IX/linker/Main.exe -m 7 -o $W/${p}jit7 $W/${p}c.7 $W/${p}jit.7 $M/lib_core/libc.a > $W/link.err 2>&1 &&
     timeout 60 $W/${p}jit7 > $W/${p}jit7.out 2>&1 && cmp -s $W/${p}jit7.out $want
  then ok "the JIT's arm64 code for $p's methods, called from C on this machine: what the interpreter prints"
  else fail "the JIT's arm64 code for $p's methods, called from C on this machine"; diff $want $W/${p}jit7.out | head -5; fi
}
if [ -z "$RUN" ] && [ "$only" != mini ]; then
  jit_run fib $P/fib.expected
  jit_run ints $T/jit/ints.expected
  jit_run7 fib $P/fib.expected
  jit_run7 ints $T/jit/ints.expected
fi
[ -z "$RUN" ] && [ "$only" != mini ] && check dune $NATIVE
[ "$only" != dune ] && check "mini-ml ($O)" $RUN $MINI
exit $failures
