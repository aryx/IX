#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Live sites, scripts on, before and after a cut (docs/plans/plan_browser.md,
# "Smaller": a cut is tried and the pages looked at): each site loaded
# by mini-netscape without a window, its frame 250 written to DIR as a
# PNG, and what its scripts said (console=on) to a text, with the
# frame's sum. Run once before a change and once after, into two
# directories, then compare the sums and the texts (diff -r), and look
# at the PNGs that differ. The sites change by themselves: run the two
# close together.
#
# usage: browsers/netscape/tests/sites.sh DIR [program] [site...]
#        browsers/netscape/tests/sites.sh -c BEFORE AFTER
#   program: default dune's _build/default/browsers/netscape/Netscape.exe
#   -c: the two runs compared, a site a line: the pixels that differ
#       (of 1,000,000), and, where some do, the two pictures side by
#       side in AFTER/compare-<site>.png: "mostly the same" is looked at
#       (plan_browser.md, C), not an equality
# needs: the network, ImageMagick's convert (the PNGs)

set -u
[ $# -ge 1 ] || { sed -n '5,22p' "$0"; exit 2; }
if [ "$1" = -c ]; then
  for a in $2/*.png; do
    n=$(basename $a .png); b=$3/$n.png
    [ -f $b ] || { echo "$n: not in $3"; continue; }
    d=$(compare -metric AE $a $b /dev/null 2>&1)
    echo "$n: $d pixels differ"
    [ "$d" != 0 ] && convert $a $b +append -resize 50% $3/compare-$n.png
  done
  exit 0
fi
D=$(realpath -m $1); shift
cd "$(dirname "$0")/../../.."
P=$(realpath ${1:-_build/default/browsers/netscape/Netscape.exe}); [ $# -ge 1 ] && shift
SITES=${*:-"https://en.wikipedia.org/wiki/OCaml https://news.ycombinator.com https://ocaml.org
  https://lwn.net https://docs.python.org/3/tutorial/index.html"}
mkdir -p $D
for u in $SITES; do
  n=$(echo $u | sed -E 's#https?://##; s#[/.?=&]+#_#g; s#_$##')
  ( timeout 300 $P -dump-frame 250 $D/$n.ppm -fixed-time 1000 url=$u profile=off helpers=off console=on > $D/$n.txt 2>&1
    echo "sum $(md5sum < $D/$n.ppm | cut -c1-32)" >> $D/$n.txt
    convert $D/$n.ppm $D/$n.png && rm $D/$n.ppm ) &
done
wait
grep -H '^sum' $D/*.txt
