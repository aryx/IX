#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A callgrind profile said short (perf.sh -callgrind): the functions by
# their own cost, then the callers of those named. The inclusive costs
# are not shown: with recursive functions callgrind's are not to be
# read.
# usage: callgrind_top.py callgrind.out count [function...]

import re, subprocess, sys

out, count, wanted = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
LINE = re.compile(r"\s*([\d,]+) \(\s*([\d.]+)%\)\s+(?:[<>*]\s+)?(\S+)(?: \(([\d,]+)x\))?")

def short(name):
    return re.sub(r"^caml", "", name.split(":")[-1])

print("-- by their own cost")
shown = 0
for line in subprocess.run(["callgrind_annotate", out], capture_output=True, text=True).stdout.split("\n"):
    m = LINE.match(line)
    if m and "PROGRAM" not in line and shown < count:
        print("%6s%%  %s" % (m.group(2), short(m.group(3))))
        shown += 1
callers = subprocess.run(["callgrind_annotate", "--tree=caller", out], capture_output=True, text=True).stdout.split("\n")
for want in wanted:
    for i, line in enumerate(callers):
        if " * " in line and want in line:
            print("-- callers of", want.strip())
            block, j = [], i - 1
            while j >= 0 and callers[j].strip() and " * " not in callers[j] and not callers[j].startswith("---"):
                block.append(callers[j]); j -= 1
            cost = lambda l: int(LINE.match(l).group(1).replace(",", "")) if LINE.match(l) else 0
            for l in sorted(block, key=cost, reverse=True)[:12]:
                m = LINE.match(l)
                if m: print("%6s%%  %-56s %s calls" % (m.group(2), short(m.group(3))[:56], m.group(4) or "?"))
            break
