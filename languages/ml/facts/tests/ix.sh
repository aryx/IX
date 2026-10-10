#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The rules' liveness and dominators against the compiler's own, on
# ix's own programs (docs/plans/plan_prolog.md, stage 9's check): for
# each .ml of the directories given, mini-ml -flow and -dflow, then
# mini-datalog with languages/datalog/analyses/liveness_ssa.dl and
# dominators.dl and tests/check.dl; a line per directory (its files,
# functions, blocks, facts, the tuples the rules find, those that
# differ from Alloc's liveness or Ssa_build's dominators, the seconds
# of mini-ml and of mini-datalog), a line per file that differs or
# that mini-ml does not compile with the directories given.
# usage: languages/ml/facts/tests/ix.sh [dir...]   (dune build first)
# ML, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../../../.."
T=languages/ml/facts/tests
A=languages/datalog/analyses
ML=${ML:-_build/default/languages/ml/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
# a program's directories, and dune's copy of each (its Parser, its Lexer)
dirs() { for d in $(find "$@" -name '*.ml' -not -path '*/tests/*' | xargs -n1 dirname | sort -u); do echo -n "-I $d -I _build/default/$d "; done; }
std=$(for u in $(grep -v '^#' lib_core/units.txt); do echo "-I lib_core/$(dirname $u)"; done | sort -u | tr '\n' ' ')
shared="$std -I lib_core/commons $(dirs assembler) $(dirs lib_code)"
[ $# = 0 ] && set -- languages/prolog languages/datalog languages/ml languages/c languages/scheme assembler linker
now() { date +%s.%N; }
total=0
printf "%-20s %5s %6s %7s %8s %8s %7s %7s %7s\n" directory files funcs blocks facts tuples differ mini-ml datalog
for d in "$@"; do
  incs="$(dirs $d) $shared"; [ $d = languages/datalog ] && incs="$incs $(dirs languages/prolog)"
  files=0; funcs=0; blocks=0; facts=0; tuples=0; differ=0; tml=0; tdl=0
  for f in $(find $d -name '*.ml' -not -path '*/tests/*' -not -path '*/runtime/*' | sort); do
    t0=$(now)
    if ! $ML -m 7 -flow -dflow $incs $f > $W/f.dl 2> $W/err; then echo "  not compiled: $f: $(head -1 $W/err | cut -c1-90)"; continue; fi
    t1=$(now)
    $DATALOG -s -q 'differs(What, Who, V, B)' $A/liveness_ssa.dl $A/dominators.dl $T/check.dl $W/f.dl > $W/out 2> $W/stats
    t2=$(now)
    n=$(wc -l < $W/out); [ $n != 0 ] && echo "  DIFFERS: $f: $n tuples, the first: $(head -1 $W/out)"
    files=$((files + 1)); funcs=$((funcs + $(grep -c '^function' $W/f.dl))); blocks=$((blocks + $(grep -c '^block' $W/f.dl)))
    facts=$((facts + $(grep -vc '^own_' $W/f.dl))); differ=$((differ + n))
    tuples=$((tuples + $(sed -n 's/.* \([0-9]*\) new tuples.*/\1/p' $W/stats)))
    tml=$(echo "$tml + $t1 - $t0" | bc); tdl=$(echo "$tdl + $t2 - $t1" | bc)
  done
  printf "%-20s %5d %6d %7d %8d %8d %7d %6.1fs %6.1fs\n" $d $files $funcs $blocks $facts $tuples $differ $tml $tdl
  total=$((total + differ))
done
[ $total = 0 ]
