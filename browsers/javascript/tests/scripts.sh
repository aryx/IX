#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-node on scripts/*.js: what each prints against its .expected
# (which is also what Node prints: checked when written, and here
# again where there is a node); and a console's lines.
#
# usage: scripts.sh [dir]   (dir: where mini-node is; default: dune's)

HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd $HERE/../../.. && pwd)
if [ $# -ge 1 ]; then NODE=$(realpath $1)/mini-node; else NODE=$ROOT/_build/default/browsers/javascript/Main.exe; fi
fail=0
for js in $HERE/scripts/*.js; do
  $NODE $js 2>&1 | cmp -s - ${js%.js}.expected || { echo "FAIL $(basename $js): $($NODE $js 2>&1 | diff - ${js%.js}.expected | head -3)"; fail=1; }
  if command -v node > /dev/null; then node $js 2>&1 | cmp -s - ${js%.js}.expected || { echo "FAIL $(basename $js): Node says otherwise"; fail=1; }; fi
done
got=$(printf '1 + 1\nvar o = {x: 1}\no.x + "s"\nnope\n[1, "a"]\n' | $NODE 2>&1 | tr '\n' '|')
want='2|undefined|1s|ReferenceError: nope is not defined|[1, "a"]|'
[ "$got" = "$want" ] || { echo "FAIL the console: $got"; fail=1; }
$NODE -e 'throw 1' > /dev/null 2>&1 && { echo "FAIL a script that throws: status 0"; fail=1; }
[ $fail = 0 ] && echo "ok: mini-node's scripts"
exit $fail
