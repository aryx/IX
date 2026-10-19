#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What no run reached inside the definitions that did run: coverage.py
# cuts a file in whole definitions, which says nothing of a builtin
# that is one entry of a table, or one arm of a match. Here each run
# of lines whose points were all left at 0 (a line with no point
# going with the run it is in), at least [min] lines long, with its
# first line: the candidates to read, and to cut if no page needs them.
#
# usage: coverage_lines.py on.json [min] [prefix]   (run from coverage_ix.sh's DIR/src)
#   on.json: coverage_ix.sh's, every run with scripts and without
#   min: the shortest run said (default 4)
#   prefix: the files looked at (default browsers/)

import json, sys

path = sys.argv[1]
least = int(sys.argv[2]) if len(sys.argv) > 2 else 4
prefix = sys.argv[3] if len(sys.argv) > 3 else 'browsers/'

total = 0
for f in sorted(json.load(open(path))['source_files'], key=lambda f: f['name']):
    name, cov = f['name'], f['coverage']
    if not name.startswith(prefix) or '/tests/' in name or '/opti/' in name:
        continue
    lines = open(name).read().split('\n')
    runs, start, dead = [], None, False
    for i, c in enumerate(cov + [1]):
        if c is not None:
            dead = c == 0
        if dead and start is None:
            start = i
        elif not dead and start is not None:
            runs.append((start, i))
            start = None
    runs = [(a, b) for a, b in runs if b - a >= least]
    if not runs:
        continue
    n = sum(b - a for a, b in runs)
    total += n
    print('%5d  %s' % (n, name))
    for a, b in runs:
        print('       %4d-%-4d %3d  %s' % (a + 1, b, b - a, lines[a].strip()[:90]))
print('%5d  in all' % total)
