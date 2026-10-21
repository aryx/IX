#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What a frame costs on mini-9pi when only a little of it changes
# (docs/plans/plan_playground_speed.md): mini-netscape on about:home
# with stats=on, the mouse put on a link (news.ycombinator.com) then
# moved off it and back, 120 times: each crossing a frame drawn whole
# (the link lit, the status line). The meter says every 40 frames the
# showing's parts: the messages, and the device's white, shapes (the
# letters, a message each) and copy to the window. The last lines.
#   make ix-usb card      first
#   usage: tests/perf/hover.sh [dir]
cd "$(dirname "$0")/../.."
d=${1:-$(mktemp -d)}
python3 -c "
steps = [('type', \"netscape 'stats=on' 'fps=off' 'profile=off'\"), ('move', -2000, -2000), ('move', 236, 175),
         ('buttons', [('move', 300, 0), ('move', -300, 0)] * 60)]
print(repr(steps))" > $d/hover.steps
timeout 900 tests/graphics.py --step 3 --pause 0.3,0.4 --steps $d/hover.steps $d/session -- \
  qemu-system-arm -M raspi1ap -device loader,file=kernel-pi1-ixu.img,addr=0x8000,cpu-num=0,force-raw=on \
  -serial mon:stdio -display none -device usb-kbd -device usb-mouse -drive file=build/card.img,if=sd,format=raw,snapshot=on > /dev/null 2>&1
grep -a "the showing\|(white\|frames in" $d/session/console.txt | tail -6
