#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What t-ix takes from m-ix's libraries: for each tiny program of the
# host (tiny/mkfile's PROGS: the ones mini-ml compiles; not the
# kernel's side, which tiny-ml compiles with its own prelude, nor
# tiny-machine-window, SDL's), the modules of lib_core/, lib_crypto/
# and lib_compression/ it names, and the ones those name, to the end
# (ocamldep -modules on each .ml and .mli; Pervasives and std_exit
# always). The lines are loc.py's (code, comment and blank), a
# module's .ml and .mli together.
#
# That is what there is to read under a tiny program, not what is
# linked: mini-mk's link starts every unit of the stdlib and of
# commons/ (mkconfig's STD and COMMONS), named or not.
#
# Usage: scripts/stats/tiny_deps.py [-v]
#   -v: each program's own list of modules too

import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loc  # noqa: E402

# where a module's file is looked for, in this order (system/ before
# system/plan9/: Linux's Unix; commons/ before concurrency/: Source)
DIRS = ["lib_core/core", "lib_core/base", "lib_core/collections",
        "lib_core/printing", "lib_core/parsing", "lib_core/system",
        "lib_core/commons", "lib_core/concurrency",
        "lib_crypto", "lib_compression"]
# a program's files: its own, then its library's (tiny/mkfile)
PROGRAMS = {
    "tiny-build": ["TinyBuildSystem"], "tiny-shell": ["TinyShell"],
    "tiny-editor": ["TinyEditor"], "tiny-assembler": ["TinyAssembler"],
    "tiny-c": ["TinyC"], "tiny-ml": ["TinyML"], "tiny-db": ["TinyDatabase"],
    "tiny-vcs": ["TinyVCS"], "tiny-arm": ["TinyCPUArm", "TinyLibArm"],
    "tiny-pi": ["TinyMachinePi", "TinyLibArm"],
    "tiny-cpu": ["TinyCPU", "TinyLibCPU"],
    "tiny-machine": ["TinyMachine", "TinyLibMachine", "TinyLibCPU"], "tiny-mkfs": ["TinyMkfs"],
}
ALWAYS = ["Pervasives", "std_exit"]


def named(path):
    """the modules a file names (ocamldep's: maybe not a module at all)"""
    out = subprocess.run(["ocamldep", "-modules", path], check=True,
                         capture_output=True, text=True).stdout
    return out.split(":", 1)[1].split()


def main():
    verbose = "-v" in sys.argv[1:]
    where = {}  # a module: its files
    for d in DIRS:
        for f in sorted(os.listdir(d)):
            m = re.match(r"(\w+)\.mli?$", f)
            if m and (m.group(1) not in where or where[m.group(1)][0].startswith(d + "/")):
                where.setdefault(m.group(1), []).append(d + "/" + f)
    deps, lines = {}, {}
    for m, fs in where.items():
        deps[m] = {n for f in fs for n in named(f) if n in where and n != m}
        lines[m] = 0
        for f in fs:
            with open(f, encoding="utf-8", errors="replace") as h:
                lines[m] += sum(loc.count(h.read()))

    def closure(roots):
        seen, todo = set(), list(roots)
        while todo:
            m = todo.pop()
            if m not in seen:
                seen.add(m)
                todo.extend(deps[m])
        return seen

    users = {m: [] for m in where}  # a module: the programs under which it is
    unknown = {}
    print(f"{'lines':>7}  {'program':<16}{'modules':>8}  what it names itself, outside the stdlib")
    for prog, files in PROGRAMS.items():
        direct = {n for f in files for n in named("tiny/%s.ml" % f)}
        for n in direct - set(where) - {f for fs in PROGRAMS.values() for f in fs}:
            unknown.setdefault(n, []).append(prog)
        mods = closure([n for n in direct if n in where] + ALWAYS)
        for m in mods:
            users[m].append(prog)
        own = sorted(n for n in direct if n in where and not where[n][0].startswith(
            ("lib_core/core", "lib_core/base", "lib_core/collections", "lib_core/printing")))
        print(f"{sum(lines[m] for m in mods):>7,}  {prog:<16}{len(mods):>8}  {' '.join(own)}")
        if verbose:
            print(f"{'':>9}{' '.join(sorted(mods))}")
    used = sorted((m for m in where if users[m]), key=lambda m: (DIRS.index(os.path.dirname(where[m][0])), m))
    print()
    print(f"{'lines':>7}  {'module':<16}{'programs':>8}  directory")
    for m in used:
        print(f"{lines[m]:>7,}  {m:<16}{len(users[m]):>8}  {os.path.dirname(where[m][0])}/")
    print()
    print(f"{'lines':>7}  {'modules':>7}  {'of':>7}  {'modules':>7}  directory")
    for d in DIRS:
        ms = [m for m in where if os.path.dirname(where[m][0]) == d]
        us = [m for m in ms if users[m]]
        print(f"{sum(lines[m] for m in us):>7,}  {len(us):>7}  {sum(lines[m] for m in ms):>7,}  {len(ms):>7}  {d}/")
    print(f"{sum(lines[m] for m in used):>7,}  {len(used):>7}  {sum(lines.values()):>7,}  {len(where):>7}  all")
    not_used = sorted(m for m in where if not users[m])
    print()
    print("under no tiny program: " + " ".join(not_used))
    for n, progs in sorted(unknown.items()):
        print(f"named, and in none of these directories: {n} ({', '.join(progs)})")


if __name__ == "__main__":
    main()
