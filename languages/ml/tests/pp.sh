#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mlpp, mini-ml -pp (plan_ml_bootstrap.md, decision 7):
# - every .ml and .mli of ix, which use none of its constructs (but
#   pp/'s), comes back unchanged;
# - each program of pp/ (a file, or a directory of units), rewritten,
#   compiled by OCaml and run, prints its .out;
# - each file of pp/errors/, rewritten, gets from OCaml the error its
#   first line expects: the source's line and columns, through the #
#   lines; or, "expected-pp:", from mini-ml -pp itself (the classes');
# - with MINI_ML=1, pp/'s programs compiled by mini-ml too (run.sh 7).
# usage: pp.sh

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
ML=${ML:-$ROOT/_build/default/languages/ml/Main.exe}
T=$ROOT/languages/ml/tests/pp
# the stdlib, for the classes (their dictionaries need the names and the
# types): ix's, lib_core's directories of it
S=$(for u in $(grep -v '^#' $ROOT/lib_core/units.txt); do echo "-I $ROOT/lib_core/$(dirname $u)"; done | sort -u | tr '\n' ' ')
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
fail() { echo "FAIL $*"; failures=$((failures + 1)); }

cd $ROOT
# (a file of ix with a [@@deriving show], a type t = [%mli], a [%bits], a [%list] or a class is one -pp
# rewrites: it must only do so without an error; the others come out as
# they are)
n=0; derived=0
for f in $(git ls-files '*.ml' '*.mli' | grep -v '^languages/ml/tests/pp/'); do
  if grep -q '^\[@@deriving show\]$\| \[@@deriving show\]$\|^type .* = \[%mli\]$\|\[%bits "\|\[%list \| |! \|\[%using: \|\[@@class\]\|\[@@instance\]' $f; then
    derived=$((derived + 1))
    $ML -pp $S $f > /dev/null 2> $W/err || fail "$f: -pp: $(head -c 200 $W/err)"
    continue
  fi
  n=$((n + 1))
  $ML -pp $f 2> $W/err | cmp -s - $f || fail "$f: changed by -pp: $(head -c 200 $W/err)"
done
echo "$n files of ix unchanged by -pp, $derived with a deriving, a [%mli], a [%bits], a [%list] or a class rewritten (but the failures above)"

for p in $T/*.ml $T/*/; do
  [ "$p" = "$T/errors/" ] && continue
  p=${p%/}; name=$(basename $p .ml); d=$W/$name; mkdir -p $d
  if [ -d $p ]; then dir=$p; srcs=$(cd $p && ls *.mli *.ml); else dir=$(dirname $p); srcs=$(basename $p); fi
  out=$T/$name.out
  (cd $dir && for s in $srcs; do $ML -pp $S $s > $d/$s || exit 1; done) || { fail "$name: -pp"; continue; }
  # the .mlis first (a directory's units are one, for now)
  order=$(cd $d && ls *.mli 2>/dev/null; ls *.ml)
  # the output and the exit status, as run.sh's .out files
  # (the units of a directory in their order: its file order, if it has one)
  [ -f $p/order ] && order=$(cat $p/order)
  (cd $d && ocamlc -o prog $order > $d/log 2>&1 && { ./prog > $d/out; echo "exit $?" >> $d/out; }) || { fail "$name: $(head -3 $d/log)"; continue; }
  cmp -s $d/out $out && echo "ok $name" || fail "$name: not $out"
done

for f in $T/errors/*.ml; do
  want=$(head -1 $f | sed -E 's/^\(\* expected(-pp)?: (.*) \*\)$/\2/')
  (cd $T/errors && $ML -pp $S $(basename $f)) > $W/$(basename $f) 2> $W/err
  if head -1 $f | grep -q 'expected-pp:'; then got=$(head -1 $W/err)
  else got=$(cd $W && ocamlc -c $(basename $f) 2>&1 | head -1 | sed 's/:$//'); fi
  [ "$got" = "$want" ] && echo "ok errors/$(basename $f)" || fail "errors/$(basename $f): $got, not $want"
done

if [ -n "${MINI_ML:-}" ]; then
  $ROOT/languages/ml/tests/run.sh 7 $W/run $T/*.ml $(ls -d $T/*/ | grep -v errors) || failures=$((failures + 1))
fi

echo "$failures failures"
[ $failures = 0 ]
