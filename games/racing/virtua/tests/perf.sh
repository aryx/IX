#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A race frame's instructions on arm, by mini-5i: frames a and b of a
# race begun at once (course=0, the throttle held, no sound), each run
# from the start, the difference divided by b - a (the course's build,
# 3 billion, taken off). The numbers of the README's "Speed". Slow: a
# run is 4 to 10 minutes; the two run side by side.
#   usage: perf.sh [virtua] [a b] [flags...]
#   virtua: mini-mk's arm build (default _mk/5/games/racing/virtua/virtua)
#   e.g. perf.sh _mk/5/games/racing/virtua/virtua 250 270 cull=off
#   PROF=dir: mini-5i -prof's profiles there too (dir/a.prof, dir/b.prof),
#   for mini-prof -diff dir/a.prof dir/b.prof virtua.map

cd "$(dirname "$0")/../../../.."
V=${1:-_mk/5/games/racing/virtua/virtua}
a=${2:-250}
b=${3:-270}
shift $(( $# < 3 ? $# : 3 ))
flags=("$@")
W=$(mktemp -d); trap 'rm -rf $W' EXIT
run() {
  local p=()
  [ -n "$PROF" ] && p=(-prof $PROF/$1.prof)
  bin/mini-5i -s "${p[@]}" $V -dump-frame $1 /dev/null \
    -script up:1-$((b + 100)) course=0 seed=1 sound=off "${flags[@]}" 2>&1 \
    > /dev/null | sed -n 's/^mini-5i: \([0-9]*\) instructions.*/\1/p' > $W/$1
}
run $a & run $b & wait
x=$(cat $W/$a); y=$(cat $W/$b)
[ -n "$x" ] && [ -n "$y" ] || { echo "perf.sh: a run failed"; exit 1; }
echo "$(( (y - x) / (b - a) )) instructions a frame ($V, frames $a to $b)"
