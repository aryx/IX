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
# The instructions a program executes, mini-ml's executable against
# ocaml-light's ocamlopt's, on arm64: both built (and their outputs
# compared) by run.sh with LIVE=1, then counted under qemu-aarch64, one
# instruction a translation block, each block's execution logged (the
# same count as mini-5i -s on mini-ml's; mini-5i cannot run ocamlopt's,
# whose glibc uses NEON). ML_FLAGS: mini-ml's flags (opti's, later).
# For variants/opti.md's numbers.
# usage: count.sh workdir prog.ml...   (needs goken, ocaml-light's arm64
#   ocamlopt as for run.sh, and dune build)
set -u
ROOT=$(cd $(dirname $0)/../../.. && pwd)
W=$(realpath -m $1); shift
LIVE=1 $ROOT/languages/ml/tests/run.sh 7 $W "$@" | grep -v "^ok" >&2
count() { (cd $W/run && qemu-aarch64 -one-insn-per-tb -d exec,nochain -D $W/q.log $1 > /dev/null 2>&1); grep -c '^Trace' $W/q.log; }
echo "program mini-ml ocamlopt ratio"
for ml in "$@"; do
  b=$(basename $ml .ml)
  m=$(count $W/$b); o=$(count ./$b.ref)
  echo "$b $m $o $(awk "BEGIN { printf \"%.2f\", $m / $o }")"
done
rm -f $W/q.log
