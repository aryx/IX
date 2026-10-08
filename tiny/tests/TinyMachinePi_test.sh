#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyMachinePi.ml, its laws:
#
# 1. each program of TinyMachinePi_tests/ assembled by TinyAssembler
#    into a raw image (the text at 0x80000, as the Pi 4's kernel8.img),
#    and run here: its console is its .expected;
# 2. run under mini-qemu and under QEMU (raspi4b, the image its
#    -kernel), the console the same; each with its .input, if it has
#    one, on the UART (QEMU's chardev file, its input-path), else
#    nothing;
# 3. the time is the machine's, not the host's: tick.s takes its five
#    interrupts and halts 50ms of simulated time after its timer
#    starts, whatever the instructions per microsecond (10, 30, 100):
#    at most its own instructions' time later.
#
# Needs a qemu-system-aarch64 with raspi4b for QEMU's part ($QEMU64,
# or the PATH's; skipped without one: Ubuntu 24.04's 8.2 has none).
#
# Usage: TinyMachinePi_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
T=${T:-$ROOT/_build/default/tiny/TinyMachinePi.exe}
A=${A:-$ROOT/_build/default/tiny/TinyAssembler.exe}
M=$ROOT/_build/default/raspberry/Main.exe
TESTS=$ROOT/tiny/tests/TinyMachinePi_tests
QEMU64=${QEMU64:-/home/pad/work/TOOLCHAINS/qemu/build/qemu-system-aarch64}
[ -x "$QEMU64" ] || QEMU64=$(command -v qemu-system-aarch64)
[ -n "$QEMU64" ] && $QEMU64 -M help | grep -q raspi4b || QEMU64=
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }

for s in $TESTS/*.s; do
  p=$(basename $s .s)
  # what it reads on its UART: p.input, or nothing
  in=${s%.s}.input; [ -f $in ] || in=/dev/null
  # 1. the image, and its console
  $A -e _start -raw 0x80000 -o $W/$p.img $s || { fail "$p: not assembled"; continue; }
  $T $W/$p.img < $in > $W/$p.out
  if cmp -s $W/$p.out ${s%.s}.expected; then echo "ok $p: its expected output"; else fail "$p: $(diff $W/$p.out ${s%.s}.expected | head -3)"; fi
  # 2. the other Pis: they never exit, a halted kernel waits forever
  timeout 5 $M -M raspi4b -kernel $W/$p.img -nographic < $in > $W/$p.mini 2>&1
  if cmp -s $W/$p.out $W/$p.mini; then echo "ok $p: under mini-qemu, the same"; else fail "$p: mini-qemu's output differs: $(diff $W/$p.out $W/$p.mini | head -6 | cat -v)"; fi
  if [ -n "$QEMU64" ]; then
    # up to three times: once in a while QEMU's console differs (seen twice
    # in make test, not reproduced alone; docs/plans/bugs/ix.md). A run
    # that differs before one that agrees is said, with what differed
    flaky=
    for try in 1 2 3; do
      timeout 5 $QEMU64 -M raspi4b -kernel $W/$p.img -display none -chardev file,id=s0,path=$W/$p.qemu,input-path=$in -serial chardev:s0 < /dev/null > /dev/null 2>&1
      cmp -s $W/$p.out $W/$p.qemu && break
      flaky="$(diff $W/$p.out $W/$p.qemu | head -6 | cat -v)"
    done
    if cmp -s $W/$p.out $W/$p.qemu; then
      echo "ok $p: under QEMU, the same"
      [ -n "$flaky" ] && echo "FLAKY $p: QEMU's output differed before try $try: $flaky"
    else fail "$p: QEMU's output differs, three times: $flaky"; fi
  fi
done
[ -n "$QEMU64" ] || echo "skipped: under QEMU (no qemu-system-aarch64 with raspi4b)"

# 3. the machine's time
for ips in 10 30 100; do
  r=$($T -ips $ips -s $W/tick.img 2>&1 >/dev/null)
  n=$(echo "$r" | sed -n 's/.* after \([0-9]*\) instructions, \([0-9]*\) interrupts, at \([0-9]*\) us/\1 \2 \3/p')
  set -- $n
  if [ "$2" = 5 ] && [ "$3" -ge 50000 ] && [ "$3" -le $((50000 + $1 / ips + 5)) ]; then echo "ok tick at $ips instructions a microsecond: 5 interrupts, halted at $3 us"
  else fail "tick at $ips: $r"; fi
done

echo "TinyMachinePi_test: $failures failures"
exit $((failures > 0))
