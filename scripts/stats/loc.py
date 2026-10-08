#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Lines of code across ix, grouped as ix is: the mini programs, the
# faithful twins (m-ix: assembler/, languages/c/, ..., kernels/), the
# tiny programs (t-ix: tiny/, one line per file, since a file is a
# program), the shared libraries (lib_*/), and apart from all of them
# the tests (every tests/ or X_tests/ directory, and the top tests/).
# OCaml (.ml, .mli, .mll, .mly), C (.c, .h) and assembly (.s): the
# runtimes, the kernels' starts, lib_core/libc/. Each line is counted
# once, as code (it has some code, maybe a comment too), comment (only
# a comment, or inside one) or blank.
#
# The files are git's (tracked, and new ones not ignored), so _build/
# is never counted. Neither is what ix runs the same without, the
# alternatives and the optional: APART, below, has the list, each with
# its reason, and the last lines printed are their sum and each one's
# lines (-v: a row each, with why it is apart):
# compat/ (a reference's exact output), opti/ and ssa/ (optimizations),
# the kernel's steps, the kernels' reference build (by ocaml-light
# and gcc) with mini-9pi's pixels in C, the runtime's header for gcc
# (gnu.h), the games' software platform
# (lib_graphics/software/ and the playground's platform over it; the
# games draw by the draw device), the systems of kernels/ that
# are not mini-9pi's nor mini-xv6's (mini-oberon, mini-singularity...),
# mini-smalltalk, which is mini-squeak's, and the playground's
# languages (mini-scheme, mini-pascal with lib_terminal/) and their
# two programs in editors/ (drscheme, turbopascal), languages/formula/,
# examples/ and apps/.
#
# Usage: scripts/stats/loc.py [-v | -l]
#   -v: every subdirectory (kernels/xv6/, lib_core/libc/, ...) and every
#       tests/ directory rather than one line per program
#   -l: only today's line for docs/loc.md, the log of those last numbers
#
# The lines come first, next to the name they count; then the files,
# the lines of each language (ocaml, c, asm), and the code, comment and
# blank lines. A group's total comes first, its parts indented under
# it. Then the same by kind of file: .ml, .mli, .mll and .mly, .c, .h,
# .s, without the tests. Last, the numbers to keep small, what there
# is to read for an operating system and its tools: m-ix (the mini
# programs and the libraries) and t-ix (the tiny programs), without
# the tests; and under m-ix, said not counted in it, what is apart:
# its sum, then each entry's lines (-v: each entry of APART with why
# it is apart).

import os
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
              "raspberry", "kernels", "builder", "shell", "editors",
              "database", "version_control", "utilities", "windows", "apps"]),
    ("tiny", ["tiny"]),
    ("libraries", ["lib_core", "lib_compression", "lib_crypto", "lib_networking", "lib_graphics"]),
]


def classify(path, verbose):
    """(group, subgroup) of a file: tests wherever they are, else by
    its top directory. The subgroup is the top directory (a program, a
    library), but in tiny/ the file itself (a program), and with
    verbose the directory under the top one (kernels/xv6/), or the tests
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
    # (not a link: a file that several directories use is counted where it is)
    return [f for f in out.splitlines() if f and not os.path.islink(f)]


# What is not counted in m-ix, but said at the end, each with its
# lines: alternatives and options, which ix builds and runs the same
# without. A name (its row's), why it is apart, and what a path must
# match: a directory's name anywhere in it, or a regular expression.
APART = [
    ("compat/", "kept for a reference's exact output (5c's code, 5l's layout)",
     lambda dirs, path: "compat" in dirs),
    ("opti/, ssa/", "optimizations, each behind a flag",
     lambda dirs, path: "opti" in dirs or "ssa" in dirs),
    ("kernels/steps/", "the steps mini-xv6 was built up by: each a small kernel of its own",
     lambda dirs, path: path.startswith("kernels/steps/")),
    ("the reference kernels", "by ocaml-light, gcc and GNU's as and ld (the Makefiles): their start and C library",
     lambda dirs, path: re.match(r"kernels/lib_machine/(libc\.c|pi[14]/start\.s)$", path)),
    # (the author, 2026-10-08: "ok let's not count gnu.h")
    ("runtime/gnu.h", "mini-ml's runtime by gcc over glibc (mini-ml -gas: GNU's as and ld), the other route",
     lambda dirs, path: path == "languages/ml/runtime/gnu.h"),
    ("lib_graphics/c/", "mini-9pi's pixels by Plan 9's C (PIXEL=c), to compare with the OCaml ones",
     lambda dirs, path: path.startswith("kernels/9pi/lib_graphics/c/")),
    # (the author, 2026-10-07: "those are optional and currently the
    # games are using the draw-device platform")
    ("the software platform", "the games' pixels by the program (PLATFORM=software): they draw by the draw device",
     lambda dirs, path: path.startswith(("lib_graphics/software/", "lib_playground/platforms/software/"))),
    # (the author, 2026-10-08: "let's adjust make loc to not count
    # those languages too"; lib_terminal/ is what Pascal's machine
    # talks through, and nothing else's yet)
    ("languages/scheme/", "mini-scheme, the playground's Scheme (plan_scheme.md): a language that is run, not m-ix's",
     lambda dirs, path: path.startswith("languages/scheme/")),
    ("languages/pascal/", "mini-pascal, the playground's Pascal, with lib_terminal/ under it (plan_pascal.md): the same",
     lambda dirs, path: path.startswith(("languages/pascal/", "lib_terminal/"))),
    # (the author, 2026-10-08: "let's not cound drscheme and turbopascal
    # as part of make loc"; the second when it is there)
    ("editors/drscheme/, turbopascal/", "TinyDrScheme and TinyTurboPascal, the playground's two programs of those languages: the same",
     lambda dirs, path: path.startswith(("editors/drscheme/", "editors/turbopascal/"))),    # (the author: "just like we don't consider
    # languages/{scheme,smalltalk,pascal} just ml and c we count")
    ("languages/formula/", "a sheet's formulas, the playground's (plan_gui.md): of languages/, ml and c count",
     lambda dirs, path: path.startswith("languages/formula/")),    # (the author, 2026-10-08: "let's not count examples and apps as
    # part of make loc")
    ("examples/", "the playground's examples: the 7GUIs, two worlds (plan_gui.md)",
     lambda dirs, path: path.startswith("examples/")),
    ("apps/", "the programs with a window (mini-colors) and the playground's kits",
     lambda dirs, path: path.startswith("apps/")),
]

# The kernels that count in m-ix are mini-9pi and mini-xv6, with what
# they stand on (kernels/lib_machine/, and kernels/tools/, their images' tools).
# Every other system in kernels/ (mini-oberon, mini-singularity...: the
# plan_system_*.md) is given a place here and is not m-ix's: a row
# each, whatever is there. (The author, 2026-10-07: "only 9pi and maybe
# xv6 (and lib) should count really".)
KERNELS = ["9pi", "xv6", "lib_machine", "tools"]
SYSTEMS = []  # their rows, after APART's (main fills it)


def other_systems():
    """a row of APART for each directory of kernels/ that is another system"""
    rows = []
    for d in sorted(os.listdir("kernels")):
        if os.path.isdir("kernels/" + d) and d not in KERNELS and d != "steps":
            rows.append(("kernels/%s/" % d, "another system given a place here (plan_system_%s.md): not m-ix's" % d,
                         lambda dirs, path, d=d: path.startswith("kernels/%s/" % d)))
    # (and a system's language, where it is a program of its own: the
    # author, 2026-10-07: "let's not count languages/smalltalk and
    # kernels/squeak as part of make loc")
    rows.append(("languages/smalltalk/", "mini-smalltalk, mini-squeak's language (plan_system_squeak.md): not m-ix's",
                 lambda dirs, path: path.startswith("languages/smalltalk/")))
    return rows


def apart(path):
    """the entry of APART the file is in (not a test), or None"""
    dirs = path.split("/")[:-1]
    if any(d == "tests" or d.endswith("_tests") for d in dirs):
        return None
    return next((name for name, _, match in APART + SYSTEMS if match(dirs, path)), None)


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
KIND = {"ml": ".ml", "mli": ".mli", "mll": ".mll .mly", "mly": ".mll .mly",
        "c": ".c", "h": ".h", "s": ".s"}


def row(name, s, indent=0):
    cells = "".join(f"{s[f]:>{CELL[f]},}" for f in REST)
    print(f"{s['lines']:>7,}  {' ' * indent}{name:<{WIDTH - indent}}{cells}")


def main():
    verbose = "-v" in sys.argv[1:]
    stats = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
    kinds = defaultdict(lambda: defaultdict(int))
    mix = defaultdict(int)  # m-ix: the mini programs and the libraries
    extra = defaultdict(lambda: defaultdict(int))  # APART's and SYSTEMS'
    SYSTEMS.extend(other_systems())
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
        if apart(path):
            # only in its own row, at the end
            s = extra[apart(path)]
            s["files"] += 1
            s[LANGUAGE[ext]] += code + comment + blank
            s["code"] += code
            s["comment"] += comment
            s["blank"] += blank
            s["lines"] += code + comment + blank
            continue
        # a row's, and (the tests apart) its kind's
        also = []
        if group != "tests":
            also.append(kinds[KIND[ext]])
        if group in ("mini", "libraries"):
            also.append(mix)
        for s in [stats[group][sub]] + also:
            s["files"] += 1
            s[LANGUAGE[ext]] += code + comment + blank
            s["code"] += code
            s["comment"] += comment
            s["blank"] += blank
            s["lines"] += code + comment + blank

    if "-l" in sys.argv[1:]:
        # docs/loc.md's: the date, the commit, m-ix, what is apart (compat/,
        # opti/ and ssa/, then the kernel's: the steps, the reference
        # build and the pixels in C, as one number; not the software
        # platform, nor the other systems of kernels/, SYSTEMS), t-ix
        def git(*args):
            return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout.strip()
        tiny = sum(s["lines"] for s in stats.get("tiny", {}).values())
        print(f"| {git('log', '-1', '--format=%ad', '--date=short')} | `{git('log', '-1', '--format=%h')}` "
              f"| {mix['lines']:,} | {extra['compat/']['lines']:,} | {extra['opti/, ssa/']['lines']:,} "
              f"| {sum(extra[n]['lines'] for n, _, _ in APART[2:5]):,} | {tiny:,} | |")
        return

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
    row("m-ix: mini + libraries", mix)
    row("t-ix: tiny", total(stats.get("tiny", {}).values()))
    # not in m-ix's lines: what ix runs the same without, and why
    print()
    print("not counted above (alternatives and options: ix is the same without them):")
    there = [(name, why) for name, why, _ in APART + SYSTEMS if name in extra]
    if "-v" in sys.argv[1:]:
        for name, why in there:
            row(name, extra[name], 2)
            print(f"{'':>11}{why}")
        row("all of them", total(extra.values()), 2)
    else:
        # one row, then each entry's lines (-v: a row each, with why)
        row("all of them", total(extra.values()), 2)
        line = ""
        for i, (name, _) in enumerate(there):
            item = f"{name} {extra[name]['lines']:,}" + (";" if i < len(there) - 1 else "")
            if line and len(line) + 1 + len(item) > 69:
                print(f"{'':>11}{line}")
                line = ""
            line = (line + " " + item) if line else item
        if line:
            print(f"{'':>11}{line}")


if __name__ == "__main__":
    main()
