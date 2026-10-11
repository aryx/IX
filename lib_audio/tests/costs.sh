#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What a second of sound costs in mini-ml's code on arm, in
# instructions (docs/plans/plan_audio.md, stage 1): mini-play built for
# arm (mini-mk O=5 in apps/music/play), run by mini-5i -s on a file of
# each format for no sample, half a second and a second. No clock: the
# same numbers on any host.
#   start     what is paid before the first sample (the file read, its
#             tables; an .abc's whole tune rendered)
#   a second  twice the second half second's instructions: what the
#             processor must do each second for the sound not to stop
#   of a Pi1  that against 700 million, a Pi1's clock (an instruction a
#             cycle: the most it could do)
# usage: costs.sh [mini-play for arm [file...]]     (minutes: the emulator;
#   a quarter of an hour for the .abc, whose tune is rendered three times)
cd "$(dirname "$0")/../.."
play=${1:-_mk/5/apps/music/play/mini-play}
[ -x $play ] || { echo "costs.sh: no $play (mini-mk O=5 in apps/music/play)"; exit 1; }
count() { mini-5i -s $play -s $2 $1 2>&1 > /dev/null | sed -n 's/.*mini-5i: \([0-9]*\) instructions.*/\1/p'; }
printf "%-24s %14s %14s %8s\n" "" start "a second" "of a Pi1"
[ $# -gt 1 ] && { shift; files="$*"; } || files=$(ls lib_audio/tests/data/*)
for f in $files; do
  a=$(count $f 0); b=$(count $f 0.5); c=$(count $f 1)
  s=$(( 2 * (c - b) ))
  printf "%-24s %14d %14d %7d%%\n" $(basename $f) $a $s $(( s / 7000000 ))
done
