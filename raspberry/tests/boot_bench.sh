#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-9pi booted from its card by the Pi 1's board alone (Boot_bench.ml:
# no terminal, no window), natively and compiled by js_of_ocaml under
# node: to the shell's prompt, then two commands; for each the seconds,
# the instructions and the speed. The instructions must be the same
# both ways (the board's time is its instructions). plan_web.md, stage 1.
#
# Usage: raspberry/tests/boot_bench.sh [dune's options, as --profile release --build-dir /tmp/b]
# Needs: dune, js_of_ocaml, node; mini-9pi built (make -C kernels/9pi card).
# Not a test of make test: minutes, and its numbers are the host's.
# With no option it builds in _build with dune's default profile, whose
# JavaScript is compiled file by file: slower than release's (5.8
# million instructions a second against 3.3, 2026-10-10).

set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
dir=_build
prev=; for a in "$@"; do [ "$prev" = --build-dir ] && dir=$a; prev=$a; done
case $dir in /*) ;; *) dir=$root/$dir;; esac
cd "$root"
dune build "$@" ./raspberry/tests/Boot_bench.exe ./raspberry/tests/Boot_bench.bc.js 2> /dev/null
b=$dir/default/raspberry/tests
cd kernels/9pi
for how in native node; do
  echo "$how:"
  if [ $how = native ]; then run=$b/Boot_bench.exe; else run="node --max-old-space-size=4096 $b/Boot_bench.bc.js"; fi
  $run kernel-pi1-ix.img build/card.img -- "ls /bin | wc" "cat /usr/pad/readme | wc" > /dev/null
done
