#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Where the time goes when mini-9pi boots by js_of_ocaml under node
# (Boot_bench.ml; plan_web.md, stage 2): node's profile, the functions'
# own time, then the lines of the JavaScript that take the most, each
# with its text (js_of_ocaml --pretty keeps OCaml's names).
#
# Usage: raspberry/tests/boot_prof.sh [build dir, default _build] [lines, default 40]
# Needs: Boot_bench built in release there (boot_bench.sh --profile
# release [--build-dir D]), js_of_ocaml, node, python3.

set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
dir=${1:-$root/_build}; n=${2:-40}
b=$dir/default/raspberry/tests
tmp=$(mktemp -d); trap 'rm -rf $tmp' EXIT
js_of_ocaml --opt 3 --pretty --debug-info $b/unix_stubs.js $b/Boot_bench.bc-for-jsoo -o $tmp/bb.js 2> /dev/null
cd "$root/kernels/9pi"
node --max-old-space-size=4096 --cpu-prof --cpu-prof-dir=$tmp/prof $tmp/bb.js kernel-pi1-ix.img build/card.img > /dev/null
python3 - $tmp/prof/*.cpuprofile $tmp/bb.js $n <<'PY'
import json, sys, collections
p = json.load(open(sys.argv[1])); src = open(sys.argv[2]).read().split("\n"); n = int(sys.argv[3])
nodes = {x['id']: x for x in p['nodes']}
own = collections.Counter(); lines = collections.Counter(); total = 0
for s, d in zip(p['samples'], p['timeDeltas']):
    f = nodes[s]['callFrame']; own[(f['functionName'] or '(a closure)') + ':' + str(f['lineNumber'])] += d; total += d
# a node's ticks by line (samples, not microseconds): scaled to its own time
for x in p['nodes']:
    for t in x.get('positionTicks', []): lines[(x['callFrame']['functionName'], t['line'])] += t['ticks']
ticks = sum(lines.values())
for k, v in own.most_common(16): print(f"  {100 * v / total:5.1f}%  {k}")
print()
for (f, l), v in lines.most_common(n): print(f"  {100 * v / ticks:5.1f}%  {f}:{l}  {src[l - 1].strip()[:110]}")
PY
