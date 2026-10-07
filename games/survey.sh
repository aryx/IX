#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_playground.md: the files of the
# author's playground a Tetris stands on (the library, a platform, the
# software rasterizer), their lines, what mini-ml says of each, and
# what the draw device of mini-9pi has to draw them with.
# usage: games/survey.sh [dir]
#   dir: the playground (default: ~/playground)

cd "$(dirname "$0")"
P=${1:-$HOME/playground}
T=..
[ -d $P/playground ] || { echo "no $P/playground"; exit 1; }

core="libs/core/Color.ml libs/core/Basics.ml libs/core/Time.ml libs/core/Keyboard.ml libs/core/Cmd.ml libs/core/Sub.ml libs/core/Program.ml libs/random/Lehmer.ml playground/Playground.ml"
soft="libs/graphics/2d/geometry/Vec2.ml libs/graphics/2d/geometry/Affine.ml libs/graphics/core/Framebuffer.ml libs/graphics/2d/Fill.ml libs/graphics/2d/Line.ml libs/graphics/2d/Circle.ml libs/graphics/2d/Stroke.ml libs/graphics/font/Hershey.ml playground/platforms/software/Shape_render_software.ml"
games="games/puzzle/Tetris.ml games/puzzle/TinyTetris.ml"

inc=""
for d in system core base collections printing parsing concurrency commons; do inc="$inc -I $T/lib_core/$d"; done
for d in libs/core libs/random libs/graphics/2d libs/graphics/2d/geometry libs/graphics/core libs/graphics/font playground; do inc="$inc -I $P/$d"; done

# a file's lines, its interface's, and the first thing mini-ml refuses
survey() {
  for f in $*; do
    mli=0; [ -f $P/${f}i ] && mli=$(cat $P/${f}i | wc -l)
    err=$($T/bin/mini-ml -m 7 -o /dev/null $inc $P/$f 2>&1 > /dev/null | head -1)
    n=$(echo "$err" | grep -o ':[0-9]*:' | head -1 | tr -d ':')
    printf "  %5d %5d %-56s %s | %s\n" $(cat $P/$f | wc -l) $mli $f "$(echo "$err" | sed 's/^[^ ]*: *//' | cut -c1-36)" "$([ "${n:-0}" -gt 0 ] && sed -n ${n}p $P/$f | sed 's/^ *//' | cut -c1-44)"
  done
}

echo "== the library (lines, its .mli's, mini-ml's first refusal)"
survey $core
echo "== the software rasterizer and its platform's renderer"
survey $soft
echo "== the games"
survey $games
echo "== the platforms there (lines)"
for d in software native web native_common; do printf "  %5d %s\n" $(cat $P/playground/platforms/$d/*.ml | wc -l) $d; done
echo "== what the platform's interface asks (Playground_platform.mli)"
echo "  $(grep -o '^val [a-z_]*' $P/playground/Playground_platform.mli | sed 's/val //' | tr '\n' ' ')"
echo "== what the games ask of the library"
for f in $games; do echo "  $(basename $f): $(grep -o '\b[A-Z][A-Za-z_0-9]*\.[a-z_]*' $P/$f | grep -v '^List\.\|^Array\.\|^Option\.\|^Printf\.\|^Fun\.' | sort -u | tr '\n' ' ')"; done
echo "== constructs mini-ml has not, in all of the above"
all="$core $soft $games"
printf "  optional arguments (definitions): %d\n" $(cd $P && grep -c '^let.*?[(a-z]' $all | awk -F: '{ s += $2 } END { print s }')
printf "  Bigarray: %d lines; lazy: %d; a GADT: %d; a module inside a file: %d\n" $(cd $P && cat $all | grep -c Bigarray) $(cd $P && cat $all | grep -c '\blazy\b\|Lazy\.') $(cd $P && cat $all | grep -c 'Any_app :') $(cd $P && cat $all | grep -c '^module .* = struct')
echo "== mini-9pi's draw device (kernel/9pi/devices/screen/Devdraw.ml): its messages"
echo "  $(grep -o "^      | ('[A-Za-z]'\( | '[A-Za-z]'\)*)\? *\(as k \)\?->\|^      | '[A-Za-z]' ->" $T/kernel/9pi/devices/screen/Devdraw.ml | grep -o "'[A-Za-z]'" | tr -d "'" | tr '\n' ' ')"
echo "  ix's library for it (lib_graphics): $(cat $T/lib_graphics/*.ml $T/lib_graphics/*.mli | wc -l) lines; Draw.mli's: $(grep -o '^val [a-z_]*' $T/lib_graphics/Draw.mli | sed 's/val //' | tr '\n' ' ')"

# The sound (docs/plans/plan_audio.md)
A=$P/libs/audio
echo "== the sound: the playground's synthesizer (lines, interfaces)"
for d in signal synthesis . formats/abc formats/wav effects instruments formats/midi formats/mod formats/mpeg_audio formats/vorbis; do
  printf "  %5d %5d %s\n" $(cat $A/$d/*.ml | wc -l) $(cat $A/$d/*.mli 2>/dev/null | wc -l) libs/audio/$d
done
printf "  %5d %5d %s\n" $(cat $P/playground/apis/Audio.ml | wc -l) $(cat $P/playground/apis/Audio.mli | wc -l) playground/apis/Audio
echo "  Audio.mli's values: $(grep -c '^val' $P/playground/apis/Audio.mli); Tetris.ml's: $(grep -o 'Audio\.[a-z_]*\|Sfx\.[a-z_]*' $P/games/puzzle/Tetris.ml | sort -u | tr '\n' ' ')"
echo "  the rate: $(grep -o 'let rate = [0-9]*' $A/signal/Signal.ml)"
echo "== the sound: what ix has"
echo "  kernel/9pi, files naming pwm or audio: $(grep -rIli 'pwm\|audio' $T/kernel/9pi --include=*.ml --include=*.mli --include=*.c | grep -v usbd | wc -l); a DMA module: $(find $T/kernel/9pi -iname 'dma*' | wc -l) (principia's bcm: $(ls $HOME/principia/kernel/COMPILE/9/bcm 2>/dev/null | grep -c '^dma.c$') dma.c, its audio drivers for arm: $(ls $HOME/principia/kernel/devices/audio 2>/dev/null | grep -vc 386))"
echo "  mini-pi (raspberry/), files naming pwm or audio: $(grep -li 'pwm\|audio' $T/raspberry/*.ml | wc -l); its DMA: $(ls $T/raspberry/Dma.ml | wc -l) (DREQ pacing: $(grep -c 'DREQ pacing are not modelled' $T/raspberry/Dma.mli) said not modelled)"
echo "  QEMU's audio devices for a raspi: $(qemu-system-arm -M raspi1ap -device help 2>/dev/null | grep -i 'audio\|pwm' | grep -v 'PCI\|HDA' | sed 's/name "\([^"]*\)".*/\1/' | tr '\n' ' ')"

# The playground's other games: how many use each of its modules
echo "== the playground's games: $(find $P/games -name '*.ml' | wc -l) files, $(find $P/games -name '*.ml' | xargs cat | wc -l) lines; files using each module"
std='List|Array|Option|Printf|Fun|String|Hashtbl|Float|Int|Char|Buffer|Bytes|Random|Sys|Unix|Stdlib|Result|Seq|Queue|Format|Lazy|Bool|Either|Map|Set|Filename|Int32|Int64|Stack'
for f in $(find $P/games -name '*.ml'); do grep -o '\b[A-Z][A-Za-z_0-9]*\.[a-z_]' $f | cut -d. -f1 | sort -u | grep -vxE "$std"; done | sort | uniq -c | sort -rn | head -16 | awk '{ printf "%s %d  ", $2, $1 } END { print "" }' | sed 's/^/  /'

# The copies here against the playground's (plan_playground.md, stage 1):
# each file with the lines it gained and lost, the files that are ix's own
echo "== ix's copies against the playground's (lines here, +gained -lost)"
copy() {   # ix's directory, the playground's, the units
  local here=$T/$1 there=$P/$2 u e; shift 2
  for u in "$@"; do for e in ml mli; do
    [ -f $here/$u.$e ] || continue
    if [ -f $there/$u.$e ]; then printf "  %5d +%-4d -%-4d %s\n" $(cat $here/$u.$e | wc -l) $(diff $there/$u.$e $here/$u.$e | grep -c '^>') $(diff $there/$u.$e $here/$u.$e | grep -c '^<') ${here#$T/}/$u.$e
    else printf "  %5d %-11s %s\n" $(cat $here/$u.$e | wc -l) "ix's own" ${here#$T/}/$u.$e; fi
  done; done
}
copy lib_graphics/software libs/graphics/core Framebuffer Opti
copy lib_graphics/software libs/graphics/2d/geometry Vec2 Affine
copy lib_graphics/software libs/graphics/2d Fill Line Circle Stroke
copy lib_graphics/software libs/graphics/font Hershey Hershey_futural
copy lib_graphics/software libs/graphics/images/rgba Rgba_image
copy lib_playground libs/core Color Basics Time Cmd Sub Set
copy lib_playground libs/random Lehmer
copy lib_playground playground Playground
copy lib_playground/platforms playground/platforms/software Shape_render_software
copy lib_playground/platforms playground Playground_platform
copy lib_playground/platforms playground/platforms/native_common Input_script
copy lib_playground/platforms none Session
copy lib_playground/platforms/ppm none Playground_platform
copy games/puzzle games/puzzle Tetris
echo "  all: $(cat $T/lib_graphics/software/*.ml $T/lib_graphics/software/*.mli $T/lib_playground/*.ml $T/lib_playground/*.mli $T/lib_playground/platforms/*.ml $T/lib_playground/platforms/*.mli $T/lib_playground/platforms/ppm/*.ml $T/lib_playground/platforms/ppm/Input_script.mli $T/games/*/*.ml | wc -l) lines ($(cat $T/lib_graphics/software/*.ml $T/lib_playground/*.ml $T/lib_playground/platforms/*.ml $T/lib_playground/platforms/ppm/*.ml $T/games/*/*.ml | wc -l) of .ml)"
echo "== a frame of Tetris (the playground's golden: frame 5, 1000 by 1000), seconds"
args="-fixed-time 1000 -dump-frame 5 /dev/null seed=1"
for b in $T/_build/default/games/puzzle/Tetris.exe $T/_mk/7/games/puzzle/tetris; do
  [ -x $b ] && [ "$(uname -m)" = aarch64 ] && printf "  %s: %s\n" ${b#$T/} "$( { /usr/bin/time -f %es $b $args; } 2>&1 | tail -1)"
done
