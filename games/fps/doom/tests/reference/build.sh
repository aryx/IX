#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The reference for mini-doom's pictures (docs/plans/plan_doom.md): id's
# Doom as 9front has it (sys/src/games/doom: linuxdoom of 1997, 64-bit
# clean, its platform Plan 9's), built on Linux by gcc with no window
# (i_ref.c here: its platform; compat/: Plan 9's two headers). id's
# source is not copied into ix (its license is id's): it is read where
# it is and built in OUT.
#   usage: build.sh 9front-doom-dir OUT
#   then:  ../compare.sh (REFDOOM=OUT/refdoom)
# The one change to id's source: r_data.c's maptexture_t says its
# obsolete columndirectory a long, 4 bytes on Plan 9's amd64 and 8 on
# Linux's: the WAD's TEXTURE1 read wrong ("R_InitTextures: Missing patch
# in texture DOORBLU"); here an int.
set -e
src=${1:?usage: build.sh 9front-doom-dir OUT}; out=${2:?usage: build.sh 9front-doom-dir OUT}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out"; cd "$out"
cp "$src"/*.c "$src"/*.h .
rm -f i_main.c i_video.c i_sound.c
sed -i 's/^\tlong\t\tcolumndirectory;/\tint\t\tcolumndirectory;/' r_data.c
cp "$here/i_ref.c" .
for f in *.c; do gcc -c -w -O1 -D_GNU_SOURCE -I"$here/compat" "$f" -o "${f%.c}.o"; done
gcc -o refdoom *.o -lm
echo "$out/refdoom"
