#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# bugs/unused.dl against the compiler it imitates: the variables OCaml's
# warnings 26 and 27 say (unused, no _ before the name) and those -bugs'
# unused lines say, for each file, the same names. The files: the test's
# (analyzers/tests/bugs/unused/) and the two of ix whose dune turns 26 and
# 27 off, the highlighters (with them on, OCaml says two in Highlight_st,
# none in Highlight_asm). Each compiled in a directory of its own, its
# .mli first, against dune's interfaces of lib_code.
# usage: analyzers/datalog/tests/unused_ocaml.sh   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
CODE=$PWD/_build/default/lib_code/.ix_code.objs/byte
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
for f in analyzers/tests/bugs/unused/Before.ml analyzers/tests/bugs/unused/After.ml \
         languages/smalltalk/highlight/Highlight_st.ml assembler/highlight/Highlight_asm.ml; do
  b=$(basename $f .ml); d=$W/$b; mkdir -p $d
  cp $f $d/; [ -f ${f%.ml}.mli ] && cp ${f%.ml}.mli $d/
  # OCaml's: "unused variable x." after each warning 26 or 27
  (cd $d && { [ ! -f $b.mli ] || ocamlfind ocamlc -w -a -I $CODE -c $b.mli; } &&
     ocamlfind ocamlc -w -a+26+27 -I $CODE -c $b.ml) 2>&1 |
    sed -n 's/.*unused variable \([A-Za-z0-9_'"'"']*\)\./\1/p' | sort > $W/$b.ocaml
  # the rules': "in F, x is never read"
  $ANALYZE -bugs -L lib_core -I lib_code $f 2>&1 |
    sed -n 's/.* unused: in .*, \([A-Za-z0-9_'"'"']*\) is never read.*/\1/p' | sort > $W/$b.rules
  if cmp -s $W/$b.ocaml $W/$b.rules; then
    echo "ok unused.dl: $b, as OCaml's 26 and 27 ($(wc -l < $W/$b.rules) variables)"
  else
    echo "FAIL unused.dl: $b, not OCaml's 26 and 27:"; diff $W/$b.ocaml $W/$b.rules | head -5
    failures=$((failures + 1))
  fi
done
exit $failures
