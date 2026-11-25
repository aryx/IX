#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The examples of mini-analyze's man page (docs/man/1/analyze.md), run as
# the page writes them, against expected.out. The page shows calc.c,
# Log.ml, Main.ml and graph.dl whole and its reports cite their lines, so
# these files have no copyright header: a change to one is a change to
# the page. expected.out has each report in full, with its last line of
# counts, which the page leaves out, and its long lines uncut.
# usage: analyzers/examples/run.sh [-record]   (dune build first)
# ANALYZE, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../.."
IX=$PWD
ANALYZE=${ANALYZE:-$IX/_build/default/analyzers/Main.exe}
DATALOG=${DATALOG:-$IX/_build/default/languages/datalog/Main.exe}
case $ANALYZE in /*) ;; *) ANALYZE=$IX/$ANALYZE;; esac
case $DATALOG in /*) ;; *) DATALOG=$IX/$DATALOG;; esac
E=$IX/analyzers/examples
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# The commands write calc.dl and flow.dl where they run, as on the page,
# so they run in a copy of this directory; those on Main.exe, the program
# by its build (dune's, this directory's dune), in ix's root.
cp $E/calc.c $E/Log.ml $E/Main.ml $E/graph.dl $W
cd $W
mini-analyze() { "$ANALYZE" "$@"; }
mini-datalog() { "$DATALOG" "$@"; }
# Each command is printed as the page writes it, $IX unexpanded, then run.
t() { echo "% $1"; eval "$1" 2>&1; }
{
  t 'mini-analyze calc.c'
  t 'mini-analyze -dead calc.c'
  cd $IX
  t 'mini-analyze analyzers/examples/Main.exe'
  t 'mini-analyze -dead analyzers/examples/Main.exe'
  t 'mini-analyze -caps analyzers/examples/Main.exe'
  t 'mini-analyze -exn analyzers/examples/Main.exe'
  cd $W
  t 'mini-analyze Log.ml Main.ml'
  t 'mini-analyze -dead Log.ml Main.ml'
  t 'mini-analyze -facts calc.c > calc.dl'
  t 'P=$IX/analyzers/datalog/points_to'
  t 'mini-datalog -q '\''reaches(main, F)'\'' $P/instructions.dl $P/contexts.dl $P/insensitive.dl calc.dl graph.dl 2> /dev/null'
  t 'mini-analyze -flow calc.c > flow.dl'
  t 'mini-datalog -q '\''across_call(V, P)'\'' $IX/analyzers/datalog/liveness.dl flow.dl'
} > $W/run.out
if [ "${1:-}" = -record ]; then cp $W/run.out $E/expected.out; echo "recorded analyzers/examples/expected.out"; exit 0
elif cmp -s $W/run.out $E/expected.out; then echo "ok mini-analyze: the man page's examples"; exit 0
else echo "FAIL mini-analyze: the man page's examples"; diff $E/expected.out $W/run.out | head -20; exit 1; fi
