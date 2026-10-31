#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-maps route A to B, against mini-httpd and a small network written
# by hand (docs/plans/plan_maps.md, stage 5): the way found, the extract
# kept and used again, and what it says when no way can be had.
#
# usage: route.sh [dir]
#   dir: where mini-maps is (mini-mk's, as _mk/7/apps/maps; default: dune's)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
D=${DUNE_BUILD:-$ROOT/_build/default}
if [ $# -ge 1 ]; then MAPS=$1/mini-maps; HTTPD=$1/../../networking/mini-httpd
else MAPS=$D/apps/maps/Maps.exe; HTTPD=$D/networking/Httpd.exe; fi
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir -p $W/site/api $W/cache
cp $ROOT/apps/maps/tests/roads.json $W/site/api/interpreter
places() {
  printf 'west\t47.300000\t0.700000\t\tWest End\n'
  printf 'east\t47.300000\t0.740000\t\tEast End\n'
  printf 'back\t47.300000\t0.750000\t\tBack End\n'
  printf 'island\t47.350000\t0.700000\t\tThe Island\n'
  printf 'sea\t47.100000\t0.700000\t\tThe Sea\n'
  printf 'paris\t48.850000\t2.350000\t\tParis\n'
}
places > $W/cache/places
$HTTPD -p 0 $W/site > $W/log 2>&1 &
pid=$!
n=0
until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
T=$(grep -o 'http://[0-9.:]*' $W/log)
[ -n "$T" ] || { echo "FAIL mini-httpd did not start: $(cat $W/log)"; exit 1; }
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: got: $2"; fail=1; fi; }
asked() { grep -c 'api/interpreter' $W/log; }
settled() { sleep 0.2; }

run() { timeout 30 $MAPS route "$@" cache=$W/cache roads=$T 2>&1; }

out=$(run west to east)
check "the way, by the faster road and a one-way" "$out" \
  "$(cat $ROOT/apps/maps/tests/route.expected)"
settled
check "the extract asked once" "$(asked)" 1
check "the extract kept beside the tiles" "$(head -c 7 $W/cache/roads)" "47.280 "
check "the same again, from the file" "$(timeout 30 $MAPS route west to east cache=$W/cache roads=$T/absent 2>&1)" "$out"
settled
check "not asked again" "$(asked)" 1
check "a one-way is not driven backwards" "$(run back to west)" \
  "mini-maps: [ERROR] no way between them by the roads known"
check "the piece cut off is no road to the island" "$(run west to island)" \
  "mini-maps: [ERROR] no road near The Island"
check "no road near" "$(run west to sea)" "mini-maps: [ERROR] no road near The Sea"
check "too far: nothing asked" "$(run west to paris)" \
  "mini-maps: [ERROR] too far for a small extract: 0.5 degrees at most"
mkdir $W/none; places > $W/none/places
check "no such service" "$(timeout 30 $MAPS route west to east cache=$W/none roads=$T/absent 2>&1)" \
  "mini-maps: [ERROR] 404 Not Found"
check "usage" "$(timeout 30 $MAPS route west 2>&1 | head -1)" "usage: mini-maps route PLACE to PLACE"
exit $fail
