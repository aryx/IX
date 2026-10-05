#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The OCaml features ix's own code uses beyond mini-ml's subset, and the
# idioms a new construct could shorten (plan_ml_bootstrap.md, "The
# census"): regexps over the files git knows, with the comments and
# strings removed, so the counts are close, not exact.
#
# --holes: the lines mlpp's type t = _ would save (plan_ml_bootstrap.md,
# decision 1): the .mli's type declarations of several lines that the
# .ml repeats line for line, in all of ix and in the files mini-ml
# parses today (parse_ix.sh). Not languages/ml/, mlpp's own source.
#
# Usage: ix_features.py [--idioms | --holes] [path-prefix...]
#   e.g. ix_features.py languages/ml lib_core assembler/   (mini-ml's closure)

import os, re, subprocess, sys
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

def holes():
    here = os.path.dirname(os.path.abspath(__file__))
    out = subprocess.run([os.path.join(here, "parse_ix.sh")], capture_output=True, text=True).stdout
    unparsed = set(l.split(":")[0] for l in out.split("\n") if re.match(r"[^ ]+:\d+:", l))
    mlis = subprocess.run(["git", "ls-files", "*.mli"], capture_output=True, text=True).stdout.split()
    total = today = types = 0
    for mli in mlis:
        ml = mli[:-1]
        if ml.startswith("languages/ml/") or not os.path.exists(ml):
            continue
        in_ml = set(l.rstrip() for l in open(ml).read().split("\n"))
        # a declaration: from its type/and line to the next item
        blocks, cur = [], None
        for l in open(mli).read().split("\n"):
            if re.match(r"(type|and) ", l):
                cur = [l]
                blocks.append(cur)
            elif re.match(r"(val|external|exception|module|open|include|\(\*|$)", l):
                cur = None
            elif cur is not None:
                cur.append(l)
        for b in blocks:
            # type t = _ is a line too: a one-line declaration saves none
            if len(b) > 1 and all(x.rstrip() in in_ml for x in b):
                total += len(b) - 1
                if ml not in unparsed and mli not in unparsed:
                    today += len(b) - 1
                    types += 1
    print(f"type t = _ would save {total} lines in all of ix, {today} in the files mini-ml parses ({types} types)")

def main(argv):
    if "--holes" in argv:
        return holes()
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
