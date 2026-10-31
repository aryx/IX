#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Each pointer analysis of lib_code/datalog/points_to on contexts.c and
# contexts.ml: what each named variable may point to, against
# contexts_c.out and contexts_ml.out. Read, not made by another analysis:
# each question in contexts.c says which analysis should tell it apart.
# Then the containments plan_datalog.md's decision 7b asks for, each a
# count that must be 0: an analysis's answers inside a coarser one's;
# and the functions reached the same: what a call site follows, an
# object must too, in a program where they differ by precision alone.
# usage: lib_code/datalog/tests/run.sh [-record]   (dune build first)
# ANALYZE, DATALOG: the two programs, if not dune's.
cd "$(dirname "$0")/../../.."
T=lib_code/datalog/tests
D=lib_code/datalog/points_to
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
analyses="steensgaard andersen insensitive call1 call1_heap1 call2_heap1 object1 object2_heap1 type2_heap1 hybrid selective"
base="$D/instructions.dl $D/andersen.dl"

# one line per question of a program: the analysis's answers, on one line
answers() { # facts, then the variables
  local facts=$1 a v; shift
  for a in $analyses; do
    case $a in
      steensgaard) rules="$D/instructions.dl $D/steensgaard.dl"; rel=pt;;
      andersen) rules=$base; rel=pt;;
      *) rules="$base $D/contexts.dl $D/$a.dl"; rel=pts;;
    esac
    echo "== $a"
    for v in "$@"; do
      echo "$v: $($DATALOG -q "$rel('$v', H)" $rules $facts 2> /dev/null | sed -E "s/^[a-z]+\('?[^,]*'?, ?//; s/\)\.$//; s/Contexts[.:]//; s/'//g" | grep -v '^scalar$' | sort -u | tr '\n' ' ')"
    done
  done
}

$ANALYZE -facts $T/contexts.c > $W/c.facts 2>&1
$ANALYZE -facts -L lib_core $T/contexts.ml > $W/ml.facts 2>&1
$ANALYZE -facts $T/hole.c > $W/hole.facts 2>&1
answers $W/c.facts p1 q1 r1 o1 n1 f1 > $W/contexts_c.out
# (not Steensgaard's: lib_core's facts are too many for its pairs)
analyses=${analyses#steensgaard }
answers $W/ml.facts Contexts.a Contexts.c Contexts.pf Contexts.f1 Contexts.h1 Contexts.e > $W/contexts_ml.out

# the functions a reaches and b does not, and the other way
same_reach() { # facts a b
  $DATALOG -q 'reach(F)' $base $D/contexts.dl $D/$2.dl $1 2> /dev/null | sort -u > $W/a
  $DATALOG -q 'reach(F)' $base $D/contexts.dl $D/$3.dl $1 2> /dev/null | sort -u > $W/b
  echo "$3 reaches what $2 reaches: $(comm -23 $W/a $W/b | wc -l) not"
}

# the tuples of a's answers that b has not
outside() { # facts a b: each a context file
  local facts=$1 a=$2 b=$3
  { $DATALOG -q 'pts(V, H)' $base $D/contexts.dl $D/$a.dl $facts 2> /dev/null | sort -u > $W/a
    $DATALOG -q 'pts(V, H)' $base $D/contexts.dl $D/$b.dl $facts 2> /dev/null | sort -u > $W/b
    echo "$a inside $b: $(comm -23 $W/a $W/b | wc -l)"; }
}
inside_andersen() { # facts a
  local facts=$1 a=$2
  $DATALOG -q 'pts(V, H)' $base $D/contexts.dl $D/$a.dl $facts 2> /dev/null | sed 's/^pts/pt/' | sort -u > $W/a
  $DATALOG -q 'pt(V, H)' $base $facts 2> /dev/null | grep -v ',scalar)' | sort -u > $W/b
  echo "$a inside andersen: $(comm -23 $W/a $W/b | wc -l)"
}
inside_steensgaard() { # facts
  $DATALOG -q 'pt(V, H)' $base $1 2> /dev/null | grep -v ',scalar)' | sort -u > $W/a
  $DATALOG -q 'pt(V, H)' $D/instructions.dl $D/steensgaard.dl $1 2> /dev/null | sort -u > $W/b
  echo "andersen inside steensgaard: $(comm -23 $W/a $W/b | wc -l)"
}
{ echo "== hole.c: a first argument with an object only in dead code"
  for a in object1 object2_heap1 type2_heap1 hybrid; do same_reach $W/hole.facts call2_heap1 $a; done
  for f in c ml; do
    echo "== $f"
    [ $f = c ] && inside_steensgaard $W/$f.facts
    for a in insensitive call1 object1 hybrid selective; do inside_andersen $W/$f.facts $a; done
    outside $W/$f.facts call1 insensitive
    outside $W/$f.facts call1_heap1 call1
    outside $W/$f.facts call2_heap1 call1_heap1
    outside $W/$f.facts object2_heap1 object1
    outside $W/$f.facts selective insensitive
    for a in object1 object2_heap1 type2_heap1 hybrid; do same_reach $W/$f.facts call2_heap1 $a; done
  done
} > $W/contained.out

for n in contexts_c.out contexts_ml.out contained.out; do
  if [ "${1:-}" = -record ]; then cp $W/$n $T/$n; echo "recorded $n"
  elif cmp -s $W/$n $T/$n; then echo "ok pointer analyses: $n"
  else echo "FAIL pointer analyses: $n"; diff $T/$n $W/$n | head -10; failures=$((failures + 1)); fi
done
exit $failures
