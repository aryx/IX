#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny/TinyLib/c/, mini-ml's runtime for the tiny programs, cut from a
# copy of languages/ml/runtime/'s files (tiny/TinyLib/README.md):
# - the branches of another system and another compiler taken out
#   (#ifdef plan9, #ifdef __GNUC__: neither is defined there);
# - a primitive (a C function an external of lib_core's OCaml names)
#   that no external of tiny/TinyLib/ocaml/ names, taken out; then a
#   static function nothing names any more, again until none goes.
# A function goes with the comment right above it. What is left is
# changed by hand after (sys.c on Linux's calls, the C library's part):
# running this again only takes out what has become unused.
#
# Usage: scripts/stats/tiny_lib_c.py [-n]      (-n: say, change nothing)

import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
C = os.path.join(ROOT, "tiny/TinyLib/c")
UNDEFINED = ["plan9", "__GNUC__"]
# what mini-ml's generated code calls itself, no external naming it
# (Lower's CallC): the link said so when obj_block went with Obj's
COMPILER = {"obj_block"}
EXTERNAL = re.compile(r'^\s*external\s+[^=]*?:[^=]*=\s*((?:"[^"]*"\s*)+)', re.M)


def externals(pattern):
    out = set()
    for f in glob.glob(os.path.join(ROOT, pattern)):
        with open(f, encoding="latin-1") as h:
            for m in EXTERNAL.finditer(h.read()):
                out |= {n for n in re.findall(r'"([^"]*)"', m.group(1)) if not n.startswith("%")}
    return out


def unifdef(lines):
    """the lines without the branches of UNDEFINED's names"""
    out, stack = [], []   # stack: (ours, keeping) for each open conditional
    for l in lines:
        m = re.match(r"#\s*(ifdef|ifndef|if|else|endif)\b\s*(\w*)", l)
        keep = all(k for _, k in stack)
        if m and m.group(1) in ("ifdef", "ifndef", "if"):
            ours = m.group(1) != "if" and m.group(2) in UNDEFINED
            stack.append((ours, m.group(1) == "ifndef" if ours else True))
            if ours:
                continue
        elif m and m.group(1) == "else" and stack[-1][0]:
            stack[-1] = (True, not stack[-1][1])
            continue
        elif m and m.group(1) == "endif":
            ours, _ = stack.pop()
            if ours:
                continue
        if keep:
            out.append(l)
    return out


def functions(lines):
    """(name, first line, last line, static) of each function: Plan 9's
    style, the name at the margin under its type, to the } at the
    margin; or all on one line; the comment right above is its"""
    out = []
    i = 0
    while i < len(lines):
        l = lines[i]
        one = re.match(r"(static\s+)?[\w \*]+?\b(\w+)\([^;]*\)\s*\{.*\}\s*$", l)
        two = re.match(r"(\w+)\(", l) if i > 0 and re.match(r"(static\s+)?[\w\* ]+$", lines[i - 1]) else None
        if one and not l.startswith(("\t", " ", "#")):
            a = b = i
            name, static = one.group(2), bool(one.group(1))
        elif two and not l.rstrip().endswith(";"):
            a, b = i - 1, i
            while not lines[b].startswith("}"):
                b += 1
            name, static = two.group(1), lines[i - 1].startswith("static")
        else:
            i += 1
            continue
        while a > 0 and lines[a - 1].rstrip().endswith("*/") and not lines[a - 1].startswith("#"):
            k = a - 1
            while not lines[k].lstrip().startswith("/*"):
                k -= 1
            if k > 0 and lines[k - 1].strip() != "" and not lines[k - 1].startswith("}"):
                break
            a = k
        out.append((name, a, b, static))
        i = b + 1
    return out


def main():
    dry = "-n" in sys.argv[1:]
    files = sorted(glob.glob(os.path.join(C, "*.[ch]")))
    text = {}
    for f in files:
        with open(f, encoding="latin-1") as h:
            text[f] = unifdef(h.read().split("\n"))
    prims = externals("lib_core/*/*.ml") | externals("lib_core/*/*.mli")
    named = externals("tiny/TinyLib/ocaml/*.ml") | externals("tiny/TinyLib/ocaml/*.mli") | COMPILER
    gone = []
    while True:
        whole = "\n".join("\n".join(ls) for ls in text.values())
        changed = False
        for f in files:
            for name, a, b, static in reversed(functions(text[f])):
                uses = len(re.findall(r"\b%s\b" % re.escape(name), whole))
                here = len(re.findall(r"\b%s\b" % re.escape(name), "\n".join(text[f][a:b + 1])))
                if (name in prims and name not in named and uses == here) or (static and uses == here):
                    del text[f][a:b + 1]
                    gone.append(name)
                    changed = True
        if not changed:
            break
    print("%d functions: %s" % (len(gone), " ".join(sorted(gone))))
    if not dry:
        for f in files:
            body = re.sub(r"\n{3,}", "\n\n", "\n".join(text[f]))
            with open(f, "w", encoding="latin-1") as h:
                h.write(body)


if __name__ == "__main__":
    main()
