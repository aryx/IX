#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A game for two computers played by two programs on this one, over UDP
# (lib_playground's Multiplayer, lib_playground/netcode): TinyTronscroll
# without a window, one that hosts and one that joins, each with its
# script of keys, a frame at its time (the ppm platform's pace=). Each
# netcode in turn. What is checked: both played most of their frames'
# ticks, and their checksums agree (the two start a fifth of a second
# apart, so their ticks are not the same number).
# Read from what each says with ticks=on (Multiplayer's flag): at each
# second of the game, its tick and whether the two games agree.
# usage: games/tests/network.sh [dir]
#   dir: where the games are (default: dune's, _build/default/games;
#        else mini-mk's, as _mk/7/games)

cd "$(dirname "$0")/../.."
dir=${1:-_build/default/games}
G=$dir/arcade/TinyTronscroll.exe; [ -x $G ] || G=$dir/arcade/tinytronscroll
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
port=7790
for netcode in lockstep rollback 1997; do
  port=$((port + 1))
  $G -dump-frame 400 $W/h.ppm -script 'space:20-22,up:100,right:160,down:220' pace=100 ticks=on net=host port=$port netcode=$netcode > /dev/null 2> $W/h.err &
  sleep 0.2
  $G -dump-frame 400 $W/j.ppm -script 'space:20-22,left:120,down:200' pace=100 ticks=on net=join port=$port netcode=$netcode > /dev/null 2> $W/j.err
  wait
  h=$(sed -n 's/^tick \([0-9]*\).*/\1/p' $W/h.err | tail -1); j=$(sed -n 's/^tick \([0-9]*\).*/\1/p' $W/j.err | tail -1)
  hs=$(sed -n 's/^tick [0-9]* //p' $W/h.err | tail -1); js=$(sed -n 's/^tick [0-9]* //p' $W/j.err | tail -1)
  # (both played most of their 400 frames, and neither says DESYNC; 1997
  # waits for the other's answer at each tick, which comes a frame
  # later: half the frames at best)
  most=240; [ $netcode = 1997 ] && most=120
  if [ "${h:-0}" -ge $most ] && [ "${j:-0}" -ge $most ] && [ "$hs" = agree ] && [ "$js" = agree ]; then echo "ok $netcode: the host at tick $h, the other at $j, the two games agree"
  else echo "FAIL $netcode: the host at tick ${h:-?} ($hs), the other at ${j:-?} ($js)"; failures=$((failures + 1)); fi
done
[ $failures = 0 ]
