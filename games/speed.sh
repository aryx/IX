#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_playground_speed.md that no host
# changes: the instructions of a frame, counted by mini-5i (-s) on a
# game built by mini-ml for arm (mini-mk O=5 in games/: the Pi1's
# processor's instructions), its picture 480 by 480 as on mini-9pi's
# screen. A run draws n frames and writes the last (the platform without
# a window); a frame's cost is the difference of two runs.
#   a whole frame:    2 frames less 1, each drawn whole (redraw=all)
#   a frame's change: (60 frames less 1) / 59, what changed only drawn
# Three runs of a minute each (mini-5i runs 15 million instructions a second).
# usage: games/speed.sh [game]     (default: puzzle/tetris)

cd "$(dirname "$0")/.."
g=_mk/5/games/${1:-puzzle/tetris}
[ -x $g ] || { echo "no $g: (cd games && mini-mk O=5)"; exit 1; }
count() { bin/mini-5i -s $g -dump-frame $1 /dev/null seed=1 size=480 $2 2>&1 | sed -n 's/^mini-5i: \([0-9]*\) instructions.*/\1/p'; }
one=$(count 1 redraw=all); two=$(count 2 redraw=all); sixty=$(count 60 "")
echo "the program's start, a frame, the picture written:  $one instructions"
echo "a whole frame (the shapes drawn, 230,400 pixels):   $((two - one))"
echo "a frame's change (Redraw: the falling piece):       $(((sixty - one) / 59))"
echo "a Pi1 at 700 million instructions a second (an upper bound: it does less): $((700000000 / (two - one))) whole frames a second"
