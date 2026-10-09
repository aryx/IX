#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# OCaml's boxed license header (ocaml-light's stdlib's, and the
# modules taken from later OCamls), in two lines: the author; the
# system's name, the copyright and the license's name. For
# tiny/TinyLib/ocaml/, where the files are meant to be short (the
# author, 2026-10-09: "copyright boilerplate that could be reduced to
# one line for the author and one line for the copyright"); lib_core/'s
# keep theirs.
# usage: short_box_header.py [-n] file...     (-n: say what would change)
import re, sys

BOX = re.compile(r"\(\*{10,}\)\n((?:\(\*.*\*\)\n)+?)\(\*{10,}\)\n+")


def shorten(text):
    m = BOX.search(text)
    if not m or text[:m.start()].count("\n") > 1 or "Copyright" not in m.group(1):
        return None
    lines = [l[2:-2].strip() for l in m.group(1).split("\n") if l[2:-2].strip()]
    k = next(i for i, l in enumerate(lines) if l.startswith("Copyright"))
    title, author = lines[0], " ".join(lines[1:k])
    rest = " ".join(lines[k:])
    year = re.match(r"Copyright (\d+)", rest).group(1)
    if "Distributed only by permission" in rest:
        license = "Distributed only by permission"
    elif "Lesser General Public License version 2.1" in rest:
        license = "LGPL 2.1, with the linking exception of OCaml's LICENSE"
    elif "Library General Public License" in rest:
        license = "GNU Library General Public License" + (
            ", with the linking exception of OCaml's LICENSE" if "special exception" in rest else "")
    else:
        return None
    two = "(* %s\n * %s. Copyright %s INRIA. %s. *)\n\n" % (author, title, year, license)
    return text[:m.start()] + two + text[m.end():]


dry = sys.argv[1:2] == ["-n"]
for f in sys.argv[(2 if dry else 1):]:
    text = open(f, encoding="latin-1").read()
    new = shorten(text)
    if new is None:
        if re.match(r"(\(\*.*\n)?\(\*{10,}\)", text):
            print("%s: a box that is not understood" % f)
        continue
    print(f)
    if not dry:
        open(f, "w", encoding="latin-1").write(new)
