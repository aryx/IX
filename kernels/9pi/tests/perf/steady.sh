#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Where a game's frames go, function by function, in instructions
# (docs/plans/plan_playground_speed.md): mini-qemu's samples (-prof) of
# a long run less a short one's. A profile from the boot on is mostly
# the boot (pages zeroed, the major collector); the same game with a
# key held 4 seconds, then 24, and the first's samples taken from the
# second's, is 20 seconds of frames and nothing else.
#   make ix-usb card      first
#   usage: tests/perf/steady.sh game [symbols] [n] [dir]
#     symbols: the kernel's ELF (the default: build/pi1-ocaml-ixu/kernel.elf),
#              the program's instructions then one line, "(user)"; or
#              the game's listing (mini-ld -v with the game's own link
#              command, its output kept), the kernel's instructions
#              then left out: the program's functions
#     n: the lines printed (30)
# The samples and the symbols are to be one build's: after any rebuild
# the names are a few functions off, and nothing says so.
cd "$(dirname "$0")/../.."
symbols=${2:-build/pi1-ocaml-ixu/kernel.elf}
d=${4:-$(mktemp -d)}
run() {
  rm -rf $d/live
  LIVE_START=6 timeout 900 tests/live.py $d/live 1 "$1" spc,right:$2 -- \
    ../../bin/mini-qemu -M raspi1ap -device loader,file=kernel-pi1-ixu.img,addr=0x8000,cpu-num=0,force-raw=on \
    -serial mon:stdio -display none -device usb-kbd -device usb-mouse -drive file=build/card.img,if=sd,format=raw,snapshot=on -prof $3 > /dev/null 2>&1
}
run "$1" 4000 $d/short.txt
run "$1" 24000 $d/long.txt
case $symbols in *.txt) user=1;; *) user=0;; esac
python3 - $d/short.txt $d/long.txt $user > $d/steady.txt <<'PY'
import sys
def samples(p):
    d = {}
    for l in open(p):
        f = l.split()
        if len(f) == 2: d[f[0]] = int(f[1])
    return d
a, b, user = samples(sys.argv[1]), samples(sys.argv[2]), sys.argv[3] == "1"
for k, v in b.items():
    n = v - a.get(k, 0)
    # (the kernel is at 0x80000000 and up; a program below 1 GB)
    if n > 0 and not (user and int(k, 16) >= 0x40000000): print(k, n)
PY
python3 tests/perf/pcprof.py $d/steady.txt $symbols ${3:-30}
