#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_gpu.md: the files of the
# author's playground its 3D stands on (the library, the geometry, the
# rasterizer with a depth for each pixel, the platforms), their lines,
# what mini-ml says of each, what the 3D programs there ask, what a
# frame costs on this host, and what ix and the emulators know of the
# boards' 3D processor.
# usage: games/survey3d.sh [dir]
#   dir: the playground (default: ~/playground)

cd "$(dirname "$0")"
P=${1:-$HOME/playground}
T=..
[ -d $P/playground ] || { echo "no $P/playground"; exit 1; }

G=libs/graphics/3d
geometry="$G/geometry/Vec3.ml $G/geometry/Mat4.ml $G/geometry/Camera.ml $G/geometry/Lighting.ml $G/geometry/Material.ml"
library="playground/Playground3d.ml playground/Gpu_scene.ml libs/graphics/gpu/Mesh_cache.ml"
painter="$G/Project.ml $G/Cull.ml $G/Painter.ml"
zbuffer="$G/Clip.ml $G/Interpolate.ml $G/Shading.ml $G/Texture.ml $G/Zbuffer.ml $G/Triangle.ml $G/Render.ml"
platforms="playground/platforms/svg/Playground3d_platform.ml playground/platforms/software/Shape3d_render_software.ml playground/platforms/software/Playground3d_platform.ml playground/platforms/native_common/Native_loop_3d.ml playground/platforms/native/Playground3d_platform.ml playground/platforms/native/Gl_shaders.ml"

inc=""
for d in system core base collections printing parsing concurrency commons; do inc="$inc -I $T/lib_core/$d"; done
for d in lib_playground lib_playground/core lib_playground/random lib_playground/platforms lib_graphics/core lib_graphics/geometry lib_graphics/images lib_graphics/software; do inc="$inc -I $T/$d"; done
for d in $G/geometry $G libs/graphics/gpu playground; do inc="$inc -I $P/$d"; done

# a file's lines, its interface's, and the first thing mini-ml refuses
# (ix's lib_playground and lib_graphics/software under it, so that what
# is said is the file's own)
survey() {
  for f in $*; do
    mli=0; [ -f $P/${f}i ] && mli=$(cat $P/${f}i | wc -l)
    err=$($T/bin/mini-ml -m 7 -o /dev/null $inc $P/$f 2>&1 > /dev/null | head -1)
    n=$(echo "$err" | grep -o ':[0-9]*:' | head -1 | tr -d ':')
    printf "  %5d %5d %-60s %s | %s\n" $(cat $P/$f | wc -l) $mli $f "$(echo "$err" | sed 's/^[^ ]*:0: .*\/\([A-Za-z0-9_]*\.mli\):[0-9]*: */(\1) /; s/^\/[^ ]*: *//' | cut -c1-30)" "$([ "${n:-0}" -gt 0 ] && sed -n ${n}p $P/$f | sed 's/^ *//' | cut -c1-50)"
  done
}
total() { (cd $P && cat $* | wc -l); }

echo "== the geometry ($(total $geometry) lines; lines, its .mli's, mini-ml's first refusal)"
survey $geometry
echo "== the library ($(total $library))"
survey $library
echo "== 3D to 2D shapes, the farthest first ($(total $painter))"
survey $painter
echo "== the rasterizer with a depth for each pixel ($(total $zbuffer))"
survey $zbuffer
echo "== the platforms"
survey $platforms
echo "  the ray tracer ($G/raytrace): $(cat $P/$G/raytrace/*.ml | wc -l) lines"
echo "== what they ask beside themselves"
for f in playground/Playground3d.ml playground/Gpu_scene.ml playground/platforms/svg/Playground3d_platform.ml playground/platforms/software/Playground3d_platform.ml; do
  echo "  $(basename $(dirname $f))/$(basename $f): $(grep -o '\b[A-Z][A-Za-z_0-9]*\.[a-z_]' $P/$f | cut -d. -f1 | sort | uniq -c | sort -rn | awk '{ printf "%s %d  ", $2, $1 }')"
done
echo "== constructs mini-ml has not, in the geometry, the library, the two renderers and the svg and software platforms"
all="$geometry $library $painter $zbuffer playground/platforms/svg/Playground3d_platform.ml playground/platforms/software/Shape3d_render_software.ml playground/platforms/software/Playground3d_platform.ml"
printf "  optional arguments (definitions): %d; Bigarray: %d lines; a GADT: %d; let open: %d\n" $(cd $P && grep -c '^let.*?[(a-z]\|^  let.*?[(a-z]' $all | awk -F: '{ s += $2 } END { print s }') $(cd $P && cat $all | grep -c Bigarray) $(cd $P && cat $all | grep -c 'Any_app3d :') $(cd $P && cat $all | grep -c 'let open')

# The programs
ex=$(ls $P/examples/*3d*.ml)
gm=$(grep -rl 'Playground3d' $P/games --include=*.ml)
echo "== the 3D programs there: $(echo "$ex" | wc -l) examples ($(cat $ex | wc -l) lines), $(echo "$gm" | wc -l) games ($(cat $gm | wc -l) lines)"
echo "  files using each value of Playground3d (the games, then the examples)"
for v in cube box plane sphere polygon3d textured_quad textured_cube hud cached3d shiny glassy split3d fade3d; do
  printf "    %-14s %3d %3d\n" $v $(grep -lw "$v" $gm | wc -l) $(grep -lw "$v" $ex | wc -l)
done
printf "    %-14s %3d %3d\n" capture_mouse $(grep -l 'capture_mouse' $gm | wc -l) $(grep -l 'capture_mouse' $ex | wc -l)
echo "  files using each module beside it (the games)"
std='List|Array|Option|Printf|Fun|String|Hashtbl|Float|Int|Char|Buffer|Bytes|Random|Sys|Unix|Stdlib|Result|Seq|Queue|Format|Lazy|Bool|Either|Map|Set|Filename|Int32|Int64|Stack'
for f in $gm; do grep -o '\b[A-Z][A-Za-z_0-9]*\.[a-z_]' $f | cut -d. -f1 | sort -u | grep -vxE "$std"; done | sort | uniq -c | sort -rn | head -18 | awk '{ printf "%s %d  ", $2, $1 } END { print "" }' | sed 's/^/    /'
echo "  golden frames of the 3D examples (tests/3d/golden): $(ls $P/tests/3d/golden | wc -l)"

# A frame's time here: the playground's software platform, by OCaml, no
# window (-dump-frame n: n frames drawn, the last saved). 20 frames more
# is what is said, so the program's start is not in it.
echo "== a frame by the playground's software platform, by OCaml on this host ($(uname -m)), 640 by 480, milliseconds"
tmp=$(mktemp -d)
for e in Triangle3d Cube3d Cubes3d Spheres3d Corridor3d TexturedCube3d StarCollector3d; do
  b=$P/_build/default/examples/software/$e.exe
  [ -x $b ] || continue
  t() { /usr/bin/time -f %e $b -fixed-time 1000 -dump-size 640 480 -dump-frame $1 $tmp/f.png 2>&1 > /dev/null | tail -1; }
  printf "  %-18s %s\n" $e $(echo "$(t 1) $(t 21)" | awk '{ printf "%.0f", ($2 - $1) * 1000 / 20 }')
done
# The goal's game: what it stands on, and its frame at two sizes (the
# same time at a quarter of the pixels: the time is the scene's)
V=$P/games/racing/TinyVirtuaRacing.ml
echo "== TinyVirtuaRacing: $(cat $V | wc -l) lines; cached3d: $(grep -c 'cached3d' $V) lines, Lazy: $(grep -c 'Lazy\.t' $V) tables, lines with a label: $(grep -c '~[a-z]' $V); golden frames: $(ls $P/tests/3d/golden | grep -c TinyVirtuaRacing)"
for m in gamekits/racing/3d/Track3d gamekits/heightmap/Heightmap gamekits/racing/Topdown gamekits/racing/Road playground/layers/Camera3d; do
  printf "  %5d %5d %-36s here: %s\n" $(cat $P/$m.ml | wc -l) $(cat $P/$m.mli | wc -l) $m "$(find $T/lib_playground $T/lib_graphics $T/games -name "$(basename $m).ml" | wc -l)"
done
echo "  its rendering: $(grep -o 'run_app3d ~rendering:{[^}]*}' $V)"
b=$P/_build/default/games/racing/software/TinyVirtuaRacing.exe
if [ -x $b ]; then
  for size in "640 480" "320 240"; do
    t() { /usr/bin/time -f %e $b -fixed-time 1000 -dump-size $size -keys space -dump-frame $1 $tmp/f.png 2>&1 > /dev/null | tail -1; }
    printf "  a frame, %s, by OCaml here: %s ms\n" "$size" $(echo "$(t 1) $(t 21)" | awk '{ printf "%.0f", ($2 - $1) * 1000 / 20 }')
  done
fi
rm -rf $tmp

# What ix has
echo "== ix: the playground's 2D here"
echo "  lib_playground's platforms: $(ls -d $T/lib_playground/platforms/*/ | xargs -n1 basename | tr '\n' ' '); files naming Playground3d: $(grep -rl 'Playground3d' $T/lib_playground $T/games $T/examples --include=*.ml --include=*.mli 2>/dev/null | wc -l)"
echo "  3D geometry here (Vec3, Mat4): $(ls $T/lib_graphics/geometry/Vec3.ml $T/lib_graphics/geometry/Mat4.ml 2>/dev/null | wc -l) files"
echo "== ix: the boards"
echo "  kernels/lib_machine: $(ls -d $T/kernels/lib_machine/pi*/ | xargs -n1 basename | tr '\n' ' ')($(cat $T/kernels/lib_machine/pi1/* | wc -l) lines the first); mini-pi's files naming a Pi2: $(grep -li 'pi2' $T/raspberry/*.ml $T/raspberry/*.mli | wc -l)"
echo "  principia's 9pi for the Pi2: $(cd $HOME/principia/kernel/COMPILE/9/bcm 2>/dev/null && cat raspi2.c startv7.s cache_raspi2.s tas_raspi2.s time_raspi2.s concurrency_raspi2.c | wc -l) lines in 6 files; QEMU's raspi2b: $(qemu-system-arm -M help 2>/dev/null | grep -c '^raspi2b')"
echo "== ix: the boards' 3D processor"
echo "  the screen (Swconsole): $(grep -o 'let wid = .*' $T/kernels/9pi/devices/screen/Swconsole.ml)"
echo "  the firmware's tags the kernel sends (lib_machine/pi1/machine.c): $(grep -o 'property(0x[0-9a-f]*' $T/kernels/lib_machine/pi1/machine.c | sed 's/property(//' | sort -u | tr '\n' ' ')"
echo "  the firmware's tags mini-pi answers (raspberry/Devices.ml): $(grep -o '| 0x000[0-9a-f]* ' $T/raspberry/Devices.ml | tr -d '| ' | sort -u | tr '\n' ' ')"
echo "  files naming v3d, kernels/ and raspberry/: $(grep -rIli 'v3d' $T/kernels $T/raspberry --include=*.ml --include=*.mli --include=*.c --include=*.h --include=*.s | wc -l)"
echo "  the host's Linux headers (the programs' side of the two drivers): $(ls /usr/include/drm/vc4_drm.h /usr/include/drm/v3d_drm.h 2>/dev/null | tr '\n' ' ')"
echo "  QEMU's devices naming v3d, raspi1ap: $(qemu-system-arm -M raspi1ap -device help 2>/dev/null | grep -ci v3d); raspi4b: $(qemu-system-aarch64 -M raspi4b -device help 2>/dev/null | grep -ci v3d)"
