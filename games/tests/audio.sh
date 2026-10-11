#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The games' sound (docs/plans/plan_audio.md, stage 4): each game run
# without a window (lib_playground's ppm platform) with -dump-audio, a
# session a line of audio.expected: the game, the session's name, its
# arguments (the frames first: a sixtieth of a second of sound each)
# and the SHA-256 of the WAV. RECORD=1 writes the sums again.
# Where the playground is there with its games built (~/playground, or
# PLAYGROUND=...: its _build/default/games/<game>.exe, the platform with
# a window, run with SDL's dummy drivers), its own -dump-audio of the
# same session is compared too, byte for byte: the same synthesizer,
# and a loop rendered here as it is played (Audio.mli) against one
# rendered whole there.
# usage: games/tests/audio.sh [dir]
#   dir: where the games are (default: dune's, _build/default/games;
#        else mini-mk's, as _mk/7/games)

cd "$(dirname "$0")/../.."
dir=${1:-_build/default/games}
P=${PLAYGROUND:-$HOME/playground}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
E=games/tests/audio.expected
failures=0
program() { if [ -x $dir/$1.exe ]; then echo $dir/$1.exe; else echo $dir/$(echo $1 | tr A-Z a-z); fi; }
in=$E
[ -n "${RECORD:-}" ] && { cp $E $W/old; in=$W/old; : > $E; }
while IFS='|' read -r game name args sum; do
  eval "set -- $args"; frames=$1; shift
  $(program $game) -dump-frame $frames $W/f.ppm -dump-audio $W/a.wav "$@" > /dev/null 2> $W/err || { echo "FAIL $game $name: $(head -1 $W/err)"; failures=$((failures + 1)); continue; }
  got=$(sha256sum < $W/a.wav | cut -d' ' -f1)
  if [ -n "${RECORD:-}" ]; then echo "$game|$name|$args|$got" >> $E
  elif [ "$got" != "$sum" ]; then echo "FAIL $game $name: another sound than the recorded one"; failures=$((failures + 1))
  else echo "ok $game $name: $(( ($(wc -c < $W/a.wav) - 44) / 4 )) samples"; fi
  theirs=$P/_build/default/games/$game.exe
  if [ -x $theirs ]; then
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy $theirs -dump-frame $frames $W/p.png -dump-audio $W/p.wav "$@" > /dev/null 2>&1
    if cmp -s $W/a.wav $W/p.wav; then echo "ok the playground's own -dump-audio: the same bytes"
    else echo "FAIL $game $name: not the playground's own -dump-audio"; failures=$((failures + 1)); fi
  fi
done < $in
[ $failures = 0 ]
