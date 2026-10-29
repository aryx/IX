#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml's checked annotations (languages/ml/Annotations.mli,
# docs/plans/plan_ml_annotations.md): annotations/holds.ml, where they
# hold, run by OCaml then compiled by mini-ml -O3 and run (run.sh 7),
# both against holds.out; each of annotations/refused/, where one does
# not hold, refused by mini-ml with its .err's message, and compiled
# by OCaml (for which [@tailcall] is a warning and [@@tailrec]
# nothing: ix compiles with both).
# usage: annotations.sh   (dune build first)
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
T=$ROOT/languages/ml/tests/annotations
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
(cd $T && ocaml holds.ml; echo "exit $?") > $W/holds.out 2>&1
if cmp -s $W/holds.out $T/holds.out; then echo "ok holds (OCaml)"
else echo "FAIL holds (OCaml)"; diff $T/holds.out $W/holds.out | head -5; failures=$((failures + 1)); fi
ML_FLAGS=-O3 $ROOT/languages/ml/tests/run.sh 7 $W/run $T/holds.ml || failures=$((failures + 1))
S=$(for u in $(grep -v '^#' $ROOT/lib_core/units.txt); do echo "-I $ROOT/lib_core/$(dirname $u)"; done | sort -u | tr '\n' ' ')
for p in $T/refused/*.ml; do
  b=$(basename $p .ml)
  if ! ocamlfind ocamlopt -w -a -c -o $W/ok.cmx $p 2> /dev/null; then echo "FAIL $b: OCaml refuses it"; failures=$((failures + 1)); continue; fi
  if $ROOT/_build/default/languages/ml/Main.exe -m 7 -O3 $S -o $W/x.7 $p > $W/$b.err 2>&1; then
    echo "FAIL $b: mini-ml takes it"; failures=$((failures + 1)); continue
  fi
  if sed 's|^.*/refused/|refused/|' $W/$b.err | cmp -s - $T/refused/$b.err; then echo "ok $b refused: $(sed 's/^[^:]*: //' $T/refused/$b.err)"
  else echo "FAIL $b: another message"; diff $T/refused/$b.err $W/$b.err | head -4; failures=$((failures + 1)); fi
done
echo "$failures failure(s)"
[ $failures = 0 ]
