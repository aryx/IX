#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_emacs.md: efuns' files (the
# author's Emacs in OCaml, ~/efuns), their lines, the constructs
# mini-ml has not, counted, the modules they name that are not efuns'
# own; and the playground's highlighters. (Not mini-ml's refusal of
# each file, as the other surveys: efuns stands on semgrep's Common,
# which ix has not, and every file is refused at its first line.) As apps/survey.sh
# and apps/office/survey.sh.
# usage: editors/emacs/survey.sh [efuns [playground]]
#   (default: ~/efuns, ~/playground)

cd "$(dirname "$0")"
E=${1:-$HOME/efuns}
P=${2:-$HOME/playground}
T=../..
[ -d $E/src/core ] || { echo "no $E/src/core"; exit 1; }

dirs="libs/commons src/graphics src/core src/features src/main src/ipc modes/major_modes modes/minor_modes modes/prog_modes modes/text_modes"
# a directory's files: lines (.ml or .mll, .mli), and whether the file
# has the first author's notice (Fabrice Le Fessant's, INRIA's)
survey() {
  local d=$1 ml=0 mli=0 n i f
  for f in $E/$d/*.ml $E/$d/*.mll; do
    [ -f $f ] || continue
    n=$(cat $f | wc -l); i=0; [ -f ${f%.*}.mli ] && i=$(cat ${f%.*}.mli | wc -l)
    ml=$((ml + n)); mli=$((mli + i))
    printf "  %5d %5d %-40s %s\n" $n $i ${f#$E/} "$(grep -q 'Fabrice\|INRIA' $f && echo INRIA)"
  done
  printf "  %5d %5d all of %s (%d files)\n" $ml $mli $d $(ls $E/$d/*.ml $E/$d/*.mll 2>/dev/null | wc -l)
}
for d in $dirs; do echo "== $d"; survey $d; done
echo "== the graphics backends (src/graphics/*/)"
wc -l $E/src/graphics/*/*.ml $E/src/graphics/libdraw/draw.c | sed "s|$E/||; s/^/  /"

all=$(for d in $dirs; do ls $E/$d/*.ml $E/$d/*.mll 2>/dev/null; done)
echo "== the constructs mini-ml has not, in those $(echo $all | wc -w) files"
printf "  [@@interactive]: %d; [@@deriving]: %d; [@@profiling]: %d; optional arguments: %d definitions; labels (~x): %d lines\n" \
  $(cat $all | grep -c '\[@@interactive') $(cat $all | grep -c '\[@@deriving') $(cat $all | grep -c '\[@@profiling') $(cat $all | grep -c '^ *let.*[ (]?[(a-z]') $(cat $all | grep -c ' ~[a-z_]*[: ]')
printf "  Obj.magic: %d; Str.: %d lines; Hashtbl: %d lines; Thread/Mutex/Condition/Concur: %d lines; Unix.: %d lines; exception definitions: %d; functors (.Make): %d; let open: %d; objects (object/method): %d; polymorphic variants: %d\n" \
  $(cat $all | grep -c 'Obj\.magic') $(cat $all | grep -c 'Str\.') $(cat $all | grep -c 'Hashtbl\.') $(cat $all | grep -c 'Thread\.\|Mutex\.\|Condition\.\|Concur\.') $(cat $all | grep -c 'Unix\.') $(cat $all | grep -c '^exception ') $(cat $all | grep -c '\.Make') $(cat $all | grep -c 'let open') $(cat $all | grep -c '^ *method \|\bobject\b') $(cat $all | grep -c '`[A-Z]')
echo "== the modules they name that are not efuns' own, and how often"
own=$(for f in $all $E/src/graphics/*/*.ml; do basename ${f%.*} | sed 's/^./\U&/'; done | sort -u)
cat $all | grep -o '\b[A-Z][A-Za-z0-9_]*\.[a-z_]' | sed 's/\..$//' | sort | uniq -c | sort -rn | while read n m; do echo "$own" | grep -qx "$m" || printf "%s(%s) " $m $n; done | fold -s -w 100 | sed 's/^/  /'; echo
echo "== the playground's highlighters, and its Emacs (lines)"
wc -l $P/libs/code/highlight/Highlight_code.ml $P/libs/code/highlight/Highlight_code.mli $P/languages/*/Highlight_*.ml $P/appkits/editor/Emacs_*.ml $P/appkits/editor/Tui_emacs.ml $P/apps/devtools/TinyEmacs.ml | sed "s|$P/||; s/^/  /"
echo "== what ix has already"
echo "  a screen of cells and its hosts: $(ls $T/lib_terminal/Curses.ml $T/lib_terminal/Tui.ml $T/lib_terminal/unix/*.ml $T/editors/turbopascal/hosts/*.ml $T/editors/turbopascal/hosts/*/Window.ml 2>/dev/null | sed "s|$T/||" | tr '\n' ' ')"
echo "  regular expressions: $(ls $T/lib_core/commons/Regex.ml | sed "s|$T/||") ($(cat $T/lib_core/commons/Regex.ml | wc -l) lines)"
