#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-doom's pictures against id's (docs/plans/plan_doom.md, stage 2):
# the same WAD, the same level, the eye at the same place, the frame of
# each (id's by reference/build.sh's refdoom, mini-doom's by the ppm
# platform at scale=1), and the pixels that differ, of 64,000. id's
# draws the things too (no monster: -nomonsters, and mini-doom's
# nomonsters; no status line); NOTHINGS=1, none of them, to compare the
# walls and flats alone.
#   usage: compare.sh WAD [x y angle]...   (default: E1M1's views below)
#   REFDOOM=.../refdoom (reference/build.sh's), OUT=dir: the pictures,
#   id's, mini-doom's and the pixels that differ (red), side by side,
#   with ImageMagick
# The default views are of doom1.wad's E1M1 (the shareware's, id's
# level): its start looking north, east and south-west, the hall's
# nukage, the zigzag's room.
cd "$(dirname "$0")/../../../.."
wad=$(realpath "${1:?usage: compare.sh WAD [x y angle]...}"); shift
ref=${REFDOOM:?REFDOOM=the reference: reference/build.sh}
[ $# = 0 ] && set -- 1056 -3616 90  1056 -3616 0  1056 -3616 200  1500 -3000 45  2900 -3000 300
W=$(mktemp -d); trap 'rm -rf $W' EXIT
ln -s "$wad" $W/doom1.wad
dune build ./games/fps/doom/Doom.exe 2> /dev/null
while [ $# -ge 3 ]; do
  x=$1 y=$2 a=$3; shift 3
  (cd $W && REF_X=$x REF_Y=$y REF_ANGLE=$a REF_OUT=$W/ref.ppm env ${NOTHINGS:+REF_NOTHINGS=1} timeout 30 "$ref" -warp 1 1 -nomonsters > /dev/null 2>&1)
  ./_build/default/games/fps/doom/Doom.exe -dump-frame 1 $W/mine.ppm wad=$wad x=$x y=$y angle=$a scale=1 window=320x320 nomonsters status=off ${NOTHINGS:+things=off}
  python3 - $W/ref.ppm $W/mine.ppm "$x $y $a" <<'PY'
import sys
def ppm(f):
    d = open(f, 'rb').read()
    parts = d.split(maxsplit=4)
    w, h = int(parts[1]), int(parts[2])
    return w, h, parts[4]
w, h, a = ppm(sys.argv[1])
mw, mh, b = ppm(sys.argv[2])
# (mini-doom's picture in the middle of a square, the platform's
# counter below it, in the black)
top = (mh - h) // 2
b = b[3 * mw * top: 3 * mw * (top + h)]
n = sum(1 for i in range(w * h) if a[3*i:3*i+3] != b[3*i:3*i+3])
print("%-16s %5d pixels differ of %d" % (sys.argv[3], n, w * h))
PY
  if [ -n "${OUT:-}" ]; then
    mkdir -p $OUT
    convert $W/mine.ppm -crop 320x200+0+60 +repage $W/mine2.ppm
    compare $W/ref.ppm $W/mine2.ppm $W/diff.png 2> /dev/null
    convert $W/ref.ppm $W/mine2.ppm $W/diff.png +append -scale 200% $OUT/view_${x}_${y}_${a}.png
  fi
done
