#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Prints an OCaml file without its comments, so that two versions of a
# file can be compared on their code alone (playground_copies.sh -c).
# A comment is replaced by nothing, but its newlines are kept, so the
# code keeps its line numbers. Comments nest, and a string inside a
# comment is read as a string, as OCaml does; a string, a quoted string
# {id|...|id} or a character literal ('"') outside a comment is code.
#
# Usage: scripts/strip_comments.py file

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "stats"))
from loc import CHAR, QUOTED  # noqa: E402  (the same lexer's pieces)


def strip(text):
    out = []
    depth = 0  # comments nesting
    i, n = 0, len(text)
    while i < n:
        if text.startswith("(*", i):
            depth += 1
            i += 2
        elif depth > 0 and text.startswith("*)", i):
            depth -= 1
            i += 2
        elif text[i] == '"':
            # a string, to its closing quote, a \ taking the next character
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            j = min(j + 1, n)
            if depth == 0:
                out.append(text[i:j])
            else:
                out.append("\n" * text.count("\n", i, j))
            i = j
        elif depth == 0 and text[i] == "{" and QUOTED.match(text, i):
            m = QUOTED.match(text, i)
            close = "|" + m.group(1) + "}"
            j = text.find(close, m.end())
            j = n if j < 0 else j + len(close)
            out.append(text[i:j])
            i = j
        elif depth == 0 and text[i] == "'" and CHAR.match(text, i):
            j = CHAR.match(text, i).end()
            out.append(text[i:j])
            i = j
        else:
            if depth == 0 or text[i] == "\n":
                out.append(text[i])
            i += 1
    return "".join(out)


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        sys.stdout.write(strip(f.read()))
