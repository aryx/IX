#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny-machine's speed (plan_web.md, stage 2): a recorded session of
# tiny-kernel's (tiny/tests/TinyKernel_tests/*.events: the mouse and the keys by the
# machine's time, so the same instructions on every run) by the native
# tiny-machine and by the same program compiled by js_of_ocaml, under
# node; for each the seconds, the millions of instructions a second
# (the session's last event's time is its count, to a few thousand), and
# whether the screen at the halt is the recorded one. That count is the
# machine's time, so it includes the time the machine slept in a wfi,
# which costs the host nothing: a session that idles (paint) shows a
# higher rate than one that computes (office, tetris). The page
# (TinyMachineWeb.ml) wants TinyMachineDevices.rate, 8 million a second, of
# what node gives less a frame's other work.
#
# Usage: TinyMachine_bench.sh [session, default paint] [-prof]
#   -prof  node's profile too: the functions' own time, the first 15
# Needs: dune, ocamlfind, js_of_ocaml, node; tiny-kernel's boot.img and
# disk.img built (make -C tiny/TinyKernel). Not a test of make test: its
# numbers are the host's.

set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
s=paint; prof=0
for a in "$@"; do case $a in -prof) prof=1;; *) s=$a;; esac; done
K=$ROOT/tiny/TinyKernel
S=$ROOT/tiny/tests/TinyKernel_tests
B=$ROOT/_build/default
W=$(mktemp -d); trap 'rm -rf $W' EXIT
[ -f $K/_make/boot.img ] && [ -f $K/_make/disk.img ] || { echo "no $K/_make/boot.img or disk.img: make -C tiny/TinyKernel"; exit 1; }

cd $ROOT
# tiny-machine's libraries in the order of its native link (dune rules
# ./tiny/TinyMachine.exe), as bytecode
LIBS="lib_core/commons/ix_core tiny/tiny_lib_machine tiny/TinyMachine/tiny_machine_cpu
  tiny/TinyMachine/tiny_machine_devices tiny/TinyKernel/tiny_kernel_network
  tiny/TinyBrowser/tiny_browser_parts tiny/TinyMachine/tiny_machine_peer
  lib_core/parallel/ix_parallel tiny/TinyLibSystem/unix/tiny_lib_system_unix"
dune build ./tiny/TinyMachine.exe $(for l in $LIBS; do echo ./$l.cma; done) \
  ./tiny/.TinyMachine.eobjs/byte/dune__exe__TinyMachine.cmo
ocamlfind ocamlc -g -package caps,fpath,unix,logs,logs.fmt,fmt,astring,ppx_deriving.runtime -linkpkg \
  $(for l in $LIBS; do echo $B/$l.cma; done) $B/tiny/.TinyMachine.eobjs/byte/dune__exe__TinyMachine.cmo -o $W/tm.bc
js_of_ocaml --opt 3 $([ $prof = 1 ] && echo --pretty --debug-info) $ROOT/machine/tests/bench_js_stubs.js $W/tm.bc -o $W/tm.js 2>/dev/null

n=$(tail -1 $S/$s.events | cut -d' ' -f1)
run() { # name command...
  local name=$1; shift
  # the programs are on the system's disk, a fresh copy grown to 64 MB for
  # each run, as make check gives each session; and make check's date
  # and seed (tetris's pieces are random)
  cp $K/_make/disk.img $W/d.img; truncate -s 64M $W/d.img
  local t0=$(date +%s.%N)
  "$@" -date 820540800 -seed 1 -d $W/d.img -events $S/$s.events -screen $W/s.ppm $K/_make/boot.img > /dev/null
  local t1=$(date +%s.%N)
  local same=another; [ "$(cksum < $W/s.ppm)" = "$(cat $S/$s.cksum)" ] && same=recorded
  echo "$name $s.events: $(echo "$t1 $t0 $n" | awk '{ printf "%.1f s, %.1f million instructions a second", $1 - $2, $3 / ($1 - $2) / 1e6 }'), the screen the $same one"
}
run "native" $B/tiny/TinyMachine.exe
run "node  " node $([ $prof = 1 ] && echo --cpu-prof --cpu-prof-dir=$W/prof) $W/tm.js
if [ $prof = 1 ]; then
  python3 - $W/prof/*.cpuprofile <<'PY'
import json, sys, collections
p = json.load(open(sys.argv[1])); nodes = {n['id']: n for n in p['nodes']}
own = collections.Counter()
for s, d in zip(p['samples'], p['timeDeltas']):
    f = nodes[s]['callFrame']; own[(f['functionName'] or '(a closure)') + ':' + str(f['lineNumber'])] += d
total = sum(own.values())
for k, v in own.most_common(15): print(f"  {100 * v / total:5.1f}%  {k}")
PY
fi
