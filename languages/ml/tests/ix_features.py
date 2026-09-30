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
# The OCaml features ix's own code uses beyond mini-ml's subset, and the
# idioms a new construct could shorten (plan_ml_bootstrap.md, "The
# census"): regexps over the files git knows, with the comments and
# strings removed, so the counts are close, not exact.
#
# Usage: ix_features.py [--idioms] [path-prefix...]
#   e.g. ix_features.py languages/ml lib_core assembler/   (mini-ml's closure)

import re, subprocess, sys
from collections import Counter

FEATURES = {
    "labeled argument ~x": r"(?<![\w)\]])~[a-z_]\w*",
    "optional argument ?x": r"(?<![\w)\]])\?\(?[a-z_]\w*",
    "object type < Cap.x; .. >": r"<\s*(Cap\.|[A-Z]\w*\.caps|\.\.)",
    "coercion :>": r":>",
    "polymorphic variant `X": r"`[A-Z]\w*",
    "inline record C of { }": r"\bof\s*\{",
    "record punning { x; }": r"\{\s*([A-Z]\w*\.)?[a-z_]\w*\s*[;}]",
    "quoted string {| |}": r"\{\|",
    "attribute [@": r"\[@",
    "match ... | exception": r"\|\s*exception\b",
    "local open M.( )": r"\b[A-Z]\w*\.\(",
    "let open": r"\blet open\b",
    "functor application X.Make (": r"\b[A-Z]\w*\.Make\s*\(",
    "lazy": r"\blazy\b",
    "exception A = B": r"^\s*exception\s+[A-Z]\w*\s*=",
    "char escape \\x \\o": r"'\\[xo]",
    "_ in a type": r":\s*_\s+[a-z]",
    "{ ...; _ } in a pattern": r";\s*_\s*\}",
    "Int32. Int64.": r"\bInt(32|64)\.\w+",
    "Bytes.": r"\bBytes\.",
    "Unix.": r"\bUnix\.",
}

IDIOMS = {
    "lines naming caps": r"\bcaps\b",
    "decode: field w lo n, bit w n": r"\b(field|bit|Bits\.field) \w+ [0-9]+",
    "encode: lsl and lor on a line": None,
    "show/print/dump definitions": r"^\s*(let|and)( rec)? (show|pp|print|dump|string_of)\w*",
    "S-expression printer clauses": r"-> (Printf\.)?sprintf \"\(",
    "ref": r"=\s*ref\b",
    "!x": r"!\w+",
    ":=": r":= ",
    "Error e -> Error e": r"Error\s+(\w+)\s*->\s*Error\s+\1",
    "None -> None": r"None\s*->\s*None\b",
}

def strip(s):
    s = re.sub(r"\(\*.*?\*\)", "", s, flags=re.S)   # comments, not nested
    s = re.sub(r"\{\|.*?\|\}", "{|Q|}", s, flags=re.S)
    return re.sub(r'"(\\.|[^"\\])*"', '"S"', s)

def main(argv):
    idioms = "--idioms" in argv
    prefixes = [a for a in argv if a != "--idioms"]
    exts = ["*.ml"] if idioms else ["*.ml", "*.mli"]
    files = subprocess.run(["git", "ls-files"] + exts, capture_output=True, text=True).stdout.split()
    files = [f for f in files if not prefixes or any(f.startswith(p) for p in prefixes)]
    table = IDIOMS if idioms else FEATURES
    uses, nfiles, lines = Counter(), Counter(), 0
    for f in files:
        raw = open(f).read()
        lines += raw.count("\n")
        s = raw if idioms else strip(raw)
        for k, r in table.items():
            if r is None:
                n = sum(1 for l in s.split("\n") if re.search(r"lsl", l) and re.search(r"lor", l))
            else:
                n = len(re.findall(r, s, flags=re.M))
            if n:
                uses[k] += n
                nfiles[k] += 1
    print(f"{len(files)} files, {lines} lines")
    for k in table:
        print(f"{uses[k]:6d} {nfiles[k]:4d}  {k}")

main(sys.argv[1:])
