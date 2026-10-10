#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A file written here, read by another program: Sample writes two
# pages of Playground shapes and the first page's pixels as
# Shape_render_software draws them; poppler (pdftoppm) draws the file
# at a pixel a point, and its first page must be near ours. Near, not
# the same: two rasterizers smooth an edge differently, and words
# under a pixel and a half of pen are hairlines here. Linux's, dune's
# build, a machine with poppler: not the build's, not make test's.
# usage: lib_graphics/pdf/tests/write.sh [dir]   (dir: where the files are left)
cd "$(dirname "$0")/../../.."
D=${1:-$(mktemp -d)}
S=_build/default/lib_graphics/pdf/tests/Sample.exe
[ -x $S ] || { echo "no $S: dune build ./lib_graphics/pdf"; exit 1; }
command -v pdftoppm > /dev/null || { echo "no pdftoppm"; exit 1; }
$S $D/sample.pdf $D/ours.ppm || exit 1
pdftoppm -r 72 $D/sample.pdf $D/theirs || exit 1
python3 - $D/ours.ppm $D/theirs-1.ppm <<'PY'
import sys
def ppm(path):
    b = open(path, 'rb').read()
    parts = b.split(None, 4)
    return int(parts[1]), int(parts[2]), parts[4]
(w, h, a), (w2, h2, b) = ppm(sys.argv[1]), ppm(sys.argv[2])
if (w, h) != (w2, h2):
    sys.exit("sizes differ: %dx%d and %dx%d" % (w, h, w2, h2))
far = sum(1 for i in range(0, len(a), 3) if max(abs(a[i + c] - b[i + c]) for c in range(3)) > 64)
mean = sum(abs(x - y) for x, y in zip(a, b)) / len(a)
print("%d x %d: %d pixels of %d far apart (a part over 64 of 255), the mean difference %.2f" % (w, h, far, w * h, mean))
# measured 2026-10-09: see docs/plans/plan_pdf.md's Status
sys.exit(0 if far < w * h / 100 and mean < 2 else "too far")
PY
r=$?
echo "left in $D: sample.pdf, ours.ppm, theirs-1.ppm, theirs-2.ppm"
exit $r
