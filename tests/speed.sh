#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Speed regressions (make test-speed; the author: "we will need to add
# some speed regression test, so we know when suddenly cameltry fps are
# going down, the time to build mini-pi is significantly higher"). Each
# measure against a limit set from what it was on the author's machine,
# the only one these run on (other machines' numbers are not these): a
# line each, ok or FAIL, and each measure added to tests/speed_history.txt
# (its date, the commit, the measure), to see when one changed.
#   tests/speed.sh              all of them (about two minutes)
#   tests/speed.sh build-9pi    those named
# The machine to be idle meanwhile: QEMU's speed is the host's.
#
#   build-9pi   what ./mini-pi -g mini-9pi builds (kernels/9pi's card
#               ix-usb, ocaml-light's kernel), built once then timed
#               when nothing changed: 8.5 s on 2026-10-18; 3 min 21 s
#               on 2026-10-21 (every program asking its libraries'
#               mkfiles: ec719b1a), 8.6 s after; 24.1 s on 2026-10-22
#               (the recipes rc's, bff90213: a backquote an rc and an
#               echo), 12.0 s by mkfiles/config.rc and libs.rc
#   build-top   the top mini-mk (ix for arm64 by ix), the same: 33 s
#               before ec719b1a, about 1 s after; 5.6 s, then 2.8 s
#   cameltry    TinyCameltry's frames a second on mini-9pi under QEMU
#               (kernels/9pi/tests/perf/frames.sh: the game's meter,
#               the maze turned 15 seconds each way), the median of
#               its lines but the first (the start): 25 on 2026-10-21,
#               the same on 2026-10-18's tree

# (the mkfiles' recipes are rc's: mkfiles/mkconfig)
export MKSHELL=mini-rc
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd $ROOT
export PATH=$ROOT/bin:$PATH
PRINCIPIA=${PRINCIPIA:-$HOME/principia}
HISTORY=$ROOT/tests/speed_history.txt
W=$(mktemp -d)
failed=0

now() { date +%s.%N; }
# record NAME VALUE UNIT LIMIT max|min
record() {
  local ok
  ok=$(echo "$2 $4 $5" | awk '{ print ($3 == "max" ? $1 <= $2 : $1 >= $2) ? "ok" : "FAIL" }')
  printf "%-4s  %-10s %6.1f %-4s (limit: %s %s)\n" $ok $1 $2 $3 $5 $4
  [ $ok = ok ] || failed=1
  printf "%s %s %-10s %6.1f %s\n" $(date +%F) $(git rev-parse --short HEAD) $1 $2 $3 >> $HISTORY
}
fail() { printf "FAIL  %-10s %s\n" $1 "$2"; failed=1; }
# a build made, then timed again when nothing changed
nothing_changed() {
  local name=$1 limit=$2 t0; shift 2
  "$@" > $W/$name.log 2>&1 || { fail $name "the build failed: $W/$name.log"; return; }
  t0=$(now)
  "$@" > $W/$name.log 2>&1 || { fail $name "the build failed: $W/$name.log"; return; }
  record $name $(echo "$(now) - $t0" | bc) s $limit max
}

build_9pi() { kernels/ocaml-light.sh arm && make -C kernels/9pi BOARD=pi1 PRINCIPIA=$PRINCIPIA card ix-usb; }
build_top() { mini-mk; }
cameltry() {
  local d=$W/cameltry fps
  mkdir -p $d
  kernels/9pi/tests/perf/frames.sh cameltry spc,left:15000,right:15000 $d > /dev/null
  fps=$(grep -a "^40 frames in" $d/console.txt | awk 'NR > 1 { print 40 / $4 }' | sort -n | awk '{ v[NR] = $1 } END { if (NR) print v[int((NR + 1) / 2)] }')
  [ -n "$fps" ] || { fail cameltry "no meter's lines: $d/console.txt"; return; }
  record cameltry $fps fps 20 min
}

for t in ${@:-build-9pi build-top cameltry}; do
  case $t in
    build-9pi) nothing_changed build-9pi 15 build_9pi;;
    build-top) nothing_changed build-top 10 build_top;;
    # (after build-9pi, which makes the card it runs from)
    cameltry) cameltry;;
    *) echo "speed.sh: $t?"; exit 2;;
  esac
done
exit $failed
