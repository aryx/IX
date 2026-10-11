#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A guest's profile (Boot_bench -prof, mini-qemu -prof: a line an
# address and its count) by module and by function, the program's and
# the kernel's together: plan_web.md's numbers of 2026-10-11.
#   usage: guest_profile.py program.syms kernel.syms profile [n]
# program.syms: the program's functions, from the linker's listing (a
# Plan 9 a.out of mini-ld's has no symbols): the link's command again
# with -v, then
#   grep 'TEXT ' listing | sed 's/^\([0-9a-f]*\): [0-9a-f]*\tTEXT \([^+]*\).*/\1 T \2/'
# kernel.syms: nm's lines of the kernel's ELF. A unit of ML's starts at
# its Unit.Init; what is not ML's is "(runtime)". game_profile.sh does
# it all for a game.
import sys, bisect, collections, re
def tab(f):
    s = [(int(l.split()[0], 16), l.split()[2]) for l in open(f)]; s.sort(); return s
us = tab(sys.argv[1]); ks = tab(sys.argv[2])
mod = [None] * len(us); cur = '(runtime)'
for i in range(len(us)):
    if us[i][1].endswith('.Init'): cur = us[i][1][:-5]
    elif not us[i][1].endswith('<>') and cur != '(runtime)' and not us[i][1][0] == 'f': cur = '(runtime)'
    mod[i] = cur
ua = [a for a, _ in us]; ka = [a for a, _ in ks]
f = collections.Counter(); m = collections.Counter()
for l in open(sys.argv[3]):
    a, n = l.split(); a = int(a, 16); n = int(n)
    if a >= 0x80000000:
        i = bisect.bisect_right(ka, a) - 1; name = ks[i][1]
        f['K ' + name] += n; m['K ' + re.sub(r'_[a-z0-9_]*$', '', name) if name[0].isupper() else 'K (C)'] += n
    else:
        i = bisect.bisect_right(ua, a) - 1
        if i < 0: f['u ?'] += n; m['u ?'] += n
        else: f['u %s.%s' % (mod[i], us[i][1])] += n; m['u ' + mod[i]] += n
tot = sum(f.values()); N = int(sys.argv[4]) if len(sys.argv) > 4 else 30
print(tot, "samples")
for s, v in m.most_common(N): print(f"{100 * v / tot:5.1f}% {s}")
print()
for s, v in f.most_common(N): print(f"{100 * v / tot:5.1f}% {s}")
