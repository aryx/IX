#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# ix for arm, built by ix (plan_mkfiles.md, step 4): mini-mk O=5 with
# the programs dune built, then the arm programs run, under qemu-arm
# (binfmt_misc runs them as any program):
# - mini-rc, mini-ed, mini-mk, mini-chidb: their differential tests,
#   against dune's builds;
# - mini-asm and mini-ld, 32-bit programs: the linker's recorded
#   executables (golden.txt), all but Mach-O's, whose text is at 4 GB
#   (an address is an int: 31 bits there);
# - mini-cc and mini-ml: the same assembly as their arm64 builds write,
#   for both machines;
# - mini-ld linking mini-asm for arm from the same objects: the same
#   executable as the 64-bit linker's;
# - the kernels' steps on the Pi 1: each booted, its lines the expected.
# usage: mkfiles/check_arm.sh     (after dune build, and mini-mk for _mk/7)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH=$ROOT/bin:$PATH
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
ok() { echo "ok $*"; }
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
cd $ROOT
[ -x _mk/7/languages/ml/mini-ml ] || mini-mk > $W/mk7.log 2>&1 || { echo "FAIL mini-mk: $(tail -3 $W/mk7.log)"; exit 1; }
mini-mk O=5 > $W/mk.log 2>&1 || { echo "FAIL mini-mk O=5: $(tail -3 $W/mk.log | cut -c1-300)"; exit 1; }
M=_mk/5
ok "mini-mk O=5: $(ls $M/*/mini-* $M/*/*/mini-* $M/tiny/tiny-* | wc -l) programs for arm"
$M/shell/mini-rc -c 'echo arm' > $W/rc.txt 2>&1 && [ "$(cat $W/rc.txt)" = arm ] || { echo "FAIL an arm program does not run here (qemu-arm, binfmt_misc): $(head -1 $W/rc.txt)"; exit 1; }

# the programs: each one's differential test, dune's build the reference
theirs() {   # the name, what a line of an agreeing case looks like, the command
  local name=$1 pattern=$2; shift 2
  "$@" > $W/$name.txt 2>&1
  local n=$(grep -c "$pattern" $W/$name.txt) fails=$(grep -c '^FAIL\|mini-mk!=mk' $W/$name.txt)
  if [ $n -gt 0 ] && [ $fails = 0 ]; then ok "$name on arm: $n cases as dune's"
  else fail "$name on arm: $(grep '^FAIL\|mini-mk!=mk' $W/$name.txt | head -3 | tr '\n' ' ')"; fi
}
theirs mini-chidb '^ok ' env CHIDB=$ROOT/bin/mini-chidb TDB=$ROOT/$M/database/mini-chidb database/tests/differential.sh
theirs mini-mk 'mini-mk=mk' env MINIMK=$ROOT/$M/builder/mini-mk MK=$ROOT/bin/mini-mk OMK= builder/tests/differential.sh live
theirs mini-rc '^ok ' env MINIRC=$ROOT/$M/shell/mini-rc RC=$ROOT/bin/mini-rc ORC= shell/tests/differential.sh
theirs mini-ed '^ok ' env MINIED=$ROOT/$M/editor/mini-ed ED=$ROOT/bin/mini-ed editor/tests/differential.sh

# mini-asm and mini-ld: the recorded executables
n=0; bad=0; macho=0
while read -r m h e f sum; do
  if [ $h = -H6 ]; then macho=$((macho + 1)); continue; fi
  n=$((n + 1))
  if $M/assembler/mini-asm -m $m -o $W/t.$m linker/tests/golden/$f 2> $W/err && $M/linker/mini-ld -m $m $h -E $e -o $W/t.exe $W/t.$m 2>> $W/err \
     && [ "$(sha256sum < $W/t.exe | cut -d' ' -f1)" = "$sum" ]; then :; else bad=$((bad + 1)); echo "  differs: $m $h $f $(head -1 $W/err | cut -c1-80)"; fi
done < linker/tests/golden.txt
if [ $bad = 0 ]; then ok "mini-asm, mini-ld on arm: $n recorded executables, the same (not Mach-O's $macho)"; else fail "mini-asm, mini-ld on arm: $bad of $n differ"; fi

# mini-cc and mini-ml: the assembly, for both machines
L=lib_core/libc; n=0; bad=0
for f in languages/ml/runtime/runtime.c $L/ix/fmt.c $L/ix/vlrt.c $L/port/pow.c; do
  for m in 5 7; do
    a=arm64; [ $m = 5 ] && a=arm
    for t in 5 7; do _mk/$t/languages/c/mini-cc -m $m -I$L/include -I$L/include/utf -I$L -I$L/include/arch/$a -D$a -Dlinux -S -o $W/x.o $f > $W/cc$t.s 2>&1; done
    n=$((n + 1)); cmp -s $W/cc5.s $W/cc7.s || { bad=$((bad + 1)); echo "  differs: mini-cc -m $m $f"; }
  done
done
if [ $bad = 0 ]; then ok "mini-cc on arm: $n listings as its arm64 build's"; else fail "mini-cc on arm: $bad of $n listings differ"; fi
I=$(for d in core base collections printing parsing system commons; do echo -n "-I lib_core/$d "; done); n=0; bad=0
for f in lib_core/collections/List.ml lib_core/printing/Printf.ml lib_core/base/Float.ml lib_core/system/Unix.ml linker/Link.ml linker/Arm64.ml assembler/Parser_asm.ml; do
  for m in 5 7; do
    for t in 5 7; do _mk/$t/languages/ml/mini-ml -m $m -I $(dirname $f) -I assembler $I -S -o /dev/stdout $f > $W/ml$t.s 2>&1; done
    n=$((n + 1)); cmp -s $W/ml5.s $W/ml7.s || { bad=$((bad + 1)); echo "  differs: mini-ml -m $m $f"; }
  done
done
if [ $bad = 0 ]; then ok "mini-ml on arm: $n assemblies as its arm64 build's"; else fail "mini-ml on arm: $bad of $n assemblies differ"; fi

# a whole link, by the linker built for arm
cp $M/assembler/mini-asm $W/ref; rm $M/assembler/mini-asm
cmd=$(cd assembler && mini-mk O=5 2>&1 | grep '^mini-ld' | tail -1)
if (cd assembler && sh -c "$(echo "$cmd" | sed "s|^mini-ld|../$M/linker/mini-ld|; s| -o [^ ]*| -o $W/by5|")") 2> $W/err && cmp -s $W/by5 $W/ref
then ok "mini-ld on arm: mini-asm for arm linked ($(stat -c %s $W/ref) bytes), the same executable as the 64-bit linker's"
else fail "mini-ld on arm: mini-asm linked differs: $(head -1 $W/err | cut -c1-120)"; fi

# the kernels' steps on the Pi 1 (plan_kernel_mini_ml.md, step 9): each
# image booted under mini-qemu, and under QEMU where it is, its lines
# the expected (mkfiles/check.sh's, for the Pi 4)
for d in kernel/step0 kernel/step1 kernel/step2 kernel/step3; do
  (cd $d && mini-mk O=5 check) > $W/k.txt 2>&1
  n=$(grep -c '^ok ' $W/k.txt)
  if [ $n -gt 0 ] && ! grep -q 'differ\|^mk:' $W/k.txt; then ok "$d on the Pi 1: $n boots as expected ($(grep -c '^ok .*under QEMU' $W/k.txt) under QEMU)"
  else fail "$d on the Pi 1: $(grep 'differ\|^mk:' $W/k.txt | head -2 | tr '\n' ' ')"; fi
done

echo "$failures failures"
[ $failures = 0 ]
