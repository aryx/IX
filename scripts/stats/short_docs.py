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
# The stdlib's documentation, short (plan_ml_bootstrap.md's ledger,
# 2026-10-04): in a .mli of lib_core, the comment that documents a
# value is cut to its first sentence, and the sentences that say what
# it raises. The full text is OCaml's manual's (and ocaml-light's
# stdlib/*.mli). Not touched: the license, a comment at the margin that
# is not right after a value (a module's header, a section's title),
# ix's own notes (ix:, claude:, pad:).
#
# usage: short_docs.py file.mli...
import re, sys, textwrap

ITEM = re.compile(r"^(val|external|type|exception|and)\b")
ABBREV = ("e.g", "i.e", "etc", "resp", "cf", "vs")


def sentences(text):
    """the text's sentences: a period ends one outside [ ] and { }"""
    out, depth, start = [], 0, 0
    for i, c in enumerate(text):
        if c in "[{":
            depth += 1
        elif c in "]}":
            depth = max(0, depth - 1)
        elif c == "." and depth == 0 and (i + 1 == len(text) or text[i + 1] == " "):
            if text[start:i].rstrip().split(" ")[-1].lower().rstrip(".") in ABBREV or text[i - 1:i] == ".":
                continue
            out.append(text[start:i + 1].strip())
            start = i + 1
    if text[start:].strip():
        out.append(text[start:].strip())
    return out


def shorten(body):
    text = re.sub(r"\s+", " ", body).strip()
    text = re.sub(r"@since [0-9.]+", "", text).strip()
    ss = sentences(text)
    if not ss:
        return text
    keep = [ss[0]] + [s for s in ss[1:] if re.match(r"(Raise|Raises|@raise|Not tail-recursive)\b", s)]
    return " ".join(keep)


def main(path):
    lines = open(path, encoding="latin-1").read().split("\n")
    out, i, after_item = [], 0, False
    while i < len(lines):
        l = lines[i]
        s = l.strip()
        doc = s.startswith("(*") and not s.startswith("(***") and (after_item and (l.startswith(" ") or s.startswith("(**")))
        if doc:
            j, depth = i, 0
            while True:
                depth += lines[j].count("(*") - lines[j].count("*)")
                j += 1
                if depth <= 0 or j >= len(lines):
                    break
            block = "\n".join(lines[i:j])
            if re.search(r"\b(ix|claude|pad):", block) or lines[j - 1].strip()[-2:] != "*)":
                out.extend(lines[i:j])
            else:
                indent = len(l) - len(l.lstrip())
                opening = "(**" if s.startswith("(**") else "(*"
                body = block.strip()[len(opening):-2]
                short = shorten(body)
                pad = " " * indent
                wrapped = textwrap.wrap(short, 76 - indent - len(opening) - 1) or [""]
                cont = pad + " " * (len(opening) + 1)
                out.append(pad + opening + " " + wrapped[0] + (" *)" if len(wrapped) == 1 else ""))
                for k, w in enumerate(wrapped[1:], 1):
                    out.append(cont + w + (" *)" if k == len(wrapped) - 1 else ""))
            i = j
            continue
        if ITEM.match(l):
            after_item = True
        elif s == "" :
            pass
        elif not l.startswith(" ") and not ITEM.match(l):
            after_item = False if s.startswith("(*") else after_item
        out.append(l)
        i += 1
    open(path, "w", encoding="latin-1").write("\n".join(out))


for p in sys.argv[1:]:
    main(p)
