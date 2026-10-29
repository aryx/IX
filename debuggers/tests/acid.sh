#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-acid's language (plan_debugger.md, stage 8's step 3): each
# script of acid/ given to mini-acid, its output (the prompts and the
# errors included) byte for byte as recorded, acid/NAME.out, which is
# principia's acid's under mini-5i (its own messages at the start, of
# the program and the libraries it did not find, taken out). With
# live: principia's acid run again, its output the expected one
# ($PRINCIPIA, ~/principia by default; not make test's).
# usage: debuggers/tests/acid.sh [live]

ROOT=$(cd $(dirname $0)/../.. && pwd)
IX=$ROOT/_build/default
T=$ROOT/debuggers/tests/acid
P=${PRINCIPIA:-$HOME/principia}
W=$(mktemp -d)
trap 'rm -rf $W' EXIT
n=0; failures=0
for f in $T/*.acid; do
  name=$(basename $f .acid)
  n=$((n + 1))
  if [ "$1" = live ]; then
    timeout 60 $IX/machine/Main.exe $P/ROOT/arch/arm/bin/acid -l /dev/null < $f 2>&1 \
      | grep -a -v "8.out: file does not exist\|pushfile: /lib/acid\|^no symbol information" | sed '1{/^$/d}' > $W/expected
  else cp $T/$name.out $W/expected; fi
  timeout 60 $IX/debuggers/acid/Main.exe < $f > $W/got 2>&1
  cmp -s $W/expected $W/got || { failures=$((failures + 1)); echo "FAIL $name"; diff $W/expected $W/got | head -6; }
done
echo "acid: $n scripts as acid's, $failures failure(s)"
[ $failures = 0 ]
