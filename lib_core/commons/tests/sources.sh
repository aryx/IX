#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Source's check (plan_rio.md, stage 4): Sources.ml, the same program
# with OCaml's threads (dune's build) and with mini-ml's (mini-mk here:
# arm64 Linux, and Plan 9 on arm under mini-5i), the same lines.
# usage: lib_core/commons/tests/sources.sh    (after dune build)

ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
export PATH=$ROOT/bin:$PATH
cd $ROOT/lib_core/commons/tests
want='got: hello
got: again
the end: 0 bytes
two: b
one: a
one: c
two: d
3 ticks'
failures=0
check() {
  local what=$1; shift
  if [ "$(timeout 60 "$@" 2>&1)" = "$want" ]; then echo "ok Source: $what"; else echo "FAIL Source: $what"; failures=$((failures + 1)); fi
}
check "OCaml's threads" $ROOT/_build/default/lib_core/commons/tests/Sources.exe
(cd $ROOT/lib_core && mini-mk > /dev/null) && mini-mk > /dev/null && check "mini-ml's threads, arm64" $ROOT/_mk/7/lib_core/commons/tests/sources
(cd $ROOT/lib_core && mini-mk O=5 OS=plan9 > /dev/null) && mini-mk O=5 OS=plan9 > /dev/null && check "mini-ml's threads, Plan 9 on arm under mini-5i" mini-5i $ROOT/_mk/5-plan9/lib_core/commons/tests/sources
echo "$failures failures"
[ $failures = 0 ]
