#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-files' frames, as the games' are (games/tests/frames.sh): the
# program run without a window on a tree made here, its days fixed, a
# session a line of frames.expected: its name, its last frame, its script,
# the frame's SHA-256. And what it started: fake programs on the PATH,
# each writing what it was given. RECORD=1 writes the sums again.
# usage: apps/files/tests/frames.sh [dir]
#   dir: where the program is (default: dune's, _build/default/apps)
cd "$(dirname "$0")/../../.."
D=${1:-_build/default/apps}/files
F=$D/Files.exe; [ -x $F ] || F=$D/files
F=$PWD/$F
E=$PWD/apps/files/tests/frames.expected
T=$(mktemp -d); trap 'rm -rf $T' EXIT
r=0
mkdir -p $T/bin $T/home $T/tree/docs $T/tree/music $T/tree/many
for p in mini-page mini-play mini-emacs; do
  printf '#!/bin/sh\necho %s "$@" >> %s/said\n' $p $T > $T/bin/$p; chmod +x $T/bin/$p
done
cp lib_graphics/pdf/tests/data/shapes.pdf $T/tree/report.pdf
cp lib_audio/tests/data/bell.mp2 $T/tree/music/bell.mp2
echo hello > $T/tree/notes.txt
echo a > $T/tree/docs/a.txt
echo secret > $T/tree/.hidden
printf '\001\002\003' > $T/tree/data.bin
for i in $(seq -w 10 69); do echo $i > $T/tree/many/file$i; done
(cd $T/tree && i=0; for f in $(find . -depth); do i=$((i+1)); touch -d "2026-01-$(printf %02d $((i%28+1))) 12:00:00 UTC" "$f"; done)
touch -d "2026-02-01 12:00:00 UTC" $T/tree/report.pdf $T/tree
touch -d "2025-12-25 12:00:00 UTC" $T/tree/notes.txt

run() { # frames script file
  HOME=$T/home PATH=$T/bin:/usr/bin:/bin $F -dump-frame $1 $3 ${2:+-script "$2"} root=$T/tree $T/tree > /dev/null 2>&1
}
[ -n "${RECORD:-}" ] && : > $T/new
while IFS='|' read -r name frames script sum; do
  [ -z "$name" ] && continue
  run "$frames" "$script" $T/f.ppm
  got=$(sha256sum < $T/f.ppm | cut -d' ' -f1)
  if [ -n "${RECORD:-}" ]; then echo "$name|$frames|$script|$got" >> $T/new
  elif [ "$got" = "$sum" ]; then echo "ok $name"
  else echo "FAIL $name: another frame than the recorded one"; r=1; fi
done < $E
[ -n "${RECORD:-}" ] && cp $T/new $E

said() { local i; for i in $(seq 10); do [ -f $T/said ] && break; sleep 0.1; done; cat $T/said 2>/dev/null | sed "s#$T#T#g" | tr '\n' ';'; rm -f $T/said; }
check() { if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: $2, not $3"; r=1; fi; }
# (the rows from the top, y 434 and 24 less each: docs, many, music,
# data.bin, notes.txt, report.pdf)
run 8 'at(-400;314):1-8,click:3,click:6' $T/o.ppm
check "a double click on report.pdf: mini-page given its whole path" "$(said)" "mini-page T/tree/report.pdf;"
run 8 'at(-400;314):1-8,click:3' $T/o.ppm
check "a single click: nothing started" "$(said)" ""
run 12 'down:2,down:4,down:6,down:8,return:10' $T/o.ppm
check "Enter on notes.txt: mini-emacs" "$(said)" "mini-emacs T/tree/notes.txt;"
exit $r
