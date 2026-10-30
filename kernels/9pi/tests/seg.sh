#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-9pi's segments (memory/Sysseg): machine/tests/plan9/seg.c, a
# JIT's way with them (code written in a segment attached, segflush,
# called; written again, flushed, the new code run; segfree, a class
# refused, segdetach), run by the kernel under mini-qemu: the boot's
# directory made with it and a boot script that runs it, the kernel of
# an ix build relinked with them (mini-mk O=5 B=dir in kernels/9pi
# made before: lite.sh's pi1_by_ix). Needs _mk/5-plan9's libc.
# usage: kernels/9pi/tests/seg.sh build-dir

ROOT=$(cd $(dirname $0)/../../.. && pwd)
b=$1
P=$HOME/principia
BIN=$P/ROOT/arch/arm/bin
IX=$ROOT/_build/default
M=$ROOT/_mk/5-plan9
L=$ROOT/lib_core/libc
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/5-plan9/lib_core/libc.a"; exit 0; }
[ -f $b/kernels/9pi/kernel.img ] || { echo "no kernel built in $b"; exit 1; }
$IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 \
  -o $W/seg.5 $ROOT/machine/tests/plan9/seg.c && $IX/linker/Main.exe -m 5 -H2 -o $W/seg $W/seg.5 $M/lib_core/libc.a ||
  { echo "seg.c not built"; exit 1; }
printf '#!/boot/rc -m /boot/rcmain\n/boot/echo segments:\n/boot/seg\n/boot/echo segments done\n' > $W/boot.rc
mini-mkbootdir $b/kernels/9pi/bootdir $P boot=$W/boot.rc rcmain=$P/ROOT/rc/lib/rcmain rc=$BIN/rc echo=$BIN/echo seg=$W/seg &&
  (cd $ROOT/kernels/9pi && MKSHELL=mini-rc NPROC=32 mini-mk O=5 B=$b PRINCIPIA=$P BOOTRC=$W/boot.rc) > $W/mk.log 2>&1 ||
  { echo "the kernel not relinked:"; tail -3 $W/mk.log | cut -c1-200; exit 1; }
out=$W/out.txt
mini-qemu -M raspi1ap -device loader,file=$b/kernels/9pi/kernel.img,addr=0x8000,cpu-num=0,force-raw=on -nographic \
  < /dev/null > $out 2>&1 &
pid=$!
n=0
until grep -aq '^segments done' $out || [ $n -ge 600 ]; do sleep 0.1; n=$((n + 1)); done
kill $pid 2> /dev/null; wait $pid 2> /dev/null
got=$(sed -n '/^segments:/,/^segments done/p' $out | tr -d '\r' | sed '1d;$d')
want="attached, zeros: 1
f(1) = 43
written again, f(1) = 8
freed, zeros: 1
a bad class refused: 1
detached: 1"
[ "$got" = "$want" ] || { echo "FAIL: mini-9pi's segments"; diff <(echo "$want") <(echo "$got") | head; tail -5 $out | cut -c1-200; exit 1; }
