#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# sweep.sh's reports of the programs read whole, each dead toplevel function
# checked by another way: is its name, Unit.name or in its own file, written
# anywhere else in the tree? None: dead in all of ix, whatever the program.
# Some: dead in this program, used by another that shares the unit, or by
# its tests, or a false report: to be read.
# Written to out-dir/TRIAGE and SAME_PROGRAM; printed: SAME_PROGRAM's lines,
# the unused, the others. tests/dead_ix.txt is its UNUSED lines.
# usage: analyzers/datalog/tests/triage.sh out-dir
cd "$(dirname "$0")/../../.."
out=$1
for o in $out/*.out; do
  [ -s ${o%.out}.err ] || grep -E ': dead: [A-Z][A-Za-z_0-9]*\.[a-z_0-9]+,' $o
done | sort -u > $out/.dead
while IFS= read -r line; do
  file=${line%%:*}
  full=$(echo "$line" | sed -E 's/.*: dead: ([^,]*),.*/\1/')
  unit=${full%%.*}; fn=${full#*.}
  # (Unit.fn elsewhere, or by an alias, module W = Unit's W.fn; an open
  # Unit's fn not counted; fn in its own file, past its definition)
  names=$(git grep -hoE "module [A-Z][A-Za-z_0-9]* = $unit\b" -- '*.ml' | sed -E 's/module ([^ ]*) .*/\1/' | sort -u | tr '\n' '|')
  others=$(git grep -lwE "(${names}$unit)\.$fn" -- '*.ml' '*.mll' '*.mly' | grep -v "^$file$" | wc -l)
  own=$(grep -cwE "$fn" "$file" 2> /dev/null)
  # (a printer of [@@deriving show], written by mlpp or ppx_deriving, not by hand)
  if [[ $fn =~ ^(pp|show)_ ]] && grep -q '\[@@deriving' "$file" 2> /dev/null; then echo "DERIVED $line"
  elif [ "$others" = 0 ] && [ "${own:-0}" -le 1 ]; then echo "UNUSED $line"
  else echo "used($others,$own) $line"; fi
done < $out/.dead | sort > $out/TRIAGE
# named by another file of the same program, though reported dead there: a
# false report, unless what names it is itself dead (named_in_dead says so)
for o in $out/*.out; do
  [ -s ${o%.out}.err ] && continue
  files=$(cat ${o%.out}.files)
  grep -E ': dead: [A-Z][A-Za-z_0-9]*\.[a-z_0-9]+, nothing names it' $o | while IFS= read -r line; do
    full=$(echo "$line" | sed -E 's/.*: dead: ([^,]*),.*/\1/')
    hit=$(grep -lwE "${full//./\\.}" $files 2> /dev/null | head -3 | tr '\n' ' ')
    [ -n "$hit" ] && echo "$(basename $o .out): $full named in $hit"
  done
done > $out/SAME_PROGRAM
wc -l < $out/SAME_PROGRAM
grep -c '^UNUSED' $out/TRIAGE
grep -c '^used' $out/TRIAGE
