#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-xv6's steps (plan_kernel.md): each kernel/stepN/ built (its
# Makefile; ocaml-light's cross compiler by ocaml-light.sh, once), then
# its kernel.img run under mini-qemu and under QEMU's raspi1ap (when
# qemu-system-arm is here), the console the same as stepN/expected; then
# mini-xv6 itself on both boards (xv6/: its Makefile's check, BOARD=pi1
# and pi4, a shell session the same as the xv6 port's C kernel's, and
# usertests); then mini-9pi (9pi/: its Makefile's check, plan_9pi.md).
#
# Usage: test.sh [stepN... xv6 9pi]

HERE=$(cd "$(dirname "$0")" && pwd)
M=$HERE/../_build/default/raspberry/Main.exe
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
$HERE/ocaml-light.sh arm > /dev/null || { echo "test.sh: no ocaml-light for arm"; exit 1; }
$HERE/ocaml-light.sh arm64 > /dev/null || { echo "test.sh: no ocaml-light for arm64"; exit 1; }
# an emulator run until its output is $d/expected, then half a second
# more (what it would say after that is a difference), or n seconds
until_expected() {  # seconds, the output's file, where the command writes, the command
  local n=$(($1 * 10)) out=$2 pid log=$3; shift 3
  "$@" < /dev/null > $log 2>&1 &
  pid=$!
  until cmp -s $out $d/expected || [ $n -le 0 ]; do sleep 0.1; n=$((n - 1)); done
  sleep 0.5
  kill $pid 2> /dev/null; wait $pid 2> /dev/null
}
steps=${@:-$(cd $HERE && ls -d step* xv6 9pi)}
for step in $steps; do
  d=$HERE/$step
  if [ $step = xv6 ]; then
    for board in pi1 pi4; do
      make -C $d BOARD=$board check > $W/check.log 2>&1 || fail "xv6 $board: $(tail -5 $W/check.log)"
      grep '^ok' $W/check.log
    done
    continue
  fi
  if [ $step = 9pi ]; then
    make -C $d check > $W/check.log 2>&1 || fail "9pi: $(tail -5 $W/check.log)"
    grep '^ok' $W/check.log
    continue
  fi
  # (step0 has a mkfile only: ix's tools', checked by mkfiles/check.sh)
  [ -f $d/Makefile ] || continue
  make -C $d > $W/make.log 2>&1 || { fail "$step: not built"; tail -5 $W/make.log; continue; }
  loader="loader,file=$d/kernel.img,addr=0x8000,cpu-num=0,force-raw=on"
  # the kernels halt: the emulators never exit, their output is kept;
  # each is stopped when it has said what is expected, or after its seconds
  # (old: timeout 60 for mini-qemu, timeout 10 for QEMU, each to its end: 70 s a step)
  until_expected 60 $W/mini $W/mini $M -M raspi1ap -device $loader -nographic
  if cmp -s $W/mini $d/expected; then echo "ok $step: under mini-qemu, as expected"; else fail "$step: mini-qemu: $(diff $W/mini $d/expected | head -3)"; fi
  if command -v qemu-system-arm > /dev/null; then
    until_expected 10 $W/qemu /dev/null qemu-system-arm -M raspi1ap -device $loader -display none -serial file:$W/qemu
    if cmp -s $W/qemu $d/expected; then echo "ok $step: under QEMU, as expected"; else fail "$step: QEMU: $(diff $W/qemu $d/expected | head -3)"; fi
  fi
done
echo "kernel: $failures failures"
exit $((failures > 0))
