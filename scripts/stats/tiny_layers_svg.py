#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# docs/pics/tiny-layers.svg: what a tiny program stands on, t-ix's side
# of docs/pics/layers.svg, which is m-ix's. Four columns, a kind of
# program each (a tool on the host, a program in ML and one in C on
# tiny-machine, the kernel), a column the boxes one needs the next of,
# from the program down to the system; a box says where its files are.
# The picture is this file's table: what it says was read in
# tiny/mkfile and tiny/TinyKernel/Makefile (what each link takes).
#
# Usage: scripts/stats/tiny_layers_svg.py > docs/pics/tiny-layers.svg

from html import escape

W, COL, GAP, LEFT, TOP = 1280, 296, 12, 30, 86
ORANGE, GREY, BLUE = ("#fff1e5", "#e16f24"), ("#f6f8fa", "#8c959f"), ("#ddf4ff", "#218bff")
WHITE = "#ffffff"

# a column: its title, what is under the title, then its boxes, the last
# one the system; a box: its name, what it is written in, its lines
COLUMNS = [
    ("A tool, on the host", "tiny-shell, tiny-c, tiny-vcs...  (mini-mk)", [
        ("The program", "OCaml, by mini-ml", [
            "tiny/TinyShell.ml: one file",
            "(its start object: mini-ml -start)"]),
        ("Its library", "OCaml, m-ix's", [
            "lib_core/: m-ix's standard library (List,",
            "String, Hashtbl, Buffer, Printf...) and",
            "commons/ (Console, FS, Procs, the",
            "capabilities); Unix: Linux's calls"]),
        ("Its runtime", "C, m-ix's", [
            "languages/ml/runtime/: mini-ml's runtime",
            "(the collector, the strings, the calls)"]),
        ("Its C library", "C, assembly, m-ix's", [
            "lib_core/libc/: Plan 9's libc, ix's,",
            "with the process's start and the system",
            "calls for Linux"]),
        ("The system", "", [
            "Linux on arm64 or arm (or mini-5i,",
            "which answers its calls)"]),
    ]),
    ("A program in ML, on tiny-machine", "windows, calc, temp, tetris  (tiny-ml)", [
        ("The program", "tiny-ml's ML", [
            "tiny/TinyAppCalculator.ml (or",
            "TinyWindows.ml...), and a last file that",
            "runs it, TinyKernel/user/calc.ml"]),
        ("The libraries it asks for", "ML", [
            "tiny/TinyLibGUI.ml (widgets),",
            "TinyLibPlayground.ml (shapes, a loop),",
            "TinyLibDraw.ml (the drawing's messages):",
            "files given to tiny-ml before its own"]),
        ("The core library", "ML", [
            "tiny/TinyLibCore.ml, a prelude: tiny-ml",
            "reads it before every program (the",
            "operators, option, the exceptions, List);",
            "TinyKernel/libml/TinyCalls.ml: the kernel's",
            "calls, as externals"]),
        ("TinyML's runtime", "C, by tiny-c", [
            "tiny/TinyMLRuntime/core.c: the allocator,",
            "Cheney's collector, strings, compare;",
            "included by TinyKernel/libml/mlsys.c",
            "(the heap in the program's megabyte,",
            "the calls as C functions)"]),
        ("The C runtime", "C, assembly", [
            "tiny/TinyCRuntime/: start.tm (the start),",
            "udivmod.tm (the division), libc.c;",
            "TinyKernel/libc/sys.tm: the system calls"]),
        ("The system", "", [
            "tiny-kernel, on tiny-machine"]),
    ]),
    ("A program in C, on tiny-machine", "sh, ls, cat, paint, ping, get...  (tiny-c)", [
        ("The program", "C", [
            "tiny/TinyKernel/user/sh.c, ls.c,",
            "paint.c...: one file each"]),
        ("What some of them add", "C", [
            "TinyKernel/libc/draw.c, draw.h: the",
            "drawing's messages (paint, wiki);",
            "net.c: a machine reached by its name",
            "(get)"]),
        ("The C runtime", "C, assembly", [
            "tiny/TinyCRuntime/: libc.c and libc.h",
            "(print, the strings, malloc), start.tm,",
            "udivmod.tm;",
            "TinyKernel/libc/sys.tm: the system calls"]),
        ("The system", "", [
            "tiny-kernel, on tiny-machine"]),
    ]),
    ("The kernel", "tiny-kernel  (tiny-ml, tiny-c)", [
        ("The kernel", "tiny-ml's ML", [
            "tiny/TinyKernel.ml: the processes, the",
            "files, the pipes, the system calls"]),
        ("Its parts that are files", "ML", [
            "tiny/TinyKernel/TinyKernelGraphics.ml",
            "(the pixels), TinyKernelNetwork.ml (IP,",
            "IL), TinyMemory.ml (the machine's bytes,",
            "as externals)"]),
        ("The core library", "ML", [
            "tiny/TinyLibCore.ml: the same prelude"]),
        ("TinyML's runtime", "C, by tiny-c", [
            "tiny/TinyMLRuntime/core.c, the same;",
            "included by TinyKernel/runtime.c (the",
            "kernel's memory, the console)"]),
        ("Its assembly", "tiny-cpu's", [
            "TinyKernel/entry.tm (the start, the",
            "traps), draw.tm (a row of pixels), the",
            "font; TinyCRuntime/udivmod.tm"]),
        ("The machine", "", [
            "tiny-machine (tiny/TinyMachine.ml,",
            "TinyMachine/): the CPU, the devices"]),
    ]),
]

NOTES = [
    "Orange: t-ix's own files. Grey: what is under them, m-ix's or the system. A name in two columns is the same file. The tools are compiled by",
    "m-ix's mini-ml (mini-mk), on lib_core/ whole, as m-ix's programs (docs/pics/layers.svg, its first column); what runs on tiny-machine by",
    "tiny-ml and tiny-c. While developing, dune builds a tool on OCaml's own standard library and lib_core/commons/.",
]


def text(x, y, s, size=12, weight="normal", fill="#1f2328", anchor="start", style=""):
    extra = f' font-style="{style}"' if style else ""
    return (f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{fill}" '
            f'text-anchor="{anchor}"{extra} xml:space="preserve">{escape(s)}</text>')


def rect(x, y, w, h, colors, fill=None):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill or colors[0]}" '
            f'stroke="{colors[1]}" stroke-width="1.5"/>')


def height(lines):
    return 36 + 17 * len(lines) + 4


def main():
    for _, _, boxes in COLUMNS:
        for name, _, lines in boxes:
            for line in lines:
                assert len(line) <= 44, (name, line)
    # the columns' boxes down to a common line, where the systems are
    body = max(sum(height(l) + 20 for _, _, l in boxes[:-1]) for _, _, boxes in COLUMNS)
    last = max(height(boxes[-1][2]) for _, _, boxes in COLUMNS)
    bottom = TOP + 64 + body + last
    H = bottom + 30 + 18 * len(NOTES) + 12
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
           'font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Helvetica, Arial, sans-serif">',
           '<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
           'orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="#57606a"/></marker></defs>',
           f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
           text(LEFT, 40, "What a tiny program stands on", 24, "600"),
           text(LEFT, 64, "t-ix's four kinds of program, and where each one's parts are. A box needs the one "
                "under it (the arrow).", 13, fill="#57606a")]
    for c, (title, sub, boxes) in enumerate(COLUMNS):
        x = LEFT + c * (COL + GAP)
        mid = x + COL // 2
        out += [rect(x, TOP, COL, 50, ORANGE), text(x + 14, TOP + 22, title, 16, "600"),
                text(x + 14, TOP + 40, sub, 12, fill="#57606a")]
        y = TOP + 64
        for i, (name, tag, lines) in enumerate(boxes):
            system = i == len(boxes) - 1
            h = last if system else height(lines)
            if system:
                # the arrow from the last box above, down to the common line
                out.append(f'<line x1="{mid}" y1="{y - 20}" x2="{mid}" y2="{bottom - last - 2}" stroke="#57606a" '
                           'stroke-width="2" marker-end="url(#a)"/>')
                y = bottom - last
            elif i > 0:
                out.append(f'<line x1="{mid}" y1="{y - 20}" x2="{mid}" y2="{y - 2}" stroke="#57606a" '
                           'stroke-width="2" marker-end="url(#a)"/>')
            # (grey: the system, and a box of m-ix's files)
            theirs = system or not lines[0].startswith(("tiny/", "TinyKernel/"))
            out.append(rect(x, y, COL, h, GREY if theirs else ORANGE, WHITE if i == 0 else None))
            out.append(text(x + 14, y + 23, name, 14, "600"))
            if tag:
                out.append(text(x + COL - 12, y + 23, tag, 11, fill="#57606a", anchor="end", style="italic"))
            for k, line in enumerate(lines):
                out.append(text(x + 14, y + 44 + 17 * k, line))
            y += h + 20
    for k, note in enumerate(NOTES):
        out.append(text(LEFT, bottom + 30 + 18 * k, note, 12, fill="#57606a"))
    out.append("</svg>")
    print("\n".join(out))


if __name__ == "__main__":
    main()
