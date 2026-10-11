#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The translator (web/jit's Jit) against the interpreter, under node
# (plan_web.md, 2026-10-11):
#   1. the console's bytes of a boot and two commands: the same from
#      Boot_bench (the interpreter) and Boot_jit (the blocks);
#   2. JIT_CHECK=1 over the same: each block's first run done again by
#      the interpreter, registers, flags and bytes written compared;
#      a difference is printed;
#   3. rio, a window, cameltry in it by Boot_jit's -do: the seconds and
#      the instructions, the screen written (D/jit_check.ppm).
#   usage: jit_check.sh D [kernel.img [card.img]]     (D: where its files go)
# Needs: node; dune build ./raspberry/tests/Boot_jit.bc.js
# ./raspberry/tests/Boot_bench.bc.js; the web kernel and the card
# (make -C kernels/9pi ix-web card). Minutes; not in make test.
R=$(cd "$(dirname "$0")/../.." && pwd); S=${1:?a directory}
K=${2:-$R/kernels/9pi/kernel-pi1-web.img}; C=${3:-$R/kernels/9pi/build/card.img}
B=$R/_build/default/raspberry/tests; N="node --max-old-space-size=4096"
mkdir -p $S; cd $R/kernels/9pi
lines=("ls /bin | wc" "seq 5 | sort -r")
BOOT_LIMIT=200 $N $B/Boot_bench.bc.js $K $C -- "${lines[@]}" > $S/console-interpreter.txt 2> $S/err-interpreter.txt
BOOT_LIMIT=200 $N $B/Boot_jit.bc.js $K $C -- "${lines[@]}" > $S/console-jit.txt 2> $S/err-jit.txt; tail -4 $S/err-jit.txt
cmp $S/console-interpreter.txt $S/console-jit.txt && echo "ok the same console"
if BOOT_LIMIT=300 JIT_CHECK=1 $N $B/Boot_jit.bc.js $K $C -- "${lines[@]}" 2>&1 > /dev/null | grep -A6 "differ" | cut -c1-700 | head -12 | grep .; then echo "FAILED: a block differs"; else echo "ok no block differs"; fi
D="k rio_; s 40; p 300 200 4; s 20; p 300 200 0; s 20; p 100 100 4; p 200 200 4; p 700 600 4; s 20; p 700 600 0; s 40; p 400 300 1; p 400 300 0; s 20; k cameltry_; s 20; s 20; shot $S/jit_check.ppm"
timeout 900 $N $B/Boot_jit.bc.js -ips ${IPS:-12} $K $C -do "$D" -- 2>&1 > /dev/null | tail -4
