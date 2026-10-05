#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Today's OCaml in mini-ml (plan_ml_bootstrap.md, goal 2): modern/'s
# programs (a file, or a directory of units), what ocaml-light doesn't read (local opens, labels, inline
# records, punning...), each run by OCaml, then compiled by mini-ml and
# run (run.sh 7), both against its .out (its output, then its exit
# status). RECORD=1 writes the .out from OCaml's run.
# usage: modern.sh [prog.ml...]

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
T=$ROOT/languages/ml/tests
W=$(mktemp -d); trap 'rm -rf $W' EXIT
progs=("$@"); [ ${#progs[@]} = 0 ] && progs=($T/modern/*.ml $(ls -d $T/modern/*/))
failures=0
for p in "${progs[@]}"; do
  p=${p%/}; name=$(basename $p .ml); out=${p%.ml}.out
  # no alert for what OCaml has deprecated and ocaml-light only has (Int64.format)
  if [ -d $p ]; then
    # a directory's units, in their dependencies' order
    (cd $p && ocamlfind ocamlopt -alert -deprecated -o $W/$name.exe $(ocamlfind ocamldep -sort *.mli *.ml) 2>&1 && rm -f *.cm[iox] *.o; $W/$name.exe; echo "exit $?") > $W/$name.out 2>&1
  else
    # (* packages: fpath *), its first line: OCaml's run with the libraries mini-ml has its own of
    pk=$(sed -n '1s/^(\* packages: \(.*\) \*)$/\1/p' $p)
    # (* shadow: dir *): dir's modules compiled first, in the stdlib's place (lib_core's Lexing and Parsing)
    sh=$(sed -n '1s/^(\* shadow: \(.*\) \*)$/\1/p' $p)
    if [ -n "$sh" ]; then
      cp $p $ROOT/$sh/*.ml $ROOT/$sh/*.mli $W/
      (cd $W && ocamlfind ocamlopt -alert -deprecated -o $name.exe $(ocamlfind ocamldep -sort $(cd $ROOT/$sh && ls *.mli *.ml)) $name.ml 2>&1 && ./$name.exe; echo "exit $?") > $W/$name.out 2>&1
    elif [ -n "$pk" ]; then
      cp $p $W/$name.ml
      (cd $W && ocamlfind ocamlopt -alert -deprecated -package $pk -linkpkg -o $name.exe $name.ml 2>&1 && ./$name.exe; echo "exit $?") > $W/$name.out 2>&1
    else
    (cd $(dirname $p) && ocaml -alert -deprecated $name.ml; echo "exit $?") > $W/$name.out 2>&1
    fi
  fi
  [ -n "${RECORD:-}" ] && cp $W/$name.out $out
  cmp -s $W/$name.out $out && echo "ok $name (OCaml)" || { echo "FAIL $name (OCaml)"; diff $out $W/$name.out | head -5; failures=$((failures + 1)); }
done
$T/run.sh 7 $W/run "${progs[@]}" || failures=$((failures + 1))
echo "$failures failures"
[ $failures = 0 ]
