#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-virtuaracing against the playground's golden frames, its
# sessions (its tests/common/scenes/Scenes_3d.ml, Testutil_golden.ml: the
# clock held at a second, -fixed-time 1000; the same frame, the
# same keys), at the same size, 1000 by 1000 (a picture of 500 by 500,
# each pixel 2 by 2), and the pixels that differ. Not a test that
# passes or fails: the trees are elsewhere (OCaml's Hashtbl.hash places
# them there, Scenery.jitter here), the colours are a palette's, the
# words are drawn by another font; the numbers say how near.
#   usage: compare.sh [title|grid] [out.png]   (default grid; out.png:
#   the two side by side, and where they differ in red, with PIL)
#   PLAYGROUND=...: the playground (default: ~/playground)
# Not yet: select (its golden is Bay Bridge's, stage 3c), curve (on
# TinyOutRun's coast, left out: plan_virtuaracing.md, decision 7).
cd "$(dirname "$0")/../../../.."
P=${PLAYGROUND:-$HOME/playground}
case ${1:-grid} in
  title) golden=TinyVirtuaRacing.png; frame=5; script="" ;;
  grid) golden=TinyVirtuaRacing_grid.png; frame=120; script="-script space:1,space:3,v:10" ;;
  *) echo "usage: compare.sh [title|grid] [out.png]"; exit 2 ;;
esac
golden=$P/tests/3d/golden/$golden
[ -f $golden ] || { echo "no $golden"; exit 1; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
dune build ./games/racing/virtua/Virtua.exe 2> /dev/null
./_build/default/games/racing/virtua/Virtua.exe -fixed-time 1000 -dump-frame $frame $W/mine.ppm $script picture=500x500 scale=2 seed=1 > /dev/null
python3 - $W/mine.ppm $golden "${2:-}" <<'PY'
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
