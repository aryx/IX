#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The test of KAudio.ml on the host, built by OCaml:
# KAudio_tests/Host.ml makes sounds into a ring of KRaw's
# and prints what can be counted of them (the crossings of zero, the
# largest sample, the last, the one after), two sounds at one place,
# the ring going round, messages read and bad ones; against
# sounds.expected. The kernel's own, on tiny-machine, is TinyKernel's
# check (tetris.events' music heard, korobeiniki.wav's sum). RECORD=1
# records.
# usage: KAudio_test.sh

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOST=${HOST:-$ROOT/_build/default/tiny/tests/KAudio_tests/Host.exe}
E=$ROOT/tiny/tests/KAudio_tests/sounds.expected
W=${W:-$(mktemp -d)}
[ -n "${KEEP:-}" ] || trap 'rm -rf $W' EXIT
failures=0

$HOST > $W/sounds.out 2>&1 || { echo "FAIL sounds: the run"; failures=$((failures + 1)); }
[ -n "${RECORD:-}" ] && cp $W/sounds.out $E
if diff $E $W/sounds.out > $W/sounds.diff; then echo "ok sounds"; else echo "FAIL sounds"; head -10 $W/sounds.diff; failures=$((failures + 1)); fi

echo "$failures failure(s)"
[ $failures = 0 ]
