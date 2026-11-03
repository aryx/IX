#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-analyze on toy programs: each directory of tests/c/ and
# tests/ml/, and of dead/, caps/, exn/ and bugs/ by their option (its .c
# or .ml files one program) against its expected.out, read, not made by
# another analysis. A directory of bugs/ is a fix's commit: Before.ml the
# code before it, reported, After.ml after it, not; one of raises/, C
# and ML, -bugs's check of the externals' [@@raise] against the C.
# usage: analyzers/tests/run.sh [-record]   (dune build first)
# ANALYZE: the program, if not dune's.
cd "$(dirname "$0")/../.."
ANALYZE=${ANALYZE:-_build/default/analyzers/Main.exe}
W=$(mktemp -d); trap 'rm -rf $W' EXIT
failures=0
for d in analyzers/tests/c/*/ analyzers/tests/ml/*/ analyzers/tests/dead/*/ analyzers/tests/caps/*/ analyzers/tests/exn/*/ analyzers/tests/bugs/*/ analyzers/tests/raises/*/; do
  d=${d%/}; n=$(basename $d)
  case $d in */dead/*) n=dead_$n; flag=-dead;; */caps/*) n=caps_$n; flag=-caps;; */exn/*) n=exn_$n; flag=-exn;; */bugs/*) n=bugs_$n; flag=-bugs;; */raises/*) n=raises_$n; flag=-bugs;; *) flag=;; esac
  # (a .mli is found beside its .ml)
  $ANALYZE $flag $(ls $d/*.c $d/*.ml 2> /dev/null) > $W/$n.out 2>&1
  if [ "${1:-}" = -record ]; then cp $W/$n.out $d/expected.out; echo "recorded $d/expected.out"
  elif cmp -s $W/$n.out $d/expected.out; then echo "ok mini-analyze: $n"
  else echo "FAIL mini-analyze: $n"; diff $d/expected.out $W/$n.out | head -10; failures=$((failures + 1)); fi
done
exit $failures
