#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-9pi's boot to rc's prompt under mini-qemu, for the collector's
# parameters PARAMS (CAMLRUNPARAM's: s the minor heap, i the heap's
# increment, both in words, o the space overhead; none, ocaml-light's
# defaults), plan_9pi_gc.md's measure: the host's seconds of RUNS
# boots, then one more with v=1, its collections counted from the
# markers the runtime prints (< a minor one, $ a major cycle's end),
# apart, as printing them slows the boot.
#
# Usage: gc_boot.sh [PARAMS [RUNS [BOARD]]]   (BOARD pi1, the default, or pi4)

set -e
P=${1:-}
N=${2:-3}
BOARD=${3:-pi1}
cd "$(dirname "$0")/../.."
S=../lib/session.py
W=$(mktemp -d)
trap 'rm -rf $W' EXIT

boot() { # params out [session.py's options]
  make -s BOARD=$BOARD CAMLRUNPARAM="$1" > /dev/null 2>&1
  local cmd; cmd=$(make -s -n BOARD=$BOARD CAMLRUNPARAM="$1" run | tail -1)
  $S --prompt "% " --timeout 300 --out $2 "${@:3}" -- $cmd > /dev/null
}

times=()
for i in $(seq $N); do
  t0=$(date +%s.%N)
  boot "$P" $W/out
  times+=($(echo "$(date +%s.%N) - $t0" | bc))
done
# the markers go on after the prompt (an idle kernel still allocates):
# up to its first "% " only
boot "${P:+$P,}v=1" $W/v --until "% "
python3 -c 'import sys; t = open(sys.argv[1]).read(); open(sys.argv[1], "w").write(t[:t.index("% ")])' $W/v
minor=$(tr -cd '<' < $W/v | wc -c)
major=$(tr -cd '$' < $W/v | wc -c)
printf '%-24s boot %s s (%s), %d minor, %d major collections\n' "${P:-(defaults)}" \
  "$(printf '%s\n' "${times[@]}" | sort -n | sed -n "$(( (N + 1) / 2 ))p")" "$(printf '%.1f ' "${times[@]}")" $minor $major
