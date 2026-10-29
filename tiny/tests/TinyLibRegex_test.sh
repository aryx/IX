#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyLibRegex.ml, grep's and the editor's regular
# expressions, on the host, built by OCaml: TinyLibRegex_tests/Cases.ml
# checks cases whose answers are written by hand (bytes, classes, ^ $,
# repeats, leftmost-longest, groups, search from p to lim and
# backwards, sam's errors), then the same patterns against m-ix's Regex
# (libregexp's algorithm, the twin), then "(a*)*b" on 3,000 letters a,
# exponential for a backtracker without its memo. A line each; the
# failed ones said.
# usage: TinyLibRegex_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CASES=${CASES:-$ROOT/_build/default/tiny/tests/TinyLibRegex_tests/Cases.exe}

out=$(timeout 10 $CASES)
status=$?
echo "ok $(echo "$out" | grep -c '^ok') cases"
echo "$out" | grep -v '^ok'
failures=$(echo "$out" | grep -c '^FAIL')
[ $status = 0 ] || [ $failures != 0 ] || failures=1
echo "$failures failure(s)"
[ $failures = 0 ]
