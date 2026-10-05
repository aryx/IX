#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Two parsers' automata compared, state by state: ocamlyacc -v's
# y.output and mini-yacc -v's listing (plan_lex_yacc.md, decision 6,
# the third level). The states' numbers differ, so the two are walked
# together from each start symbol's first state, a symbol at a time:
# the states reached by the same symbols are a pair, and a pair must
# have the same action for each token (a shift to a pair, the same
# rule reduced, the same default) and the same gotos.
# ocamlyacc has three states more: its own first, which chooses the
# start symbol by a token of its own ('\001'...), and two for its end.
# usage: automata.py y.output mini.output
import re, sys

def read(path):
    rules, states, lhs, cur = {}, {}, None, None
    for line in open(path):
        line = line.rstrip('\n')
        m = re.match(r'\s*(\d+)  (\S+) :(.*)$', line)
        m2 = re.match(r'\s*(\d+)\s+\|(.*)$', line)
        if cur is None and m:
            lhs = m.group(2); rules[int(m.group(1))] = (lhs, tuple(m.group(3).split()))
        elif cur is None and m2:
            rules[int(m2.group(1))] = (lhs, tuple(m2.group(2).split()))
        elif line.startswith('state '):
            cur = states.setdefault(int(line.split()[1]), {'act': {}, 'goto': {}, 'default': None})
        elif cur is not None and line.startswith('\t'):
            m = re.match(r'\t(\S+)  (shift|reduce|goto) (\d+)$', line)
            if m:
                sym, kind, n = m.group(1), m.group(2), int(m.group(3))
                if kind == 'goto': cur['goto'][sym] = n
                elif sym == '.': cur['default'] = ('reduce', n)
                else: cur['act'][sym] = (kind, n)
            elif line == '\t.  accept': cur['default'] = ('accept', 0)
    return rules, states

ref_rules, ref = read(sys.argv[1])
my_rules, mine = read(sys.argv[2])
# ocamlyacc's state 0 goes by '\001', '\002'... to each start symbol's first state: mini-yacc's 0, 1...
entries = sorted((sym, n) for sym, (kind, n) in ref[0]['act'].items())
pairs = {n: k for k, (sym, n) in enumerate(entries)}
todo, errors = list(pairs), []

def pair(r, m, why):
    if r in pairs:
        if pairs[r] != m: errors.append('%s: ocamlyacc\'s state %d is mini-yacc\'s %d and %d' % (why, r, pairs[r], m))
    else:
        pairs[r] = m; todo.append(r)

# a rule by its text; ocamlyacc's entry rule (%entry% : '\001' start) is mini-yacc's accept
def said(rules, a, accept=False):
    kind, n = a
    if kind == 'accept': return 'accept'
    if kind == 'reduce':
        lhs, rhs = rules[n]
        return 'accept' if lhs in ('%entry%', '$accept') else 'reduce %s : %s' % (lhs, ' '.join(rhs))
    return kind

while todo:
    r = todo.pop(); m = pairs[r]
    a, b = ref[r], mine[m]
    where = 'state %d (mini-yacc\'s %d)' % (r, m)
    if set(a['act']) != set(b['act']): errors.append('%s: the tokens with an action differ: %s' % (where, sorted(set(a['act']) ^ set(b['act']))[:6]))
    for sym in set(a['act']) & set(b['act']):
        x, y = a['act'][sym], b['act'][sym]
        if x[0] == 'shift' and y[0] == 'shift': pair(x[1], y[1], where + ' on ' + sym)
        elif said(ref_rules, x) != said(my_rules, y): errors.append('%s on %s: %s, mini-yacc: %s' % (where, sym, said(ref_rules, x), said(my_rules, y)))
    da = said(ref_rules, a['default']) if a['default'] else None
    db = said(my_rules, b['default']) if b['default'] else None
    if da != db: errors.append('%s: the default: %s, mini-yacc: %s' % (where, da, db))
    # the gotos: not on ocamlyacc's %entry%
    ga = {s: n for s, n in a['goto'].items() if s != '%entry%'}
    if set(ga) != set(b['goto']): errors.append('%s: the gotos differ: %s' % (where, sorted(set(ga) ^ set(b['goto']))[:6]))
    for sym in set(ga) & set(b['goto']): pair(ga[sym], b['goto'][sym], where + ' by ' + sym)

for e in errors[:10]: print(e)
unseen = len(mine) - len(set(pairs.values()))
print('%d states of mini-yacc\'s %d paired with ocamlyacc\'s (which has %d), %d differences' % (len(set(pairs.values())), len(mine), len(ref), len(errors)))
sys.exit(1 if errors or unseen else 0)
