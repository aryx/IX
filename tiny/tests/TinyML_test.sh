#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyML.ml, which need goken (~/goken, built, with its
# arm64 libc): each program of languages/ml/tests/tiny/ compiled by
# tiny-ml, linked with the runtime (TinyML_runtime.c, by tiny-c) and
# all of goken's libc (7c -S) by TinyAssembler, run, and its output and
# exit status compared with the recorded ones (prog.out), which are
# ocaml-light's arm64 ocamlopt's: RECORD=1 records them again, from
# $OCL (default /tmp/ix-ocaml-light-arm64, built by
# kernels/ocaml-light.sh arm64). Then the collector's law: each program
# again with a heap of 64 words, where it collects all the time, the
# same output; and again under tiny-arm (not gc: 700 million
# instructions). Then the programs on tiny-cpu, by tiny-ml -tm (below);
# a program with an integer beyond 31 bits is refused there (TinyCPU is
# 32 bits), and said so.
# usage: TinyML_test.sh [prog.ml...]

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TML=${TML:-$ROOT/_build/default/tiny/TinyML.exe}
TC=${TC:-$ROOT/_build/default/tiny/TinyC.exe}
TA=${TA:-$ROOT/_build/default/tiny/TinyAssembler.exe}
TARM=${TARM:-$ROOT/_build/default/tiny/TinyCPUArm.exe}
GOKEN=${GOKEN:-$HOME/goken}
OCL=${OCL:-/tmp/ix-ocaml-light-arm64}
export PATH=$GOKEN/bin:$GOKEN/ROOT/arch/boot-gcc/bin:$PATH
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0
progs=("$@")

# the libc's assembly, in its mkfile's order, 7c's listing being the
# lines with a tab (TinyC_test.sh's)
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

$TC -o $W/runtime.s $ROOT/tiny/TinyML_runtime.c || { echo "FAIL the runtime: tiny-c TinyML_runtime.c"; exit 1; }

# (SLOW: the emulators' seconds for a program, 60; more for tiny-arm and
# tiny-cpu built by mini-ml, whose code is slower: SLOW=300)
T=$ROOT/languages/ml/tests/tiny
[ ${#progs[@]} = 0 ] && progs=($T/*.ml)
# a program a job, all at once (a core each: one after the other they
# took 4 minutes with tiny-arm built by mini-ml); its lines in
# $W/$b.log, printed after, in the programs' order
one() {
  local ml=$1 b out want got
  ml=$(realpath $ml); b=$(basename $ml .ml)
  out=${ml%.ml}.out
  if [ -n "${RECORD:-}" ]; then
    (cd $W && cp $ml $b.ml && $OCL/bin/ocamlopt -o $b.ref $b.ml 2>/dev/null) || { echo "FAIL $b: ocamlopt"; failures=$((failures + 1)); return; }
    (cd $W && timeout 10 ./$b.ref 2>&1; echo "exit $?") > $out
  fi
  $TML -o $W/$b.s $ml || { echo "FAIL $b: tiny-ml"; failures=$((failures + 1)); return; }
  $TA -o $W/$b $W/$b.s $W/runtime.s "${libc[@]}" || { echo "FAIL $b: assembling"; failures=$((failures + 1)); return; }
  # (a .tiny-ml.out where tiny-ml's own behavior is another: an index
  # out of bounds is a fatal error for it, an exception for mini-ml)
  [ -f ${ml%.ml}.tiny-ml.out ] && out=${ml%.ml}.tiny-ml.out
  want=$(cat $out)
  got=$(cd $W && timeout 10 ./$b 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b"; else echo "FAIL $b"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); return; fi
  got=$(cd $W && ML_HEAP=64 timeout 20 ./$b 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b ML_HEAP=64"; else echo "FAIL $b ML_HEAP=64"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); fi
  [ $b = gc ] && return
  got=$(cd $W && timeout ${SLOW:-60} $TARM ./$b 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b tiny-arm"; else echo "FAIL $b tiny-arm"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); fi
}
for ml in "${progs[@]}"; do one $ml > $W/$(basename $ml .ml).log 2>&1 & done
wait
for ml in "${progs[@]}"; do cat $W/$(basename $ml .ml).log; done

# -tm: each program again on tiny-cpu (tiny-ml -tm, the runtime by
# tiny-c -tm, a main giving it tiny-cpu's memory), the same output, with
# the heap from 64 words so that it collects all the time. Not arith
# and strings (they print max_int: 31 bits there) nor gc (its lists are
# deeper than tiny-cpu's 1 MB holds)
CPU=${CPU:-$ROOT/_build/default/tiny/TinyCPU.exe}
L=$ROOT/tiny/tiny-os/libc
cat > $W/main.c <<EOF
#include "$ROOT/tiny/TinyML_core.c"
static value vstack[32768];
static value space0[65536];
static value space1[65536];
void main(void) { ml_run(vstack, space0, space1, 65536, 64); flush(); exit(0); }
EOF
printf 'exit:\n\tldw\tr1, 0(sp)\n\tsys\t0\n' > $W/exit.tm
$TC -tm -o $W/main.tm $W/main.c || { echo "FAIL the runtime: tiny-c -tm"; exit 1; }
one_tm() {
  local ml=$1 b out want got
  ml=$(realpath $ml); b=$(basename $ml .ml)
  case $b in arith|strings|gc) return;; esac
  if ! $TML -tm -o $W/$b.tm $ml 2> $W/$b.tm.err; then
    if grep -q "beyond 31 bits" $W/$b.tm.err; then echo $b >> $W/refused; else echo "FAIL $b -tm: $(cat $W/$b.tm.err)"; failures=$((failures + 1)); fi
    return
  fi
  # the program before main.tm, whose arrays a jal would not jump over
  $CPU -o $W/$b.tmimg $L/start.tm $L/udivmod.tm $W/exit.tm $W/$b.tm $W/main.tm \
    || { echo "FAIL $b -tm: linking"; failures=$((failures + 1)); return; }
  out=${ml%.ml}.out; [ -f ${ml%.ml}.tiny-ml.out ] && out=${ml%.ml}.tiny-ml.out
  want=$(cat $out)
  got=$(timeout ${SLOW:-60} $CPU $W/$b.tmimg 2>&1; echo "exit $?")
  if [ "$want" = "$got" ]; then echo "ok $b -tm"; else echo "FAIL $b -tm"; /usr/bin/diff <(echo "$want") <(echo "$got") | /usr/bin/head -10; failures=$((failures + 1)); fi
}
: > $W/refused
for ml in "${progs[@]}"; do one_tm $ml > $W/$(basename $ml .ml).tm.log 2>&1 & done
wait
for ml in "${progs[@]}"; do cat $W/$(basename $ml .ml).tm.log; done
refused=($(sort $W/refused))
failures=$(cat $W/*.log | grep -c '^FAIL')
[ ${#refused[@]} = 0 ] || echo "refused by -tm (an integer beyond 31 bits): ${refused[*]}"
echo "$failures failure(s)"
[ $failures = 0 ]
