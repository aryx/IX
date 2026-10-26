#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A frame's instructions on arm by mini-5i -s, for the games whose
# frame a plan counts (plan_ml_floats.md, plan_virtuaracing.md): each
# game built by mini-ml for arm (mini-mk O=5 in games/, the ppm
# platform), run to frame a and to frame b, (b's - a's) / (b - a). The
# runs are in parallel; mini-5i does 15 million instructions a second,
# so mini-virtuaracing's start alone is minutes. Twenty frames for it:
# its collector copies megabytes now and then, which two frames may
# miss or catch whole.
# usage: games/frame_count.sh [root [game...]]   (root: the tree whose _mk/5 is
#   counted, default this one; mini-5i is this one's, and the runs are
#   in its top directory, where the games look for their data)

I=$(cd "$(dirname "$0")/.." && pwd); R=${1:-$I}; shift; only="$*"
M=$R/_mk/5/games; T=$(mktemp -d)
count() { "$I/bin/mini-5i" -s "$@" 2>&1 >/dev/null |
  sed -n 's/^mini-5i: \([0-9]*\) instructions.*/\1/p'; }
# a game, its directory, frames a and b, its arguments
games="doom fps/doom 1 31 -script up:1-31 music=off
quake fps/quake 1 31
virtua racing/virtua 3 23"
echo "$games" | { while read -r g d a b args; do
  [ -z "$only" ] || [[ " $only " == *" $g "* ]] || continue
  [ -x "$M/$d/$g" ] || { echo "$g: no $M/$d/$g (cd games && mini-mk O=5)"; continue; }
  (cd "$I" &&
    { count "$M/$d/$g" -dump-frame $a /dev/null $args > $T/$g.a &
      count "$M/$d/$g" -dump-frame $b /dev/null $args > $T/$g.b; wait; }
    x=$(cat $T/$g.a) y=$(cat $T/$g.b)
    rm -f $T/$g.a $T/$g.b
    printf "%-8s the start %14s, a frame %12s\n" $g $x $(( (y - x) / (b - a) ))) &
done; wait; }
rm -rf "$T"
