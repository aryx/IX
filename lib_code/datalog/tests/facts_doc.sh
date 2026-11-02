#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_code/datalog/FACTS.md against the compilers: each fact it shows is what they
# say of tests/facts_toy/ today, and each relation they can say is in it. So a
# change of the facts changes the document, or this fails.
# usage: lib_code/datalog/tests/facts_doc.sh   (dune build first)
# ANALYZE, CC, DATALOG: the programs, if not dune's.
cd "$(dirname "$0")/../../.."
R=lib_code/datalog; D=$R/points_to; T=$R/tests/facts_toy
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
CC=${CC:-_build/default/languages/c/Main.exe}
DATALOG=${DATALOG:-_build/default/languages/datalog/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0

$ANALYZE -facts $T/toy.c > $W/c.facts 2>&1
$ANALYZE -facts -L lib_core $T/Toy.ml > $W/ml.facts 2>&1
$CC -m 7 -flow $T/toy.c > $W/c.flow 2>&1
$ANALYZE -flow -L lib_core $T/Toy.ml > $W/ml.flow 2>&1
$DATALOG -q 'target(I, F)' $D/instructions.dl $D/contexts.dl $D/insensitive.dl $W/c.facts > $W/c.answers 2> /dev/null
cat $W/c.facts $W/ml.facts $W/c.flow $W/ml.flow $W/c.answers | sort -u > $W/real

# each line of the document that is a fact
grep -E '^[a-z_]+\(.*\)\.$' $R/FACTS.md | sort -u > $W/shown
comm -23 $W/shown $W/real > $W/not_real
if [ -s $W/not_real ]; then
  echo "FAIL FACTS.md: not what the compilers say:"; head -10 $W/not_real; failures=$((failures + 1))
else echo "ok FACTS.md: its $(wc -l < $W/shown) facts are what the compilers say"; fi

# each relation the compilers can say
{ grep -ohE '(fact1?|load|put|typed) "[a-z_]+"' languages/c/facts/Facts.ml analyzers/ml/Closure_facts.ml
  grep -ohE 'fact b "[a-z_]+"' languages/c/facts/Ir_facts.ml analyzers/ml/Ssa_facts.ml
} | sed -E 's/.*"(.*)"/\1/' | sort -u > $W/relations
# (those passed by name to Facts.load, Facts.store's put)
grep -ohE '"assign_[a-z_]+"' languages/c/facts/Facts.ml | tr -d '"' >> $W/relations
missing=$(sort -u $W/relations | while read -r r; do grep -q "\b$r\b" $R/FACTS.md || echo $r; done | tr '\n' ' ')
if [ -n "$missing" ]; then
  echo "FAIL FACTS.md: relations it does not say: $missing"; failures=$((failures + 1))
else echo "ok FACTS.md: says each of the $(sort -u $W/relations | wc -l) relations"; fi
exit $failures
