#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-maps weather PLACE, the forecast as lines, against mini-httpd and
# canned answers (docs/plans/plan_maps.md, stage 4): what it prints; a
# place known from the last run not asked again; and what it says when
# there is no such place, or no service.
#
# usage: weather.sh [dir]
#   dir: where mini-maps is (mini-mk's, as _mk/7/apps/maps; default: dune's)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
D=${DUNE_BUILD:-$ROOT/_build/default}
if [ $# -ge 1 ]; then MAPS=$1/mini-maps; HTTPD=$1/../../networking/mini-httpd
else MAPS=$D/apps/maps/Maps.exe; HTTPD=$D/networking/Httpd.exe; fi
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir -p $W/site/v1 $W/site/none $W/site/none/v1 $W/cache
cp $ROOT/apps/maps/tests/forecast.json $W/site/v1/forecast
echo '[{"lat":"47.39","lon":"0.69","display_name":"Tours, France"}]' > $W/site/search
echo '[]' > $W/site/none/search
$HTTPD -p 0 $W/site > $W/log 2>&1 &
pid=$!
n=0
until grep -q 'serving' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
T=$(grep -o 'http://[0-9.:]*' $W/log)
[ -n "$T" ] || { echo "FAIL mini-httpd did not start: $(cat $W/log)"; exit 1; }
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: got: $2"; fail=1; fi; }

run() { timeout 30 $MAPS weather "$@" 2>&1; }

out=$(run tours cache=$W/cache places=$T forecast=$T)
check "the forecast's lines" "$out" "$(cat $ROOT/apps/maps/tests/weather.expected)"
# (the same answer with no place service: the last places remembered)
check "a place known is not asked again" \
  "$(run Tours cache=$W/cache places=$T/absent forecast=$T | head -1)" "Tours, France"
check "no such place" "$(run nowhere cache=off places=$T/none forecast=$T)" "mini-maps: [ERROR] no place called nowhere"
check "no place service" "$(run tours cache=off places=$T/absent forecast=$T)" "mini-maps: [ERROR] 404 Not Found"
check "no forecast service" "$(run tours cache=off places=$T forecast=$T/absent)" "mini-maps: [ERROR] 404 Not Found"
check "no place at all" "$(run | head -1)" "usage: mini-maps weather PLACE"
exit $fail
