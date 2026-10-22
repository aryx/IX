#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The macro benchmarks: whole programs of ix's, their instructions
# counted by mini-5i -s, on a tree built by ix's tools (mini-mk O=5 at
# its top, with the MLOPT to measure: -O0, -O3). A game's frame: the
# instructions of its session to frame 61, less those to frame 31, by
# 30 (its start taken off: a session that ends at frame 1 does more
# than one that ends at 2, cameltry's); mini-ml: the instructions to compile some of
# its own units (the compiler compiled by itself, running). Beside
# tests/bench.sh's loops, for variants/ssa.md's numbers.
# usage: macro.sh tree      (tree: the top of a built copy of ix, arm)
#   for v in O0 O3; do (cd copy_$v && MLOPT=-$v mini-mk O=5); macro.sh copy_$v; done
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
T=$(realpath $1)
M=$T/_mk/5
I=$ROOT/_build/default/machine/Main.exe
count() { $I -s "$@" 2>&1 >/dev/null | grep -o '^mini-5i: [0-9]*' | cut -d' ' -f2; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# a game: where it runs (its data found from there), its program, its
# script's keys, the same for both sessions; one frame's instructions
frame() {
  local dir=$1 prog=$2 keys=$3; shift 3
  local a b
  a=$(cd $T/$dir && count $M/$prog -dump-frame 31 $W/f.ppm -script $keys "$@")
  b=$(cd $T/$dir && count $M/$prog -dump-frame 61 $W/f.ppm -script $keys "$@")
  echo $(( (b - a) / 30 ))
}
printf "%-22s %12s\n" doom "$(frame games/fps/doom games/fps/doom/doom up:1-61 wad=data/freedoom.wad)"
printf "%-22s %12s\n" quake "$(frame . games/fps/quake/quake up:1-61)"
printf "%-22s %12s\n" cameltry "$(frame . games/arcade/tinycameltry space:2-3,right:4-61 -fixed-time 1000 seed=1)"
# mini-ml compiling its own largest units (the stdlib's interfaces: lib_core)
L=$T/lib_core
S=$(for u in $(grep -v '^#' $L/units.txt); do echo "-I $L/$(dirname $u)"; done | sort -u | tr '\n' ' ')
ml=$T/languages/ml
n=0
for f in simple/Lower.ml Typing.ml ssa/Ssa_build.ml; do
  n=$(( n + $(cd $ml && count $M/languages/ml/mini-ml -m 5 $S -I . -I simple -I ssa -I opti -I compat -o $W/x.5 $f) ))
done
printf "%-22s %12s\n" "mini-ml compiling" $n
