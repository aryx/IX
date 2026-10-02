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
#   pcprof.py samples.txt listing.txt [N]      (mini-ld -v ... > listing.txt)

import bisect, collections, subprocess, sys

samples, elf = sys.argv[1], sys.argv[2]
top = int(sys.argv[3]) if len(sys.argv) > 3 else 20
syms = []
# (or mini-ld -v's listing, for a kernel built by ix's tools, which has
# no ELF: its lines "address: word TEXT name+0(SB), $frame"; an OCaml
# int has 63 bits, so the addresses are compared without their top bit)
MASK = (1 << 63) - 1
if elf.endswith(".txt"):
    for l in open(elf):
        f = l.split()
        if len(f) > 3 and f[2] == "TEXT": syms.append((int(f[0].rstrip(":"), 16) & MASK, f[3].split("+")[0].rstrip(",")))
else:
  for l in subprocess.run(["nm", "-n", elf], capture_output=True, text=True).stdout.splitlines():
    f = l.split()
    if len(f) == 3 and f[1] in "tT": syms.append((int(f[0], 16) & MASK, f[2]))
addrs = [a for a, _ in syms]
count, total = collections.Counter(), 0
for l in open(samples):
    pc, n = l.split(); pc, n = int(pc, 16) & MASK, int(n); total += n
    i = bisect.bisect_right(addrs, pc) - 1
    count[syms[i][1] if i >= 0 else "(user)"] += n
for name, n in count.most_common(top): print("%5.1f%% %s" % (100 * n / total, name))
