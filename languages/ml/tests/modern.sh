#!/bin/bash
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# Today's OCaml in mini-ml (plan_ml_bootstrap.md, goal 2): modern/'s
# programs, what ocaml-light doesn't read (local opens, labels, inline
# records, punning...), each run by OCaml, then compiled by mini-ml and
# run (run.sh 7), both against its .out (its output, then its exit
# status). RECORD=1 writes the .out from OCaml's run.
# usage: modern.sh [prog.ml...]

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
T=$ROOT/languages/ml/tests
W=$(mktemp -d); trap 'rm -rf $W' EXIT
progs=("$@"); [ ${#progs[@]} = 0 ] && progs=($T/modern/*.ml)
failures=0
for p in "${progs[@]}"; do
  name=$(basename $p .ml)
  (cd $(dirname $p) && ocaml $name.ml; echo "exit $?") > $W/$name.out 2>&1
  [ -n "${RECORD:-}" ] && cp $W/$name.out ${p%.ml}.out
  cmp -s $W/$name.out ${p%.ml}.out && echo "ok $name (OCaml)" || { echo "FAIL $name (OCaml)"; diff ${p%.ml}.out $W/$name.out | head -5; failures=$((failures + 1)); }
done
$T/run.sh 7 $W/run "${progs[@]}" || failures=$((failures + 1))
echo "$failures failures"
[ $failures = 0 ]
