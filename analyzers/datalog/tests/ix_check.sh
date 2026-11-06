#!/usr/bin/env bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze FLAG on the 44 programs (sweep.sh's), each report once,
# sorted, recorded: -caps caps_ix.txt, -bugs bugs_ix.txt (and the
# kernel's, kernel.sh's, its paths the tree's), -dead dead_all_ix.txt
# (what is dead in every program that has the file: a function of a
# shared unit unused by one program is not dead in ix; triage.sh's
# dead_ix.txt is another list, to read), -exn exn_ix.txt (a program's
# toplevel exceptions, but lib_core's every program may raise). The
# reports are known ones,
# read (analyzers/datalog/README.md); -check (make test's) fails on any
# other answer, a new report the first: new code that goes around a
# capability, or dead, or a bug the rules know, is said the day it
# comes. Compared without line numbers, the reports' own too (an edit above
# a function moves it). Under a minute each.
# usage: analyzers/datalog/tests/ix_check.sh -caps|-dead|-bugs|-exn out-file|-check
#   (dune build, ix built first: its generated parsers, in MK or _mk/7)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
export LC_ALL=C
export ANALYZE=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
# (no analyzer, being rebuilt say: every program would say nothing)
[ -x "${ANALYZE%% *}" ] || { echo "no analyzer: $ANALYZE"; exit 2; }
flag=$1; out=$2; check=
case $flag in
  -caps) expected=caps_ix.txt;; -bugs) expected=bugs_ix.txt;;
  -dead) expected=dead_all_ix.txt;; -exn) expected=exn_ix.txt;;
  *) echo "usage: ix_check.sh -caps|-dead|-bugs|-exn out-file|-check"; exit 2;;
esac
expected=analyzers/datalog/tests/$expected
if [ "$out" = -check ]; then check=1; out=$(mktemp); fi
W=$(mktemp -d); trap 'rm -rf $W' EXIT
FLAG=$flag analyzers/datalog/tests/sweep.sh $W/sweep 300 > $W/sweep.log 2>&1
. analyzers/datalog/tests/compare.sh
notes=$(notes_of $expected)
# (a generated file by its place in _mk/7, wherever MK built it)
gen() { sed "s|^${MK:-_mk/7}/|_mk/7/|"; }
case $flag in
  -caps) cat $W/sweep/*.out 2> /dev/null | grep -E ': (no capability|has <|names .* itself)' |
           gen | sort -u > $out;;
  -bugs)
    analyzers/datalog/tests/kernel.sh -bugs $W/kernel.out
    { cat $W/sweep/*.out; } 2> /dev/null | grep '^bug? ' | sed 's/^bug? //' |
      gen > $W/all
    # (the kernel's paths are kernels/9pi's: the tree's)
    grep '^bug? ' $W/kernel.out | sed 's/^bug? //' |
      sed -E -e 's|^\.\./\.\./||' -e t -e 's|^|kernels/9pi/|' >> $W/all
    sort -u $W/all > $out;;
  -exn)
    # (a program's name first: many have a Main.ml)
    for f in $W/sweep/*.out; do
      n=$(basename $f .out); exn_lines < $f | gen | sed "s|^|$n: |"
    done | sort -u > $out;;
  -dead)
    # a report a program, by its file; the files a program has: sweep.sh's
    # name.files; kept where every program that has the file says it
    for f in $W/sweep/*.out; do
      n=$(basename $f .out)
      grep -E ': dead( [a-z]+)?:' $f | gen | sed "s|^|$n\t|"
    done > $W/said
    for f in $W/sweep/*.files; do
      n=$(basename $f .files); tr ' ' '\n' < $f | grep . | sed "s|^|$n\t|"
    done > $W/has
    awk -F'\t' 'NR == FNR { has[$2]++; next }
      { split($2, p, ":"); key = $2; sub(/:[0-9]+:/, ":", key)
        said[key]++; line[key] = $2; file[key] = p[1] }
      END { for (k in said) if (said[k] >= has[file[k]]) print line[k] }' \
      $W/has $W/said | sort -u > $out;;
esac
if [ -z "$check" ]; then
  keep_notes "$notes" $out; echo "$(grep -vc '^#' $out) reports: $out"; exit 0
fi
# (a program not read here, a unit of its not built in this ix, as make
# test's builds part of it: its lines left out, the recorded ones too)
# (its files: a report in one, or dead there for every program, cannot be
# known here; its generated ones by their place in _mk/7)
skipped=$(grep 'NOT READ' $W/sweep.log | awk '{print $1}' | tr '\n' ' ')
# (-exn's lines are a program's: its name)
for d in $skipped; do
  cat $W/sweep/$(echo $d | tr / _).files 2> /dev/null | tr ' ' '\n'
  echo $d | tr / _
done | grep . | gen | sort -u > $W/unknown
# (and a generated file this ix did not make: no build, CI's fresh tree)
for g in $(grep -ho '^_mk/7/[^:]*' $expected $out | sort -u); do
  [ -f "${MK:-_mk/7}/${g#_mk/7/}" ] || echo $g
done >> $W/unknown
compare "mini-analyze $flag on the 44 programs" $out $expected $W/unknown
st=$?
[ -n "$skipped" ] && echo "  (not read here: $(echo $skipped | sed 's/ /, /g'))"
rm -f $out; exit $st
