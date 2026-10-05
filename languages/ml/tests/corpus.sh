#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-ml's front end over its corpus (plan_ml.md, phase 2): every .ml
# and .mli of mini-9pi (kernel/9pi, kernel/lib), of ocaml-light's
# stdlib (lib_core's, from the one the kernels are built with, $OCL's, from
# kernel/ocaml-light.sh) and of its test/ ($OCAML_LIGHT/test), through
# mini-ml (a .mli parsed; a .ml compiled, for arm), with the kernel's and
# the stdlib's directories as -I; each failure printed, then
# the counts. The files outside the subset are expected to fail:
# EXPECTED lists them.
# usage: corpus.sh [file...]

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
ML=${ML:-$ROOT/_build/default/languages/ml/Main.exe}
OCL=${OCL:-/tmp/ix-ocaml-light-arm64}
OCAML_LIGHT=${OCAML_LIGHT:-$HOME/ocaml-light}
files=("$@")
if [ ${#files[@]} = 0 ]; then
  # (mini-9pi's own files, in directories under kernel/9pi since, are
  # compile_ix.sh's: each needs the others' directories)
  files=($ROOT/kernel/lib/*.ml $ROOT/kernel/lib/*.mli)
  for d in core base collections printing parsing system; do files+=($ROOT/lib_core/$d/*.ml $ROOT/lib_core/$d/*.mli); done
  [ -d $OCAML_LIGHT/test ] && files+=($(find $OCAML_LIGHT/test -name '*.ml' -o -name '*.mli' | sort))
fi
# outside the subset: let-operators (letstar), a functor (sets: Set.Make),
# Caml Light's #open (testmain); Lex's main, whose Scanner and Grammar
# are generated (ocamllex, ocamlyacc); not yet: a recursive value
# (recvalues), a function of 11 arguments on arm, which passes 8 in
# registers (manyargs); and what ix's stdlib gave up (2026-10-04):
# Gc.print_stat (alloc), List.sort_bool (Lex's output)
S=$(for u in $(grep -v '^#' $ROOT/lib_core/units.txt); do echo "-I $ROOT/lib_core/$(dirname $u)"; done | sort -u | tr '\n' ' ')
EXPECTED=" letstar.ml sets.ml testmain.ml main.ml recvalues.ml manyargs.ml alloc.ml output.ml "
ok=0; expected=0; failures=0
for f in "${files[@]}"; do
  if out=$($ML -o /dev/null -I $ROOT/kernel/lib $S $f 2>&1 >/dev/null); then ok=$((ok + 1))
  elif [[ "$EXPECTED" == *" $(basename $f) "* ]]; then expected=$((expected + 1))
  else echo "FAIL $out"; failures=$((failures + 1)); fi
done
echo "$ok ok, $expected outside the subset, $failures failure(s)"
[ $failures = 0 ]
