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
# timed, by Microsoft's dotnet. Then mini-analyze's reports, of the
# rules it loads (C's: call1_heap1 and bugs/pointers.dl; ML's: calls.dl): the
# .NET program's (no query) the native mini-analyze's, on
# analyzers/tests' bugs, callbacks and handlers (ML), dead/ (-dead),
# caps/ (-caps) and exn/ (-exn). And a C module (stage 8's):
# -fingerprint's number of the answers by fingerprint.c, compiled by
# mini-cc -dotnet and called from ML on .NET (dotnet/Fingerprint.ml's
# externals), by Fingerprint.ml natively: the same.
# usage: analyzers/dotnet/tests/run.sh [-ms] [-rc] [-build]   (dune build,
#   and mini-mk in languages/c for its parser and lexer, first)
# -build: no test, the C report's assemblies made in WORK (analyze_rt.dll,
#   fingerprint.dll, report.dll): mini-9pi's card's (its make card)
# DUNEML, DUNEDATALOG, DUNEDOTNET, DUNEANALYZE: if not _build's.
cd "$(dirname "$0")/../../.."
ms=; rc=; build=
for a in "$@"; do case $a in -ms) ms=1;; -rc) rc=1;; -build) build=1;; esac; done
B=_build/default
ML=${DUNEML:-$B/languages/ml/Main.exe}
DL=${DUNEDATALOG:-$B/languages/datalog/Main.exe}
DN=${DUNEDOTNET:-$B/languages/dotnet/Main.exe}
AN=$(realpath ${DUNEANALYZE:-$B/analyzers/Main.exe})
CC=${DUNECC:-$B/languages/c/Main.exe}
P=_mk/7/languages/c
# (WORK=dir: the assemblies made kept there)
W=${WORK:-$(mktemp -d)}; [ -n "${WORK:-}" ] || trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }
[ -f $P/Parser.ml ] || { echo "skipped: $P/Parser.ml not built (mini-mk in languages/c)"; exit 0; }

# analyze_rt.dll: mini-cc's front end (its mkfile's order), Facts,
# C_front; mini-ml's front end (Ast to Typing, mlpp's Pp), Closure_facts,
# Ml_front; mini-datalog's relations, Datalog_rt, Analyze_rt. The two
# front ends each have a Parser and a Lexer, mini-ml one namespace of
# units: mini-cc's copied with theirs renamed C_parser and C_lexer, and
# what names them (dune's wrapped copy of them, analyzers/c, by hand)
M=_mk/7/languages/ml
[ -f $M/Parser.ml ] || { echo "skipped: $M/Parser.ml not built (mini-mk in languages/ml)"; exit 0; }
mkdir -p $W/c
cp lib_core/parallel/Parallel.mli $W/
cp lib_core/parallel/host/single.ml.in $W/Parallel.ml
rename() { case $1 in Parser) echo C_parser;; Lexer) echo C_lexer;; *) echo $1;; esac; }
files=
for u in Asm Show_asm; do files="$files assembler/$u.ml"; done
for u in Tree Tree_helpers Pre Acid Check Declare Machines Emit Com64 Parser Lexer Facts C_front; do
  for f in languages/c/$u.ml languages/c/*/$u.ml analyzers/c/$u.ml $P/$u.ml; do [ -f $f ] && break; done
  for x in ml mli; do
    for g in ${f%.ml}.$x languages/c/$u.$x $P/$u.$x; do
      [ -f $g ] && { sed -E 's/\bParser\b/C_parser/g; s/\bLexer\b/C_lexer/g' $g > $W/c/$(rename $u).$x; break; }
    done
  done
  files="$files $W/c/$(rename $u).ml"
done
for u in Ast Annotations Parser Lexer Scope Resolve Typing Bits Derive Pp Closure_facts Ml_front \
         Prolog Prolog_read Parallel Tuples Btree Relset Hash_index Tree_index Index Datalog Datalog_eval Datalog_rt C_report Ml_report Fingerprint Answers Dead_report Caps_report Exn_report Bugs_report Analyze_rt; do
  for f in analyzers/dotnet/$u.ml languages/ml/$u.ml languages/ml/*/$u.ml $M/$u.ml analyzers/$u.ml analyzers/ml/$u.ml analyzers/report/$u.ml languages/prolog/$u.ml \
           languages/datalog/$u.ml languages/datalog/dotnet/$u.ml $W/$u.ml; do [ -f $f ] && break; done
  files="$files $f"
done
if ! $ML -L lib_core -I $W/c -I assembler -I languages/ml -I languages/ml/pp -I $M -I analyzers -I analyzers/ml -I analyzers/report \
     -I analyzers/dotnet -I languages/prolog -I languages/datalog -I languages/datalog/dotnet -I $W \
     -dotnet -o $W/analyze_rt.dll $files > $W/rt.err 2>&1; then
  echo "FAIL analyze_rt.dll by mini-ml -dotnet"; head -3 $W/rt.err; exit 1
fi
# the C module: fingerprint.c by mini-cc -dotnet, beside the program;
# the .NET road's Fingerprint (dotnet/Fingerprint.ml) calls it
if ! $CC -dotnet -L languages/c/dotnet -o $W/fingerprint.dll analyzers/dotnet/fingerprint.c > $W/fp.err 2>&1; then
  echo "FAIL fingerprint.dll by mini-cc -dotnet"; head -3 $W/fp.err; exit 1
fi
R=lib_code/datalog/points_to
if [ -n "$build" ]; then
  $DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/report.dll \
    $R/instructions.dl $R/andersen.dl $R/contexts.dl $R/call1_heap1.dl lib_code/datalog/bugs/pointers.dl ||
    { echo "FAIL mini-datalog -dotnet, the C report's program"; exit 1; }
  exit 0
fi
Q=(-q 'target(I, F)' -q 'pts(V, H)')
QML=(-q 'pts(V, H)' -q 'reach(F)')
# (C's analysis: call1_heap1; ML's: call1, as lib_code/datalog/tests')
C_RULES="$R/instructions.dl $R/andersen.dl $R/contexts.dl $R/call1_heap1.dl"
ML_RULES="$R/instructions.dl $R/andersen.dl $R/contexts.dl $R/call1.dl"
$DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/pta.dll "${Q[@]}" $C_RULES &&
  $DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/pta_ml.dll "${QML[@]}" $ML_RULES ||
  { echo "FAIL mini-datalog -dotnet"; exit 1; }

# a program: the native road's answers, the .NET road's by each runtime
roads() { # name, the compiled program (pta or pta_ml), the directory, the files and -I's
  local name=$1 prog=$2 dir=$3; shift 3
  [ -n "${ms_only:-}" ] && [ -z "$ms" ] && { echo "skipped: $name (Microsoft's dotnet only: -ms)"; return; }
  local args=("$@") t0=$(date +%s%N) rules=$C_RULES q=("${Q[@]}")
  [ $prog = pta_ml ] && { rules=$ML_RULES; q=("${QML[@]}"); }
  (cd $dir && $AN -facts "$@") > $W/$name.facts 2> /dev/null
  $DL "${q[@]}" $rules $W/$name.facts > $W/$name.want 2> /dev/null
  local native=$(( ($(date +%s%N) - t0) / 1000000 ))
  run() { # what, runtime
    local t0=$(date +%s%N)
    (cd $dir && $2 $W/$prog.dll "${args[@]}") > $W/$name.got 2>&1
    local ms=$(( ($(date +%s%N) - t0) / 1000000 ))
    if [ -s $W/$name.want ] && cmp -s $W/$name.want $W/$name.got; then
      echo "ok mini-analyze's two roads on $name: $(wc -l < $W/$name.want) answers the same (native $native ms, .NET by $1 $ms ms)"
    else fail "mini-analyze's .NET road on $name, by $1"; diff $W/$name.want $W/$name.got | head -5; fi
  }
  [ -z "${ms_only:-}" ] && run mini-dotnet "$(realpath $DN)"
  [ -n "$ms" ] && run "Microsoft's dotnet" dotnet
}
roads contexts pta lib_code/datalog/tests contexts.c
# (an ML program, lib_core's units it names read too: Microsoft's only,
# mini-dotnet's interpreter too slow for make test's minute)
ms_only=1 roads contexts_ml pta_ml lib_code/datalog/tests -L $PWD/lib_core contexts.ml
# the reports: a program of the rules mini-analyze loads, no query;
# its report the native mini-analyze's
REPORT_C="$R/instructions.dl $R/andersen.dl $R/contexts.dl $R/call1_heap1.dl lib_code/datalog/bugs/pointers.dl"
REPORT_ML="$R/instructions.dl $R/andersen.dl lib_code/datalog/calls.dl"
REPORT_DEAD="$R/instructions.dl $R/contexts.dl $R/insensitive.dl lib_code/datalog/dead.dl"
REPORT_CAPS="$REPORT_DEAD lib_code/datalog/capabilities.dl"
REPORT_EXN="$R/instructions.dl $R/andersen.dl $R/contexts.dl $R/call1_rec.dl lib_code/datalog/exceptions.dl"
$DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/report_c.dll $REPORT_C &&
  $DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/report_ml.dll $REPORT_ML &&
  $DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/report_dead.dll $REPORT_DEAD &&
  $DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/report_caps.dll $REPORT_CAPS &&
  $DL -dotnet -runtime analyze_rt -entry Analyze_rt -o $W/report_exn.dll $REPORT_EXN ||
  { echo "FAIL mini-datalog -dotnet, the reports' programs"; exit 1; }
report() { # name, its program, the directory, the files
  local name=$1 prog=$2 dir=$3; shift 3
  [ -n "${ms_only:-}" ] && [ -z "$ms" ] && { echo "skipped: $name's report (Microsoft's dotnet only: -ms)"; return; }
  local root=$PWD
  (cd $dir && $AN -r $root/lib_code/datalog "$@") > $W/$name.report.want 2>&1
  local args=("$@")
  run() { # what, runtime
    (cd $dir && $2 $W/$prog.dll "${args[@]}") > $W/$name.report.got 2>&1
    if [ -s $W/$name.report.want ] && cmp -s $W/$name.report.want $W/$name.report.got; then
      echo "ok mini-analyze's report on $name: the native's ($(wc -l < $W/$name.report.want) lines), by $1"
    else fail "mini-analyze's .NET report on $name, by $1"; diff $W/$name.report.want $W/$name.report.got | head -5; fi
  }
  [ -z "${ms_only:-}" ] && run mini-dotnet "$(realpath $DN)"
  [ -n "$ms" ] && run "Microsoft's dotnet" dotnet
}
report bugs report_c analyzers/tests/c/bugs bugs.c
ms_only=1 report callbacks report_c analyzers/tests/c/callbacks $(cd analyzers/tests/c/callbacks && ls *.c)
ms_only=1 report handlers report_ml . analyzers/tests/ml/handlers/Events.ml analyzers/tests/ml/handlers/Main.ml
# a C module called from ML: the answers' fingerprint by fingerprint.c on
# .NET, by Fingerprint.ml natively, the same number
report fingerprint report_c analyzers/tests/c/bugs -fingerprint bugs.c
ms_only=1 report fingerprint_ml report_ml . -fingerprint analyzers/tests/ml/handlers/Events.ml analyzers/tests/ml/handlers/Main.ml
for d in analyzers/tests/dead/c analyzers/tests/dead/ml; do
  ms_only=1 report dead_$(basename $d) report_dead . -dead $(ls $d/*.[cm]* | grep -v expected)
done
ms_only=1 report caps report_caps . -caps $(ls analyzers/tests/caps/ml/*.ml)
ms_only=1 report exn report_exn . -exn analyzers/tests/exn/toplevel/Main.ml
if [ -n "$rc" ]; then
  G=${GOKEN:-$HOME/goken}
  F="builtins.c code.c env.c error.c exec.c executils.c fmt.c getflags_.c globals.c glob.c goken.c here.c input.c io.c lex.c main.c notify_full.c path.c pcmd.c pfnc.c processes.c rfork_fork.c simple.c status.c trap.c tree.c utils.c var.c words.c y.tab.c"
  ms=1 ms_only=1 roads rc pta $G/rc -I$G/include/ALL -I$G/include/arch/arm64 -I$G/include $F
fi
echo "$failures failure(s)"
[ $failures = 0 ]
