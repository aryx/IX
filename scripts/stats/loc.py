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
# Lines of code across ix, grouped as ix is: the mini programs, the
# faithful twins (m-ix: assembler/, languages/c/, ..., kernel/), the
# tiny programs (t-ix: tiny/, one line per file, since a file is a
# program), the shared libraries (lib_*/), and apart from all of them
# the tests (every tests/ or X_tests/ directory, and the top tests/).
# OCaml (.ml, .mli, .mll, .mly), C (.c, .h) and assembly (.s): the
# runtimes, the kernels' starts, lib_core/libc/. Each line is counted
# once, as code (it has some code, maybe a comment too), comment (only
# a comment, or inside one) or blank.
#
# The files are git's (tracked, and new ones not ignored), so _build/
# is never counted. Neither are the compat/ directories (linker/compat/):
# code kept only for compatibility, not part of ix (as in .codemapignore);
# nor the opti/ ones (languages/c/opti/): optimizations, each behind a
# flag, which the program runs the same without; nor ssa/, an optional
# back end (languages/ml/ssa/).
#
# Usage: scripts/stats/loc.py [-v]
#   -v: every subdirectory (kernel/xv6/, lib_core/libc/, ...) and every
#       tests/ directory rather than one line per program
#
# The lines come first, next to the name they count; then the files,
# the lines of each language (ocaml, c, asm), and the code, comment and
# blank lines. A group's total comes first, its parts indented under
# it. Then the same by kind of file: .ml, .mli, .mll and .mly, .c, .h,
# .s, without the tests. Last, the numbers to keep small: m-ix (the
# mini programs and the libraries) and t-ix (the tiny programs),
# without the tests (nor compat/, opti/, ssa/: above); m-ix's with what
# it copied apart (the stdlib from ocaml-light, libc from goken:
# lib_core/README.md), which is to be trimmed, from what is ix's own.

import re
import subprocess
import sys
from collections import defaultdict

# ---------------------------------------------------------------------
# Counting the lines of a file
# ---------------------------------------------------------------------

CHAR = re.compile(r"'(\\[\\'\"ntbr ]|\\[0-9]{3}|\\x[0-9a-fA-F]{2}|[^\\'\n])'")
QUOTED = re.compile(r"\{([a-z_]*)\|")


def count(text, c_comments=False):
    """(code, comment, blank) lines of an OCaml source: a small lexer
    for comments (nested, and with strings inside them), strings,
    quoted strings {id|...|id} and character literals ('"'); with
    c_comments, ocamlyacc's /* ... */ too (not nested)."""
    code = comment = blank = 0
    has_code = has_comment = False
    depth = 0  # comments nesting
    close = None  # inside a string: what ends it
    i, n = 0, len(text)
    while i <= n:
        if i == n or text[i] == "\n":
            if has_code:
                code += 1
            elif has_comment or depth > 0:
                comment += 1
            elif i < n or (n > 0 and text[-1] != "\n"):
                blank += 1
            has_code = False
            has_comment = depth > 0
            i += 1
            continue
        c = text[i]
        if close is not None:
            if depth > 0:
                has_comment = True
            elif not c.isspace():
                has_code = True
            if close == '"' and c == "\\":
                # an escape, but not over the newline of a "...\
                # continued" string: the line must still be counted
                i += 1 if text.startswith("\\\n", i) else 2
                continue
            if text.startswith(close, i):
                i += len(close)
                close = None
                continue
            i += 1
            continue
        if c_comments and text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end < 0 else end + 2
            # the lines it spans, but its last, are comment lines
            for _ in range(text.count("\n", i, end)):
                if has_code:
                    code += 1
                else:
                    comment += 1
                has_code = False
            has_comment = True
            i = end
            continue
        if text.startswith("(*", i):
            depth += 1
            has_comment = True
            i += 2
            continue
        if depth > 0 and text.startswith("*)", i):
            depth -= 1
            i += 2
            continue
        if depth > 0:
            if not c.isspace():
                has_comment = True
            if c == '"':
                close = '"'
            i += 1
            continue
        if not c.isspace():
            has_code = True
        if c == '"':
            close = '"'
            i += 1
            continue
        if c == "{":
            m = QUOTED.match(text, i)
            if m:
                close = "|" + m.group(1) + "}"
                i = m.end()
                continue
        if c == "'":
            m = CHAR.match(text, i)
            if m:
                i = m.end()
                continue
        i += 1
    return code, comment, blank


def count_c(text):
    """(code, comment, blank) lines of a C or assembly source (Plan
    9's: its comments are C's): /* ... */, // to the line's end, and
    strings and characters, where a comment doesn't start."""
    code = comment = blank = 0
    has_code = has_comment = False
    inside = False  # a /* ... */
    i, n = 0, len(text)
    while i <= n:
        if i == n or text[i] == "\n":
            if has_code:
                code += 1
            elif has_comment or inside:
                comment += 1
            elif i < n or (n > 0 and text[-1] != "\n"):
                blank += 1
            has_code = False
            has_comment = inside
            i += 1
            continue
        c = text[i]
        if inside:
            if text.startswith("*/", i):
                inside = False
                i += 2
            else:
                i += 1
            has_comment = True
            continue
        if text.startswith("/*", i):
            inside = has_comment = True
            i += 2
            continue
        if text.startswith("//", i):
            has_comment = True
            end = text.find("\n", i)
            i = n if end < 0 else end
            continue
        if c in "\"'":
            # to its end on this line, a \ taking the next character
            has_code = True
            i += 1
            while i < n and text[i] != c and text[i] != "\n":
                i += 2 if text[i] == "\\" and i + 1 < n and text[i + 1] != "\n" else 1
            i += 1 if i < n and text[i] == c else 0
            continue
        if not c.isspace():
            has_code = True
        i += 1
    return code, comment, blank


# ---------------------------------------------------------------------
# Grouping the files
# ---------------------------------------------------------------------

# (group, its top directories), in the order printed; the rest is
# "other" (tiny-os's, docs/'s, ...)
GROUPS = [
    ("mini", ["assembler", "linker", "languages", "generators", "machine",
              "raspberry", "kernel", "builder", "shell", "editor",
              "database", "version_control"]),
    ("tiny", ["tiny"]),
    ("libraries", ["lib_core", "lib_compression", "lib_security"]),
]


def classify(path, verbose):
    """(group, subgroup) of a file: tests wherever they are, else by
    its top directory. The subgroup is the top directory (a program, a
    library), but in tiny/ the file itself (a program), and with
    verbose the directory under the top one (kernel/xv6/), or the tests
    directory itself."""
    parts = path.split("/")
    # languages/ and generators/ hold a program per directory (languages/c/)
    top = 2 if parts[0] in ("languages", "generators") and len(parts) > 2 else 1
    prog = "/".join(parts[:top]) + "/"
    # tests/, and tiny/'s TinyC_tests/
    tests = [i for i, d in enumerate(parts[:-1]) if d == "tests" or d.endswith("_tests")]
    if tests:
        if verbose:
            return "tests", "/".join(parts[:tests[0] + 1]) + "/"
        return "tests", prog
    for group, tops in GROUPS:
        if parts[0] in tops:
            if group == "tiny" and len(parts) == 2:
                return group, path
            if verbose and len(parts) > top + 1:
                return group, "/".join(parts[:top + 1]) + "/"
            return group, prog
    return "other", parts[0] + "/" if len(parts) > 1 else "./"


def files():
    out = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard",
         "--", "*.ml", "*.mli", "*.mll", "*.mly", "*.c", "*.h", "*.s"],
        check=True, capture_output=True, text=True).stdout
    return [f for f in out.splitlines()
            if f and not {"compat", "opti", "ssa"} & set(f.split("/")[:-1])]


# ---------------------------------------------------------------------
# Printing
# ---------------------------------------------------------------------

FIELDS = ["files", "ocaml", "c", "asm", "code", "comment", "blank", "lines"]
# the lines first, right beside the name they count, the rest after it
REST = [f for f in FIELDS if f != "lines"]
# 80 columns: the lines (7), 2 spaces, the name, then each cell a
# space wider than its title or its numbers ("48,813"), whichever is
# the longer
WIDTH = 25  # of the name column: "  tiny/TinyBuildSystem.ml" with -v
CELL = {"files": 5, "ocaml": 7, "c": 7, "asm": 6, "code": 7,
        "comment": 7, "blank": 7}
TITLE = {"comment": "comm."}
# a file's language, and its kind for the last table
LANGUAGE = {"ml": "ocaml", "mli": "ocaml", "mll": "ocaml", "mly": "ocaml",
            "c": "c", "h": "c", "s": "asm"}
KINDS = [".ml", ".mli", ".mll .mly", ".c", ".h", ".s"]
# what ix copied (lib_core/README.md), the rest of lib_core/ being its own
COPIED = tuple("lib_core/" + d + "/" for d in
               ["core", "base", "collections", "printing", "libc"])
KIND = {"ml": ".ml", "mli": ".mli", "mll": ".mll .mly", "mly": ".mll .mly",
        "c": ".c", "h": ".h", "s": ".s"}


def row(name, s, indent=0):
    cells = "".join(f"{s[f]:>{CELL[f]},}" for f in REST)
    print(f"{s['lines']:>7,}  {' ' * indent}{name:<{WIDTH - indent}}{cells}")


def main():
    verbose = "-v" in sys.argv[1:]
    stats = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
    kinds = defaultdict(lambda: defaultdict(int))
    mix = defaultdict(lambda: defaultdict(int))  # m-ix: "own", "copied"
    for path in files():
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
        except FileNotFoundError:  # deleted, not yet staged
            continue
        ext = path.rsplit(".", 1)[1]
        if LANGUAGE[ext] == "ocaml":
            code, comment, blank = count(text, ext == "mly")
        else:
            code, comment, blank = count_c(text)
        group, sub = classify(path, verbose)
        # a row's, and (the tests apart) its kind's
        also = []
        if group != "tests":
            also.append(kinds[KIND[ext]])
        if group in ("mini", "libraries"):
            also.append(mix["copied" if path.startswith(COPIED) else "own"])
        for s in [stats[group][sub]] + also:
            s["files"] += 1
            s[LANGUAGE[ext]] += code + comment + blank
            s["code"] += code
            s["comment"] += comment
            s["blank"] += blank
            s["lines"] += code + comment + blank

    def total(subs):
        t = defaultdict(int)
        for s in subs:
            for f in FIELDS:
                t[f] += s[f]
        return t

    print(f"{'lines':>7}  {'':<{WIDTH}}"
          + "".join(f"{TITLE.get(f, f):>{CELL[f]}}" for f in REST))
    order = [g for g, _ in GROUPS] + ["tests", "other"]
    first = True
    for group in order:
        subs = stats.get(group, {})
        if not subs:
            continue
        if not first:
            print()
        first = False
        row(group, total(subs.values()))
        # in the order of GROUPS (the toolchain, the machines, the
        # kernel, the programs), not alphabetical
        tops = dict(GROUPS).get(group, [])
        rank = {t: i for i, t in enumerate(tops)}
        for sub in sorted(subs, key=lambda k: (rank.get(k.split("/")[0],
                                                        len(tops)), k)):
            row(sub, subs[sub], 2)
    print()
    row("total", total(s for g in stats.values() for s in g.values()))
    row("total without tests",
        total(s for g, subs in stats.items() if g != "tests"
              for s in subs.values()))
    # the same lines, by kind of file
    print()
    for kind in KINDS:
        if kind in kinds:
            row(kind, kinds[kind], 2)
    # the numbers to keep small
    print()
    row("m-ix: mini + libraries", total(mix.values()))
    row("ix's own", mix["own"], 2)
    row("copied: stdlib, libc", mix["copied"], 2)
    row("t-ix: tiny", total(stats.get("tiny", {}).values()))


if __name__ == "__main__":
    main()
