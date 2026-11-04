#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze -caps on the 44 programs (sweep.sh's), each function
# reported once, sorted: caps_ix.txt. Its reports are known ones, read
# (analyzers/datalog/README.md); -check (make test's) fails on any other
# answer, a new report the first: new code that goes around a capability
# is said the day it comes. Compared without the line numbers (an edit
# above a function moves it). Half a minute.
# usage: analyzers/datalog/tests/caps_ix.sh out-file | -check
#   (dune build, ix built first: its generated parsers, in MK or _mk/7)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
export LC_ALL=C
export ANALYZE=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
out=$1; check=
if [ "$1" = -check ]; then check=1; out=$(mktemp); fi
W=$(mktemp -d); trap 'rm -rf $W' EXIT
FLAG=-caps analyzers/datalog/tests/sweep.sh $W/sweep 300 > $W/sweep.log 2>&1
# (a generated file by its place in _mk/7, wherever MK built it)
cat $W/sweep/*.out 2> /dev/null | grep -E ': (no capability|has <)' |
  sed "s|^${MK:-_mk/7}/|_mk/7/|" | sort -u > $out
if [ -z "$check" ]; then echo "$(wc -l < $out) functions: $out"; exit 0; fi
expected=analyzers/datalog/tests/caps_ix.txt
# (a program not read here, a unit of its not built in this ix, as make
# test's builds part of it: its lines left out, the recorded ones too)
skipped=$(grep 'NOT READ' $W/sweep.log | awk '{print $1}' | tr '\n' '|')
skipped=${skipped%|}
bare() {
  sed -E 's/^([^:]*):[0-9]+:/\1:/' $1 |
    if [ -n "$skipped" ]; then grep -vE "^(_mk/7/)?($skipped)/"; else cat; fi |
    sort
}
if cmp -s <(bare $out) <(bare $expected); then
  echo "ok the 44 programs: -caps as recorded ($(bare $out | wc -l) functions$([ -n "$skipped" ] && echo "; not read here: ${skipped//|/, }"))"
  rm -f $out
else
  echo "FAIL the 44 programs: -caps not as recorded (< recorded, > now;"
  echo "  a new line: give the function the capability; one gone: record)"
  diff <(bare $expected) <(bare $out) | head -10
  grep 'NOT READ' $W/sweep.log | head -3
  rm -f $out; exit 1
fi
