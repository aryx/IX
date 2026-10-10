#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The top of an .ml file of ix, in one shape: the author's line and the
# copyright's, a blank line, then the header comment, the module's
# documentation (docs/tags.md), a comment of its own:
#
#     (* Claude Code
#      * Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt. *)
#
#     (* mini-cat: Plan 9's cat ...
#
# It puts the blank line where there is none, and cuts in two a comment
# that goes on after the copyright's line with the description. The
# nine lines of a license are short_header.py's to make two, first. An
# .mli has no copyright (an interface is not copyrightable): its
# header comment is its first line, and nothing is done to it. A file
# with no author's line is said, and left.
# usage: header_shape.py [-n] file.ml...     (-n: say what would change)
import re, sys

TWO = re.compile(r"\(\* ?(?P<author>[^\n*]+)\n \* ?Copyright \(C\) [^\n]*?LGPL 2\.1: see license\.txt\.")

def shape(text):
    """the text in that shape, the same text if it is, None without the two lines"""
    m = TWO.match(text)
    if not m:
        return None
    rest = text[m.end():]
    if rest.startswith(" *)"):
        return text[:m.end()] + " *)\n\n" + rest[3:].lstrip("\n")
    # the comment goes on: " *" lines, empty first, then the description
    go = re.match(r"\n(?: \*[ \t]*\n)*", rest)
    if not go or not rest[go.end():].startswith(" * "):
        return None
    return text[:m.end()] + " *)\n\n(* " + rest[go.end() + 3:]

dry = sys.argv[1:2] == ["-n"]
changed = 0
for f in sys.argv[(2 if dry else 1):]:
    text = open(f, encoding="latin-1").read()
    new = shape(text)
    if new is None:
        print("no author's and copyright's lines:", f)
    elif new != text:
        changed += 1
        if dry:
            print("would change:", f)
        else:
            open(f, "w", encoding="latin-1").write(new)
print(changed, "files", "would change" if dry else "changed")
