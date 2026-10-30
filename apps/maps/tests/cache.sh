#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-maps's cache (docs/plans/plan_maps.md, stage 2; Tile_cache.mli)
# against mini-httpd, by what its log says was asked: a tile got once and
# not asked while it is good; old, asked if it changed, 304 and nothing
# sent; changed on the server, the new one; the server gone, the old tile
# shown; and the cache kept within its size. The frames compared with each
# other: the same picture whichever way a tile came.
#
# usage: cache.sh [dir]
#   dir: where mini-maps is (mini-mk's, as _mk/7/apps/maps; default: dune's)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
D=${DUNE_BUILD:-$ROOT/_build/default}
TOOL=$D/apps/maps/tests/Make_tiles.exe
if [ $# -ge 1 ]; then MAPS=$1/mini-maps; HTTPD=$1/../../networking/mini-httpd; CURL=$1/../../networking/mini-curl
else MAPS=$D/apps/maps/Maps.exe; HTTPD=$D/networking/Httpd.exe; CURL=$D/networking/Curl.exe; fi
W=$(mktemp -d); pid=; trap 'stop; rm -rf $W' EXIT
stop() { [ -n "$pid" ] && kill $pid 2> /dev/null; wait $pid 2> /dev/null; pid=; }
mkdir $W/site
$TOOL $W/site 2 || { echo "FAIL the tiles were not made"; exit 1; }

# [start args]: a server, its log empty, $T its address
start() {
  stop; : > $W/log
  # (appending: the log is emptied under it, by forget)
  $HTTPD -p 0 "$@" $W/site >> $W/log 2>&1 &
  pid=$!
  local n=0
  until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
  T=$(grep -o 'http://[0-9.:]*' $W/log)
  [ -n "$T" ] || { echo "FAIL mini-httpd did not start: $(cat $W/log)"; exit 1; }
}
# the window at zoom 2 until all's there; its frame's sum in $sum
run() {
  local dir=$1; shift
  timeout 60 $MAPS -dump-frame 24 $W/f.ppm -fixed-time 1000 window=640x480 worker=wait \
    zoom=2 cache=$dir tiles=$T "$@" > /dev/null 2> $W/err ||
    { echo "FAIL the window: $(head -1 $W/err)"; fail=1; }
  sum=$(sha256sum < $W/f.ppm | cut -d' ' -f1)
}
forget() { : > $W/log; }
# what the log says was asked. The server logs after it answers, so the
# window may be gone before its last line: it serves one client at a time,
# so one more request's line comes after all of them
asked() {
  $CURL $T/settled > /dev/null 2>&1
  local n=0
  until grep -q settled $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
  grep -v settled $W/log | grep -c "^GET .*$1"
}
fail=0
check() { # what, got, expected
  if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: $2, expected $3"; fail=1; fi
}

# good for a long while
start -max-age 100000
run $W/a; first=$sum
n=$(asked ' 200 ')
[ "$n" -gt 0 ] && echo "ok the first time, $n tiles sent" || { echo "FAIL nothing asked"; fail=1; }
forget
run $W/a
check "while they are good, nothing asked" "$(asked .)" 0
check "and the same picture" $sum $first

# good for no time: each asked, none sent
start -max-age 0
run $W/b
asked . > /dev/null
forget
run $W/b
check "old: asked, and nothing sent" "$(asked ' 200 ')" 0
check "old: all answered 304" "$(asked ' 304 ')" $n
check "and the same picture" $sum $first

# one tile changed on the server
cp $W/site/0/0/0.png $W/site/2/1/1.png
forget
run $W/b
check "the one that changed sent again" "$(asked ' 200 ')" 1
[ "$sum" != "$first" ] && echo "ok and it is another picture" || { echo "FAIL the same picture"; fail=1; }
changed=$sum

# the server gone: the old tiles
stop
run $W/b
check "the server gone, the old tiles shown" $sum $changed

# a cache of no size keeps nothing (which goes first: tests/Test.ml)
start -max-age 100000
run $W/c cache-size=0
check "within its size" "$(ls $W/c | grep -c -v index)" 0
exit $fail
