#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The tests of TinyMachine.ml, its laws, on TinyKernel/steps/v0/kernel.tm linked
# with its four user programs (v0/a.tm to d.tm: a and b print 20
# letters each, c executes csrw, d stores into the kernel):
#
# 1. with a period longer than any program, no interrupt: the programs
#    one after the other, exactly;
# 2. with periods from 30 to 400 (every 13th) (below 30 the next interrupt
#    comes before the kernel's eret: no user instruction ever runs),
#    every letter printed, c's and d's faults caught, the machine
#    halted with status 0; and a and b interleaved, a b before a's
#    last a;
# 3. the same period, the same output: the time is the program's;
# 4. the programs linked in another order (tiny-linker; every .tm here
#    is assembled and linked by link.sh's link_tm), the same output;
# 5. each program of TinyMachine_tests/ (the machine's features for
#    v6, a kernel that was (xv6's kind, removed on 2026-10-13): amoswap, core, ip, the pages, the console's input,
#    the disk) prints its .expected, given its .input if there is one;
#    disk.tm a fresh image (block 1 "hello, disk"), whose block 2 it
#    has written WRITTEN after the halt; screen.tm its events
#    (screen.events: the mouse, then keys), whose screen at the halt
#    has screen.cksum's sum; net.tm a wire that comes back (-net-loop
#    100), and, run again without one, a machine that says it has none;
#    rate.tm the speed that -rate 16 gives the machine, read from its
#    rate register; cores.tm three cores (-cores 3): their count, the
#    interrupt between them and who raised it, a device of core 0's
#    reached by another, a fault.
#
# Usage: TinyMachine_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
T=${T:-$ROOT/_build/default/tiny/TinyMachine.exe}
. $ROOT/tiny/tests/link.sh
K=$ROOT/tiny/TinyKernel/steps/v0/kernel.tm
P=$(ls $ROOT/tiny/TinyKernel/steps/v0/[abcd].tm)
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }

with_period() { # period -> the output, then the status on its own line
  sed "s/^period:\t.word\t[0-9]*/period:\t.word\t$1/" $K > $W/k.tm
  link_tm $W/k.img $W/k.tm $P && timeout 10 $T $W/k.img; echo; echo $?
}

out=$(with_period 1000000)
expected="$(printf 'a%.0s' {1..20})$(printf 'b%.0s' {1..20})c<illegal>d<fault>"
if [ "$out" = "$expected
0" ]; then echo "ok long period: the programs one after the other"; else fail "long period: $out"; fi

bad=0
for p in $(seq 30 13 400); do
  out=$(with_period $p); s=${out##*$'\n'}; text=${out%$'\n'*}; text=${text%$'\n'}
  letters=$(echo -n "$text" | sed 's/<illegal>//; s/<fault>//')
  # (wc's count without its padding: BSD's, macOS's, has some)
  na=$(echo -n "$letters" | tr -cd a | wc -c | tr -d ' '); nb=$(echo -n "$letters" | tr -cd b | wc -c | tr -d ' ')
  why=""
  [ "$s" = 0 ] || why="status $s"
  [ "$na" = 20 ] && [ "$nb" = 20 ] || why="$why; $na a, $nb b"
  case "$text" in *c*"<illegal>"*) ;; *) why="$why; no c then <illegal>" ;; esac
  case "$text" in *d*"<fault>"*) ;; *) why="$why; no d then <fault>" ;; esac
  last_a=$(echo -n "$letters" | grep -bo a | tail -1 | cut -d: -f1); first_b=$(echo -n "$letters" | grep -bo b | head -1 | cut -d: -f1)
  [ "$p" -le 100 ] && { [ -n "$first_b" ] && [ "$first_b" -lt "$last_a" ] || why="$why; not interleaved"; }
  [ "$(with_period $p)" = "$out" ] || why="$why; not the same twice"
  if [ -n "$why" ]; then bad=$((bad + 1)); [ $bad -le 3 ] && echo "  period $p: $why: $text"; fi
done
if [ $bad = 0 ]; then echo "ok 29 periods, 30-400: every letter, both faults caught, halted with 0, interleaved, the same twice"; else fail "periods: $bad of 29"; fi

link_tm $W/kernel.img $K $P && link_tm $W/other.img $K $(echo $P | tr ' ' '\n' | tac)
if [ "$($T $W/other.img; echo $?)" = "$($T $W/kernel.img; echo $?)" ]; then
  echo "ok link: the programs in another order, the same run"
else fail "link: the order of the programs matters"; fi

for t in $ROOT/tiny/tests/TinyMachine_tests/*.tm; do
  b=$(basename $t .tm); in=/dev/null; opts=
  [ -f ${t%.tm}.input ] && in=${t%.tm}.input
  if [ $b = disk ]; then
    { head -c 1024 /dev/zero; printf 'hello, disk\n'; head -c 1012 /dev/zero; head -c 1024 /dev/zero; } > $W/disk.img
    opts="-d $W/disk.img"
  fi
  [ $b = net ] && opts="-net-loop 100"
  [ $b = rate ] && opts="-rate 16"
  [ $b = cores ] && opts="-cores 3"
  [ -f ${t%.tm}.events ] && opts="-events ${t%.tm}.events -screen $W/$b.ppm"
  link_tm $W/$b.image $t && timeout 10 $T $opts $W/$b.image < $in > $W/$b.out 2>&1
  if cmp -s $W/$b.out ${t%.tm}.expected; then echo "ok $b: its expected output"
  else fail "$b: $(diff ${t%.tm}.expected $W/$b.out | head -3)"; fi
  if [ $b = disk ]; then
    if [ "$(dd if=$W/disk.img bs=1024 skip=2 count=1 2>/dev/null | head -c 7)" = WRITTEN ]; then echo "ok disk: block 2 written back"
    else fail "disk: block 2 not written back"; fi
  fi
  if [ -f ${t%.tm}.cksum ]; then
    if [ "$(cksum < $W/$b.ppm)" = "$(cat ${t%.tm}.cksum)" ]; then echo "ok $b: its screen at the halt"
    else fail "$b: its screen: $(cksum < $W/$b.ppm)"; fi
  fi
done

out=$(timeout 10 $T $W/net.image 2>&1)
if [ "$out" = "no wire" ]; then echo "ok net: without a wire, said so"; else fail "net without a wire: $out"; fi

echo "TinyMachine_test: $failures failures"
exit $((failures > 0))
