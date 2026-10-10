#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The interpreters' speed compiled by js_of_ocaml (plan_web.md): mini-5i
# linked as bytecode, turned into JavaScript, and bench.py's loop (arm32
# and arm64) run by the native mini-5i and by node. Each prints its
# line of -s (instructions, seconds, MIPS) after the program's 4 or 8
# bytes of checksum, shown in hexadecimal: the two must be the same.
#
# Usage: machine/tests/bench_js.sh [iterations, default 20000000]
# Needs: dune, ocamlfind, js_of_ocaml, node.
#
# Not a test of make test: it takes a minute and its numbers are the
# host's. The native mini-5i is dune's default profile (release is
# faster: plan_arm.md's 30 MIPS).

set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$here/../..
n=${1:-20000000}
b=$root/_build/default
tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT

cd "$root"
dune build ./machine/Main.exe ./lib_core/commons/ix_core.cma ./machine/ix_machine.cma \
  ./machine/compat/ix_machine_compat.cma ./machine/ix_machine_cli.cma \
  ./machine/.Main.eobjs/byte/dune__exe__Main.cmo

ocamlfind ocamlc -package caps,fpath,unix,logs,fmt -linkpkg \
  $b/lib_core/commons/ix_core.cma $b/machine/ix_machine.cma \
  $b/machine/compat/ix_machine_compat.cma $b/machine/ix_machine_cli.cma \
  $b/machine/.Main.eobjs/byte/dune__exe__Main.cmo -o $tmp/mini5i.bc

# the primitives of Unix that js_of_ocaml has not are named on stderr,
# and fail only if called: bench_js_stubs.js gives the one this run calls
js_of_ocaml --opt 3 "$here/bench_js_stubs.js" $tmp/mini5i.bc -o $tmp/mini5i.js 2>/dev/null

echo "js_of_ocaml $(js_of_ocaml --version), node $(node --version), mini5i.js $(wc -c < $tmp/mini5i.js) bytes"
for arch in 5 7; do
  python3 "$here/bench.py" $arch $n -o $tmp/bench$arch > /dev/null
  for how in native js; do
    if [ $how = native ]; then run="$b/machine/Main.exe"; else run="node $tmp/mini5i.js"; fi
    $run -s $tmp/bench$arch > $tmp/out 2> $tmp/err || true
    # the checksum's bytes are the first of the output; -s's line is after
    sum=$(head -c 8 $tmp/out | od -An -tx1 | tr -d ' \n')
    line=$(cat $tmp/out $tmp/err | tr -c '[:print:]\n' '\n' | grep -o 'mini-5i:.*MIPS' | tail -1)
    echo "arm$( [ $arch = 5 ] && echo 32 || echo 64) $how: $line (first bytes $sum)"
  done
done
