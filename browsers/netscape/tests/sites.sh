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
#   program: default dune's _build/default/browsers/netscape/Netscape.exe
# needs: the network, ImageMagick's convert (the PNGs)

set -u
[ $# -ge 1 ] || { sed -n '5,17p' "$0"; exit 2; }
D=$(realpath -m $1); shift
cd "$(dirname "$0")/../../.."
P=$(realpath ${1:-_build/default/browsers/netscape/Netscape.exe}); [ $# -ge 1 ] && shift
SITES=${*:-"https://en.wikipedia.org/wiki/OCaml https://news.ycombinator.com https://ocaml.org
  https://lwn.net https://docs.python.org/3/tutorial/index.html"}
mkdir -p $D
for u in $SITES; do
  n=$(echo $u | sed -E 's#https?://##; s#[/.?=&]+#_#g; s#_$##')
  ( timeout 300 $P -dump-frame 250 $D/$n.ppm -fixed-time 1000 url=$u profile=off console=on > $D/$n.txt 2>&1
    echo "sum $(md5sum < $D/$n.ppm | cut -c1-32)" >> $D/$n.txt
    convert $D/$n.ppm $D/$n.png && rm $D/$n.ppm ) &
done
wait
grep -H '^sum' $D/*.txt
