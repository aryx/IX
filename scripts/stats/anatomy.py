#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What an executable of ix's is made of: its code's bytes by where they
# come from, read in mini-ld -v's listing of the link (each
# instruction, its address; a function's first line says TEXT name).
# The pieces, in the order mini-ld -nofollow lays them:
# - the start (mini-ml -start's object: ml_start, the curry functions);
# - each unit of ML, the program's and the library's: from its
#   Unit.Init, the functions f1_name<>, f2_name<>...;
# - mini-ml's runtime and the C library: a C or assembly function, by
#   the file that defines it (languages/ml/runtime/*.c, the parts
#   runtime.c includes; lib_core/libc/, the directory of the system
#   and of the machine first).
# What follows the code in the file (the strings, the constants, the
# globals) is one piece, "data": the listing does not say whose.
#
# Usage: mini-ld ... -v -o out objects... | scripts/stats/anatomy.py out [-v] [-prog dir] [-libs dir...]
#   out: the executable, for its size
#   -v: each unit and each C file, not one row for a group
#   -prog: the program's directory, for its sources' lines
#   -libs: where the units' sources are, to name each unit's directory
#     (default: lib_core's directories; tiny/TinyLib/ocaml for LIB=tiny)
# docs/projects.md, "What is in an executable", has three of them.

import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
RUNTIME = "languages/ml/runtime"
LIBC = "lib_core/libc"
STDLIB = ["lib_core/core", "lib_core/base", "lib_core/collections", "lib_core/printing", "lib_core/parsing",
          "lib_core/system", "lib_core/system/plan9", "lib_core/concurrency", "lib_core/commons",
          "lib_crypto", "lib_compression"]
# a function's definition: Plan 9's C has the name at the margin; an
# assembly file says TEXT name(SB)
# (not a declaration: a line that ends with ;)
CDEF = re.compile(r"^(?:[a-zA-Z_][\w \t\*]*[ \t\*])?([a-zA-Z_]\w*)\((?![^\n]*;[ \t]*$)", re.M)
SDEF = re.compile(r"^\s*TEXT\s+([\w·]+)(?:<>)?(?:\+0)?\(SB\)", re.M)
KEYWORDS = {"if", "while", "for", "switch", "return", "sizeof", "defined"}


def libc_files(plan9, arm):
    """the C library's files a program links: lib_core/mkfile's lists
    (LIBC_C, the system's, the machine's), as paths"""
    with open(os.path.join(ROOT, "lib_core/mkfile")) as h:
        text = h.read().replace("\\\n", " ")
    lists = {m.group(1): m.group(2).split() for m in re.finditer(r"^LIBC_(\w+)=(.*)$", text, re.M)}
    system, o = ("plan9" if plan9 else "linux"), ("5" if arm else "7")
    names = lists["C"] + lists[system] + lists.get(system + o, []) + lists["S" + o]
    if plan9:
        names.append("ix/syscall6_plan9_arm")
    out = []
    for n in names:
        n = n.replace("$OS", system)
        out.append(next(f for f in ("%s/%s.c" % (LIBC, n), "%s/%s.s" % (LIBC, n))
                        if os.path.exists(os.path.join(ROOT, f))))
    return out


def definitions(listing_names, plan9, arm):
    """a C or assembly function's file: the runtime's parts, then the
    C library's"""
    where = {}
    rt = os.path.join(ROOT, RUNTIME)
    files = sorted("%s/%s" % (RUNTIME, f) for f in os.listdir(rt) if f.endswith(".c")) + libc_files(plan9, arm)
    for f in files:
        with open(os.path.join(ROOT, f), encoding="latin-1") as h:
            text = h.read()
        # (a function a header of its directory defines, included here:
        # Plan 9's read, write and exit, syscall_plan9_arm.h's)
        for inc in re.findall(r'^#include\s+"([^"/]+\.h)"', text, re.M):
            local = os.path.join(ROOT, os.path.dirname(f), inc)
            if not f.startswith(RUNTIME) and os.path.exists(local):
                with open(local, encoding="latin-1") as h:
                    text += h.read()
        for name in (SDEF if f.endswith(".s") else CDEF).findall(text):
            if name not in KEYWORDS and name in listing_names:
                where.setdefault(name, f)
    return where


GROUPS = ["the start", "the program", "the library", "mini-ml's runtime", "the C library", "?"]


def measure(listing, out, libs, prog=""):
    """(total bytes, plan9, arm, [((group, source), bytes of code)]) of
    the executable out, from mini-ld -v's listing of its link"""
    funs, last = [], 0
    for line in listing:
        m = re.match(r"([0-9a-f]{8}): [0-9a-f]+\t(TEXT ([^+ ]+)\+0\(SB\))?", line)
        if m:
            last = int(m.group(1), 16)
            if m.group(3):
                funs.append((last, m.group(3)))
    names = {n.replace("<>", "") for _, n in funs}
    with open(out, "rb") as h:
        head = h.read(8)
    plan9 = head[:4] != b"\x7fELF"
    arm = plan9 or head[4] == 1  # (Plan 9's a.out here is arm's; an ELF of 32 bits)
    where = definitions(names, plan9, arm)
    unit_dir = {}
    # (Plan 9's Unix and Sys_plan9 are system/plan9/'s)
    for d in sorted(libs, key=lambda d: not (plan9 and d.endswith("/plan9"))):
        for f in os.listdir(os.path.join(ROOT, d)):
            if f.endswith(".ml"):
                unit_dir.setdefault(f[:-3], d)
    pieces, order = {}, []
    unit = None
    for i, (addr, name) in enumerate(funs):
        size = (funs[i + 1][0] if i + 1 < len(funs) else last + 4) - addr
        if name.endswith(".Init"):
            unit = name[:-5]
        if name.endswith(".Init") or (unit and re.match(r"f\d+_.*<>$", name)):
            u = "std_exit" if unit == "Std_exit" else unit
            d = unit_dir.get(u)
            key = ("the library", "%s/%s.ml" % (d, u)) if d else ("the program", os.path.join(prog, u + ".ml"))
        else:
            unit = None
            f = where.get(name.replace("<>", ""))
            if f is None:
                key = ("the start", "mini-ml -start") if name.startswith("ml_") else ("?", name)
            elif f.startswith(RUNTIME):
                key = ("mini-ml's runtime", f)
            else:
                key = ("the C library", f)
        if key not in pieces:
            pieces[key] = 0
            order.append(key)
        pieces[key] += size
    order.sort(key=lambda k: GROUPS.index(k[0]))
    return os.path.getsize(out), plan9, arm, [(k, pieces[k]) for k in order]


def lines_of(src):
    path = os.path.join(ROOT, src)
    if not os.path.exists(path):
        return 0
    with open(path, encoding="latin-1") as h:
        return h.read().count("\n")


def main():
    args = sys.argv[1:]
    verbose = "-v" in args
    libs = STDLIB
    if "-libs" in args:
        libs = args[args.index("-libs") + 1:]
        args = args[:args.index("-libs")]
    prog = ""
    if "-prog" in args:
        prog = args[args.index("-prog") + 1]
        del args[args.index("-prog"):args.index("-prog") + 2]
    out = next(a for a in args if not a.startswith("-"))
    total, plan9, arm, pieces = measure(sys.stdin, out, libs, prog)
    code = sum(s for _, s in pieces)
    print("%s: %s bytes (%s; %s)" % (os.path.basename(out), f"{total:,}",
                                    "Plan 9's a.out" if plan9 else "ELF", "arm" if arm else "arm64"))
    print(f"{'bytes':>9}  {'%':>5}  {'lines':>6}  piece (lines: its sources', every line)")
    for g in GROUPS:
        mine = [(src, s) for (gg, src), s in pieces if gg == g]
        if not mine:
            continue
        size = sum(s for _, s in mine)
        print(f"{size:>9,}  {100 * size / total:>5.1f}  {sum(lines_of(src) for src, _ in mine):>6,}  "
              f"{g} ({len(mine)} file{'s' if len(mine) > 1 else ''})")
        if verbose or g == "?":
            for src, s in sorted(mine, key=lambda x: -x[1]):
                print(f"{s:>20,}  {lines_of(src):>6,}  {src}")
    print(f"{total - code:>9,}  {100 * (total - code) / total:>5.1f}  {'':>6}  "
          "data and the header: strings, constants, globals (not told apart)")


if __name__ == "__main__":
    main()
