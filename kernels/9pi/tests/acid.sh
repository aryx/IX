#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-acid on mini-9pi (plan_debugger.md, stage 7: the kernel's #p for
# a debugger: mem, regs, ctl's stop, start, startstop, waitstop, hang, a
# breakpoint's note): mini-acid built for Plan 9, with ix's library,
# debugging a program by mini-cc (debuggers/tests/acid/proc/target.c)
# in mini-9pi under mini-qemu: tests/acid.acid's session (new, a
# breakpoint, cont, stk, a variable, step, stk), its output as recorded
# (tests/acid.out). The boot's directory made with them and a boot
# script that runs it, the kernel of an ix build relinked with them
# (mini-mk O=5 B=dir in kernels/9pi made before: lite.sh's pi1_by_ix),
# in kernels/9pi or in the copy of it the third argument names (cp -a:
# only the boot's directory and the link made again), so that another
# relink of the same build may run beside it (seg.sh's).
# Needs _mk/5-plan9's lib_core.
# usage: kernels/9pi/tests/acid.sh build-dir [record | check] [kernel-dir]

ROOT=$(cd $(dirname $0)/../../.. && pwd)
b=$1
K=${3:-kernels/9pi}
P=$HOME/principia
BIN=$P/ROOT/arch/arm/bin
IX=$ROOT/_build/default
M=$ROOT/_mk/5-plan9
L=$ROOT/lib_core/libc
T=$ROOT/kernels/9pi/tests
LIB=$ROOT/debuggers/acid/lib
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
[ -f $M/lib_core/libc.a ] || { echo "skipped: no _mk/5-plan9/lib_core/libc.a"; exit 0; }
[ -f $b/$K/kernel.img ] || { echo "no kernel built in $b/$K"; exit 1; }
(cd $ROOT/debuggers/acid && MKSHELL=mini-rc PATH=$ROOT/bin:$PATH mini-mk O=5 OS=plan9 > $W/acid.log 2>&1) ||
  { echo "mini-acid not built"; tail -3 $W/acid.log; exit 1; }
$IX/languages/c/Main.exe -m 5 -I$L/include -I$L/include/utf -I$L -I$L/include/arch/arm -Darm -Dplan9 \
  -o $W/target.5 $ROOT/debuggers/tests/acid/proc/target.c && $IX/linker/Main.exe -m 5 -g -H2 -o $W/target $W/target.5 $M/lib_core/libc.a ||
  { echo "the target not built"; exit 1; }
printf '#!/boot/rc -m /boot/rcmain\n/boot/bind %s /proc\n/boot/echo acid:\n/boot/acid -l /boot/port.acid -l /boot/arm.acid /boot/target < /boot/s.acid\n/boot/echo acid done\n' "'#p'" > $W/boot.rc
mini-mkbootdir $b/$K/bootdir $P boot=$W/boot.rc rcmain=$P/ROOT/rc/lib/rcmain rc=$BIN/rc echo=$BIN/echo bind=$BIN/bind \
    acid=$M/debuggers/acid/mini-acid target=$W/target port.acid=$LIB/port.acid arm.acid=$LIB/arm.acid s.acid=$T/acid.acid &&
  (cd $ROOT/kernels/9pi && MKSHELL=mini-rc NPROC=32 mini-mk O=5 B=$b DIR=$K PRINCIPIA=$P BOOTRC=$W/boot.rc) > $W/mk.log 2>&1 ||
  { echo "the kernel not relinked:"; tail -3 $W/mk.log | cut -c1-200; exit 1; }
out=$W/out.txt
timeout 120 mini-qemu -M raspi1ap -device loader,file=$b/$K/kernel.img,addr=0x8000,cpu-num=0,force-raw=on -nographic \
  < /dev/null > $out 2>&1 &
pid=$!
n=0
until grep -aq '^acid done' $out || [ $n -ge 1200 ]; do sleep 0.1; n=$((n + 1)); done
kill $pid 2> /dev/null; wait $pid 2> /dev/null
tr -d '\r' < $out | sed -n '/^acid:$/,/^acid done/p' | sed '1d;$d' > $W/got
[ "$2" = record ] && cp $W/got $T/acid.out
[ -s $W/got ] || { echo "FAIL: mini-acid on mini-9pi: no session"; tail -5 $out | cut -c1-200; exit 1; }
cmp -s $T/acid.out $W/got || { echo "FAIL: mini-acid on mini-9pi"; diff $T/acid.out $W/got | head; tail -5 $out | cut -c1-200; exit 1; }
echo "mini-acid on mini-9pi: a session as recorded"
