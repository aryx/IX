#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# node's profile of Boot_jit by function (plan_web.md, 2026-10-11):
# where the emulator's own time goes with the translator, the blocks
# together as "(block)" or f.
#   usage: jit_profile.sh D Boot_bench's arguments...
#   e.g.   jit_profile.sh /tmp/p -ips 12 kernel-pi1-web.img build/card.img -do "k rio_; s 40" --
# (run from kernels/9pi as Boot_bench; the boot is in the profile too)
# Needs: node; dune build ./raspberry/tests/Boot_jit.bc.js.
R=$(cd "$(dirname "$0")/../.." && pwd); S=${1:?a directory}; shift
rm -rf $S/jprof; mkdir -p $S
node --max-old-space-size=4096 --cpu-prof --cpu-prof-dir=$S/jprof $R/_build/default/raspberry/tests/Boot_jit.bc.js "$@" 2>&1 > /dev/null | tail -6
python3 - $S/jprof/*.cpuprofile <<'PY'
import json, sys, collections
p = json.load(open(sys.argv[1]))
nodes = {x['id']: x for x in p['nodes']}
own = collections.Counter(); total = 0
for s, d in zip(p['samples'], p['timeDeltas']):
    f = nodes[s]['callFrame']
    name = f['functionName'] or ('(block)' if f['url'] == '' or f['lineNumber'] < 3 else '(closure:%d)' % f['lineNumber'])
    own[name] += d; total += d
for k, v in own.most_common(24): print(f"  {100 * v / total:5.1f}%  {k}")
PY
