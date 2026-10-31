#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Doop's table (plan_datalog.md, decision 7d) for a program, an analysis
# a row: its seconds, the (variable, object) pairs, call edges, the
# calls with several targets, the functions reached, and "lost": call
# edges of Andersen's, in a function this analysis reaches, it has not.
# Each is precision gained or, for object1.dl and those after it, may
# be its hole: compare with call2_heap1's, which follows every call.
# usage: lib_code/datalog/tests/table.sh limit-seconds facts.dl [analysis...]
# facts by mini-analyze -facts. DATALOG: the program, if not dune's.
cd "$(dirname "$0")/../../.."
D=lib_code/datalog/points_to
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
limit=$1; facts=$2; shift 2
W=$(mktemp -d); trap 'rm -rf $W' EXIT
base="$D/instructions.dl $D/andersen.dl"
ulimit -v 16000000
printf '%-14s %8s %9s %8s %8s %7s %6s\n' analysis seconds pt edges several reached lost
count() { if [ "$1" = none ]; then echo -; else grep -c "$2" $W/out; fi; }
row() { # name, pt's relation, edges' relation, reached's query (or none), then the rules
  local name=$1 pts=$2 edges=$3 reach=$4; shift 4
  local t0=$(date +%s.%N)
  local q="-q $pts(V,H) -q $edges(I,F)"
  [ "$reach" != none ] && q="$q -q $reach(F) -q lost(I,F)"
  if ! timeout $limit $DATALOG $q "$@" $facts > $W/out 2> /dev/null; then
    printf '%-14s %8s\n' $name ">$limit"; return
  fi
  local t1=$(date +%s.%N)
  grep "^$edges(" $W/out | sort -u > $W/edges
  printf '%-14s %8.1f %9d %8d %8d %7s %6s\n' $name $(echo "$t1 - $t0" | bc) \
    $(grep "^$pts(" $W/out | grep -vc ',scalar)') \
    $(wc -l < $W/edges) \
    $(cut -d, -f1 $W/edges | uniq -d | wc -l) \
    $(count "$reach" "^$reach(") \
    $(count "$reach" '^lost(')
}
cat > $W/lost.dl <<'EOF'
lost(I, F) :- call_edge(I, F), in_function(I, G), root(G, R), reach(R), \+ target(I, F).
EOF
all="steensgaard andersen insensitive call1 call1_heap1 call2_heap1 object1 object2_heap1 type2_heap1 hybrid selective"
for a in ${@:-$all}; do
  case $a in
    steensgaard) row $a pt call_edge none $D/instructions.dl $D/steensgaard.dl;;
    andersen) row $a pt call_edge none $base;;
    *) row $a pts target reach $base $D/contexts.dl $D/$a.dl $W/lost.dl;;
  esac
done
