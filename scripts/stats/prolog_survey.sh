#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The numbers behind docs/plans/plan_prolog.md: the author's Prolog and
# Datalog files in pfff (the rules, the facts' makers, the tests), their
# lines, their rules, what of Prolog codequery's file calls; the lines
# of ix's interpreted languages, to compare an estimate with; the trees
# of ix's two compilers a fact would be made from; and whether a Prolog
# or a Datalog is on this machine to compare with.
# As scripts/stats/pdf_survey.sh.
# usage: scripts/stats/prolog_survey.sh [pfff]

cd "$(dirname "$0")"
T=../..
F=${1:-$HOME/github/DEPRECATED/facebookarchive-pfff}
[ -d $F/h_program-lang ] || { echo "no $F/h_program-lang"; exit 1; }

lines() { cat "$@" 2>/dev/null | wc -l; }

echo "== pfff's files (lines)"
for f in h_program-lang/datalog_code.dl h_program-lang/datalog_code.ml lang_c/analyze/datalog_c.ml mini/datalog_minic.ml \
         tests/mini/datalog/pointer.dl h_program-lang/prolog_code.pl h_program-lang/prolog_code.ml graph_code/graph_code_prolog.ml; do
  printf "%6d  %s\n" $(lines $F/$f) $f
done
echo "tests/c/datalog: $(ls $F/tests/c/datalog | tr '\n' ' ')"

echo "== datalog_code.dl"
echo "rules: $(grep -c ':-' $F/h_program-lang/datalog_code.dl)"
echo "relations in a rule's head: $(grep -o -E '^[a-z_]+\(' $F/h_program-lang/datalog_code.dl | sort -u | tr -d '(' | tr '\n' ' ')"
echo "the facts' constructors (datalog_code.mli): $(grep -c -E '^  \| ' $F/h_program-lang/datalog_code.mli)"
echo "a negation: $(grep -c -E '^[^%]*(\\\+|not\(|!)' $F/h_program-lang/datalog_code.dl)"

echo "== prolog_code.pl"
echo "clauses with a body: $(grep -c ':-' $F/h_program-lang/prolog_code.pl)"
echo "directives: $(grep -E '^:-' $F/h_program-lang/prolog_code.pl | sed 's/^:- *//' | tr '\n' ' ')"
echo "what it calls of the system:"
grep -v -E '^ *%' $F/h_program-lang/prolog_code.pl \
  | grep -o -E '\b(findall|setof|bagof|asserta|assertz|assert|retract|format|writeln|write|nl|atom_[a-z]+|concat_atom|sub_atom|forall|aggregate_all|length|sort|msort|use_module|not|call|member|append|is)\(' \
  | sort | uniq -c | sort -rn | sed 's/($//'

echo "== ix's languages that are run (lines of .ml, of .mli)"
for d in scheme pascal smalltalk; do
  printf "%-10s %6d %6d\n" $d $(lines $T/languages/$d/*.ml) $(lines $T/languages/$d/*.mli)
done

echo "== the trees a fact would be made from (lines)"
for f in languages/c/Tree.ml languages/c/simple/Ir.ml languages/ml/Ast.ml languages/ml/simple/Ir.ml languages/ml/ssa/Ssa.ml; do
  printf "%6d  %s\n" $(lines $T/$f) $f
done
echo "a liveness computed by hand today: $(grep -l -i liveness $T/languages/c/opti/*.mli $T/languages/ml/ssa/*.mli | sed "s|$T/||" | tr '\n' ' ')"

echo "== on this machine"
for p in swipl gprolog yap souffle; do
  if command -v $p > /dev/null; then echo "$p: $(command -v $p)"; else echo "$p: no"; fi
done
