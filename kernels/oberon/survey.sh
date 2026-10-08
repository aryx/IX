#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/done/plan_system_oberon.md: Project Oberon
# 2013's modules (N. Wirth and J. Gutknecht; the sources as ETH serves
# them), their lines, what each exports, the messages its frames
# answer, and what of ix a mini-oberon would link to.
# usage: kernels/oberon/survey.sh [dir]
#   dir: where the sources are kept (fetched there when missing;
#   default: $TMPDIR/project-oberon)

cd "$(dirname "$0")"
PO=${1:-${TMPDIR:-/tmp}/project-oberon}
URL=https://people.inf.ethz.ch/wirth/ProjectOberon/Sources
INNER="Kernel FileDir Files Modules"
OUTER="Input Display Viewers Fonts Texts Oberon MenuViewers TextFrames System Edit"
COMPILER="ORS ORB ORG ORP ORTool"
GRAPHICS="Graphics GraphicFrames Draw GraphTool Rectangles Curves MacroTool"
DEMOS="Blink Stars Checkers Sierpinski Hilbert"
OTHERS="Net SCC RS232 PCLink1 Tools EBNF RISC ORC BootLoad"
mkdir -p $PO
for m in $INNER $OUTER $COMPILER $GRAPHICS $DEMOS $OTHERS; do
  [ -s $PO/$m.Mod ] || curl -s -f -m 30 -o $PO/$m.Mod $URL/$m.Mod.txt || echo "missing: $m"
done

group() {
  name=$1; shift; total=0; line=""
  for m in "$@"; do n=$(wc -l < $PO/$m.Mod); total=$((total + n)); line="$line $m $n"; done
  printf "%6d %s:%s\n" $total "$name" "$line"
}
echo "== Project Oberon 2013 (lines)"
group "inner core" $INNER
group "outer core" $OUTER
group "the compiler" $COMPILER
group "graphics" $GRAPHICS
group "small programs" $DEMOS
group "others" $OTHERS
echo "== exported procedures (PROCEDURE name*)"
for m in $INNER $OUTER; do printf "%s %s  " $m $(grep -c 'PROCEDURE [A-Za-z]*\*' $PO/$m.Mod); done; echo
echo "== the commands (exported, no parameter) of System and Edit"
for m in System Edit; do echo "  $m: $(grep -o 'PROCEDURE [A-Za-z]*\*;' $PO/$m.Mod | sed 's/PROCEDURE //; s/\*;//' | tr '\n' ' ')"; done
echo "== the messages (extensions of Display.FrameMsg), the frames (of Display.FrameDesc, Viewers.ViewerDesc)"
(cd $PO && grep -o '[A-Za-z]* *\*\? *= *RECORD *([A-Za-z.]*\(FrameMsg\|FrameDesc\|ViewerDesc\))' *.Mod | sed 's/\.Mod:/./; s/ *\*\? *= *RECORD */ /' | sed 's/^/  /')
echo "== SYSTEM's uses (the machine under the language)"
for m in $INNER $OUTER; do printf "%s %s  " $m $(grep -o 'SYSTEM\.[A-Z]*' $PO/$m.Mod | wc -l); done; echo
echo "== Display's operations and modes"
grep -o 'PROCEDURE [A-Za-z]*\*([^)]*)' $PO/Display.Mod | sed 's/PROCEDURE /  /'
grep 'replace\* = \|base = ' $PO/Display.Mod | sed 's/^ */  /'
echo "== ix: what a mini-oberon would link to (lines, .ml and .mli)"
G=../9pi/lib_graphics/ocaml
for f in ../lib_machine/Machine ../lib_machine/Screen $G/Memchan $G/Memimage $G/Memdraw $G/Memfont ../9pi/devices/keyboard/Kbd ../xv6/Fs; do
  printf "%6d %s\n" $(cat $f.ml $f.mli | wc -l) $f
done
wc -l ../lib_machine/runtime.c ../lib_machine/usb.c ../lib_machine/machine.c ../lib_machine/pi1/machine.c ../lib_machine/pi1/l.s ../lib_machine/pi4/machine.c ../lib_machine/pi4/l.s | sed '$d'
echo "== ix: Memdraw's operators (Porter-Duff's; no xor), mini-ml's open types"
grep -o 'o_[a-z]* = [0-9]*' $G/Memdraw.ml | tr '\n' ' '; echo
echo "  'type t = ..' in mini-ml's grammar: $(grep -c 'EQUAL DOTDOT\|PLUSEQ' ../../languages/ml/Parser.mly) rule"
