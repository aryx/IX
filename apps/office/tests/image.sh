#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A picture from a file in mini-office (docs/plans/plan_office.md,
# stage 7): the program run without a window, as frames.sh, but with a
# store that has a picture in it (picture.png: frames.sh's stores are
# empty). Two sessions, each its last frame's sum against
# image.expected: the picture inserted (Insert > Image..., the file
# chosen in the dialog, Insert); then clicked again, turned by its own
# menu (Image > Rotate Right), put down, and the document exported.
# The exported PDF is then read by mini-page, whose words must be the
# page's (the picture is in the file: its size says so).
# usage: apps/office/tests/image.sh [dir]
#   dir: where the programs are (default: dune's, _build/default/apps;
#        else mini-mk's, as _mk/7/apps)
# RECORD=1 writes image.expected from this run; RECORD=2 adds this
# run's sums as a second one (mini-ml's build, where a pixel differs)
cd "$(dirname "$0")/../../.."
A=${1:-_build/default/apps}
E=apps/office/tests/image.expected
O=$PWD/$A/office/Office.exe; [ -x $O ] || O=$PWD/$A/office/office
P=$PWD/$A/page/Pageview.exe; [ -x $P ] || P=$PWD/$A/page/pageview
[ -x $O ] || { echo "no mini-office in $A/office"; exit 1; }
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
insert='at(-360;30):1-2,click:1,at(-206;470):3-5,click:4,at(-206;221):6-8,click:7,at(0;160):9-11,click:10,at(90;-75):12-14,click:13'
turn='at(0;20):15-17,click:16,at(-308;470):18-20,click:19,at(-308;365):21-23,click:22,escape:25,at(-410;472):27-29,click:28,at(-410;257):30-32,click:31'
r=0
session() { # name frames script
  rm -rf $W/store; mkdir -p $W/store
  cp lib_graphics/pdf/tests/data/shapes-1.png $W/store/picture.png
  (cd $W && PLAYGROUND_STORE=$W/store $O -dump-frame $2 $W/f.ppm -fixed-time 1000 -script "$3" seed=1 > /dev/null 2> $W/err) || { echo "FAIL $1: $(head -1 $W/err)"; r=1; return; }
  sum=$(sha256sum < $W/f.ppm | cut -d' ' -f1)
  if [ "$RECORD" = 1 ]; then echo "$1|$sum" >> $E.new
  elif [ "$RECORD" = 2 ]; then
    grep -q "^$1|.*$sum" $E && grep "^$1|" $E >> $E.new || echo "$(grep "^$1|" $E)|$sum" >> $E.new
  elif grep -q "^$1|.*$sum" $E; then echo "ok $1"
  else echo "FAIL $1: the frame's sum is $sum"; r=1; fi
}
rm -f $E.new
session inserted 18 "$insert,at(600;-600):15-18"
session turned 40 "$insert,$turn,at(600;-600):33-40"
[ -n "$RECORD" ] && mv $E.new $E && echo "recorded in $E"
# the export of the second session: more than a page of strokes alone
# (the picture's 400 by 300 pixels are in it), and read back
if [ -x $P ] && [ -f $W/untitled.pdf ]; then
  size=$(cat $W/untitled.pdf | wc -c)
  $P -ppm 1 $W/untitled.pdf $W/p.ppm 2> $W/err && [ $size -gt 190000 ] && echo "ok exported: $size bytes, read back by mini-page" || { echo "FAIL exported: $size bytes; $(head -1 $W/err)"; r=1; }
else echo "FAIL exported: no untitled.pdf, or no mini-page in $A/page"; r=1; fi
exit $r
