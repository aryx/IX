#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The examples built by ix's tools for Linux (../mkfile), run: what
# hello, helloml and procsml print (procsml's pids as N), and the sum of
# the frame that game and counter end with (the platform without a
# window, as games/tests/frames.sh), against run.expected. RECORD=1
# writes it again. fetchml is not run: it needs another machine.
# Where the host is not Linux on arm64, mini-5i runs them.
# usage: examples/tests/run.sh [dir]
#   dir: where the programs are (default: _mk/7/examples)
cd "$(dirname "$0")/../.."
dir=${1:-_mk/7/examples}
run=; [ "$(uname -sm)" = "Linux aarch64" ] || run=bin/mini-5i
W=$(mktemp -d); trap 'rm -rf $W' EXIT
{
  $run $dir/hello
  $run $dir/helloml
  $run $dir/procsml | sed 's/[0-9][0-9]*/N/g'
  for p in game counter; do
    $run $dir/$p -dump-frame 60 $W/$p.ppm -fixed-time 1000 > /dev/null
    echo "$p: frame 60 $(sha256sum < $W/$p.ppm | cut -d' ' -f1)"
  done
} > $W/out 2>&1
[ -n "${RECORD:-}" ] && cp $W/out examples/tests/run.expected
if diff examples/tests/run.expected $W/out; then echo "ok examples: hello, helloml, procsml, game, counter"
else echo "FAIL examples: another output than the recorded one"; fi
