#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A route in mini-maps's window on mini-9pi (docs/plans/done/plan_maps.md,
# stage 5): the card booted on the Pi 2 under QEMU, real keys (/, a place,
# Enter, r, / the other, Enter, then the right arrow at each screen), a small
# server on this machine as all services, silent as Overpass for SILENT seconds
# (default 0) before the roads. Its screens are to be looked at (DIR/liveN.png);
# what is said is the time from the last Enter to the first screen with the
# route's blue line, to the step of a screen, and how many screens differ from
# the one before until then: the arrow moves the map if the window is alive.
# Minutes long, so not in make test.
#   make -C kernels/9pi card      first
#
# usage: route_9pi.sh DIR [ROADS LAT0 LON0 LAT1 LON1 ZOOM STEP WAITS]
#   ROADS: an Overpass answer (default: tests/roads.json, written by hand)
#   the places, the map's zoom, seconds between screens, screens after Enter

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
DIR=$(realpath -m "${1:?usage: route_9pi.sh DIR [ROADS LAT0 LON0 LAT1 LON1 ZOOM STEP WAITS]}")
ROADS=$(realpath "${2:-$ROOT/apps/maps/tests/roads.json}")
LAT0=${3:-47.3} LON0=${4:-0.70} LAT1=${5:-47.3} LON1=${6:-0.74}
ZOOM=${7:-12} STEP=${8:-6} WAITS=${9:-3}
W=$(mktemp -d); trap 'kill $pid 2> /dev/null; rm -rf $W' EXIT
mkdir -p $DIR
printf 'a\t%s\t%s\t\tFrom\nb\t%s\t%s\t\tTo\n' $LAT0 $LON0 $LAT1 $LON1 > $W/places
python3 - "$ROADS" $W/places ${SILENT:-0} > $W/log 2>&1 <<'PY' &
import http.server, sys, time
roads, places, silent = open(sys.argv[1], "rb").read(), open(sys.argv[2], "rb").read(), float(sys.argv[3])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = places if self.path == "/places" else roads if self.path.startswith("/api/") else None
        if body is roads: time.sleep(silent)
        self.send_response(200 if body else 404)
        self.send_header("Content-Length", str(len(body or b"")))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body or b"")
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
print("port", s.server_address[1], flush=True)
s.serve_forever()
PY
pid=$!
n=0
until grep -q '^port' $W/log || [ $n -ge 50 ]; do sleep 0.1; n=$((n + 1)); done
PORT=$(grep '^port' $W/log | cut -d' ' -f2)
[ -n "$PORT" ] || { echo "FAIL the server did not start: $(cat $W/log)"; exit 1; }
T=http://10.0.2.2:$PORT

# (no tile is served at this zoom: a grey map, and the route on it)
LINE="mkdir /tmp/c; /progs/net/curl $T/places > /tmp/c/places; /progs/net/maps 'zoom=$ZOOM' 'lat=$LAT0' 'lon=$LON0' 'cache=/tmp/c' 'tiles=$T' 'roads=$T'"
KEYS=slash,a,ret,r,slash,b,ret
ENTER=7
for i in $(seq 1 $WAITS); do KEYS=$KEYS,right; done
K=$ROOT/kernels/9pi
BOOT="-M raspi2b -device loader,file=$K/kernel-pi2-ix.img,addr=0x8000,cpu-num=0,force-raw=on"
for c in 1 2 3; do BOOT="$BOOT -device loader,addr=0x8000,cpu-num=$c"; done
LIVE_START=15 timeout $((300 + (ENTER + WAITS) * STEP)) $K/tests/live.py $DIR $STEP "$LINE" $KEYS -- \
  qemu-system-arm $BOOT -serial mon:stdio -display none -device usb-kbd -device usb-mouse \
  -device usb-net,netdev=n0 -netdev user,id=n0 \
  -drive file=$K/build/card.img,if=sd,format=raw,snapshot=on > /dev/null 2>&1

python3 - $DIR $ENTER $STEP <<'PY'
import glob, os, sys
from PIL import Image
d, enter, step = sys.argv[1], int(sys.argv[2]), float(sys.argv[3])
first = None
before = None
changed = []
for n in range(1, len(glob.glob(d + "/live*.ppm")) + 1):
    im = Image.open("%s/live%d.ppm" % (d, n)).convert("RGB")
    im.save("%s/live%d.png" % (d, n))
    # (Routing's colour on a screen of 16 bits a pixel)
    blue = (40, 88, 216) in im.getdata()
    if blue and first is None: first = n
    if n > enter + 1 and first is None: changed.append(im.tobytes() != before)
    before = im.tobytes()
if first is None: print("FAIL no route on any screen of " + d); sys.exit(1)
print("ok the route on screen %d, %d to %d s after Enter: look at %s/live%d.png"
      % (first, (first - enter - 1) * step, (first - enter) * step, d, first))
print("while waiting, %d screens of %d differ from the one before" % (sum(changed), len(changed)))
PY
