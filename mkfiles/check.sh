#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# ix built by ix (plan_mkfiles.md): mini-mk over the mkfiles, with the
# programs dune built (./bin), then each program made so against dune's
# own: the same output, to the byte.
# - mini-asm: the repository's arm and arm64 .s files and goken's, each one's object;
# - mini-ar: a library; mini-ld: two small links, and mini-asm's own;
# - mini-cc: lib_core/libc's C files and mini-ml's runtime, their
#   listings and objects;
# - mini-chidb, mini-mk, mini-rc, mini-ed: their differential tests'
#   corpora, against dune's builds;
# - the tiny programs: each one's own test;
# - the kernels' steps on the Pi 4: each booted, its lines the expected;
#   and mini-xv6, its Makefile's check with the image ix's tools made.
# usage: mkfiles/check.sh     (after dune build; goken's .s files too for the inputs, where it is)
# (and mkfiles/fixpoint.sh: ix built again by what mini-mk built here)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
# only ix's programs: nothing of goken's builds (its .s files are the inputs below)
export PATH=$ROOT/bin:$PATH
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
cd $ROOT
W0=$W
mini-mk > $W/mk.log 2>&1 || { echo "FAIL mini-mk: $(tail -3 $W/mk.log)"; exit 1; }
echo "ok mini-mk: $(ls _mk/7/*/*.7 | wc -l) objects under _mk/7"

ok() { echo "ok $*"; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
G=$HOME/goken
M=_mk/7

# Each check below is a job, all of them at once (they took 12 minutes
# one after the other, a core each): its own directory for what it
# writes (W, in it), its lines kept and printed at the end, in the
# order the jobs were started.
jobs_n=0
job() {
  jobs_n=$((jobs_n + 1))
  local k=$W/job$jobs_n
  mkdir -p $k
  ( W=$k; "$@" ) > $k.out 2>&1 &
}

tools() {
# mini-asm: each .s by the two, the same exit status, messages and object
n=0; bad=0
# (the repository's own: the C library's, the linker's recorded tests'; and goken's where it is)
gs=; [ -d $G ] && gs="$G/lib_core/libc/arch/arm/*.s $G/lib_core/libc/arch/arm64/*.s $G/lib_core/libc/syscall/os/linux/*arm*.s $G/tests/s/*/*arm*.s"
for f in lib_core/libc/arch/arm/*.s lib_core/libc/arch/arm64/*.s lib_core/libc/syscall/os/linux/*arm*.s linker/tests/golden/*.s $gs; do
  case $f in *arm64*|*_7.s) m=7;; *) m=5;; esac
  $M/assembler/mini-asm -m $m -o $W/mk.o $f 2> $W/mk.err; r1=$?
  mini-asm -m $m -o $W/dune.o $f 2> $W/dune.err; r2=$?
  n=$((n + 1))
  if [ $r1 != $r2 ] || ! cmp -s $W/mk.err $W/dune.err || { [ $r1 = 0 ] && ! cmp -s $W/mk.o $W/dune.o; }; then bad=$((bad + 1)); echo "  differs: $f"; fi
done
if [ $bad = 0 ]; then ok "mini-asm: $n files, the same objects as dune's mini-asm"; else fail "mini-asm: $bad of $n files differ"; fi

# mini-ar: the C library's objects in a library, and its listing
objs=$(find $M/lib_core/libc -name '*.7' | sort)
$M/linker/tools/mini-ar u $W/mk.a $objs && mini-ar u $W/dune.a $objs
if cmp -s $W/mk.a $W/dune.a && [ "$($M/linker/tools/mini-ar tv $W/mk.a)" = "$(mini-ar tv $W/dune.a)" ]; then ok "mini-ar: $(echo $objs | wc -w) objects, the same library and listing as dune's mini-ar"; else fail "mini-ar: the library differs"; fi

# mini-ld: a small program (an ELF, a Plan 9 a.out), and a large one,
# mini-asm itself, of the objects mini-mk just linked: 800 KB
mini-asm -m 7 -o $W/hello.7 linker/tests/golden/hello_linux_arm64.s
bad=0
for flags in "-H7 -E _start" "-H2 -E _start"; do
  $M/linker/mini-ld -m 7 $flags -o $W/mk.exe $W/hello.7 && mini-ld -m 7 $flags -o $W/dune.exe $W/hello.7 && cmp -s $W/mk.exe $W/dune.exe || bad=$((bad + 1))
done
link=$(grep -h 'mini-ld .*assembler/mini-asm ' $W0/mk.log | tail -1 | sed 's|^mini-ld ||; s| -o [^ ]*| |; s|\.\./_mk|_mk|g')
[ -n "$link" ] || link=$(cd assembler && mini-mk -a -n 2>/dev/null | grep '^mini-ld ' | sed 's|^mini-ld ||; s| -o [^ ]*| |; s|\.\./_mk|_mk|g')
$M/linker/mini-ld $link -o $W/mk.exe && cmp -s $W/mk.exe $M/assembler/mini-asm || bad=$((bad + 1))
if [ $bad = 0 ]; then ok "mini-ld: hello (ELF, a.out) and mini-asm itself ($(wc -c < $W/mk.exe) bytes), the same executables as dune's mini-ld"; else fail "mini-ld: $bad links differ"; fi
}
job tools

cc() {
# mini-cc: the C library's sources and mini-ml's runtime, for arm64 and
# arm: the listings of the two back ends (-S, -simple -S, with -O) and
# the tree (-x) the same; on arm64 the objects too, to the byte. (On arm
# an object's bytes may differ where its value doesn't: a marshalled
# value says which blocks are shared, and OCaml shares more constants.)
CINC="-Ilib_core/libc/include -Ilib_core/libc/include/utf -Ilib_core/libc"
n=0; bad=0
for m in 7 5; do
  a=arm64; [ $m = 5 ] && a=arm
  for f in $(find lib_core/libc -name '*.c' -not -path '*/tests/*' | sort) languages/ml/runtime/runtime.c; do
    case $f in *arm64*) [ $m = 7 ] || continue;; *_arm.c|*/arm/*) [ $m = 5 ] || continue;; esac
    fl="-m $m $CINC -Ilib_core/libc/include/arch/$a -D$a -Dlinux"
    n=$((n + 1)); differs=
    for mode in "-S" "-simple -S" "-simple -O -S" "-x"; do
      # (-x also writes the object: not here)
      $M/languages/c/mini-cc $mode $fl -o $W/x.o $f > $W/mk.s 2>&1; mini-cc $mode $fl -o $W/x.o $f > $W/dune.s 2>&1
      cmp -s $W/mk.s $W/dune.s || differs="$differs [$mode]"
    done
    if [ $m = 7 ]; then
      $M/languages/c/mini-cc $fl -o $W/mk.o $f 2> /dev/null; mini-cc $fl -o $W/dune.o $f 2> /dev/null
      cmp -s $W/mk.o $W/dune.o || differs="$differs [object]"
    fi
    [ -z "$differs" ] || { bad=$((bad + 1)); echo "  differs: -m $m $f:$differs"; }
  done
done
if [ $bad = 0 ]; then ok "mini-cc: $n files (arm64, arm), the same listings, trees and arm64 objects as dune's mini-cc"; else fail "mini-cc: $bad of $n files differ"; fi
}
job cc

# mini-chidb, mini-mk, mini-rc, mini-ed: each program's own differential
# test, with dune's program in the reference's place (chidb's, 9base's)
theirs() {   # the name, what a line of an agreeing case looks like, the command
  local name=$1 pattern=$2; shift 2
  "$@" > $W/$name.txt 2>&1
  local n=$(grep -c "$pattern" $W/$name.txt)
  local fails=$(grep -c '^FAIL\|mini-mk!=mk' $W/$name.txt)
  if [ $n -gt 0 ] && [ $fails = 0 ]; then ok "$name: $n cases as dune's"
  else fail "$name: $(grep '^FAIL\|mini-mk!=mk' $W/$name.txt | head -3 | tr '\n' ' ')"; fi
}
job theirs mini-chidb '^ok ' env CHIDB=$ROOT/bin/mini-chidb TDB=$ROOT/$M/database/mini-chidb database/tests/differential.sh
job theirs mini-mk 'mini-mk=mk' env MINIMK=$ROOT/$M/builder/mini-mk MK=$ROOT/bin/mini-mk OMK= builder/tests/differential.sh live
job theirs mini-rc '^ok ' env MINIRC=$ROOT/$M/shell/mini-rc RC=$ROOT/bin/mini-rc ORC= shell/tests/differential.sh
job theirs mini-ed '^ok ' env MINIED=$ROOT/$M/editors/ed/mini-ed ED=$ROOT/bin/mini-ed editors/ed/tests/differential.sh
job theirs mini-hoc '^ok ' env MINIHOC=$ROOT/$M/utilities/calc/hoc/mini-hoc utilities/calc/hoc/tests/differential.sh
job theirs mini-awk '^ok ' env MINIAWK=$ROOT/$M/utilities/text/awk/mini-awk utilities/text/awk/tests/differential.sh
job theirs mini-dc '^ok ' env MINIDC=$ROOT/$M/utilities/calc/dc/mini-dc utilities/calc/dc/tests/differential.sh
job theirs mini-bc '^ok ' env MINIBC=$ROOT/$M/utilities/calc/bc/mini-bc utilities/calc/bc/tests/differential.sh

# the tiny programs: each one's own test, with the program ix's tools made
# (SLOW: tiny-arm and tiny-cpu by mini-ml run tiny-ml's programs slower)
T=$ROOT/$M/tiny
tiny() {   # the name, then the test's command
  local name=$1; shift
  if "$@" > $W/tiny.txt 2>&1; then ok "$name: its test passes ($(tail -1 $W/tiny.txt))"; else fail "$name: $(grep -m2 'FAIL\|rror' $W/tiny.txt | tr '\n' ' ')"; fi
}
# (tiny-assembler's, tiny-c's and tiny-ml's tests take goken's C library and its 7c)
nogoken() { echo "skip $1: its test needs goken (~/goken)"; }
if [ -d $G ]; then job tiny tiny-assembler env TA=$T/tiny-assembler tiny/TinyAssembler_test.sh; else job nogoken tiny-assembler; fi
job tiny tiny-build env TB=$T/tiny-build tiny/TinyBuildSystem_test.sh
job tiny tiny-shell env TS=$T/tiny-shell tiny/TinyShell_test.sh
job tiny tiny-editor env TE=$T/tiny-editor tiny/TinyEditor_test.sh
job tiny tiny-db env TD=$T/tiny-db tiny/TinyDatabase_test.sh
job tiny tiny-vcs env V=$T/tiny-vcs tiny/TinyVCS_test.sh
if [ -d $G ]; then job tiny tiny-c env TC=$T/tiny-c TA=$T/tiny-assembler TCPU=$T/tiny-cpu TARM=$T/tiny-arm tiny/TinyC_test.sh; else job nogoken tiny-c; fi
if [ -d $G ]; then job tiny tiny-ml env SLOW=300 TML=$T/tiny-ml TC=$T/tiny-c TA=$T/tiny-assembler TARM=$T/tiny-arm CPU=$T/tiny-cpu tiny/TinyML_test.sh; else job nogoken tiny-ml; fi
job tiny tiny-cpu env T=$T/tiny-cpu tiny/TinyCPU_test.sh
job tiny tiny-arm env T=$T/tiny-arm A=$T/tiny-assembler tiny/TinyCPUArm_test.sh
job tiny tiny-machine env T=$T/tiny-machine tiny/TinyMachine_test.sh
job tiny tiny-pi env T=$T/tiny-pi A=$T/tiny-assembler tiny/TinyMachinePi_test.sh

# the kernels' steps on the Pi 4 (plan_kernel_mini_ml.md): each image
# booted under mini-qemu, and under QEMU where it is, its lines the expected
# (mini-xv6 itself when the xv6 port's disk image is there: its mkfile's FS)
xv6=; [ -f $HOME/xv6/forks/arm64-pi4/fs.img ] && xv6=kernels/xv6
kernel_dir() {
  local d=$1
  (cd $d && mini-mk check) > $W/k.txt 2>&1
  n=$(grep -c '^ok ' $W/k.txt)
  if [ $n -gt 0 ] && ! grep -q 'differ\|^mk:' $W/k.txt; then ok "$d: $n boots as expected ($(grep -c '^ok .*under QEMU' $W/k.txt) under QEMU)"
  else fail "$d: $(grep 'differ\|^mk:' $W/k.txt | head -2 | tr '\n' ' ')"; fi
}
for d in kernels/steps/step0 kernels/steps/step1 kernels/steps/step2 kernels/steps/step3 $xv6; do job kernel_dir $d; done

wait
for i in $(seq $jobs_n); do cat $W/job$i.out; done
failures=$(cat $W/job*.out | grep -c '^FAIL')
echo "$failures failures"
[ $failures = 0 ]
