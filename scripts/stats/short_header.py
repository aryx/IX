#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The license header of ix's files, in two lines: the author; the
# copyright and where the license is (license.txt), in the place of
# the nine lines each file had. In OCaml's, C's, the shell's and the
# assemblers' comments; a header whose comment goes on (a description
# after the license) keeps the rest.
# usage: short_header.py [-n] file...     (-n: say what would change)
import re, sys

LICENSE = [r"This library is free software; you can redistribute it and/or",
           r"modify it under the terms of the GNU Library General Public License",
           r"\(LGPL\) as published by the Free Software Foundation; either version",
           r"2 of the License, or \(at your option\) any later version\."]

def pattern(open_, mid, close):
    """the header: author, blank, copyright, blank, the license's four lines, the comment's end"""
    m = re.escape(mid)
    lines = [re.escape(open_) + r" ?(?P<author>[^\n]+)", m, m + r" ?Copyright \(C\) (?P<year>[0-9, -]+) (?P<holder>[^\n]+)", m] + [m + " ?" + l for l in LICENSE]
    return re.compile(r"\n".join(l.rstrip() + r"[ \t]*" for l in lines) + r"\n" + (r"(?P<end>" + re.escape(close) + r"[ \t]*\n)?" if close else ""))

# a style: the comment's opening, its lines' start, its end
STYLES = [("(*", " *", " *)"), ("/*", " *", " */"), ("#", "#", ""), ("//", "//", ""), ("@", "@", "")]

def shorten(text):
    for open_, mid, close in STYLES:
        m = pattern(open_, mid, close).search(text)
        if m and text[:m.start()].count("\n") <= 3:
            ended = close != "" and m.group("end")
            two = "%s %s\n%s Copyright (C) %s %s. LGPL 2.1: see license.txt.%s\n" % (
                open_, m.group("author").strip(), mid, m.group("year").strip(), m.group("holder").strip(), close if ended else "")
            return text[:m.start()] + two + text[m.end():]
    return None

dry = sys.argv[1:2] == ["-n"]
done = 0
for f in sys.argv[(2 if dry else 1):]:
    text = open(f, encoding="latin-1").read()
    new = shorten(text)
    if new is None:
        print("no header found:", f)
    else:
        done += 1
        if not dry: open(f, "w", encoding="latin-1").write(new)
print(done, "files", "would change" if dry else "changed")
