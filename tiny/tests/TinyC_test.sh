#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyC.ml: each program of TinyC_tests/ compiled by
# tiny-cc, linked with the runtime (runtime/: start.s, udivmod.s,
# and libc.c compiled by tiny-cc) by tiny-cpu, run by tiny-cpu, its
# output and exit status compared with the recorded ones (prog.out).
# They are the host's cc's: RECORD=1 records them again, each program
# built by $CC with TinyC_tests/host.h for its libc.h (Plan 9's C on a
# 32-bit machine, made the host's), what TinyC_fuzz.py's programs need
# (make test-vs-ocaml-light). A program with long long is refused (TinyCPU is 32
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
RT=$ROOT/tiny/runtime
(cd $RT && $TC -o $W/libc.o libc.c) || { echo "FAIL the runtime: tiny-cc libc.c"; exit 1; }
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
  if ! (cd $(dirname $c) && $TC -o $W/$b.o $b.c 2> $W/$b.err); then
    if grep -q "long long" $W/$b.err; then refused+=($b); else echo "FAIL $b: $(cat $W/$b.err)"; failures=$((failures + 1)); fi
    continue
  fi
  link_tm $W/tm/$b $RT/start.s $RT/udivmod.s $W/libc.o $W/$b.o || { echo "FAIL $b: linking"; failures=$((failures + 1)); continue; }
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
# (a parameter list not closed: a segmentation fault before, 2026-11-06)
printf 'int f( {\n' > $W/err/params.c
printf 'int g(int a' > $W/err/end.c
# (any word taken for the while: until compiled as one, 2026-11-09)
printf 'int main(void) {\n  int i;\n  do i++; until (i);\n  return i;\n}\n' > $W/err/do.c
# (a number past 64 bits: Int64.of_string's Failure said as the error
# before, its name the message, 2026-11-11)
printf 'int main(void) {\n  return 99999999999999999999999;\n}\n' > $W/err/big.c
printf 'int x = 0x10000000000000000;\n' > $W/err/hex.c
for want in "expr.c: line 3: expected an expression" "semi.c: line 3: expected ;" \
            "bad.h: line 3: expected an expression" "macro.c: line 4: expected an expression" \
            "params.c: line 1: expected )" "end.c: line 1: expected )" \
            "do.c: line 3: expected while" "big.c: line 2: bad integer 99999999999999999999999" \
            "hex.c: line 1: bad integer 0x10000000000000000"; do
  c=${want%%.*}.c; [ $c = bad.c ] && c=include.c
  got=$(cd $W/err && $TC -o /dev/null $c 2>&1)
  if [ "$got" = "$want" ]; then echo "ok error in $c"; else echo "FAIL error in $c: $got"; failures=$((failures + 1)); fi
done
echo "$failures failure(s)"
[ $failures = 0 ]
