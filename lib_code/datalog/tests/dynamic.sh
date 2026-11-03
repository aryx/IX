#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The analysis against real runs (plan_datalog.md, decision 7c): a function
# that ran and that the call graph does not reach is the analysis's mistake,
# and every "dead" of -dead rests on there being none. mini-5i -prof counts
# each instruction's address; the link's map says each address's symbol and,
# by the M.Init before them, its unit. A program built by mini-ml, its own
# tests as what it runs:
#
#    workload --mini-5i -prof--> pc counts ---\
#    mini-ld -map -------------> symbols ------> ran(Unit, name)
#    mini-analyze -facts, dead.dl ------------> reach(F) --> Unit, name
#                                 ran \ reach = missed: expected none
#
# A function that ran is said by mini-where, from a link with -g: its unit's
# file and its body's first line; it is the closure(F, Unit, Line) at or
# just before that line, or any of them if several share it (let f x y's f
# and f', lambdas on one line). A function inlined leaves no symbol: nothing
# is said of it. The test is one way: what ran is a part of what can run, so
# nothing here says -dead's answers are dead, only that it did not call dead
# what ran.
# usage: lib_code/datalog/tests/dynamic.sh [-c | program...]   (dune build first)
# ANALYZE, DATALOG, MINI5I, WHERE: the programs, if not dune's. RULES: other
# points_to rules (a broken copy: does the check see it?). SHOW: lines shown.
cd "$(dirname "$0")/../../.."
ROOT=$PWD
T=lib_code/datalog/tests
D=${RULES:-lib_code/datalog/points_to}
ANALYZE=${ANALYZE:-$ROOT/_build/default/analyzers/Main.exe}
DATALOG=${DATALOG:-$ROOT/_build/default/languages/datalog/Main.exe}
MINI5I=${MINI5I:-$ROOT/_build/default/machine/Main.exe}
WHERE=${WHERE:-$ROOT/_build/default/debuggers/where/Where.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
all="forth datalog rc prolog dc"

. $T/mk_units.sh

# one run: prog args, stdin from /dev/null unless $IN; profile added to $W/prof
run() {
  n=$((n + 1))
  (cd $W/cwd; ulimit -v 12000000; timeout 120 $MINI5I -prof $W/prof.$n $W/prog "$@" < ${IN:-/dev/null} > /dev/null 2>&1)
}

workload() { # a program's own tests
  case $1 in
    forth) t=languages/forth/tests
      for f in core classics see errors; do run $ROOT/$t/$f.fs; done
      IN=$ROOT/$t/prompt.in run;;
    datalog) t=languages/datalog/tests
      for f in graph liveness dominators; do
        run -all $ROOT/$t/$f.dl; run -naive -s -profile -all $ROOT/$t/$f.dl; run -btree all -all $ROOT/$t/$f.dl
      done
      run -q 'call_edge(I, F)' $ROOT/lib_code/datalog/pointer.dl $ROOT/$t/pointer_facts.dl
      run -h; run /nonexistent;;
    rc) for f in $ROOT/shell/tests/corpus/*.rc; do run $f; done;;
    prolog) for f in $ROOT/languages/prolog/tests/*.pl; do run $f; done;;
    dc) for f in $ROOT/utilities/calc/dc/tests/corpus/*; do [ -f $f ] && IN=$f run; done;;
  esac
}

# the functions that ran, a line "Unit line function" each, from the map, the
# profiles and mini-where
ran_functions() { # map, then profiles
  local map=$1; shift
  { sed -E 's/^([0-9a-f]+) (.*)/\1 m \2/' $map
    cat "$@" | awk '{ pc = sprintf("%8s", $1); gsub(/ /, "0", pc); print pc, "p" }'
  } | sort -k1,1 -k2,2 | awk '
    $2 == "m" { sym = $3; at = $1; next }
    $2 == "p" && sym ~ /^f[0-9]+_/ { print at }
  ' | sort -u | xargs -n 500 $WHERE $W/prog |
    awk 'split($NF, w, ":") == 2 && w[1] ~ /\.ml$/ {
      u = w[1]; sub(/.*\//, "", u); sub(/\.ml$/, "", u)
      print toupper(substr(u, 1, 1)) substr(u, 2), w[2], $2 }' | sort -u
}

# ran against closure and reach: what ran with none of its line's closures reached
compare() { # ran, facts, reached names
  sed -nE "s/^closure\('(.*)', '([^']*)', '([0-9]+)'\)\.$/\2 \3 \1/p" $2 | sed "s/\\\\'/'/g" | sort -k1,1 -k2,2n > $W/closures
  awk -v reached=$3 -v closures=$W/closures '
    BEGIN {
      while ((getline line < reached) > 0) ok[line] = 1
      while ((getline line < closures) > 0) {
        split(line, f, " ")
        n[f[1]]++; lines[f[1], n[f[1]]] = f[2] + 0; names[f[1], n[f[1]]] = f[3]
      }
    }
    {
      u = $1; l = $2 + 0; best = -1
      for (i = 1; i <= n[u]; i++) if (lines[u, i] <= l && lines[u, i] > best) best = lines[u, i]
      if (best < 0) { print "no-closure", $0; next }
      seen = 0; model = 0
      for (i = 1; i <= n[u]; i++) if (lines[u, i] == best) {
        if (names[u, i] in ok) seen = 1
        # (a function the models replace, Pervasives.@: model:Pervasives.@)
        if (names[u, i] ~ /^model:/) model = 1
      }
      if (model) print "modeled", $0
      else if (!seen) print "missed", $0, "closure at line " best
    }' $1
}

# C (-c): toy programs by mini-cc, their functions by name, against each
# context file: the hole is in the ones that choose by an object. The libc
# as languages/c/tests/bench.sh's; a goken checkout's headers: by hand.
c_check() {
  local O=7 G=$HOME/goken/include CC=$ROOT/_build/default/languages/c/Main.exe LD=$ROOT/_build/default/linker/Main.exe
  local rules prog files a
  [ -d $G ] || { echo "no $G"; exit 2; }
  MINICC=1 linker/tests/libc.sh $O $W > /dev/null 2>&1
  [ -f $W/t/libc.a ] || { echo "no libc.a"; exit 2; }
  printf '%-16s %-14s %5s %7s %6s\n' program analysis ran reached missed
  for prog in hole callbacks dead; do
    case $prog in
      hole) files=$T/hole.c;;
      callbacks) files=analyzers/tests/c/callbacks/callbacks.c;;
      dead) files=analyzers/tests/dead/c/dead.c;;
    esac
    objs=
    for f in $files; do
      $CC -m $O -I$G -I$G/ALL -I$G/arch/arm64 -o $W/$(basename $f .c).$O $f || { echo "$prog: not compiled"; continue 2; }
      objs="$objs $W/$(basename $f .c).$O"
    done
    $LD -m $O -H7 -map -o $W/prog $objs $W/t/libc.a || { echo "$prog: not linked"; continue; }
    (cd $W; timeout 60 $MINI5I -prof $W/prof.c ./prog > /dev/null 2>&1)
    $ANALYZE -facts -I$G -I$G/ALL -I$G/arch/arm64 $files > $W/facts 2> /dev/null
    sed -nE "s/^defined\('([^']*)',.*/\1/p" $W/facts | sort -u > $W/own
    { sed -E 's/^([0-9a-f]+) (.*)/\1 m \2/' $W/prog.map
      awk '{ pc = sprintf("%8s", $1); gsub(/ /, "0", pc); print pc, "p" }' $W/prof.c
    } | sort -k1,1 -k2,2 | awk '$2 == "m" { sym = $3; next } $2 == "p" { print sym }' | sed 's/<>$//' | sort -u > $W/ran
    comm -12 $W/ran $W/own > $W/ran_own
    for a in insensitive call1 call2_heap1 object1 object2_heap1 type2_heap1 hybrid selective; do
      $DATALOG -q 'reach(F)' $D/instructions.dl $D/andersen.dl $D/contexts.dl $D/$a.dl lib_code/datalog/dead.dl $W/facts 2> /dev/null |
        sed -E "s/^reach\('?//; s/'?\)\.$//" | sort -u > $W/reached
      comm -23 $W/ran_own $W/reached > $W/missed
      printf '%-16s %-14s %5d %7d %6d %s\n' $prog $a $(wc -l < $W/ran_own) $(comm -12 $W/reached $W/own | wc -l) $(wc -l < $W/missed) "$(tr '\n' ' ' < $W/missed)"
      failures=$((failures + $(wc -l < $W/missed)))
    done
  done
  exit $failures
}
[ "${1:-}" = -c ] && c_check

printf '%-8s %6s %7s %7s %7s %8s %7s\n' program runs ran reached missed unmatched modeled
for p in ${@:-$all}; do
  case $p in
    forth) mk=languages/forth/mkfile; bin=_mk/7/languages/forth/mini-forth;;
    datalog) mk=languages/datalog/mkfile; bin=_mk/7/languages/datalog/mini-datalog;;
    rc) mk=shell/mkfile; bin=_mk/7/shell/mini-rc;;
    prolog) mk=languages/prolog/mkfile; bin=_mk/7/languages/prolog/mini-prolog;;
    dc) mk=utilities/calc/dc/mkfile; bin=_mk/7/utilities/calc/dc/mini-dc;;
    *) echo "$p: which?"; continue;;
  esac
  dir=$(dirname $mk)
  rm -f $bin
  link=$(cd $dir && MKSHELL=mini-rc PATH=$ROOT/bin:$PATH mini-mk 2>&1 | grep -E '^mini-ld' | tail -1)
  [ -x $bin ] && [ -n "$link" ] || { echo "$p: not built"; failures=$((failures + 1)); continue; }
  set -- $link; shift
  (cd $dir && $ROOT/bin/mini-ld -g "$@" -o $W/prog) || { echo "$p: not linked with -g"; failures=$((failures + 1)); continue; }
  rm -rf $W/cwd $W/prof.*; mkdir $W/cwd; n=0
  workload $p
  read flags files < <(program_args $mk)
  $ANALYZE -facts -L lib_core ${flags//,/ } $files > $W/facts 2> $W/err
  [ -s $W/err ] && { echo "$p: not read: $(head -1 $W/err | cut -c1-90)"; failures=$((failures + 1)); continue; }
  ran_functions $W/prog.map $W/prof.* > $W/ran_all
  # (the units the models replace, analyzers/ml/Models: List's and Hashtbl's
  # bodies are not in the facts, nor their helpers, and are not checked;
  # what they call back is the program's, and is)
  grep -vE '^(List|Hashtbl) ' $W/ran_all > $W/ran
  skipped=$(grep -cE '^(List|Hashtbl) ' $W/ran_all)
  # (a source edited since its object: its lines say another function; so
  # on a tree others edit, a clean copy of it)
  stale=$(awk '{ print $1 }' $W/ran | sort -u | while read -r u; do
    o=$(find _mk/7 -name "$u.7" | head -1); f=$(git ls-files "*/$u.ml" 2> /dev/null | grep -v '^tiny/' | head -1)
    [ -n "$o" ] && [ -n "$f" ] && [ "$f" -nt "$o" ] && echo $u
  done | tr '\n' ' ')
  [ -n "$stale" ] && echo "$p: newer than their objects, lines not to be trusted: $stale"
  $DATALOG -q 'reach(F)' $D/instructions.dl $D/contexts.dl $D/insensitive.dl lib_code/datalog/dead.dl $W/facts 2> /dev/null |
    sed -E "s/^reach\('?//; s/'?\)\.$//; s/\\\\'/'/g" | sort -u > $W/reached
  compare $W/ran $W/facts $W/reached > $W/result
  modeled=$((skipped + $(grep -c '^modeled' $W/result)))
  printf '%-8s %6d %7d %7d %7d %8d %7d\n' $p $n $(wc -l < $W/ran) $(wc -l < $W/reached) $(grep -c '^missed' $W/result) $(grep -c '^no-closure' $W/result) $modeled
  grep -E '^(missed|no-closure)' $W/result | sed "s/^/   $p: /" | head -${SHOW:-30}
  failures=$((failures + $(grep -c '^missed' $W/result)))
done
exit $failures
