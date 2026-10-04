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
# The stdlib trimmed to what ix uses (docs/plans/plan_ml_bootstrap.md's
# ledger, 2026-10-04 and after): the values of a module of lib_core
# taken out of its .mli (each with the comment that follows it) and of
# its .ml (each definition, to the next one), and their names listed at
# the .mli's end, so that a reader knows what the module had and where
# to restore it from.
#
# usage: trim_stdlib.py -l Module             its values, and the files of ix naming each
#        trim_stdlib.py Module "from where" name...    takes them out
import glob, os, re, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
rd = lambda p: open(p, errors="replace").read()
ITEM = re.compile(r"^(val|external|type|exception|module|let|and) ")


def uses(m):
    files = subprocess.run(["git", "ls-files", "*.ml", "*.mli", "*.mll", "*.mly"], capture_output=True, text=True,
                           cwd=ROOT).stdout.split()
    src = {f: rd(os.path.join(ROOT, f)) for f in files if not re.search(r"/%s\.mli?$" % m, f)}
    mli = glob.glob(os.path.join(ROOT, "lib_core/*/%s.mli" % m))[0]
    own = rd(mli[:-1])
    for kind, v in re.findall(r"^(val|external|type|exception) ([a-zA-Z_0-9']+)", rd(mli), re.M):
        named = [f for f, t in src.items() if re.search(r"\b%s\.%s\b" % (m, re.escape(v)), t)]
        tests = sum(1 for f in named if "/tests/" in f)
        inner = len(re.findall(r"\b%s\b" % re.escape(v), own)) - 1
        print("%2d files (%d of them tests), %d more in its own .ml  %s %s" % (len(named), tests, inner, kind, v))


def cut_mli(lines, name):
    """the item's lines: its signature, then the comment right after it"""
    i = next(k for k, l in enumerate(lines) if re.match(r"(val|external) %s\b" % re.escape(name), l))
    j = i + 1
    while j < len(lines) and lines[j].strip() != "" and not lines[j].lstrip().startswith("(*") and not ITEM.match(lines[j]):
        j += 1
    if j < len(lines) and lines[j].lstrip().startswith("(*"):
        depth = 0
        while j < len(lines):
            depth += lines[j].count("(*") - lines[j].count("*)")
            j += 1
            if depth <= 0:
                break
    while j < len(lines) and lines[j].strip() == "" and j + 1 < len(lines) and lines[j + 1].strip() == "":
        j += 1
    del lines[i:j]


def cut_ml(lines, name):
    """the definition's lines, to the next item at the margin; its
    comment just above, if it has one of its own"""
    pat = re.compile(r"(let|external|and)( rec)? \(?%s\b" % re.escape(name))
    hits = [k for k, l in enumerate(lines) if pat.match(l)]
    if not hits:
        return False
    i = hits[0]
    j = i + 1
    while j < len(lines) and not ITEM.match(lines[j]) and not lines[j].startswith("(*"):
        j += 1
    while j > i + 1 and lines[j - 1].strip() == "":
        j -= 1
    k = i
    if k > 0 and lines[k - 1].rstrip().endswith("*)") and not ITEM.match(lines[k - 1]):
        a = k - 1
        while a > 0 and "(*" not in lines[a]:
            a -= 1
        if a == 0 or lines[a - 1].strip() == "":
            k = a
    if lines[i].startswith("and "):
        k = i
    del lines[k:j]
    return True


def main():
    if sys.argv[1] == "-l":
        return uses(sys.argv[2])
    m, where, names = sys.argv[1], sys.argv[2], sys.argv[3:]
    mli = glob.glob(os.path.join(ROOT, "lib_core/*/%s.mli" % m))[0]
    ml = mli[:-1]
    a, b = rd(mli).split("\n"), rd(ml).split("\n")
    for n in names:
        cut_mli(a, n)
        if not cut_ml(b, n):
            print("%s: no definition of %s in the .ml" % (m, n))
    while a and a[-1].strip() == "":
        a.pop()
    # a list already there: this call's names join it
    k = next((k for k, l in enumerate(a) if l.startswith("(* ix: no program of ix called these")), None)
    if k is not None:
        old = " ".join(l.strip() for l in a[k + 1:])
        old = old.replace("*)", "").replace("*", " ")
        names = [n.strip(" .") for n in old.split(",") if n.strip(" .")] + names
        del a[k:]
        while a and a[-1].strip() == "":
            a.pop()
    text = ", ".join(names)
    wrapped, line = [], " *"
    for w in text.split(" "):
        if len(line) + 1 + len(w) > 72:
            wrapped.append(line)
            line = " *"
        line += " " + w
    wrapped.append(line)
    a += ["", "(* ix: no program of ix called these, taken out (to restore from %s):" % where] + wrapped[:-1] + [wrapped[-1] + ". *)", ""]
    open(mli, "w").write("\n".join(a))
    open(ml, "w").write("\n".join(b))


main()
