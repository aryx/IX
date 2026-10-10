#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What a program of ix never calls (docs/plans/plan_prolog.md, stage
# 10): mini-ml -facts on each .ml of the program's directories and of
# lib_core (the stdlib's units and commons/), all the facts together,
# then mini-datalog with languages/datalog/analyses/pointer.dl (the
# author's rules, unchanged) and calls.dl. Printed: the numbers
# (units, functions written, calls, the calls' targets found, the
# seconds), then each function of the program's own directories that
# no call reaches from a unit's toplevel, with its line. lib_core's
# own unreached ones are counted only: a program uses a part of it.
# -holes: also the calls in code that runs which reach nothing.
# usage: languages/ml/facts/tests/program.sh [-holes] dir|file.ml...   (dune build first: bin/mini-yacc, mini-lex)
# ML, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../../../.."
export LC_ALL=C
A=languages/datalog/analyses
ML=${ML:-_build/default/languages/ml/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
holes=; [ "${1:-}" = -holes ] && { holes=1; shift; }
[ $# = 0 ] && { echo "usage: program.sh [-holes] dir..."; exit 2; }
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# (an argument is a directory, or one .ml of another program's: mini-datalog's Prolog_read)
files() { for a in "$@"; do if [ -d $a ]; then find $a -name '*.ml' -not -path '*/tests/*' -not -path '*/runtime/*'; else echo $a; fi; done | sort; }
dirs() { for d in $(files "$@" | xargs -n1 dirname | sort -u); do echo -n "-I $d "; done; }
std=$(for u in $(grep -v '^#' lib_core/units.txt); do echo "-I lib_core/$(dirname $u)"; done | sort -u | tr '\n' ' ')
incs="-I $W/gen $(dirs "$@") $std -I lib_core/commons $(dirs lib_code)"
own=$(files "$@")
lib="$(for u in $(grep -v '^#' lib_core/units.txt); do echo lib_core/$u.ml; done) $(ls lib_core/commons/*.ml)"
t0=$(date +%s.%N)
mkdir $W/own $W/lib
# a grammar's and a lexer's units: made here by mini-yacc and mini-lex,
# as ix's mkfiles do (mini-ml does not take ocamlyacc's parser)
mkdir $W/gen
for g in $(for a in "$@"; do [ -d $a ] && find $a -maxdepth 1 -name '*.mly' -o -maxdepth 1 -name '*.mll'; done); do
  case $g in
    *.mly) bin/mini-yacc -b $W/gen/$(basename $g .mly) $g > /dev/null 2>&1;;
    *.mll) bin/mini-lex -o $W/gen/$(basename $g .mll).ml $g > /dev/null 2>&1;;
  esac
done
for f in $lib; do $ML -m 7 -facts $incs $f > $W/lib/$(basename $f .ml).dl 2> /dev/null || rm $W/lib/$(basename $f .ml).dl; done
for f in $own; do
  # (a Lexer, a Parser: dune's, made of the .mll and the .mly)
  $ML -m 7 -facts $incs $f > $W/own/$(basename $f .ml).dl 2> $W/err || { echo "not compiled: $f: $(head -1 $W/err | cut -c1-90)"; rm $W/own/$(basename $f .ml).dl; }
done
for f in $(ls $W/gen/*.ml 2> /dev/null); do
  $ML -m 7 -facts -I $W/gen $incs $f > $W/own/$(basename $f .ml).dl 2> $W/err || { echo "not compiled: $(basename $f): $(head -1 $W/err | cut -c1-90)"; rm $W/own/$(basename $f .ml).dl; }
done
t1=$(date +%s.%N)
# (the rules' own question, every point_to, is not asked)
grep -v '^point_to(A,B)?' $A/pointer.dl > $W/rules.dl
cat $W/lib/*.dl $W/own/*.dl > $W/all.dl
$DATALOG -s -q 'unreached(F)' -q 'hole(I, F)' $W/rules.dl $A/calls.dl $W/all.dl > $W/out 2> $W/stats
t2=$(date +%s.%N)
count() { sed -n "s|^$1 *\([0-9]*\) tuples.*|\1|p" $W/stats; }
units=$(ls $W/own | sed 's/\.dl$//' | tr '\n' '|' | sed 's/|$//')
mine() { grep -E "^$1\('($units)[.:]" $W/out; }
printf "%s: %d units and %d of lib_core, %d functions written, %d facts\n" "$*" $(ls $W/own | wc -l) $(ls $W/lib | wc -l) $(grep -c '^closure' $W/all.dl) $(wc -l < $W/all.dl)
printf "%d calls, %d targets found (call_edge), %d point_to; mini-ml %.1f s, mini-datalog %.1f s\n" $(grep -c '^call_indirect' $W/all.dl) $(count call_edge/2) $(count point_to/2) $(echo "$t1 - $t0" | bc) $(echo "$t2 - $t1" | bc)
printf "unreached: %d of the program's own functions, %d of lib_core's; calls that reach nothing in code that runs: %d\n" $(mine unreached | wc -l) $(($(grep -c '^unreached' $W/out) - $(mine unreached | wc -l))) $(grep -c '^hole' $W/out)
# each with its line: closure(F, Unit, Line)
mine unreached | sed -E "s/^unreached\((.*)\)\.$/\1/" | while IFS= read -r f; do
  grep -F "closure($f, " $W/all.dl | sed -E "s/^closure\('(.*)', '([^']*)', '([0-9]+)'\)\.$/  \2.ml:\3: \1/; s/\\\\'/'/g"
done | sort -t: -k1,1 -k2,2n
[ -n "$holes" ] && grep '^hole' $W/out
exit 0
