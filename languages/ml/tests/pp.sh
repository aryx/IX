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
# mlpp, mini-ml -pp (plan_ml_bootstrap.md, decision 7):
# - every .ml and .mli of ix, which use none of its constructs (but
#   pp/'s), comes back unchanged;
# - each program of pp/ (a file, or a directory of units), rewritten,
#   compiled by OCaml and run, prints its .out;
# - each file of pp/errors/, rewritten, gets from OCaml the error its
#   first line expects: the source's line and columns, through the #
#   lines;
# - with MINI_ML=1, pp/'s programs compiled by mini-ml too (run.sh 7).
# usage: pp.sh

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
ML=${ML:-$ROOT/_build/default/languages/ml/Main.exe}
T=$ROOT/languages/ml/tests/pp
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }

cd $ROOT
# (a file of ix with a [@@deriving show], a type t = [%mli] or a [%bits] is one -pp
# rewrites: it must only do so without an error; the others come out as
# they are)
n=0; derived=0
for f in $(git ls-files '*.ml' '*.mli' | grep -v '^languages/ml/tests/pp/'); do
  if grep -q '^\[@@deriving show\]$\| \[@@deriving show\]$\|^type .* = \[%mli\]$\|\[%bits "' $f; then
    derived=$((derived + 1))
    $ML -pp $f > /dev/null 2> $W/err || fail "$f: -pp: $(head -c 200 $W/err)"
    continue
  fi
  n=$((n + 1))
  $ML -pp $f 2> $W/err | cmp -s - $f || fail "$f: changed by -pp: $(head -c 200 $W/err)"
done
echo "$n files of ix unchanged by -pp, $derived with a deriving, a [%mli] or a [%bits] rewritten (but the failures above)"

for p in $T/*.ml $T/*/; do
  [ "$p" = "$T/errors/" ] && continue
  p=${p%/}; name=$(basename $p .ml); d=$W/$name; mkdir -p $d
  if [ -d $p ]; then dir=$p; srcs=$(cd $p && ls *.mli *.ml); else dir=$(dirname $p); srcs=$(basename $p); fi
  out=$T/$name.out
  (cd $dir && for s in $srcs; do $ML -pp $s > $d/$s || exit 1; done) || { fail "$name: -pp"; continue; }
  # the .mlis first (a directory's units are one, for now)
  order=$(cd $d && ls *.mli 2>/dev/null; ls *.ml)
  # the output and the exit status, as run.sh's .out files
  (cd $d && ocamlc -o prog $order > $d/log 2>&1 && { ./prog > $d/out; echo "exit $?" >> $d/out; }) || { fail "$name: $(head -3 $d/log)"; continue; }
  cmp -s $d/out $out && echo "ok $name" || fail "$name: not $out"
done

for f in $T/errors/*.ml; do
  want=$(head -1 $f | sed -E 's/^\(\* expected: (.*) \*\)$/\1/')
  (cd $T/errors && $ML -pp $(basename $f)) > $W/$(basename $f)
  got=$(cd $W && ocamlc -c $(basename $f) 2>&1 | head -1 | sed 's/:$//')
  [ "$got" = "$want" ] && echo "ok errors/$(basename $f)" || fail "errors/$(basename $f): $got, not $want"
done

if [ -n "${MINI_ML:-}" ]; then
  $ROOT/languages/ml/tests/run.sh 7 $W/run $T/*.ml $(ls -d $T/*/ | grep -v errors) || failures=$((failures + 1))
fi

echo "$failures failures"
[ $failures = 0 ]
