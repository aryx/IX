#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What Redraw saves the draw platform on mini-9pi (docs/notes/notes_opti_inventory.md,
# O30): a program that changes a little of its picture, run under QEMU
# with stats=on and a redraw= flag, the meter's last lines printed.
#   hover     mini-netscape, the mouse on and off a link of about:home
#   office    mini-office, a line typed in a Document
#   drscheme  DrScheme, a line typed in its editor
# The flag: all (each frame whole), top (the shapes compared at the top
# of the list only), or none (inside the groups too, the default).
# The games: tests/perf/frames.sh "cameltry 'redraw=top'".
#   make ix-usb card      first
#   usage: tests/perf/redraw.sh hover|office|drscheme [all|top] [dir]
cd "$(dirname "$0")/../.."
X=${2:+"'redraw=$2'"}
d=${3:-$(mktemp -d)}
case $1 in
hover) python3 -c "
steps = [('type', \"netscape 'stats=on' 'fps=off' 'profile=off' $X\"), ('move', -2000, -2000), ('move', 236, 175),
         ('buttons', [('move', 300, 0), ('move', -300, 0)] * 60)]
print(repr(steps))" > $d/s.steps ;;
office) python3 -c "
steps = [('type', \"office 'stats=on' 'fps=off' $X\"), ('move', 236, 361), ('buttons', [('down', 'left'), ('up', 'left')]),
         ('type', 'Typed on mini-9pi, a line of text. ' * 4)]
print(repr(steps))" > $d/s.steps ;;
drscheme) python3 -c "
steps = [('type', \"drscheme 'stats=on' 'fps=off' $X\"), ('move', 752, 50), ('buttons', [('down', 'left'), ('up', 'left')]),
         ('key', 'esc'), ('type', '(define (f x) (* x x)) ' * 6)]
print(repr(steps))" > $d/s.steps ;;
*) echo "usage: tests/perf/redraw.sh hover|office|drscheme [all|top] [dir]"; exit 1 ;;
esac
timeout 1200 tests/graphics.py --step 3 --pause 0.3,0.4 --steps $d/s.steps $d/session -- \
  qemu-system-arm -M raspi1ap -device loader,file=kernel-pi1-ixu.img,addr=0x8000,cpu-num=0,force-raw=on \
  -serial mon:stdio -display none -device usb-kbd -device usb-mouse -drive file=build/card.img,if=sd,format=raw,snapshot=on > /dev/null 2>&1
grep -a "the showing\|(white\|frames in" $d/session/console.txt | tail -6
