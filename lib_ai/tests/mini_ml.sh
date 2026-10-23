#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_ai and the playground's Ai by mini-ml: mini_ml/Main.ml with the
# units it names (Pathfind, Ai, and mini_ml/Playground.ml, the type
# Ai.mli takes of the playground), compiled and run on arm64 and on arm
# (an int of 31 bits), by languages/ml/tests/run.sh, its output compared
# with mini_ml/Main.out (OCaml's: ocaml-light's ocamlopt, run.sh's
# LIVE=1, has not what these units use). Test.exe is OCaml's tests, by
# dune.
# usage: lib_ai/tests/mini_ml.sh [5|7]...
cd "$(dirname "$0")/../.." || exit 1
W=$(mktemp -d); trap 'rm -rf $W' EXIT
mkdir $W/lib_ai
cp lib_ai/movement/Pathfind.ml* lib_playground/apis/Ai.ml* \
  lib_ai/tests/mini_ml/Main.ml lib_ai/tests/mini_ml/Playground.ml $W/lib_ai/
cp lib_ai/tests/mini_ml/Main.out $W/lib_ai.out
[ $# = 0 ] && set -- 7 5
status=0
for o in "$@"; do
  languages/ml/tests/run.sh $o $W/w$o $W/lib_ai || status=1
done
exit $status
