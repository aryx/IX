#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_virtuaracing.md: what the
# playground's TinyVirtuaRacing stands on (the files a copy needs, the
# 3D values it names), what its frame costs by the playground's
# software platform, where that goes (callgrind, by part), and how many
# triangles a frame draws. Slow: two runs under callgrind, ~3 minutes.
# usage: games/survey_virtua.sh [dir]
#   dir: the playground (default: ~/playground)

P=${1:-$HOME/playground}
V=$P/games/racing/TinyVirtuaRacing.ml
B=$P/_build/default/games/racing/software/TinyVirtuaRacing.exe
[ -f $V ] || { echo "no $V"; exit 1; }

echo "== TinyVirtuaRacing: $(cat $V | wc -l) lines"
echo "  the 3D values it names (playground3d):"
grep -o '\b\(box\|cone\|polygon3d\|group3d\|cached3d\|[a-z_]*3d\)\b' $V | sort | uniq -c | sort -rn | awk '{ printf "    %4d %s\n", $1, $2 }'
echo "  the other modules it names:"
grep -o '\b[A-Z][a-z0-9]*[0-9]*d*\.[a-z_]*' $V | sed 's/\..*//' | sort | uniq -c | sort -rn | awk '$1 > 0 { printf "    %4d %s\n", $1, $2 }'

echo "== what a copy needs from the playground: lines (.ml .mli)"
total=0
for m in gamekits/racing/3d/Track3d gamekits/heightmap/Heightmap gamekits/racing/Topdown gamekits/racing/Road playground/layers/Camera3d \
         libs/graphics/3d/geometry/Vec3 libs/graphics/3d/geometry/Mat4 libs/graphics/3d/geometry/Camera; do
  ml=$(cat $P/$m.ml | wc -l); mli=$(cat $P/$m.mli 2>/dev/null | wc -l)
  total=$((total + ml))
  printf "  %5d %5d %s\n" $ml $mli $m
done
echo "  $total lines of .ml"
echo "  not needed: playground/apis/Physics3d.ml $(cat $P/playground/apis/Physics3d.ml | wc -l) lines; playground/Playground3d.ml $(cat $P/playground/Playground3d.ml | wc -l); libs/graphics/3d/*.ml $(cat $P/libs/graphics/3d/*.ml | wc -l)"

[ -x $B ] || { echo "no $B (dune build in $P)"; exit 0; }
tmp=$(mktemp -d)
trap "rm -rf $tmp" EXIT

# a frame's time: n+20 frames less n, so the start is not in it
echo "== a frame by the playground's software platform, by OCaml on this host ($(uname -m)), ms"
for size in "640 480" "320 240"; do
  t() { /usr/bin/time -f %e $B -fixed-time 1000 -dump-size $size -keys space -dump-frame $1 $tmp/f.png 2>&1 > /dev/null | tail -1; }
  printf "  %s: %s\n" "$size" $(echo "$(t 5) $(t 25)" | awk '{ printf "%.0f", ($2 - $1) * 1000 / 20 }')
done

# where a frame goes: callgrind of 2 and of 7 frames, the difference by 5
command -v valgrind > /dev/null || { echo "no valgrind"; exit 0; }
run() {
  valgrind --tool=callgrind --callgrind-out-file=$tmp/cg$1 $B -fixed-time 1000 -dump-size 320 240 -keys space \
    -dump-frame $1 $tmp/f.png > /dev/null 2>&1
  callgrind_annotate --threshold=100 $tmp/cg$1 2>/dev/null | grep '^ *[0-9,]* (' | grep -v 'PROGRAM TOTALS' |
    sed 's/ (.*%)  */ /; s/,//g; s/ \[.*//' > $tmp/fn$1
  # the triangles: calls of Triangle.fill (a name given once as
  # "cfn=(id) name", then "cfn=(id)" alone)
  awk '/^cfn=/ { if (match($0, /\(([0-9]+)\) (.*)/, m)) name[m[1]] = m[2]; match($0, /\(([0-9]+)\)/, k); cur = name[k[1]] }
       /^calls=/ { if (cur ~ /camlTriangle__fill_/) { split($0, c, /[= ]/); n += c[2] } }
       END { print n + 0 }' $tmp/cg$1 > $tmp/tri$1
}
run 2; run 7
echo "== a frame at 320 by 240 by part (callgrind, (7 frames - 2) / 5), millions of instructions"
part() {
  case "$1" in
    *libs/graphics/3d/Triangle.ml*|*Triangle__*|*Interpolate*|*Zbuffer*|*Framebuffer*|*Shading*) echo "pixels: the rasterizer (Triangle, Interpolate, Zbuffer, Framebuffer, Shading)";;
    *libs/graphics/3d/*|*Render__*|*Clip__*|*Project__*|*Playground3d*) echo "the scene: shapes made triangles, placed, cut (Playground3d, Render, Clip, Project)";;
    *runtime/*|*libc.so*|*caml_*) echo "OCaml's runtime: the GC, allocation";;
    *Track3d*|*Topdown*|*Heightmap*|*TinyVirtuaRacing*|*hypot*|*e_atan*|*s_sin*|*s_cos*) echo "the game: the car, the rivals, the view's lists, Track3d.locate";;
    *stdlib/list.ml*|*stdlib/array.ml*) echo "Stdlib's List and Array (the scene's lists)";;
    *) echo "other (the window, deflate of the PNG, the 2D hud)";;
  esac
}
for f in 2 7; do
  while read n name; do echo "$(part "$name")|$n"; done < $tmp/fn$f | awk -F'|' '{ s[$1] += $2 } END { for (k in s) print k "|" s[k] }' | sort > $tmp/parts$f
done
join -t'|' $tmp/parts2 $tmp/parts7 | awk -F'|' '{ printf "  %8.1f %s\n", ($3 - $2) / 5e6, $1; t += ($3 - $2) / 5e6 } END { printf "  %8.1f total\n", t }' | sort -rn
echo "  triangles filled a frame: $(echo "$(cat $tmp/tri2) $(cat $tmp/tri7)" | awk '{ printf "%.0f", ($2 - $1) / 5 }')"
