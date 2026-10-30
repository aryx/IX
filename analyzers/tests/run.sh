#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze on toy programs: each directory of tests/c/ (its .c
# files one program) against its expected.out, read, not made by
# another analysis.
# usage: analyzers/tests/run.sh [-record]   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
for d in analyzers/tests/c/*/; do
  d=${d%/}; n=$(basename $d)
  $ANALYZE $d/*.c > $W/$n.out 2>&1
  if [ "${1:-}" = -record ]; then cp $W/$n.out $d/expected.out; echo "recorded $d/expected.out"
  elif cmp -s $W/$n.out $d/expected.out; then echo "ok mini-analyze: $n"
  else echo "FAIL mini-analyze: $n"; diff $d/expected.out $W/$n.out | head -10; failures=$((failures + 1)); fi
done
exit $failures
