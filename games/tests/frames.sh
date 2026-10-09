#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The games' frames (docs/plans/plan_playground.md): each game run
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
# to read its PNG, the frame is compared with it too, pixel by pixel.
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
# usage: games/tests/frames.sh [dir]
#   dir: where the games are (default: dune's, _build/default/games, its
#        puzzle/Tetris.exe; else mini-mk's, as _mk/7/games, its puzzle/tetris)

cd "$(dirname "$0")/../.."
dir=${1:-_build/default/games}
P=${PLAYGROUND:-$HOME/playground}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
E=${FRAMES:-games/tests/frames.expected}
failures=0
program() { if [ -x $dir/$1.exe ]; then echo $dir/$1.exe; else echo $dir/$(echo $1 | tr A-Z a-z); fi; }
in=$E
[ -n "${RECORD:-}" ] && { cp $E $W/old; in=$W/old; : > $E; }
while IFS='|' read -r game name args sum sum2; do
  # (the arguments as a shell reads them: a script with spaces or
  # parentheses, as type((car 5)) and at(1;2), is quoted in the list)
  eval "set -- $args"; frames=$1; shift
  # (a store of documents of its own for each session, empty: mini-office's that saves and opens)
  rm -rf $W/store
  PLAYGROUND_STORE=$W/store $(program $game) -dump-frame $frames $W/f.ppm "$@" > /dev/null 2> $W/err || { echo "FAIL $game $name: $(head -1 $W/err)"; failures=$((failures + 1)); continue; }
  got=$(sha256sum < $W/f.ppm | cut -d' ' -f1)
  if [ "${RECORD:-}" = 2 ]; then
    [ "$got" != "$sum" ] && sum2=$got; echo "$game|$name|$args|$sum${sum2:+|$sum2}" >> $E; continue
  elif [ -n "${RECORD:-}" ]; then echo "$game|$name|$args|$got${sum2:+|$sum2}" >> $E
  elif [ -n "$sum2" ] && [ "$got" = "$sum2" ]; then echo "ok $game $name (mini-ml's frame: a pixel's level apart from OCaml's)"; continue
  elif [ "$got" != "$sum" ]; then echo "FAIL $game $name: another frame than the recorded one"; failures=$((failures + 1))
  else echo "ok $game $name"; fi
  # (a program the playground names TinyXxx and ix Xxx: DrScheme)
  theirs=$(basename $game); [ -f $P/tests/2d/golden/$theirs.png ] || theirs=Tiny$theirs
  golden=$P/tests/2d/golden/$theirs.png
  [ "$name" = golden ] || golden=$P/tests/2d/golden/${theirs}_$name.png
  if [ -f $golden ] && python3 -c 'import PIL' 2> /dev/null; then
    python3 - $W/f.ppm $golden <<'PY' || failures=$((failures + 1))
import sys
from PIL import Image
a = Image.open(sys.argv[1]).convert('RGB'); b = Image.open(sys.argv[2]).convert('RGB')
n = sum(1 for p, q in zip(a.getdata(), b.getdata()) if p != q) if a.size == b.size else -1
print(('ok' if n == 0 else 'FAIL') + " the playground's golden frame: %d pixels differ of %d" % (n, a.size[0] * a.size[1]))
sys.exit(0 if n == 0 else 1)
PY
  fi
done < $in
[ $failures = 0 ]
