#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# make test-pi: mini-qemu against QEMU and the kernels by ocaml-light
# and gcc, its scripts side by side. Each one is an emulator or two
# waited on, a core each: one after the other they took 43 minutes
# (docs/test_times.md), most of the machine idle. Each has its own
# kernels, images and build directory; what shares one is one job (the
# two runs of xv6_pi4.py: their copy of xv6; mini-xv6's two boards).
# A job's output is printed when all are done, in the order below,
# with its seconds.
# usage: tests/pi.sh [-u]     (-u: the Pi 1 ports' full usertests too, as XV6_USERTESTS)

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd $ROOT
W=$(mktemp -d); trap 'rm -rf $W' EXIT
dune build --profile release ./raspberry/Main.exe || exit 1
# the kernels' compiler, once, before the jobs that each ask for it
kernels/ocaml-light.sh arm > /dev/null && kernels/ocaml-light.sh arm64 > /dev/null || { echo "FAIL no ocaml-light"; exit 1; }

names=()
job() {
  local name=$1; shift
  names+=("$name")
  local k=$W/job${#names[@]}
  ( t0=$(date +%s); if true | bash -c "$*" > $k.log 2>&1; then s=ok; else s=FAIL; fi
    echo "$s $(( $(date +%s) - t0 ))" > $k.status ) &
}
job "9pi's session" raspberry/tests/9pi.py
job "9pi's graphics, rio" raspberry/tests/9pi_graphics.py
job "xv6's Pi 1 ports booted" raspberry/tests/xv6.sh "$@"
job "xv6's Pi 1 ports' graphics" raspberry/tests/graphics.py
job "xv6 on the Pi 4, usertests, four cores" "raspberry/tests/xv6_pi4.py && raspberry/tests/xv6_pi4.py -smp 4 preempt pipe1 forktest"
job "the kernel's steps" kernels/test.sh $(cd kernels/steps && ls -d step* | tr "\n" " ")
job "mini-xv6, Pi 1 and Pi 4" kernels/test.sh xv6
job "mini-9pi" kernels/test.sh 9pi
wait
failures=0; n=0
for name in "${names[@]}"; do
  n=$((n + 1)); read -r s secs < $W/job$n.status
  echo "== $s $secs s: $name"
  cat $W/job$n.log
  [ $s = ok ] || failures=$((failures + 1))
done
echo "test-pi: ${#names[@]} jobs, $failures failure(s)"
[ $failures = 0 ]
