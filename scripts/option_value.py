#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A copied file made what mini-ml takes (plan_browser.md): each
#   Option.value X ~default:Y   (or ~default:Y X)
# written out as a match, where X is a name or a parenthesized
# expression and Y a literal, a name or a parenthesized expression;
# says how many it left (to do by hand).
# usage: option_value.py file.ml...
import re, sys
arg = r'\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)'
simple = r'(?:"(?:[^"\\]|\\.)*"|[A-Za-z_0-9.\']+|' + arg + ')'
pat = re.compile(r'Option\.value (' + arg + r'|[a-z_][A-Za-z_0-9.\']*) ~default:(' + simple + ')')
# (not after |>: "x |> Option.value ~default:d in" would take "in" for X)
pat2 = re.compile(r'(?<!\|> )Option\.value ~default:(' + simple + r') (' + arg + r'|[a-z_][A-Za-z_0-9.\']*)')
for p in sys.argv[1:]:
    s = open(p).read()
    t = pat.sub(lambda m: '(match %s with Some v_ -> v_ | None -> %s)' % (m.group(1), m.group(2)), s)
    t = pat2.sub(lambda m: '(match %s with Some v_ -> v_ | None -> %s)' % (m.group(2), m.group(1)), t)
    if t != s: open(p, 'w').write(t)
    left = t.count('Option.value')
    if left: print('%s: %d Option.value left' % (p, left))
