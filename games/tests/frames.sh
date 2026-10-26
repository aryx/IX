#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The games' frames (docs/plans/done/plan_playground.md): each game run
# without a window (lib_playground's ppm platform), a session a line of
# frames.expected: the game (its directory and its unit), the session's
# name, its arguments, and the
# SHA-256 of the frame it ends with (a PPM of 3 MB: its sum is kept, not
# the picture). RECORD=1 writes the sums again.
# A session named golden is the playground's own golden frame's (its
# tests/common/Testutil_golden.ml's arguments), and one of another name
# may be one of its scenes too (TinyWolfenstein's treasure: its
# Scenes_2d.ml's script): where the playground is there (~/playground,
# or PLAYGROUND=...) with a picture of that name, and python3 with PIL
# to read its PNG, the frame is compared with it too: ok when few
# pixels are far apart (a level of 64) and the mean difference is small.
# A session with redraw=each has the sum of the same one without: every
# frame drawn by what changed (Redraw) ends with the same picture.
# A line may end with a second sum, the frame by mini-ml's code where it
# is not OCaml's: on arm64 OCaml computes a*b+c in one instruction, with
# one rounding (fmadd), and mini-ml in two, so a pixel at an edge may be
# a level of grey apart (1 to 3 pixels of a million in seven of the
# examples' sessions; none in the games'). Either sum is the frame; with
# the second, the playground's golden frame is not compared.
# RECORD=2 writes that second sum, for the lines whose frame differs
# (run on mini-mk's build).
# FRAMES=file: another list than the games' (editors/drscheme/tests/frames.sh,
# examples/tests/frames.sh, apps/office/tests/frames.sh: the same test of
# their programs).
# The sessions run side by side, J at a time (16; J=1 one after the
# other), their lines printed after in the list's order.
# usage: games/tests/frames.sh [dir]
#   dir: where the games are (default: dune's, _build/default/games, its
#        puzzle/Tetris.exe; else mini-mk's, as _mk/7/games, its puzzle/tetris)

cd "$(dirname "$0")/../.."
dir=${1:-_build/default/games}
P=${PLAYGROUND:-$HOME/playground}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
E=${FRAMES:-games/tests/frames.expected}
program() { if [ -x $dir/$1.exe ]; then echo $dir/$1.exe; else echo $dir/$(echo $1 | tr A-Z a-z); fi; }
in=$E
[ -n "${RECORD:-}" ] && { cp $E $W/old; in=$W/old; }
# a session: its lines in $W/$i.log, its line of the list (RECORD) in
# $W/$i.rec, its files in $W/$i/
one() {
  local i=$1 game=$2 name=$3 args=$4 sum=$5 sum2=$6
  local w=$W/$i
  mkdir -p $w
  # (the arguments as a shell reads them: a script with spaces or
  # parentheses, as type((car 5)) and at(1;2), is quoted in the list)
  eval "set -- $args"; frames=$1; shift
  # (a store of documents of its own for each session, empty: mini-office's that saves and opens)
  PLAYGROUND_STORE=$w/store $(program $game) -dump-frame $frames $w/f.ppm "$@" > /dev/null 2> $w/err || { echo "FAIL $game $name: $(head -1 $w/err)"; return; }
  got=$(sha256sum < $w/f.ppm | cut -d' ' -f1)
  if [ "${RECORD:-}" = 2 ]; then
    [ "$got" != "$sum" ] && sum2=$got; echo "$game|$name|$args|$sum${sum2:+|$sum2}" > $W/$i.rec; return
  elif [ -n "${RECORD:-}" ]; then echo "$game|$name|$args|$got${sum2:+|$sum2}" > $W/$i.rec
  elif [ -n "$sum2" ] && [ "$got" = "$sum2" ]; then echo "ok $game $name (mini-ml's frame: a pixel's level apart from OCaml's)"; return
  elif [ "$got" != "$sum" ]; then echo "FAIL $game $name: another frame than the recorded one"
  else echo "ok $game $name"; fi
  # (a program the playground names TinyXxx and ix Xxx: DrScheme)
  theirs=$(basename $game); [ -f $P/tests/2d/golden/$theirs.png ] || theirs=Tiny$theirs
  golden=$P/tests/2d/golden/$theirs.png
  [ "$name" = golden ] || golden=$P/tests/2d/golden/${theirs}_$name.png
  if [ -f $golden ] && python3 -c 'import PIL' 2> /dev/null; then
    python3 - $w/f.ppm $golden <<'PY' 2>&1
import sys
from PIL import Image
a = Image.open(sys.argv[1]).convert('RGB'); b = Image.open(sys.argv[2]).convert('RGB')
if a.size != b.size: sys.exit("FAIL the playground's golden frame: sizes differ: %s and %s" % (a.size, b.size))
pairs = [(p, q) for p, q in zip(a.getdata(), b.getdata()) if p != q]
far = sum(1 for p, q in pairs if max(abs(x - y) for x, y in zip(p, q)) > 64)
mean = sum(abs(x - y) for p, q in pairs for x, y in zip(p, q)) / (3 * a.size[0] * a.size[1])
# (letters drawn through masks smooth their edges otherwise than the
# playground's strokes: a page of office's text 33,000 pixels a level
# or more apart, 8 far apart, a mean of 0.4, 2026-10-20)
ok = far < a.size[0] * a.size[1] / 10000 and mean < 1
print(('ok' if ok else 'FAIL') + " the playground's golden frame: %d pixels differ of %d, %d far apart, the mean difference %.2f" % (len(pairs), a.size[0] * a.size[1], far, mean))
sys.exit(0 if ok else 1)
PY
  fi
}
n=0
while IFS='|' read -r game name args sum sum2; do
  n=$((n + 1))
  # (J at a time: wait -n for one to end; bash 3's, macOS's, waits all)
  while [ $(jobs -rp | wc -l) -ge ${J:-16} ]; do wait -n 2> /dev/null || wait; done
  one $n "$game" "$name" "$args" "$sum" "$sum2" > $W/$n.log 2>&1 &
done < $in
wait
for i in $(seq 1 $n); do cat $W/$i.log; done
[ -n "${RECORD:-}" ] && for i in $(seq 1 $n); do cat $W/$i.rec 2> /dev/null; done > $E
[ $(cat $W/*.log /dev/null | grep -c '^FAIL') = 0 ]
