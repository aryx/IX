#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What each site's scripts reach in javascript/ and webapi/ beyond what
# every page reaches: coverage_ix.sh's runs. The preludes (Js_prelude,
# Script_prelude: JavaScript run before a page's own) reach much of the
# language by themselves, so a page with one line of script is the
# baseline, on0.json; on1.json... are the sites', in sites.txt's order.
# Counted in lines of whole top-level definitions with a point reached
# (coverage.py's cut): an upper bound.
#
# usage: coverage_sites.py DIR   (coverage_ix.sh's DIR; run from DIR/src,
#   where the JSON's names are)

import collections, json, os, re, sys

d = os.path.realpath(sys.argv[1])
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'coverage.py')).read()
exec(src[src.index('START = '):src.index('# of a definition under a run')])

WHERE = ('javascript', 'webapi')

def reached(path):
    r = {}
    for f in json.load(open(path))['source_files']:
        name, cov = f['name'], f['coverage']
        if not name.startswith('browsers/') or '/tests/' in name:
            continue
        for defn, a, b in definitions(open(name).read().split('\n')):
            pts = [c for c in cov[a:b] if c is not None]
            if pts and any(pts):
                r[(name, defn, a)] = b - a
    return r

def by_dir(r, keep=lambda k: True):
    g = collections.Counter()
    for k, v in r.items():
        w = k[0].split('/')[1]
        if w in WHERE and keep(k):
            g[w] += v
    return dict(g)

sites = [l.split(' ', 1)[1] for l in open(os.path.join(d, 'runs/sites.txt')).read().split('\n') if l]
runs = [reached(os.path.join(d, 'on%d.json' % n)) for n in range(len(sites) + 1)]
base = runs[0]
print('the baseline (a page of one line of script: the preludes):', by_dir(base))
for n, s in enumerate(sites, 1):
    print('%-52s beyond it: %s' % (s, by_dir(runs[n], lambda k: k not in base)))
every = {}
for r in runs:
    every.update(r)
print('all the runs:', by_dir(every))
