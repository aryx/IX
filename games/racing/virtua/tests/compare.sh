#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-virtuaracing's grid against the playground's golden frame of it
# (docs/plans/plan_virtuaracing.md, stage 1): the same view (behind and
# above, the player 9th on Big Forest's grid) at the same size, 1000 by
# 1000 (a picture of 500 by 500, each pixel 2 by 2), and the pixels that
# differ. Not a test that passes or fails: the playground's frame has
# its race's screen over it (the time, the position, the tachometer,
# the map), its trees elsewhere (OCaml's Hashtbl.hash places them,
# Scenery.jitter here) and its countdown's 2; the numbers say how near.
#   usage: compare.sh [out.png]   (the two side by side, and where they
#   differ in red, with python3's PIL)
#   PLAYGROUND=...: the playground (default: ~/playground)
cd "$(dirname "$0")/../../../.."
P=${PLAYGROUND:-$HOME/playground}
golden=$P/tests/3d/golden/TinyVirtuaRacing_grid.png
[ -f $golden ] || { echo "no $golden"; exit 1; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
dune build ./games/racing/virtua/Virtua.exe 2> /dev/null
./_build/default/games/racing/virtua/Virtua.exe -dump-frame 3 $W/mine.ppm view=behind picture=500x500 scale=2 > /dev/null
python3 - $W/mine.ppm $golden "${1:-}" <<'PY'
import sys
from PIL import Image
a = Image.open(sys.argv[1]).convert('RGB'); b = Image.open(sys.argv[2]).convert('RGB')
n = a.size[0] * a.size[1]
pa, pb = list(a.getdata()), list(b.getdata())
far = [i for i in range(n) if max(abs(x - y) for x, y in zip(pa[i], pb[i])) > 64]
near = sum(1 for i in range(n) if pa[i] != pb[i])
mean = sum(abs(x - y) for p, q in zip(pa, pb) for x, y in zip(p, q)) / (3 * n)
print("%d pixels of %d differ, %d far apart (a level of 64), the mean difference %.1f" % (near, n, len(far), mean))
if sys.argv[3]:
    d = b.copy()
    for i in far: d.putpixel((i % a.size[0], i // a.size[0]), (255, 0, 0))
    out = Image.new('RGB', (3 * a.size[0], a.size[1]))
    out.paste(a, (0, 0)); out.paste(b, (a.size[0], 0)); out.paste(d, (2 * a.size[0], 0))
    out.save(sys.argv[3])
PY
