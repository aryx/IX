#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_pdf.md: mini-chrome's PDF reader
# and the fonts under it, the playground's modules they name that ix
# has not, their lines, what mini-ml says of each (its first refusal
# only: a file has others behind it), the constructs mini-ml has not,
# counted, how long mini-chrome's own build takes to draw each page of
# its test files, and Plan 9's page, counted.
# As apps/office/survey.sh.
# usage: scripts/stats/pdf_survey.sh [mini-chrome] [playground] [principia]

cd "$(dirname "$0")"
T=../..
C=${1:-$HOME/github/mini-chrome}
P=${2:-$HOME/playground}
S=${3:-$HOME/github/principia-softwarica}
[ -d $C/libs/pdf ] || { echo "no $C/libs/pdf"; exit 1; }
[ -d $P/libs/graphics ] || { echo "no $P/libs/graphics"; exit 1; }

# in their dependencies' order; a unit is a path without its extension
under="$P/libs/graphics/2d/geometry/Curve $P/libs/compression/Huffman $P/libs/graphics/images/jpeg/Dct $P/libs/graphics/images/jpeg/Jpeg_progressive $P/libs/graphics/images/jpeg/Jpeg"
fonts="$C/libs/fonts/Outline $C/libs/fonts/Glyph_names $C/libs/fonts/Standard_widths $C/libs/fonts/Truetype $C/libs/fonts/Cff $C/libs/fonts/Type1"
pdf="$C/libs/pdf/Pdf_object $C/libs/pdf/Pdf_filter $C/libs/pdf/Pdf $C/libs/pdf/Pdf_color $C/libs/pdf/Pdf_canvas $C/libs/pdf/Pdf_font $C/libs/pdf/Pdf_shading $C/libs/pdf/Pdf_image $C/libs/pdf/Pdf_render"
viewer="$C/src/viewers/Pdf_viewer"

# ix's own first, then the two trees' for what is not here yet
inc="-I $T/lib_graphics/software -I $T/lib_compression"
for d in system core base collections printing parsing concurrency commons; do inc="$inc -I $T/lib_core/$d"; done
for d in libs/graphics/2d/geometry libs/compression libs/compression/deflate libs/graphics/images/jpeg; do inc="$inc -I $P/$d"; done
inc="$inc -I $C/libs/fonts -I $C/libs/pdf"

short() { echo "$1" | sed "s|$C/||; s|$P/|playground/|"; }

# a file's lines, its interface's, and the first thing mini-ml refuses
survey() {
  local ml=0 mli=0 n i err l
  for u in $*; do
    n=$(cat $u.ml | wc -l); i=0; [ -f $u.mli ] && i=$(cat $u.mli | wc -l)
    ml=$((ml + n)); mli=$((mli + i))
    err=$($T/bin/mini-ml -m 7 -o /dev/null $inc $u.ml 2>&1 > /dev/null | head -1)
    l=$(echo "$err" | grep -o "$(basename $u).ml:[0-9]*:" | grep -o ':[0-9]*:' | tr -d ':')
    printf "  %5d %5d %-44s %s | %s\n" $n $i "$(short $u).ml" "$(echo "$err" | sed "s/^[^ ]*\.ml:[0-9:]* *//; s|^[^ ]*/\([A-Za-z_0-9]*\.mli:[0-9]*\):.*|its \1|" | cut -c1-44)" "$([ "${l:-0}" -gt 0 ] && sed -n ${l}p $u.ml | sed 's/^ *//' | cut -c1-48)"
  done
  printf "  %5d %5d all (%d files)\n" $ml $mli $(echo $* | wc -w)
}
# the constructs mini-ml has not, in a set of units
constructs() {
  local ml="" mli=""
  for u in $*; do ml="$ml $u.ml"; [ -f $u.mli ] && mli="$mli $u.mli"; done
  printf "  optional arguments: %d definitions (%d in the interfaces); Map.Make: %d; let open: %d; Hashtbl: %d lines; Buffer: %d lines; Printf/Scanf: %d lines; Bigarray: %d lines; for: %d; while: %d; float arrays made: %d\n" \
    $(cat $ml | grep -c '^ *let.*[ (]?[(a-z]') $(cat $mli /dev/null | grep -c '?[a-z_]*:') $(cat $ml | grep -c '\.Make') $(cat $ml | grep -c 'let open') $(cat $ml | grep -c 'Hashtbl') $(cat $ml | grep -c 'Buffer\.') $(cat $ml | grep -c 'Printf\.\|Scanf\.') $(cat $ml | grep -c 'Bigarray\|Array1') $(cat $ml | grep -c '\bfor \b') $(cat $ml | grep -c '\bwhile\b') $(cat $ml | grep -c 'Array.make\|Float.Array\|Array.init')
}
# the modules a set of units names that are neither theirs nor ix's
outside() {
  local ml=""
  for u in $*; do ml="$ml $u.ml"; done
  for m in $(cat $ml | grep -o "\b[A-Z][A-Za-z_0-9]*\.[a-z_]" | sed 's/\..$//' | sort -u); do
    find $T/lib_core $T/lib_graphics $T/lib_compression $C/libs/fonts $C/libs/pdf -name "$m.ml" | grep -q . || printf "%s " $m
  done
}

echo "== mini-chrome at $(git -C $C log -1 --format='%h %ad' --date=short), the playground at $(git -C $P log -1 --format='%h %ad' --date=short)"
echo "== the playground's modules under them that ix has not (lines, its .mli's, mini-ml's first refusal)"
survey $under
constructs $under
echo "== the fonts (mini-chrome's libs/fonts)"
survey $fonts
constructs $fonts
echo "== the reader and what draws a page (mini-chrome's libs/pdf)"
survey $pdf
constructs $pdf
echo "== the browser's viewer over it (src/viewers), and the lines of its tab that name it"
survey $viewer
echo "  Browser_tab.ml: $(grep -ci 'pdf' $C/src/chrome/Browser_tab.ml) lines naming it"
echo "== modules named by the fonts and the reader that neither they nor ix have"
echo "  $(outside $fonts $pdf)"
echo "== the data in them: lines that are tables"
echo "  Glyph_names.ml $(grep -c '^ *"\|^ *([0-9"]' $C/libs/fonts/Glyph_names.ml), Standard_widths.ml $(grep -c '^ *[0-9"|\[]' $C/libs/fonts/Standard_widths.ml)"
echo "== mini-chrome's tests of them (lines), and its files"
wc -l $C/tests/pdf/*.ml | sed "s|$C/||; s/^/  /"
ls -l $C/tests/pdf/data/*.pdf | awk '{ printf "  %7d %s\n", $5, $9 }' | sed "s|$C/||"
D=$C/_build/default/tests/pdf/Dump.exe
if [ -x $D ]; then
  echo "== each file by mini-chrome's own build (OCaml native, this machine), 2 pixels a point as the browser's viewer: its pages, the first's pixels, the seconds to draw them all"
  for f in $C/tests/pdf/data/*.pdf $C/data/about/sample.pdf; do
    n=$($D info $f | head -1 | grep -o '[0-9]* page' | grep -o '[0-9]*')
    i=1; sum=0; size=""
    while [ $i -le ${n:-0} ]; do
      r=$($D render $f $i 2 /dev/null)
      [ -z "$size" ] && size=$(echo "$r" | sed 's/ in .*//')
      sum=$(echo "$sum + $(echo "$r" | sed 's/.* in //; s/ s//')" | bc); i=$((i + 1))
    done
    printf "  %-14s %3d page(s) %-12s %5.2f s\n" $(basename $f) ${n:-0} "$size" $sum
  done
else
  echo "== $D not built: no times"
fi
if [ -d $S/typesetting/page ]; then
  echo "== Plan 9's page (principia's typesetting/page), lines"
  wc -l $S/typesetting/page/*.c $S/typesetting/page/*.h 2>/dev/null | sed "s|$S/||; s/^/  /"
fi
echo "== what ix has for the other direction, a file written"
echo "  Zlib.deflate: $(grep -c '^val deflate' $T/lib_compression/Zlib.mli); Playground's forms: $(sed -n '/^and form/,/Group of/p' $T/lib_playground/Playground.ml | grep -o '^ *| *[A-Z][a-z]*' | tr -d '| ' | tr '\n' ' ')"
echo "  the office's Export today: $(grep -c 'Store.export' $T/apps/office/file_menu/File_menu.ml) call, of $(grep -c 'Saved.to_string' $T/apps/office/file_menu/File_menu.ml) Saved.to_string"
