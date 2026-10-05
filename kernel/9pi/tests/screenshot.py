#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
#
# The website's picture of mini-9pi (docs/pics/mini-9pi.png): the kernel
# booted under mini-qemu with a USB keyboard and mouse, rio started
# from the console, a window swept out over most of the screen and a
# few commands typed in it; then the screen, a PPM (pnmtopng makes the
# PNG). As tests/graphics.py, whose steps are the check's and not to be
# changed for a picture.
#
#   screenshot.py OUT.ppm -- EMULATOR ARGS...
#   (the arguments: make -n check's, of its tests/graphics.py for mini-qemu)

import hashlib, os, subprocess, sys, tempfile, time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../lib"))
from session import Qmp  # noqa: E402

LINES = ["echo hello from mini-9pi, on mini-qemu", "date", "ls /dev | sed 8q", "ps | sed 4q"]

def main():
    out, cmd = sys.argv[1], sys.argv[3:]
    d = tempfile.mkdtemp()
    sock = os.path.join(d, "qmp.sock")
    p = subprocess.Popen(cmd + ["-qmp", "unix:%s,server,nowait" % sock], stdin=subprocess.PIPE,
                         stdout=open(os.path.join(d, "console.txt"), "wb"), stderr=subprocess.DEVNULL)
    try:
        for _ in range(100):
            if os.path.exists(sock): break
            time.sleep(0.1)
        m = Qmp(sock)
        def still(step=5.0):
            """the screen when three dumps a step apart are alike"""
            last, same = None, 0
            while True:
                time.sleep(step)
                m.cmd({"execute": "screendump", "arguments": {"filename": os.path.abspath(out)}})
                if not os.path.exists(out): continue
                h = hashlib.md5(open(out, "rb").read()).hexdigest()
                same = same + 1 if h == last else 0
                last = h
                if same >= 2: return
        def mouse(events):
            m.cmd({"execute": "input-send-event", "arguments": {"events": events}})
            time.sleep(2)
        def move(dx, dy):
            mouse([{"type": "rel", "data": {"axis": "x", "value": dx}}, {"type": "rel", "data": {"axis": "y", "value": dy}}])
        def button(down):
            mouse([{"type": "btn", "data": {"down": down, "button": "right"}}])
        def type_(line):
            for ch in line + "\n": m.key(ch)
        still()
        type_("rio")
        still()
        # to the top left corner (the screen's edge stops it), then a little in
        for _ in range(4): move(-400, -400)
        move(24, 24)
        button(True); button(False)          # the menu, on "New"
        button(True); move(280, 210); move(280, 210); button(False)   # the window, swept
        still()
        for line in LINES:
            type_(line)
            still(3.0)
        m.close()
    finally:
        p.kill(); p.wait()

main()
