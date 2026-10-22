#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-quake's level made from LibreQuake's source (data/README.md):
# the texture WADs its map names, from LibreQuake's PNGs (mini-mkwad2),
# then the three tools a Quake map went through: qbsp (the BSP tree,
# the faces, the hulls) and vis (the PVS), ericw-tools' (QBSP=, VIS=, or
# on the PATH), and light, ours (tools/Light.ml).
# usage: games/fps/quake/tools/mklevel.sh LIBREQUAKE-DIR [map] [out.bsp]
#   map: the map's path in lq1/maps/src (default e0/lq_e0m1)
#   out: default games/fps/quake/data/e0m1.bsp
set -e
cd "$(dirname "$0")/../../../.."
LQ=${1:?usage: mklevel.sh LIBREQUAKE-DIR [map] [out.bsp]}
MAP=${2:-e0/lq_e0m1}
OUT=${3:-games/fps/quake/data/e0m1.bsp}
QBSP=${QBSP:-qbsp}
VIS=${VIS:-vis}
dune build ./games/fps/quake/tools/Mkwad.exe ./games/fps/quake/tools/Light.exe
T=_build/default/games/fps/quake/tools
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# (the map where its "wad" key's ../../../../texture-wads/ finds ours)
mkdir -p $W/lq1/maps/src/$(dirname $MAP) $W/texture-wads
cp $LQ/lq1/maps/src/$MAP.map $W/lq1/maps/src/$MAP.map
for w in $(grep -m1 '^"wad"' $W/lq1/maps/src/$MAP.map | sed 's/^"wad" "//; s/"$//; s/;/ /g'); do
  n=$(basename $w .wad)
  $T/Mkwad.exe $LQ/lq1/gfx/palette.lmp $W/texture-wads/$n.wad $LQ/texture-wads/$n
done
(cd $W/lq1/maps/src/$(dirname $MAP) && $QBSP $(basename $MAP).map $W/level.bsp > $W/qbsp.log)
(cd $W && $VIS level.bsp > vis.out)
$T/Light.exe $W/level.bsp $OUT $LQ/lq1/gfx/palette.lmp
