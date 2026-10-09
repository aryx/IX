#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# docs/pics/anatomy.svg: what is in an executable of ix's, for a few of
# them side by side, each a column of boxes, a piece each (anatomy.py's:
# the start, the program, the library, mini-ml's runtime, the C library,
# the data), as tall as it is big, with where it comes from and what
# compiled it.
#
# Usage: scripts/stats/anatomy_svg.py out.svg column...
#   column: "title|subtitle|executable|listing|program's directory|library directories (spaces)|system"
#   (the listing is mini-ld -v's of the executable's link; docs/projects.md
#   has the commands)

import os
import sys
from html import escape

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import anatomy  # noqa: E402

W, COL, GAP, LEFT, TOP = 1280, 392, 22, 30, 150
SCALE = 620 / 830000  # pixels a byte
MIN = 74  # a box's least height: its four lines
COLORS = {"the start": ("#f6f8fa", "#8c959f"), "the program": ("#fff8c5", "#bf8700"),
          "the library": ("#ddf4ff", "#218bff"), "mini-ml's runtime": ("#dafbe1", "#2da44e"),
          "the C library": ("#fbefff", "#a475f9"), "data": ("#f6f8fa", "#8c959f")}


def text(x, y, s, size=12, weight="normal", fill="#1f2328", anchor="start"):
    return (f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{fill}" '
            f'text-anchor="{anchor}" xml:space="preserve">{escape(s)}</text>')


def top_dirs(srcs, depth):
    seen = []
    for s in srcs:
        d = "/".join(s.split("/")[:depth]) + "/"
        if d not in seen:
            seen.append(d)
    return seen


def column(x, spec):
    title, subtitle, exe, listing, prog, libs, system = spec.split("|")
    libs = libs.split()
    with open(listing) as h:
        total, plan9, arm, pieces = anatomy.measure(h, exe, libs, prog)
    o = "5" if arm else "7"
    out = [f'<rect x="{x}" y="86" width="{COL}" height="50" rx="8" fill="#ffffff" stroke="#57606a" stroke-width="1.5"/>',
           text(x + 14, 108, title, 16, "600"),
           text(x + 14, 126, f"{subtitle}  {total:,} bytes", 12, fill="#57606a")]
    y = TOP
    code = sum(s for _, s in pieces)
    rows = []
    for g in anatomy.GROUPS[:5]:
        mine = [(src, s) for (gg, src), s in pieces if gg == g]
        size = sum(s for _, s in mine)
        big = [os.path.basename(src)[:-3] for src, _ in sorted(mine, key=lambda p: -p[1])[:3]]
        srcs = [src for src, _ in mine]
        if g == "the start":
            lines = ["made by mini-ml -start: the units' initializations", "in their order, and the functions partial",
                     "applications call"]
        elif g == "the program":
            n = len(mine)
            lines = [f"{prog}/{srcs[0].split('/')[-1]}" if n == 1 else f"{prog}/: {n} units ({', '.join(big)}...)",
                     f"{sum(anatomy.lines_of(s) for s in srcs):,} lines of OCaml", f"compiled by mini-ml -m {o}"]
        elif g == "the library":
            there = sum(1 for d in libs for f in os.listdir(os.path.join(anatomy.ROOT, d)) if f.endswith(".ml"))
            dirs = top_dirs(srcs, 3 if srcs[0].startswith("tiny/") else 1)
            lines = [f"{' '.join(dirs)}: {len(mine)} of its {there} units, the ones named",
                     f"the largest: {', '.join(big)}",
                     f"{sum(anatomy.lines_of(s) for s in srcs):,} lines of OCaml (.ml), by mini-ml; kept by mini-ar"]
        elif g == "mini-ml's runtime":
            lines = [f"{anatomy.RUNTIME}/: runtime.c and the {len(mine) - 1} parts", "it includes (gc.c, io.c, strings.c, unix.c...)",
                     f"{sum(anatomy.lines_of(s) for s in srcs):,} lines of C, by mini-cc -m {o}"]
        else:
            asm = sum(1 for s in srcs if s.endswith(".s"))
            lines = [f"{anatomy.LIBC}/ (Plan 9's, by goken): {len(mine)} files,",
                     "port/, os/%s/, the start (rt0.s) and the call (svc)" % ("plan9" if plan9 else "linux"),
                     f"{sum(anatomy.lines_of(s) for s in srcs):,} lines: C by mini-cc, {asm} of assembly by mini-asm"]
        rows.append((g, size, lines))
    rows.append(("data", total - code, ["what follows the code in the file: strings,", "constants, globals, and the header",
                                        "(ELF's)" if not plan9 else "(Plan 9's a.out: 32 bytes)"]))
    for g, size, lines in rows:
        h = max(MIN, round(size * SCALE))
        fill, stroke = COLORS[g]
        out.append(f'<rect x="{x}" y="{y}" width="{COL}" height="{h}" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="1.5"/>')
        name = "Data, and the header" if g == "data" else "The " + g[4:] if g.startswith("the ") else g
        out.append(text(x + 14, y + 21, name, 14, "600"))
        out.append(text(x + COL - 12, y + 21, f"{size:,} bytes, {100 * size / total:.0f}%", 12, fill="#57606a", anchor="end"))
        for i, l in enumerate(lines):
            out.append(text(x + 14, y + 40 + 15 * i, l, 12))
        y += h + 8
    # what is under the executable
    out.append(f'<line x1="{x + COL / 2}" y1="{y}" x2="{x + COL / 2}" y2="{y + 22}" stroke="#57606a" stroke-width="1.5" marker-end="url(#a)"/>')
    y += 26
    out.append(f'<rect x="{x}" y="{y}" width="{COL}" height="56" rx="8" fill="#ffffff" stroke="#57606a" stroke-width="1.5" stroke-dasharray="5 4"/>')
    a, b = system.split(";")
    out.append(text(x + 14, y + 23, a.strip(), 14, "600"))
    out.append(text(x + 14, y + 42, b.strip(), 12))
    return out, y + 56


def main():
    path, specs = sys.argv[1], sys.argv[2:]
    body, bottom = [], 0
    for i, spec in enumerate(specs):
        out, y = column(LEFT + i * (COL + GAP), spec)
        body += out
        bottom = max(bottom, y)
    height = bottom + 60
    head = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {height}" width="{W}" height="{height}" '
            "font-family=\"-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif\">",
            '<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
            'orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="#57606a"/></marker></defs>',
            f'<rect width="{W}" height="{height}" fill="#ffffff"/>',
            text(30, 40, "What is in an executable of ix", 24, "600"),
            text(30, 64, "Three programs linked by mini-ld, their bytes by where they come from, in the file's order. "
                 "A box is as tall as its piece is big (a small one has the height of its text).", 13, fill="#57606a")]
    foot = [text(30, height - 24, "Measured by scripts/stats/anatomy.py on mini-ld -v's listing of each link; "
                 "drawn by scripts/stats/anatomy_svg.py.", 12, fill="#57606a"), "</svg>"]
    with open(path, "w") as h:
        h.write("\n".join(head + body + foot) + "\n")


if __name__ == "__main__":
    main()
