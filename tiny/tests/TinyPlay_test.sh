#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of TinyPlay.ml on the host, built by OCaml:
# TinyPlay_tests/Host.ml reads tiny-kernel's example WAV and WAVs of
# other shapes (8 bits in two channels, a chunk to skip, rates above
# and below 8,000) and prints what the speaker's samples are (how many,
# their sum, the first ones), the file in play's blocks against the
# file at once, and why the files that are no WAV it plays are not;
# against play.expected. play on tiny-kernel is TinyKernel's check
# (/examples/korobeiniki.wav played, a WAV's sum). RECORD=1 records.
# usage: TinyPlay_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/TinyPlay_tests/Host.exe}
E=$ROOT/tiny/tests/TinyPlay_tests/play.expected
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST $ROOT/tiny/TinyKernel/examples/korobeiniki.wav > $W/play.out 2>&1 || { echo "FAIL play: the run"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/play.out $E
if diff $E $W/play.out > $W/play.diff; then echo "ok play"; else echo "FAIL play"; head -10 $W/play.diff; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]
