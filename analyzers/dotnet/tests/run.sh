#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze's two roads (plan_dotnet_languages.md, stage 8; the
# author: "It's good to have the 2 code paths working for a teaching and
# comparison purpose"), their answers compared: native, mini-analyze
# -facts's text read by mini-datalog's evaluator; .NET, one process,
# mini-cc's front end compiled by mini-ml -dotnet giving its facts as
# values to the rules mini-datalog -dotnet compiled (analyze_rt.dll,
# Analyze_rt). call1_heap1's target and pts on
# lib_code/datalog/tests/contexts.c, by mini-dotnet (Microsoft's dotnet
# too with -ms); -rc: on Plan 9's rc (goken's 30 files: minutes),
# timed, by Microsoft's dotnet.
# usage: analyzers/dotnet/tests/run.sh [-ms] [-rc]   (dune build, and
#   mini-mk in languages/c for its parser and lexer, first)
# DUNEML, DUNEDATALOG, DUNEDOTNET, DUNEANALYZE: if not _build's.
cd "$(dirname "$0")/../../.."
ms=; rc=
for a in "$@"; do case $a in -ms) ms=1;; -rc) rc=1;; esac; done
B=_build/default
ML=${DUNEML:-$B/languages/ml/Main.exe}
DL=${DUNEDATALOG:-$B/languages/datalog/Main.exe}
DN=${DUNEDOTNET:-$B/languages/dotnet/Main.exe}
AN=$(realpath ${DUNEANALYZE:-$B/analyzers/Main.exe})
P=_mk/7/languages/c
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
[ -f $P/Parser.ml ] || { echo "skipped: $P/Parser.ml not built (mini-mk in languages/c)"; exit 0; }

# analyze_rt.dll: mini-cc's front end (its mkfile's order), Facts,
# C_front, mini-datalog's relations, Datalog_rt, Analyze_rt
cp lib_core/parallel/Parallel.mli $W/
cp lib_core/parallel/host/single.ml.in $W/Parallel.ml
files=
for u in Asm Show_asm Tree Tree_helpers Pre Acid Check Declare Machines Emit Com64 Parser Lexer Facts C_front \
         Prolog Prolog_read Parallel Tuples Btree Relset Hash_index Tree_index Index Datalog Datalog_eval Datalog_rt Analyze_rt; do
  for f in languages/c/$u.ml languages/c/*/$u.ml assembler/$u.ml analyzers/c/$u.ml analyzers/dotnet/$u.ml languages/prolog/$u.ml \
           languages/datalog/$u.ml languages/datalog/dotnet/$u.ml $W/$u.ml $P/$u.ml; do [ -f $f ] && break; done
  files="$files $f"
done
if ! $ML -L lib_core -I languages/c -I $P -I languages/c/debug -I languages/c/facts -I assembler -I analyzers/c \
     -I analyzers/dotnet -I languages/prolog -I languages/datalog -I languages/datalog/dotnet -I $W \
     -dotnet -o $W/analyze_rt.dll $files > $W/rt.err 2>&1; then
  echo "FAIL analyze_rt.dll by mini-ml -dotnet"; head -3 $W/rt.err; exit 1
fi
R=lib_code/datalog/points_to
RULES="$R/instructions.dl $R/andersen.dl $R/contexts.dl $R/call1_heap1.dl"
Q=(-q 'target(I, F)' -q 'pts(V, H)')
$DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/pta.dll "${Q[@]}" $RULES || { echo "FAIL mini-datalog -dotnet"; exit 1; }

# a program: the native road's answers, the .NET road's by each runtime
roads() { # name, the directory, the files and -I's
  local name=$1 dir=$2; shift 2
  local args=("$@") t0=$(date +%s%N)
  (cd $dir && $AN -facts "$@") > $W/$name.facts
  $DL "${Q[@]}" $RULES $W/$name.facts > $W/$name.want 2> /dev/null
  local native=$(( ($(date +%s%N) - t0) / 1000000 ))
  run() { # what, runtime
    local t0=$(date +%s%N)
    (cd $dir && $2 $W/pta.dll "${args[@]}") > $W/$name.got 2>&1
    local ms=$(( ($(date +%s%N) - t0) / 1000000 ))
    if [ -s $W/$name.want ] && cmp -s $W/$name.want $W/$name.got; then
      echo "ok mini-analyze's two roads on $name: $(wc -l < $W/$name.want) answers the same (native $native ms, .NET by $1 $ms ms)"
    else fail "mini-analyze's .NET road on $name, by $1"; diff $W/$name.want $W/$name.got | head -5; fi
  }
  [ -z "${ms_only:-}" ] && run mini-dotnet "$(realpath $DN)"
  [ -n "$ms" ] && run "Microsoft's dotnet" dotnet
}
roads contexts lib_code/datalog/tests contexts.c
if [ -n "$rc" ]; then
  G=${GOKEN:-$HOME/goken}
  F="builtins.c code.c env.c error.c exec.c executils.c fmt.c getflags_.c globals.c glob.c goken.c here.c input.c io.c lex.c main.c notify_full.c path.c pcmd.c pfnc.c processes.c rfork_fork.c simple.c status.c trap.c tree.c utils.c var.c words.c y.tab.c"
  ms=1 ms_only=1 roads rc $G/rc -I$G/include/ALL -I$G/include/arch/arm64 -I$G/include $F
fi
echo "$failures failure(s)"
[ $failures = 0 ]
