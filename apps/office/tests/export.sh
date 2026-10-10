#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-office's Export read by another program: Export_sample exports
# a document of each kind and writes each page's pixels as the screen
# draws them; poppler (pdftoppm) draws the files at a pixel a point,
# and each page must be near ours (as lib_graphics/pdf/tests/write.sh,
# which says why near; a picture is the exception: the screen draws
# its box, grey, until the office's stage 7). Linux's, dune's build, a
# machine with poppler: not the build's, not make test's.
# usage: apps/office/tests/export.sh [dir]   (dir: where the files are left)
cd "$(dirname "$0")/../../.."
D=${1:-$(mktemp -d)}
S=_build/default/apps/office/tests/Export_sample.exe
[ -x $S ] || { echo "no $S: dune build ./apps/office"; exit 1; }
command -v pdftoppm > /dev/null || { echo "no pdftoppm"; exit 1; }
$S $D || exit 1
r=0
for f in $D/*.pdf; do
  n=$(basename $f .pdf)
  pdftoppm -r 72 $f $D/theirs-$n || exit 1
  for ours in $D/$n-*.ppm; do
    python3 - $ours $D/theirs-$n-${ours##*-} <<'PY' || r=1
import sys, os
def ppm(path):
    b = open(path, 'rb').read()
    parts = b.split(None, 4)
    return int(parts[1]), int(parts[2]), parts[4]
(w, h, a), (w2, h2, b) = ppm(sys.argv[1]), ppm(sys.argv[2])
name = os.path.basename(sys.argv[1])
if (w, h) != (w2, h2):
    sys.exit("%s: sizes differ: %dx%d and %dx%d" % (name, w, h, w2, h2))
far = sum(1 for i in range(0, len(a), 3) if max(abs(a[i + c] - b[i + c]) for c in range(3)) > 64)
mean = sum(abs(x - y) for x, y in zip(a, b)) / len(a)
# (a page of text is strokes a pixel and a third wide, which the two
# smooth each their way: 1.2% of a page's pixels far apart and a mean
# of 2.5 measured, 2026-10-09, the letters the same seen side by side)
ok = far < w * h / 50 and mean < 4
print("%-22s %d x %d: %6d pixels far apart, the mean difference %.2f%s" % (name, w, h, far, mean, "" if ok else "  TOO FAR"))
sys.exit(0 if ok else 1)
PY
  done
done
# and the menu's way to it: the program run without a window, a
# document chosen, File clicked, then Export: the file it leaves where
# it was started is the one Export_sample wrote
O=$PWD/_build/default/apps/office/Office.exe
(cd $D && PLAYGROUND_STORE=$D/store $O -dump-frame 12 $D/menu.ppm -fixed-time 1000 -script 'at(-360;30):1-2,click:1,at(-410;472):3-5,click:4,at(-410;257):6-8,click:7,at(600;-600):9-12' seed=1 > /dev/null) || r=1
if cmp -s $D/untitled.pdf $D/document.pdf; then echo "File > Export: untitled.pdf, the same bytes"; else echo "File > Export: untitled.pdf is not document.pdf  FAIL"; r=1; fi
echo "left in $D"
exit $r
