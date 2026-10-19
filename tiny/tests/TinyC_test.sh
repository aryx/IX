#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyC.ml: each program of TinyC_tests/ compiled by
# tiny-c, linked with the runtime (TinyCRuntime/: start.tm, udivmod.tm,
# and libc.c compiled by tiny-c) by tiny-cpu, run by tiny-cpu, its
# output and exit status compared with the recorded ones (prog.out).
# They are the host's cc's: RECORD=1 records them again, each program
# built by $CC with TinyC_tests/host.h for its libc.h (Plan 9's C on a
# 32-bit machine, made the host's), what TinyC_fuzz.py's programs need
# (make test-ocaml). A program with long long is refused (TinyCPU is 32
# bits), and said so. Then the errors: the file and the line.
# usage: TinyC_test.sh [prog.c...]

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
TCPU=${TCPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
. $ROOT/tiny/tests/link.sh
CC=${CC:-cc}
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
progs=("$@")

T=$ROOT/tiny/tests/TinyC_tests
[ ${#progs[@]} = 0 ] && progs=($T/*.c)
RT=$ROOT/tiny/TinyCRuntime
(cd $RT && $TC -o $W/libc.tm libc.c) || { echo "FAIL the runtime: tiny-c libc.c"; exit 1; }
refused=()
mkdir -p $W/host $W/tm
for c in "${progs[@]}"; do
  c=$(realpath $c); b=$(basename $c .c); out=${c%.c}.out
  if [ -n "${RECORD:-}" ]; then
    # the same name in two directories, for argv[0]
    sed 's|#include ".*libc.h"|#include "host.h"|' $c > $W/host/$b.c
    cp $T/host.h $W/host/
    (cd $W/host && $CC -w -fsigned-char -fwrapv -o $b $b.c) || { echo "FAIL $b: $CC"; failures=$((failures + 1)); continue; }
    (cd $W/host && timeout 10 ./$b one two 2>&1; echo "exit $?") > $out
  fi
  if ! (cd $(dirname $c) && $TC -o $W/$b.tm $b.c 2> $W/$b.err); then
    if grep -q "long long" $W/$b.err; then refused+=($b); else echo "FAIL $b: $(cat $W/$b.err)"; failures=$((failures + 1)); fi
    continue
  fi
  link_tm $W/tm/$b $RT/start.tm $RT/udivmod.tm $W/libc.tm $W/$b.tm || { echo "FAIL $b: linking"; failures=$((failures + 1)); continue; }
  want=$(cat $out)
  got=$(cd $W/tm && timeout 10 $TCPU ./$b one two 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b"; else echo "FAIL $b"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); fi
done
[ ${#refused[@]} = 0 ] || echo "refused (long long): ${refused[*]}"

# the errors: the file and the line, an #include's own, a macro's use's
mkdir -p $W/err
printf 'int main(void) {\n  int x;\n  x = 1 +;\n  return x;\n}\n' > $W/err/expr.c
printf 'int main(void) {\n  int x;\n  x = 1\n  return x;\n}\n' > $W/err/semi.c
printf '/* a header */\nint g(int a);\nint h(int a) { return a +* ; }\n' > $W/err/bad.h
printf '#include "bad.h"\nint main(void) {\n  return 0;\n}\n' > $W/err/include.c
printf '#define BAD 1 +\nint main(void) {\n\n  return BAD;\n}\n' > $W/err/macro.c
for want in "expr.c: line 3: expected an expression" "semi.c: line 3: expected ;" \
            "bad.h: line 3: expected an expression" "macro.c: line 4: expected an expression"; do
  c=${want%%.*}.c; [ $c = bad.c ] && c=include.c
  got=$(cd $W/err && $TC -o /dev/null $c 2>&1)
  if [ "$got" = "$want" ]; then echo "ok error in $c"; else echo "FAIL error in $c: $got"; failures=$((failures + 1)); fi
done
echo "$failures failure(s)"
[ $failures = 0 ]
