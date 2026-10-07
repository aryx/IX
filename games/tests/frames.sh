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
# The first session of a game is the playground's own golden frame's
# (its tests/common/Testutil_golden.ml's arguments): where the playground
# is there (~/playground, or PLAYGROUND=...), and python3 with PIL to read
# its PNG, the frame is compared with it too, pixel by pixel.
# usage: games/tests/frames.sh [dir]
#   dir: where the games are (default: dune's, _build/default/games, its
#        puzzle/Tetris.exe; else mini-mk's, as _mk/7/games, its puzzle/tetris)

cd "$(dirname "$0")/../.."
dir=${1:-_build/default/games}
P=${PLAYGROUND:-$HOME/playground}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
E=games/tests/frames.expected
failures=0
program() { if [ -x $dir/$1.exe ]; then echo $dir/$1.exe; else echo $dir/$(echo $1 | tr A-Z a-z); fi; }
in=$E
[ -n "${RECORD:-}" ] && { cp $E $W/old; in=$W/old; : > $E; }
while IFS='|' read -r game name args sum; do
  $(program $game) -dump-frame ${args%% *} $W/f.ppm ${args#* } 2> $W/err || { echo "FAIL $game $name: $(head -1 $W/err)"; failures=$((failures + 1)); continue; }
  got=$(sha256sum < $W/f.ppm | cut -d' ' -f1)
  if [ -n "${RECORD:-}" ]; then echo "$game|$name|$args|$got" >> $E
  elif [ "$got" != "$sum" ]; then echo "FAIL $game $name: another frame than the recorded one"; failures=$((failures + 1))
  else echo "ok $game $name"; fi
  golden=$P/tests/2d/golden/$(basename $game).png
  if [ "$name" = golden ] && [ -f $golden ] && python3 -c 'import PIL' 2> /dev/null; then
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
