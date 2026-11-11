#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-9pi's own panic, its trace (plan_debugger.md, stage 6): a boot
# whose script writes "exception" to #k/reboot, an exception raised in
# the system call and not caught, Main.guard's panic; its message and
# the raise's addresses on the console, named on the host by mini-where
# from kernel.img.aout, the image linked again with its tables (mini-ld
# -g -H0): Devsys's write, where the exception was raised, among them.
# The kernel of an ix build relinked with that boot, as acid.sh's, in a
# copy of kernels/9pi the second argument names.
# usage: kernels/9pi/tests/panic.sh build-dir [kernel-dir]

ROOT=$(cd $(dirname $0)/../../.. && pwd)
b=$1
K=${2:-kernels/9pi}
P=$HOME/principia
BIN=$P/ROOT/arch/arm/bin
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
[ -f $b/$K/kernel.img ] || { echo "no kernel built in $b/$K"; exit 1; }
printf '#!/boot/rc -m /boot/rcmain\n/boot/echo exception > %s\n' "'#k/reboot'" > $W/boot.rc
# (dated in the past: OCaml 4.14 stats whole seconds on macOS, and
# mini-mk took the bootdir below, of the same second, as out of date,
# made again without this boot's files: /boot/seg did not exist)
touch -t 200001010000 $W/boot.rc
mini-mkbootdir $b/$K/bootdir $P boot=$W/boot.rc rcmain=$P/ROOT/rc/lib/rcmain rc=$BIN/rc echo=$BIN/echo &&
  (cd $ROOT/kernels/9pi && MKSHELL=mini-rc NPROC=32 mini-mk O=5 B=$b DIR=$K PRINCIPIA=$P BOOTRC=$W/boot.rc) > $W/mk.log 2>&1 ||
  { echo "the kernel not relinked:"; tail -3 $W/mk.log | cut -c1-200; exit 1; }
out=$W/out.txt
timeout 120 mini-qemu -M raspi1ap -device loader,file=$b/$K/kernel.img,addr=0x8000,cpu-num=0,force-raw=on -nographic \
  < /dev/null > $out 2>&1 &
pid=$!
n=0
until grep -aq '^raised at:' $out || [ $n -ge 1200 ]; do sleep 0.1; n=$((n + 1)); done
sleep 0.5
kill $pid 2> /dev/null; wait $pid 2> /dev/null
tr -d '\r' < $out > $W/console
grep -q '^panic: an exception in a system call: Failure("/dev/reboot")$' $W/console ||
  { echo "FAIL: mini-9pi's panic: no message"; tail -5 $W/console | cut -c1-200; exit 1; }
named=$(grep '^raised at:' $W/console | xargs $ROOT/bin/mini-where $b/$K/kernel.img.aout 2>&1)
echo "$named" | grep -q 'Devsys' ||
  { echo "FAIL: mini-9pi's panic: its trace does not name Devsys"; echo "$named" | head -8; exit 1; }
echo "mini-9pi's panic: its message, its trace named by mini-where ($(echo "$named" | wc -l) frames)"
