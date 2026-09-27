#!/usr/bin/env python3
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# A guest profile's PCs mapped to the kernel's functions: the samples'
# file (lines "pc count", hexadecimal pc, from the sampler in
# docs/notes_performance.md) against the kernel ELF's symbols (nm -n),
# each PC charged to the symbol at or below it; the top N (default 20),
# as shares of all the samples. PCs below the kernel's first symbol
# are user programs'.
#
#   pcprof.py samples.txt build/pi1-ocaml/kernel.elf [N]

import bisect, collections, subprocess, sys

samples, elf = sys.argv[1], sys.argv[2]
top = int(sys.argv[3]) if len(sys.argv) > 3 else 20
syms = []
for l in subprocess.run(["nm", "-n", elf], capture_output=True, text=True).stdout.splitlines():
    f = l.split()
    if len(f) == 3 and f[1] in "tT": syms.append((int(f[0], 16), f[2]))
addrs = [a for a, _ in syms]
count, total = collections.Counter(), 0
for l in open(samples):
    pc, n = l.split(); pc, n = int(pc, 16), int(n); total += n
    i = bisect.bisect_right(addrs, pc) - 1
    count[syms[i][1] if i >= 0 else "(user)"] += n
for name, n in count.most_common(top): print("%5.1f%% %s" % (100 * n / total, name))
