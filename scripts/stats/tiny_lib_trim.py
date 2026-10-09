#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# tiny/TinyLib/ocaml/ trimmed to what the tiny programs call: a value
# of a module there (a val or an external of its .mli) that no tiny
# program names, and no other module of TinyLib, and that the module's
# own .ml does not use, is taken out of the .mli (with the comment that
# follows it) and of the .ml (trim_stdlib.py's cuts); again until
# nothing goes, since a function taken out may have been another's
# only caller. Then a module that nothing names any more is said: its
# two files are to be removed, and its name in tiny/mkfile's TSTD.
#
# A name is looked for as a word (M.v; v alone where M is opened, in
# M's own .ml, and anywhere for Pervasives), in the code and in the
# comments alike: a value may be kept for nothing, never taken out
# wrongly but by a name made at run time. Operators (val ( + )) and
# types, exceptions and modules stay. The build is the judge: mini-mk
# LIB=tiny in tiny/.
#
# Usage: scripts/stats/tiny_lib_trim.py [-n | -t] [keep...]
#   -n: say what would go, change nothing
#   -t: TinyLib/README.md's table: each module, where it is from, its
#       lines there and here (.ml and .mli, every line)
#   keep: M.v's to leave (what the build asked back)

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trim_stdlib as trim  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
LIB = os.path.join(ROOT, "tiny/TinyLib/ocaml")
# the tiny programs of the host (tiny/mkfile's), and their libraries
PROGRAMS = ["TinyBuildSystem", "TinyShell", "TinyEditor", "TinyAssembler", "TinyC", "TinyML",
            "TinyDatabase", "TinyVCS", "TinyCPUArm", "TinyLibArm", "TinyMachinePi", "TinyCPU",
            "TinyLibCPU", "TinyMachine", "TinyMkfs"]
# kept whole though no tiny program names them yet (the author,
# 2026-10-09: "let's not delete Chan.ml and Chan.mli; we should use them
# more in the futur"), with Fpath_, whose operators Chan opens
KEPT = ["Chan", "Fpath_"]
VALUE = re.compile(r"^(?:val|external) ([a-z_][A-Za-z_0-9']*)", re.M)


def read(path):
    with open(path, encoding="latin-1") as f:
        return f.read()


def word(name, text):
    return len(re.findall(r"(?<![A-Za-z_0-9'.])%s(?![A-Za-z_0-9'])" % re.escape(name), text))


def table():
    lines = lambda p: read(p).count("\n")
    print("| module | from | lines there | lines here |\n|---|---|---|---|")
    there = here = 0
    for m in sorted(f[:-4] for f in os.listdir(LIB) if f.endswith(".mli")):
        d = next(d for d in ["lib_core/core", "lib_core/base", "lib_core/collections", "lib_core/printing",
                             "lib_core/system", "lib_core/commons", "lib_crypto", "lib_compression"]
                 if os.path.exists(os.path.join(ROOT, d, m + ".mli")))
        a = sum(lines(os.path.join(ROOT, d, m + e)) for e in (".ml", ".mli"))
        b = sum(lines(os.path.join(LIB, m + e)) for e in (".ml", ".mli"))
        there, here = there + a, here + b
        print("| `%s` | `%s/` | %d | %d |" % (m, d, a, b))
    print("| all | | %d | %d |" % (there, here))


def main():
    args = sys.argv[1:]
    if "-t" in args:
        return table()
    dry = "-n" in args
    keep = {a for a in args if a != "-n"}
    progs = {p: read(os.path.join(ROOT, "tiny/%s.ml" % p)) for p in PROGRAMS}
    gone = {}
    while True:
        mods = sorted(f[:-4] for f in os.listdir(LIB) if f.endswith(".mli"))
        ml = {m: read(os.path.join(LIB, m + ".ml")) for m in mods}
        mli = {m: read(os.path.join(LIB, m + ".mli")) for m in mods}
        ml["std_exit"] = read(os.path.join(LIB, "std_exit.ml"))
        changed = False
        for m in mods:
            if m in KEPT:
                continue
            # the other files: where M.v is looked for; and v alone,
            # where M is opened (all of them for Pervasives)
            others = [t for p, t in progs.items()] + [ml[o] for o in ml if o != m] + [mli[o] for o in mli if o != m]
            opened = others if m == "Pervasives" else [t for t in others if re.search(r"\bopen %s\b" % m, t)]
            out = []
            for v in VALUE.findall(mli[m]):
                if "%s.%s" % (m, v) in keep:
                    continue
                if any(re.search(r"\b%s\.%s(?![A-Za-z_0-9'])" % (m, re.escape(v)), t) for t in others):
                    continue
                if any(word(v, t) for t in opened):
                    continue
                # its own .ml: more than its definition (let v, and v,
                # external v; a let rec's v names itself: not counted,
                # a definition's line)
                body = [l for l in ml[m].split("\n")
                        if not re.match(r"(let|and|external)( rec)? \(?%s\b" % re.escape(v), l)]
                if word(v, "\n".join(body)):
                    continue
                out.append(v)
            if not out:
                continue
            a, b = mli[m].split("\n"), ml[m].split("\n")
            for v in out:
                # a let whose next item is its "and": the pair stays
                i = next((k for k, l in enumerate(b) if re.match(r"let( rec)? \(?%s\b" % re.escape(v), l)), None)
                if i is not None:
                    j = next((k for k in range(i + 1, len(b)) if trim.ITEM.match(b[k]) or b[k].startswith("(*")), None)
                    if j is not None and b[j].startswith("and "):
                        continue
                saved = list(b)
                if not trim.cut_ml(b, v):
                    b = saved
                    continue
                trim.cut_mli(a, v)
                gone.setdefault(m, []).append(v)
                changed = True
            if not dry:
                open(os.path.join(LIB, m + ".mli"), "w", encoding="latin-1").write("\n".join(a))
                open(os.path.join(LIB, m + ".ml"), "w", encoding="latin-1").write("\n".join(b))
        if dry or not changed:
            break
    # a value taken out leaves its blank line beside its neighbour's:
    # two blank lines made one, none at a file's start or end
    if not dry:
        for f in sorted(os.listdir(LIB)):
            text = read(os.path.join(LIB, f))
            new = re.sub(r"\n[ \t]*(\n[ \t]*)+\n", "\n\n", text).strip("\n") + "\n"
            if new != text:
                open(os.path.join(LIB, f), "w", encoding="latin-1").write(new)
    for m in sorted(gone):
        print("%s (%d): %s" % (m, len(gone[m]), " ".join(gone[m])))
    print("%d values" % sum(len(v) for v in gone.values()))
    # a module nothing names any more (Pervasives and std_exit always are)
    texts = dict(progs)
    for f in os.listdir(LIB):
        texts[f] = read(os.path.join(LIB, f))
    for m in sorted(f[:-4] for f in os.listdir(LIB) if f.endswith(".mli")):
        if m != "Pervasives" and m not in KEPT and not any(re.search(r"\b%s\." % m, t) or re.search(r"\bopen %s\b" % m, t)
                                           for f, t in texts.items() if not f.startswith(m + ".")):
            print("named by nothing: %s" % m)


if __name__ == "__main__":
    main()
