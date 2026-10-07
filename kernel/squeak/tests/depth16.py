#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A picture of the Display made comparable with a board's of 16 bits
# (mini-mk check, DEPTH=16): each colour of mini-smalltalk -ppm's cut to
# the 5, 6 and 5 high bits such a board shows. At another depth, nothing.
#   tests/depth16.py picture.ppm depth      (the file is written again)
import sys
if sys.argv[2] == "16":
    d = open(sys.argv[1], "rb").read()
    h = d.split(b"\n", 3)
    px = bytes(b & (0xfc if k % 3 == 1 else 0xf8) for k, b in enumerate(h[3]))
    open(sys.argv[1], "wb").write(b"\n".join(h[:3]) + b"\n" + px)
