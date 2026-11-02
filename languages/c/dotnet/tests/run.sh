#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-cc -dotnet's tests (docs/plans/plan_dotnet_languages.md, stage 5):
# tiny/tests/TinyC_tests' programs (integers of each width, calls,
# control, enums, function pointers, globals and their initializers,
# pointers into arrays, a sort, structures, unsigned division), each
# compiled to an assembly with libc.c, verified by mini-dotnet (every
# method), run with arguments one two, against its .out (the host's
# cc's, Plan 9's C made the host's: TinyC_test.sh); by dune's mini-cc
# and mini-dotnet, by ix's own (_mk/7) and its mini-dotnet's JIT
# (arm64), Microsoft's dotnet too with -ms (not in make test: the SDK).
# Then what is refused, each with its message (refused.expected).
# -fuzz N: N of TinyC_fuzz.py's programs (vlong too, seed 11), against
# mini-cc's native arm64 build linked with goken's libc (libc.sh's,
# mini-ld -H7): the native build's output the reference, not the
# host's cc's, whose ANSI promotions differ from Plan 9's (an unsigned
# short an int there, an unsigned int here). Needs goken: make test-all.
# -dune: dune's builds only; -mini: ix's only.
# usage: languages/c/dotnet/tests/run.sh [-dune|-mini] [-ms] [-fuzz N]
#   (dune build, and mini-mk in languages/c and languages/dotnet, first)
# MINICC, MINIDOTNET: ix's builds, if not _mk/7's; DUNECC, DUNEDOTNET:
# dune's, if not _build's.
cd "$(dirname "$0")/../../../.."
ms=; fuzz=0; only=
while [ $# -gt 0 ]; do
  case $1 in
    -ms) ms=1;;
    -dune) only=dune;;
    -mini) only=mini;;
    -fuzz) fuzz=$2; shift;;
  esac
  shift
done
T=tiny/tests/TinyC_tests
R=languages/c/dotnet/tests
LIB=$PWD/languages/c/dotnet
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
abs() { case $1 in /*) echo $1;; *) echo $PWD/$1;; esac; }
CC=$(abs ${DUNECC:-_build/default/languages/c/Main.exe})
DOTNET=$(abs ${DUNEDOTNET:-_build/default/languages/dotnet/Main.exe})

# what is refused: a program a line, its message
refused() {
  local cc=$1 n=0
  while IFS= read -r line; do
    n=$((n + 1)); echo "$line" > $W/r$n.c
    echo "-- $line"
    (cd $W && $cc -dotnet -L $LIB r$n.c 2>&1)
  done <<'R'
union U { int i; char c; } u; void main(void) { u.i = 1; }
int x; void main(void) { char *p; p = (char*)&x; }
void main(void) { int *p; p = (int*)4; }
int x; void main(void) { long l; l = (long)&x; }
struct S { int a; } s; void main(void) { int *p; p = &s.a; }
extern int print(char*, ...); char *f = "%d"; void main(void) { print(f, 1); }
int g(int, ...); void main(void) { g(1, 2); }
void *malloc(unsigned long); void main(void) { void *p; p = malloc(8); }
R
}

# the programs by a mini-cc, run by a runtime (verified by mini-dotnet's
# when the runtime is one)
check() {
  local what=$1 cc=$2 run=$3 verify=$4 b out
  [ -x $cc ] || { echo "skipped: $what (no $cc)"; return; }
  mkdir -p $W/$what
  for c in $T/*.c; do
    b=$(basename $c .c)
    if ! (cd $T && $cc -dotnet -L $LIB -o $W/$what/$b.dll $b.c) 2> $W/$b.err; then
      fail "mini-cc -dotnet $b, by $what"; head -3 $W/$b.err; continue
    fi
    if [ -n "$verify" ]; then
      case "$($verify -verify $W/$what/$b.dll | tail -1)" in
        *" 0 refused") ;; *) fail "mini-cc -dotnet $b, verified"; $verify -verify $W/$what/$b.dll | head -3;; esac
    fi
    out=$(cd $W/$what && timeout 60 $run $b.dll one two 2>&1; echo "exit $?")
    if [ "$out" = "$(cat $T/$b.out)" ]; then echo "ok mini-cc -dotnet $b, run by $what"
    else fail "mini-cc -dotnet $b, run by $what"; diff $T/$b.out <(echo "$out") | head -5; fi
  done
  refused $cc > $W/refused.out
  if cmp -s $W/refused.out $R/refused.expected; then echo "ok mini-cc -dotnet: what it refuses, by $what"
  else fail "mini-cc -dotnet: what it refuses, by $what"; diff $R/refused.expected $W/refused.out | head -5; fi
}

[ "$only" != mini ] && check dune $CC $DOTNET $DOTNET
MCC=$(abs ${MINICC:-_mk/7/languages/c/mini-cc})
MD=$(abs ${MINIDOTNET:-_mk/7/languages/dotnet/mini-dotnet})
if [ "$only" = dune ]; then :
elif [ -x $MD ]; then
  check mini $MCC $MD $MD
  # (the JIT where mini-ml's build has one: arm64)
  if $MD -jit -tier 0 -s languages/dotnet/tests/jit/zero.dll 2>&1 > /dev/null | grep -q "methods compiled"; then
    printf '#!/bin/sh\nexec %s -jit "$@"\n' $MD > $W/jit.sh; chmod +x $W/jit.sh
    check jit $MCC $W/jit.sh ""
  fi
else echo "skipped: ix's mini-dotnet (no $MD)"; fi
if [ -n "$ms" ]; then
  if command -v dotnet > /dev/null; then check ms $CC "$(command -v dotnet)" ""
  else echo "skipped: Microsoft's dotnet (none here)"; fi
fi

# the fuzzer's programs against mini-cc's native build (goken's libc)
if [ $fuzz -gt 0 ]; then
  G=$HOME/goken/include
  MINICC=1 linker/tests/libc.sh 7 $W/libc > /dev/null 2>&1 || { fail "goken's libc by mini-cc (libc.sh 7)"; fuzz=0; }
  mkdir -p $W/fuzz/n $W/fuzz/d
  python3 tiny/tests/TinyC_fuzz.py $W/fuzz $fuzz 11 > /dev/null
  same=0; native=0
  for c in $W/fuzz/*.c; do
    b=$(basename $c .c)
    (cd $W/fuzz && $CC -m 7 -I$G -I$G/ALL -I$G/arch/arm64 -o n/$b.7 $b.c) &&
      _build/default/linker/Main.exe -m 7 -H7 -o $W/fuzz/n/$b $W/fuzz/n/$b.7 $W/libc/t/libc.a 2> /dev/null ||
      { native=$((native + 1)); continue; }
    want=$(cd $W/fuzz/n && timeout 10 ./$b one two 2>&1; echo "exit $?")
    (cd $W/fuzz && $CC -dotnet -L $LIB -o d/$b.dll $b.c) 2> $W/fuzz/$b.err || { fail "fuzz $b: $(head -1 $W/fuzz/$b.err)"; continue; }
    got=$(cd $W/fuzz/d && timeout 60 $DOTNET $b.dll one two 2>&1; echo "exit $?")
    if [ "$want" = "$got" ]; then same=$((same + 1)); else fail "fuzz $b"; diff <(echo "$want") <(echo "$got") | head -4; fi
  done
  # (native: goken's 7c's SXTW of a constant, bugs/goken.md 5e)
  echo "fuzz: $same of $fuzz as the native build; $native not built natively"
fi
echo "$failures failure(s)"
[ $failures = 0 ]
