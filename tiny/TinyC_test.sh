#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyC.ml, which need goken (~/goken, built, with its
# arm64 libc): each program of TinyC_tests/ compiled by TinyC and by
# 7c, both assembled with all of goken's libc (7c -S) by TinyAssembler,
# run, and their outputs and exit statuses compared; and TinyC's run
# again under tiny-arm, the same output. Then the other
# machine: each compiled by tiny-c -tm, linked with the runtime
# (tiny-os/libc/: start.tm, udivmod.tm, and libc.c compiled by tiny-c -tm) by
# tiny-cpu, run by tiny-cpu, its output and status compared with 7c's
# too; a program with long long is refused there (TinyCPU is 32 bits),
# and said so.
# usage: TinyC_test.sh [prog.c...]

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
TA=${TA:-$ROOT/_build/default/tiny/TinyAssembler.exe}
TCPU=${TCPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
TARM=${TARM:-$ROOT/_build/default/tiny/TinyCPUArm.exe}
GOKEN=${GOKEN:-$HOME/goken}
export PATH=$GOKEN/bin:$GOKEN/ROOT/arch/boot-gcc/bin:$PATH
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
progs=("$@")

# the libc's assembly, in its mkfile's order, 7c's listing being the
# lines with a tab
mkdir -p $W/libc
libc=()
pushd $GOKEN/lib_core/libc > /dev/null
while read -r line; do
  set -- $line
  src=${@: -1}; b=$(echo ${src%.*} | tr / _)
  case $1 in
  7c) flags=$(echo "$line" | sed -e 's/^7c //' -e 's/ -o [^ ]* [^ ]*$//' -e 's/\$CFLAGS_EXTRA//')
      7c $flags -S -o $W/libc/$b.7 $src 2>/dev/null | grep '^	' > $W/libc/$b.s; libc+=($W/libc/$b.s) ;;
  7a) libc+=($GOKEN/lib_core/libc/$src) ;;
  esac
done < <(mk -a -n objtype=arm64 cputype=arm64 2>/dev/null)
popd > /dev/null

T=$ROOT/tiny/TinyC_tests
[ ${#progs[@]} = 0 ] && progs=($T/*.c)
RT=$ROOT/tiny/tiny-os/libc
(cd $RT && $TC -tm -o $W/libc.tm libc.c) || { echo "FAIL the runtime: tiny-c -tm libc.c"; exit 1; }
refused=()
for c in "${progs[@]}"; do
  b=$(basename $c .c)
  # claude: 7c -O0: its optimizer gets some constants wrong (bugs/goken.md)
  (cd $(dirname $c) && 7c -O0 -S -o $W/$b.7 $b.c 2>/dev/null | grep '^	' > $W/$b.ref.s) || { echo "7c-FAIL $b"; continue; }
  $TC -o $W/$b.s $c || { echo "FAIL $b: tiny-c"; failures=$((failures + 1)); continue; }
  $TA -o $W/$b.ref $W/$b.ref.s "${libc[@]}" || { echo "FAIL $b: assembling 7c's"; failures=$((failures + 1)); continue; }
  $TA -o $W/$b.exe $W/$b.s "${libc[@]}" || { echo "FAIL $b: assembling"; failures=$((failures + 1)); continue; }
  # the same name in two directories, for argv[0]
  mkdir -p $W/ref $W/tiny-c; cp $W/$b.ref $W/ref/$b; cp $W/$b.exe $W/tiny-c/$b
  want=$(cd $W/ref && timeout 10 ./$b one two 2>&1; echo "exit $?")
  got=$(cd $W/tiny-c && timeout 10 ./$b one two 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b"; else echo "FAIL $b"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); fi
  got=$(cd $W/tiny-c && timeout 60 $TARM ./$b one two 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b tiny-arm"; else echo "FAIL $b tiny-arm"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); fi
  # -tm: TinyCPU
  if ! (cd $(dirname $c) && $TC -tm -o $W/$b.tm $b.c 2> $W/$b.tm.err); then
    if grep -q "long long" $W/$b.tm.err; then refused+=($b); else echo "FAIL $b -tm: $(cat $W/$b.tm.err)"; failures=$((failures + 1)); fi
    continue
  fi
  mkdir -p $W/tm; $TCPU -o $W/tm/$b $RT/start.tm $RT/udivmod.tm $W/libc.tm $W/$b.tm || { echo "FAIL $b -tm: linking"; failures=$((failures + 1)); continue; }
  got=$(cd $W/tm && timeout 10 $TCPU ./$b one two 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b -tm"; else echo "FAIL $b -tm"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); fi
done
[ ${#refused[@]} = 0 ] || echo "refused by -tm (long long): ${refused[*]}"

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
