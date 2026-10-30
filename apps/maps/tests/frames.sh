#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-maps's window (docs/plans/plan_maps.md) against mini-httpd: tiles
# made here (Make_tiles: each says its z/x/y), the window run without one
# (lib_playground's ppm platform) with worker=wait, one tile a frame; a
# session a line of frames.expected: its name, its arguments, the SHA-256
# of the frame it ends with. No network but this machine's, nothing of
# OSM's. RECORD=1 writes the sums again; FRAMES=dir keeps each session's
# last frame there as a PNG (python3 and PIL), to look at. A line may end
# with a second sum, the frame by mini-ml's code where it is not OCaml's
# (games/tests/frames.sh says why: a letter's pixel a grey level apart);
# RECORD=2 writes it, run on mini-mk's build.
#
# usage: frames.sh [dir]
#   dir: where mini-maps is, and ../networking/mini-httpd (mini-mk's, as
#        _mk/7/apps/maps; default: dune's, _build/default/apps/maps)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
D=${DUNE_BUILD:-$ROOT/_build/default}
TOOL=$D/apps/maps/tests/Make_tiles.exe
if [ $# -ge 1 ]; then MAPS=$1/mini-maps; HTTPD=$1/../../networking/mini-httpd
else MAPS=$D/apps/maps/Maps.exe; HTTPD=$D/networking/Httpd.exe; fi
E=$ROOT/apps/maps/tests/frames.expected
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir $W/site
$TOOL $W/site 3 || { echo "FAIL the tiles were not made"; exit 1; }

$HTTPD -p 0 $W/site > $W/log 2>&1 &
pid=$!
n=0
until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
T=$(grep -o 'http://[0-9.:]*' $W/log)
[ -n "$T" ] || { echo "FAIL mini-httpd did not start: $(cat $W/log)"; exit 1; }

fail=0
: > $W/new
while IFS='|' read -r name args sum sum2; do
  [ -z "$name" ] && continue
  mkdir $W/$name
  eval "set -- $args"; frames=$1; shift
  timeout 60 $MAPS -dump-frame $frames $W/$name/f.ppm -fixed-time 1000 \
    window=640x480 worker=wait cache=off tiles=$T "$@" > /dev/null 2> $W/$name/err ||
    { echo "FAIL $name: $(head -1 $W/$name/err)"; fail=1; continue; }
  got=$(sha256sum < $W/$name/f.ppm | cut -d' ' -f1)
  if [ "${RECORD:-}" = 2 ]; then [ "$got" != "$sum" ] && sum2=$got; echo "$name|$args|$sum${sum2:+|$sum2}" >> $W/new
  else echo "$name|$args|$got${sum2:+|$sum2}" >> $W/new; fi
  [ -n "${FRAMES:-}" ] && mkdir -p $FRAMES &&
    python3 -c "import sys; from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2])" $W/$name/f.ppm $FRAMES/$name.png
  if [ -n "${RECORD:-}" ]; then echo "recorded $name"
  elif [ "$got" = "$sum" ] || [ "$got" = "$sum2" ]; then echo "ok $name"
  else echo "FAIL $name: its frame is another (FRAMES=dir to see it)"; fail=1; fi
done < $E
[ -n "${RECORD:-}" ] && cp $W/new $E
exit $fail
