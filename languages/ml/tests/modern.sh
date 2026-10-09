#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Today's OCaml in mini-ml (plan_ml_bootstrap.md, goal 2): modern/'s
# programs (a file, or a directory of units), what ocaml-light doesn't read (local opens, labels, inline
# records, punning...), each run by OCaml, then compiled by mini-ml and
# run (run.sh 7), both against its .out (its output, then its exit
# status). RECORD=1 writes the .out from OCaml's run. The .out are
# OCaml 4.14's: another OCaml's run that differs is "apart", not a
# failure (5.5 has no Int32.format, no s.[i] <- c, a quiet nan, and a
# marshalled block's header with its color). And refused/'s,
# what today's OCaml refuses and ocaml-light took (a string written):
# each refused by both.
# usage: modern.sh [prog.ml...]

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
T=$ROOT/languages/ml/tests
W=$(mktemp -d); trap 'rm -rf $W' EXIT
progs=("$@"); [ ${#progs[@]} = 0 ] && progs=($T/modern/*.ml $(ls -d $T/modern/*/))
failures=0
V=$(ocamlfind ocamlopt -version)
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
      (cd $W && ocamlfind ocamlopt -alert -deprecated $([[ $pk == *threads* ]] && echo -thread) -package $pk -linkpkg -o $name.exe $name.ml 2>&1 && ./$name.exe; echo "exit $?") > $W/$name.out 2>&1
    else
    (cd $(dirname $p) && ocaml -alert -deprecated $name.ml; echo "exit $?") > $W/$name.out 2>&1
    fi
  fi
  [ -n "${RECORD:-}" ] && cp $W/$name.out $out
  if cmp -s $W/$name.out $out; then echo "ok $name (OCaml)"
  elif [[ $V != 4.* && -z "${RECORD:-}" ]]; then echo "apart $name (OCaml $V)"
  else echo "FAIL $name (OCaml)"; diff $out $W/$name.out | head -5; failures=$((failures + 1)); fi
done
$T/run.sh 7 $W/run "${progs[@]}" || failures=$((failures + 1))
S=$(for u in $(grep -v '^#' $ROOT/lib_core/units.txt); do echo "-I $ROOT/lib_core/$(dirname $u)"; done | sort -u | tr '\n' ' ')
[ $# = 0 ] && for p in $T/refused/*.ml; do
  if ocamlfind ocamlopt -c -o $W/bad.cmx $p 2> /dev/null; then echo "FAIL $(basename $p): OCaml takes it"; failures=$((failures + 1))
  elif $ROOT/_build/default/languages/ml/Main.exe $S -o /dev/null $p 2> /dev/null; then echo "FAIL $(basename $p): mini-ml takes it"; failures=$((failures + 1))
  else echo "ok $(basename $p) refused"; fi
done
echo "$failures failures"
[ $failures = 0 ]
