#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What of each file of docs/plans/plan_browser.md's tables a Wikipedia
# article runs: browsers/coverage.sh's report, from bisect_ppx's
# per-line counts (bisect-ppx-report coveralls) of the runs without
# scripts and with them.
#
# A file is cut in its top-level definitions (a let, and, type or
# module at column 0, with the comment above it). A definition is
#   never run: it has points and none was reached: the solid cut
#   in part:   some reached; the lines after a point not reached, up
#              to the next point, are counted "not run": an estimate
#              (a point is where an expression starts, not a line)
#   no point:  types, constants, a module's header
#
# usage: coverage.py [-v] sets.txt off.json on.json [root]
#   sets.txt: survey.sh -files's ("where file" a line)
#   -v: each definition never run, by file, with its lines
#   root: what the names in the JSON are relative to

import json, re, sys

args = sys.argv[1:]
verbose = '-v' in args
args = [a for a in args if a != '-v']
sets, off_json, on_json = args[:3]
root = args[3] if len(args) > 3 else '.'

def load(path):
    return {f['name']: f['coverage'] for f in json.load(open(path))['source_files']}
off, on = load(off_json), load(on_json)

START = re.compile(r'(let|and|type|module|exception|external|open|include)\b')
NAME = re.compile(r'(?:let|and)\s+(?:rec\s+)?(?:\(\s*)?([A-Za-z_0-9\']+|\([^)]*\))')

# the definitions of a file: (name, first line, last line), 0-based,
# a comment at column 0 going with the definition under it
def definitions(lines):
    starts = []
    pending = None
    depth = 0
    for i, l in enumerate(lines):
        if depth == 0 and l.startswith('(*') and pending is None:
            pending = i
        if depth == 0 and START.match(l):
            m = NAME.match(l)
            starts.append((m.group(1) if m else l.split()[0], pending if pending is not None else i))
            pending = None
        elif depth == 0 and l.strip() == '' and not (i > 0 and lines[i - 1].rstrip().endswith('*)')):
            pending = None
        depth += l.count('(*') - l.count('*)')
        depth = max(depth, 0)
    defs = []
    for k, (name, a) in enumerate(starts):
        b = starts[k + 1][1] if k + 1 < len(starts) else len(lines)
        while b > a and lines[b - 1].strip() == '':
            b -= 1
        defs.append((name, a, b))
    return defs

# of a definition under a run: its state, and its lines not run
def under(cov, a, b):
    pts = [c for c in cov[a:b] if c is not None]
    if not pts:
        return 'none', 0
    if not any(pts):
        return 'never', b - a
    n, dead = 0, False
    for c in cov[a:b]:
        if c is not None:
            dead = c == 0
        n += dead
    return 'part', n

groups = {}
for l in open(sets):
    where, f = l.rsplit(' ', 1)
    if not where.startswith('the '):   # "the engine whole": the seven again
        groups.setdefault(where, []).append(f.strip())

def rel(f):
    for k in ('/mini-chrome/', '/ocaml-elm-playground/', '/playground/'):
        if k in f:
            return ('mini-chrome/' if 'mini-chrome' in k else 'playground/') + f.split(k, 1)[1]
    return f

tot = [0] * 5
print('lines of .ml; in definitions never run without scripts, and with them; '
      'and, with them, the estimate of lines not run in the others')
for where in groups:
    print('== ' + where)
    g = [0] * 5
    detail = []
    for f in sorted(groups[where]):
        if not f.endswith('.ml'):
            continue
        r = rel(f)
        lines = open(f).read().split('\n')
        n = len(lines) - 1
        if r not in on:
            print('  %-24s %5d  not linked, or not instrumented' % (r.split('/')[-1], n))
            g[0] += n; g[1] += n; g[2] += n
            continue
        row = [n, 0, 0, 0, 0]
        names = []
        for name, a, b in definitions(lines):
            s_off, n_off = under(off[r], a, b)
            s_on, n_on = under(on[r], a, b)
            if s_off == 'never': row[1] += n_off
            if s_on == 'never':
                row[2] += n_on
                names.append('%s(%d)' % (name, n_on))
            elif s_on == 'part':
                row[3] += n_on
            if s_off == 'never' and s_on != 'never':
                row[4] += n_off
        print('  %-24s %5d  %5d %5d  %5d' % (r.split('/')[-1], *row[:4]))
        if verbose and names:
            detail.append('    %s: %s' % (r.split('/')[-1], ' '.join(names)))
        for i in range(5): g[i] += row[i]
    print('  %-24s %5d  %5d %5d  %5d   (%d%% never run with scripts, %d%% with the estimate; scripts alone reach %d lines)'
          % ('all', *g[:4], 100 * g[2] // max(g[0], 1), 100 * (g[2] + g[3]) // max(g[0], 1), g[4]))
    for d in detail: print(d)
    for i in range(5): tot[i] += g[i]
print('== all\n  %-24s %5d  %5d %5d  %5d' % ('', *tot[:4]))
