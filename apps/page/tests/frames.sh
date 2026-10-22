#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-page's frames (docs/plans/done/plan_pdf.md), as the games' are
# (games/tests/frames.sh, which says how): the program run without a
# window, a session a line of frames.expected here, its last frame's
# sum. The files shown are lib_graphics/pdf/tests/data's. And its two
# ways without a window: a file's words (-t) and a page's picture
# (-ppm), each against what is kept in this directory. And a file
# opened again where it was left: its first frame the last one's of
# the run before, by a file of places of the test's own (the sessions'
# too: not the user's, $XDG_CONFIG_HOME/mini-page/places).
# usage: apps/page/tests/frames.sh [dir]
#   dir: where the programs are (default: dune's, _build/default/apps;
#        else mini-mk's, as _mk/7/apps)
cd "$(dirname "$0")/../../.."
dir=${1:-_build/default/apps}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
export XDG_CONFIG_HOME=$W/config
FRAMES=apps/page/tests/frames.expected games/tests/frames.sh $dir; r=$?
P=$dir/page/Pageview.exe; [ -x $P ] || P=$dir/page/pageview
D=lib_graphics/pdf/tests/data
for f in tex standard browser; do $P -t $D/$f.pdf; done > $W/words 2>&1
if [ -n "${RECORD:-}" ]; then cp $W/words apps/page/tests/words.expected; fi
if cmp -s $W/words apps/page/tests/words.expected; then echo "ok -t: the words of three files"; else echo "FAIL -t: other words than the kept ones"; r=1; fi
$P -ppm 1 $D/shapes.pdf $W/shapes.ppm
got=$(sha256sum < $W/shapes.ppm | cut -d' ' -f1)
if [ -n "${RECORD:-}" ]; then echo $got > apps/page/tests/ppm.expected; fi
if [ "$got" = "$(cat apps/page/tests/ppm.expected)" ]; then echo "ok -ppm: a page's picture"; else echo "FAIL -ppm: another picture than the recorded one"; r=1; fi
# still 30 frames after the wheel: the place written
$P -dump-frame 50 $W/left.ppm -fixed-time 1000 -script 'type(+):2,wheel(-3):4' $D/tex.pdf > /dev/null 2>&1
$P -dump-frame 3 $W/again.ppm -fixed-time 1000 ./$D/tex.pdf > /dev/null 2>&1
if [ -s $W/left.ppm ] && cmp -s $W/left.ppm $W/again.ppm
then echo "ok places: opened again where it was left"
else echo "FAIL places: not where it was left"; r=1; fi
exit $r
