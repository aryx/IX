#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The picture tiny-machine -net tiny/tests/www gives for "wiki
# mandelbrot" (plan_tiny_network.md's step 4): computed here, so that a
# test and a terminal have a picture with no Internet and no file of
# somebody else's. Written as the peer wants a kept picture
# (TinyLibPeer.mli): a line "width height", the pixels, a row after the
# other, a byte each, one of the screen's 256 colours (Plan 9's table,
# TinyLibMachine's colour: the nearest, no dithering), then the text.
# No library is needed.
# usage: wiki_picture.py > tiny/tests/www/mandelbrot.wiki
import math
import sys

W, H, DEPTH = 320, 240, 120

TEXT = """The Mandelbrot set is the set of the numbers c of the plane for which
z = z*z + c, started at 0 and done again and again, never goes far:
the black part. Outside it, a colour says how soon z left. Its edge
has the same shapes at every scale. (Computed by a script of IX's
tests, not fetched: in a terminal the wire's other end has a
directory, and the Internet is the page's.)
"""


def colour(i):
    """Plan 9's rgbv, as TinyLibMachine.colour"""
    r, v = i >> 6, (i >> 4) & 3
    j = (i - v + r) & 15
    g, b = j >> 2, j & 3
    den = max(r, g, b)
    if den == 0:
        return (17 * v, 17 * v, 17 * v)
    num = 17 * (4 * den + v)
    return (r * num // den, g * num // den, b * num // den)


TABLE = [colour(i) for i in range(256)]


def nearest(rgb):
    return min(range(256), key=lambda i: sum((a - b) ** 2 for a, b in zip(TABLE[i], rgb)))


def left_after(cx, cy):
    """how many turns before z leaves, with a fraction; DEPTH if it stays"""
    x = y = 0.0
    for n in range(DEPTH):
        if x * x + y * y > 64.0:
            return n + 1 - math.log(math.log(x * x + y * y) / 2 / math.log(2)) / math.log(2)
        x, y = x * x - y * y + cx, 2 * x * y + cy
    return DEPTH


def shade(t):
    if t >= DEPTH:
        return (0, 0, 0)
    a = 0.25 * t
    return tuple(int(127.5 * (1 + math.cos(a + phase))) for phase in (3.0, 2.0, 0.8))


cache = {}
out = bytearray()
for py in range(H):
    for px in range(W):
        rgb = shade(left_after(-2.3 + 3.2 * px / W, -1.2 + 2.4 * py / H))
        key = tuple(c >> 2 for c in rgb)
        if key not in cache:
            cache[key] = nearest(rgb)
        out.append(cache[key])
sys.stdout.buffer.write(b"%d %d\n" % (W, H) + bytes(out) + TEXT.encode())
