#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_office.md: the files of the
# author's playground that TinyOffice stands on and ix has not yet,
# their lines, what mini-ml says of each (its first refusal only: a
# file has others behind it), the constructs mini-ml has not, counted,
# and what TinyOffice asks of the Playground that ix's has not.
# As apps/survey.sh, which is Scheme's and Pascal's.
# usage: apps/office/survey.sh [dir]
#   dir: the playground (default: ~/playground)

cd "$(dirname "$0")"
P=${1:-$HOME/playground}
T=../..
[ -d $P/playground ] || { echo "no $P/playground"; exit 1; }

# in their dependencies' order
kits="appkits/document/Saved appkits/richtext/Style appkits/richtext/Rich appkits/richtext/Page appkits/paint/Bitmap appkits/paint/Pattern appkits/paint/Seed_fill appkits/paint/Paint appkits/draw/Figure appkits/draw/Drawing"
drawn="apps/graphics/draw_view/Figure_shapes apps/office/stroke_text/Stroke_text apps/office/file_menu/File_menu apps/office/embed/Component"
office="apps/office/Part_text apps/office/Part_sheet apps/office/Part_picture apps/office/Part_drawing apps/office/Part_chart apps/office/TinyOffice"
# the office's other programs, and what they alone stand on
others="apps/office/embed/Compound appkits/slides/Outline appkits/nls/Nls_doc apps/office/TinyVisiCalc apps/office/TinyLotus123 apps/office/TinyExcel apps/office/TinyBravo apps/office/TinyWord apps/office/TinyOpenDoc apps/office/TinyPowerPoint apps/office/TinyFrameMaker apps/office/TinyNLS apps/office/TinyHyperCard"

# ix's own first (its Playground, Gui, Sheet, Undo, Hershey: already
# copied), then the playground's for what is not here yet
inc=""
for d in . core random layers apis ways platforms/ppm platforms; do inc="$inc -I $T/lib_playground/$d"; done
inc="$inc -I $T/lib_graphics/software -I $T/lib_gui -I $T/lib_terminal -I $T/apps/kits -I $T/apps/office/sheet -I $T/apps/office/formula"
for d in appkits/document appkits/richtext appkits/paint appkits/draw appkits/slides appkits/nls apps/graphics/draw_view apps/office/stroke_text apps/office/file_menu apps/office/embed apps/office languages/hypertalk; do inc="$inc -I $P/$d"; done
for d in system core base collections printing parsing concurrency commons; do inc="$inc -I $T/lib_core/$d"; done

# a file's lines, its interface's, and the first thing mini-ml refuses
survey() {
  local ml=0 mli=0 n i err
  for u in $*; do
    n=$(cat $P/$u.ml | wc -l); i=0; [ -f $P/$u.mli ] && i=$(cat $P/$u.mli | wc -l)
    ml=$((ml + n)); mli=$((mli + i))
    err=$($T/bin/mini-ml -m 7 -o /dev/null $inc $P/$u.ml 2>&1 > /dev/null | head -1)
    l=$(echo "$err" | grep -o "$u.ml:[0-9]*:" | grep -o ':[0-9]*:' | tr -d ':')
    printf "  %5d %5d %-44s %s | %s\n" $n $i $u.ml "$(echo "$err" | sed "s|$P/||; s/^\([^ ]*\.mli:[0-9]*\):.*/its \1/; s/^[^ ]*\.ml:[0-9:]* *//" | cut -c1-44)" "$([ "${l:-0}" -gt 0 ] && sed -n ${l}p $P/$u.ml | sed 's/^ *//' | cut -c1-48)"
  done
  printf "  %5d %5d all (%d files)\n" $ml $mli $(echo $* | wc -w)
}
# the constructs mini-ml has not, in a set of units
constructs() {
  local ml="" mli=""
  for u in $*; do ml="$ml $P/$u.ml"; [ -f $P/$u.mli ] && mli="$mli $P/$u.mli"; done
  printf "  optional arguments: %d definitions (%d in the interfaces); Map.Make: %d; let open: %d; Hashtbl: %d lines; to_seq: %d; Buffer: %d lines; Printf/Scanf: %d lines\n" \
    $(cat $ml | grep -c '^ *let.*[ (]?[(a-z]') $(cat $mli /dev/null | grep -c '?[a-z_]*:') $(cat $ml | grep -c '\.Make') $(cat $ml | grep -c 'let open') $(cat $ml | grep -c 'Hashtbl') $(cat $ml | grep -c 'to_seq') $(cat $ml | grep -c 'Buffer\.') $(cat $ml | grep -c 'Printf\.\|Scanf\.')
}
# a module's values a set of units names (M.v), that ix's interface has not
lacks() {   # module, ix's .mli, units
  local m=$1 mli=$2 ml=""; shift 2
  for u in $*; do ml="$ml $P/$u.ml"; done
  for v in $(cat $ml | grep -o "\b$m\.[a-z_][a-zA-Z_0-9']*" | sort -u | sed "s/^$m\.//"); do
    grep -q "^\(val\|external\|type\|and\) *\(('[a-z, ']*) *\|'[a-z] *\)\?$v\b\|^ *| *$v\b\|[{;] *\(mutable \)\?$v *:" $mli || printf "%s " $v
  done
}

echo "== the kits TinyOffice stands on that ix has not (lines, its .mli's, mini-ml's first refusal)"
survey $kits
constructs $kits
echo "== what is drawn of them, and the libraries beside the office's programs"
survey $drawn
constructs $drawn
echo "== the parts and TinyOffice"
survey $office
constructs $office
echo "== the office's other programs, and what they alone stand on"
survey $others
constructs $others
echo "== the playground's tests of them (Testo; lines)"
wc -l $P/appkits/tests/Unit_{document,rich,page,flow,paint,draw,sheet,slides,nls}.ml $P/apps/office/tests/Unit_embed.ml | sed "s|$P/||; s/^/  /"
echo "== its golden frames of TinyOffice (tests/2d/golden), and their scripts"
echo "  $(ls $P/tests/2d/golden | grep -c '^TinyOffice') frames: $(ls $P/tests/2d/golden | grep '^TinyOffice' | sed 's/TinyOffice_\?//; s/\.png//' | tr '\n' ' ')"
echo "== what ix has already, and what these files name that it has not"
all="$kits $drawn $office"
echo "  Playground: $(lacks Playground $T/lib_playground/Playground.mli $all)"
echo "  Gui:        $(lacks Gui $T/lib_playground/apis/Gui.mli $all)"
echo "  Immediate:  $(lacks Immediate $T/lib_gui/Immediate.mli $all)"
echo "  Widget:     $(lacks Widget $T/lib_gui/Widget.mli $all)"
echo "  Look:       $(lacks Look $T/lib_gui/Look.mli $all)"
echo "  Text_edit:  $(lacks Text_edit $T/lib_gui/Text_edit.mli $all)"
echo "  Hershey:    $(lacks Hershey $T/lib_graphics/software/Hershey.mli $all)"
echo "  Sheet:      $(lacks Sheet $T/apps/office/sheet/Sheet.mli $all)"
echo "  Sheet_view: $(lacks Sheet_view $T/apps/office/sheet/Sheet_view.mli $all)"
echo "  Undo:       $(lacks Undo $T/apps/kits/Undo.mli $all)"
echo "  ix's Playground.mli lacks, of the playground's values: $(diff <(grep -o '^val [a-z_0-9]*' $P/playground/Playground.mli | sort) <(grep -o '^val [a-z_0-9]*' $T/lib_playground/Playground.mli | sort) | grep '^<' | sed 's/< val //' | tr '\n' ' ')"
