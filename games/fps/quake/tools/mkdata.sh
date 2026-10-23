#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What mini-quake's game reads beside its level (data/README.md): the
# models, the sounds and the music it lists (mini-quake precache: the
# models and sounds of Monsters and Weapons, the level's CD track),
# copied from LibreQuake's lq1/ as they are, at the same paths (Quake's
# own directory: progs/, sound/, music/).
# usage: games/fps/quake/tools/mkdata.sh LIBREQUAKE-DIR
set -e
cd "$(dirname "$0")/../../../.."
LQ=${1:?usage: mkdata.sh LIBREQUAKE-DIR}
D=games/fps/quake/data
dune build ./games/fps/quake/Quake.exe
for f in $(./_build/default/games/fps/quake/Quake.exe precache); do
  mkdir -p $D/$(dirname $f)
  cp $LQ/lq1/$f $D/$f
done
du -sh $D/progs $D/sound $D/music
