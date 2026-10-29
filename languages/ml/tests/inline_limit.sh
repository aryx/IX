#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# -O3's inlining limit (Lower.inline_most) measured, the numbers behind
# CLI's -inline 24 (plan_ml_speed.md, 2026-10-29): for each limit, a
# copy of a commit built for arm by ix (MLOPT="-O3 -inline n": the
# libraries, mini-ml, mini-doom, mini-quake, cameltry), then under
# mini-5i the instructions of 61 frames of each game (frame 61's
# checksum: the pixels the same) and of mini-ml compiling three of its
# units, and the programs' sizes. Each limit's copy in dir/n; about 20
# minutes for two limits side by side.
# usage: inline_limit.sh dir commit n...   (dune build first: mini-5i)
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
D=$1 C=$2; shift 2
I=$ROOT/_build/default/machine/Main.exe
build() { local T=$D/$1
  rm -rf "${T:?}"; mkdir -p $T; git -C $ROOT archive $C | tar -x -C $T
  (cd $T && make all > $T.all.log 2>&1) || { echo "$1: make all failed"; return 1; }
  export PATH=$T/bin:$PATH MKSHELL=mini-rc NPROC=8 MLOPT="-O3 -inline $1"
  (cd $T && mini-mk O=5 OS=linux libs > $T.libs.log 2>&1) || { echo "$1: libs failed"; return 1; }
  for d in assembler languages/ml games/fps/doom games/fps/quake games/arcade; do
    (cd $T/$d && mini-mk O=5 > $T.$(basename $d).log 2>&1) || { echo "$1: $d failed"; return 1; }
  done; }
count() { $I -s "$@" 2>&1 >/dev/null | grep -o '^mini-5i: [0-9]*' | cut -d' ' -f2; }
measure() { local T=$D/$1 M=$D/$1/_mk/5
  local doom=$(cd $T/games/fps/doom && count $M/games/fps/doom/doom -dump-frame 61 $T.doom.ppm -script up:1-61 wad=data/freedoom.wad)
  local quake=$(cd $T && count $M/games/fps/quake/quake -dump-frame 61 $T.quake.ppm -script up:1-61)
  local camel=$(cd $T && count $M/games/arcade/tinycameltry -dump-frame 61 $T.camel.ppm -script space:2-3,right:4-61 -fixed-time 1000 seed=1)
  local L=$T/lib_core n=0 f inc
  inc=$(for u in $(grep -v '^#' $L/units.txt); do echo "-I $L/$(dirname $u)"; done | sort -u | tr '\n' ' ')
  for f in simple/Lower.ml Typing.ml ssa/Ssa_build.ml; do
    n=$((n + $(cd $T/languages/ml && count $M/languages/ml/mini-ml -m 5 $inc -I . -I simple -I ssa -I opti -I compat -o $T.x.5 $f)))
  done
  echo "-inline $1: doom $doom ($(md5sum < $T.doom.ppm | cut -c1-8)), quake $quake ($(md5sum < $T.quake.ppm | cut -c1-8)), cameltry $camel, mini-ml compiling $n"
  echo "  sizes: doom $(stat -c %s $M/games/fps/doom/doom), quake $(stat -c %s $M/games/fps/quake/quake), mini-ml $(stat -c %s $M/languages/ml/mini-ml)"; }
for n in "$@"; do build $n & done; wait
for n in "$@"; do measure $n > $D/$n.txt & done; wait
for n in "$@"; do cat $D/$n.txt; done
