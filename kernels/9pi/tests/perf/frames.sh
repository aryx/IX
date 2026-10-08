#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What a frame of a game costs on mini-9pi, by the game's own meter
# (docs/plans/plan_playground_speed.md): the game run from the card
# under QEMU with stats=on, a key held; every 40 frames drawn the meter
# says, on the console, the frames' time and a frame's parts (the
# update, the view, the showing; the draw platform: the messages made
# and the device's time for them). The last lines printed.
#   make ix-usb card      first: the kernel and the card it runs from
#   usage: tests/perf/frames.sh game [keys] [dir]
#     game: a command of the card's (wolfenstein, cameltry, tetris;
#           "ML_HEAP=4194304 wolfenstein": the heap's half 16 MB)
#     keys: tests/live.py's (default spc,right:12000: the game started,
#           the right arrow held 12 seconds)
# The parts are read from a clock of 10 ms: right to 2 or 3 ms over 40
# frames. QEMU runs integers at about a thousand million instructions a
# second and floats at a quarter of that (it computes them): no board's
# numbers.
cd "$(dirname "$0")/../.."
d=${3:-$(mktemp -d)}
LIVE_START=6 tests/live.py $d 1 "$1 'stats=on'" ${2:-spc,right:12000} -- \
  qemu-system-arm -M raspi1ap -device loader,file=kernel-pi1-ixu.img,addr=0x8000,cpu-num=0,force-raw=on \
  -serial mon:stdio -display none -device usb-kbd -device usb-mouse -drive file=build/card.img,if=sd,format=raw,snapshot=on > /dev/null 2>&1
grep -a "^40 frames\|the showing" $d/console.txt | tail -4
