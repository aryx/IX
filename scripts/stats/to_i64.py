#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Int64's calls as I64's operators, in a local open (lib_core/commons/I64):
#   Int64.logand (Int64.shift_right_logical v 32) m   I64.((v lsr 32) land m)
# A call is rewritten when its arguments are other such calls, or text
# without an int's arithmetic in it (inside I64.( ... ) a + is the
# 64-bit one); the others are left. The type checker says the rest.
# usage: to_i64.py file.ml...
import re, sys

BIN = {"logand": "land", "logor": "lor", "logxor": "lxor", "add": "+", "sub": "-", "mul": "*",
       "shift_left": "lsl", "shift_right_logical": "lsr", "shift_right": "asr"}
UN = {"lognot": "lnot", "of_int": "int"}
CALL = re.compile(r"Int64\.(%s)\b" % "|".join(list(BIN) + list(UN)))
ARITH = re.compile(r"[+*/]|[^(,=>] *-|\b(land|lor|lxor|lsl|lsr|asr|lnot|mod)\b")

def skip(s, i):
    while i < len(s) and s[i] in " \n\t": i += 1
    return i

def atom(s, i):
    """the end of the atom at i: a parenthesized group, or a name with its fields and indices"""
    if i >= len(s): return None
    if s[i] == "(":
        d = 0
        for j in range(i, len(s)):
            if s[j] == "(": d += 1
            elif s[j] == ")":
                d -= 1
                if d == 0: return j + 1
        return None
    m = re.compile(r"!?[A-Za-z_0-9']+(\.[A-Za-z_0-9']+|\.\((?:[^()]|\([^()]*\))*\))*").match(s, i)
    return m.end() if m else None

def call(s, i):
    """the Int64 call at i: its text with I64's operators (None if an
    argument has an int's arithmetic) and its end; None if not a call"""
    m = CALL.match(s, i)
    if not m: return None
    f = m.group(1); j = skip(s, m.end()); args = []
    for k in range(2 if f in BIN else 1):
        e = atom(s, j)
        if e is None: return None
        args.append(s[j:e]); j = e if k == (1 if f in BIN else 0) else skip(s, e)
    out = []
    for a in args:
        inner = a[1:-1].strip() if a.startswith("(") else None
        c = call(inner, 0) if inner is not None else None
        if c and c[1] == len(inner):
            if c[0] is None: return None, j
            # an application binds tighter than an operator: no parentheses
            out.append(c[0] if CALL.match(inner).group(1) in UN else "(" + c[0] + ")")
        elif ARITH.search(inner if inner is not None else a): return None, j
        # a plain application needs no parentheses beside an operator
        elif inner is not None and not re.search(r"\b(if|then|else|fun|function|match|let|in|not)\b", inner) and re.fullmatch(r"[A-Za-z_][A-Za-z_0-9.' ]*( \([A-Za-z_0-9.' ]*\)| [A-Za-z_0-9.']+)*", inner): out.append(inner)
        else: out.append(a)
    return ("%s %s %s" % (out[0], BIN[f], out[1]) if f in BIN else "%s %s" % (UN[f], out[0])), j

def convert(s):
    """all of an expression or nothing: no I64.( ... ) inside an Int64 call left as it is"""
    out = []; i = 0; n = 0
    while True:
        m = CALL.search(s, i)
        if not m: break
        c = call(s, m.start())
        if c and c[0] is not None and m.group(1) in BIN:
            a, b = m.start(), c[1]
            # (Int64.f x y) had its parentheses for the application: I64.( ... ) has its own
            if a > 0 and s[a - 1] == "(" and b < len(s) and s[b] == ")" and (a < 2 or s[a - 2] in " (\n"):
                a -= 1; b += 1
            out.append(s[i:a] + "I64.(" + c[0] + ")"); i = b; n += 1
        else:
            end = c[1] if c else m.end()
            out.append(s[i:end]); i = end
    return "".join(out) + s[i:], n

for f in sys.argv[1:]:
    s = open(f).read()
    t, n = convert(s)
    open(f, "w").write(t)
    print(f, n, "expressions")
