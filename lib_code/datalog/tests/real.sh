#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# table.sh on real programs of ix, the numbers in lib_code/README.md: ML,
# mini-datalog (with mini-prolog's two units and what they use of
# lib_core); C, Plan 9's rc, if a goken checkout is there. Minutes: by
# hand, not in make test.
# usage: lib_code/datalog/tests/real.sh [limit-seconds]   (dune build first)
# GOKEN: goken's checkout (~/goken); ANALYZE, DATALOG: if not dune's.
cd "$(dirname "$0")/../../.."
limit=${1:-120}
T=$PWD/lib_code/datalog/tests
ANALYZE=${ANALYZE:-$PWD/_build/default/analyzers/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
d=languages/datalog; p=languages/prolog
# (Parallel: dune's choice of a file by the compiler, not a unit's name)
cp lib_core/parallel/Parallel.mli $W/Parallel.mli
cp lib_core/parallel/host/single.ml.in $W/Parallel.ml
$ANALYZE -facts -L lib_core $p/Prolog.ml $p/Prolog_read.ml $W/Parallel.ml $d/Tuples.ml $d/Btree.ml $d/Relset.ml $d/Hash_index.ml $d/Tree_index.ml $d/Index.ml $d/Datalog.ml $d/Datalog_eval.ml $d/CLI.ml $d/Main.ml > $W/datalog.facts
echo "== mini-datalog: $(wc -l < $W/datalog.facts) facts"
$T/table.sh $limit $W/datalog.facts andersen insensitive call1 call1_heap1 call2_heap1 object1 object2_heap1 type2_heap1 hybrid selective
GOKEN=${GOKEN:-$HOME/goken}
if [ -d $GOKEN/rc ]; then
  F="builtins.c code.c env.c error.c exec.c executils.c fmt.c getflags_.c globals.c glob.c goken.c here.c input.c io.c lex.c main.c notify_full.c path.c pcmd.c pfnc.c processes.c rfork_fork.c simple.c status.c trap.c tree.c utils.c var.c words.c y.tab.c"
  I="-I $GOKEN/include/ALL -I $GOKEN/include/arch/arm64 -I $GOKEN/include"
  (cd $GOKEN/rc && $ANALYZE -facts $I $F) > $W/rc.facts
  echo "== rc: $(wc -l < $W/rc.facts) facts"
  $T/table.sh $limit $W/rc.facts andersen insensitive call1 call1_heap1 call2_heap1 object1 object2_heap1 type2_heap1 hybrid selective
fi
