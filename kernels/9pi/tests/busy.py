#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A user at mini-rio for some minutes, played by a script
# (docs/notes/notes_debugging_techniques.md, section 19): mini-9pi booted
# under an emulator with a USB keyboard and mouse and the card, rio
# typed, three windows swept with the right button's "New", a program
# typed in each (stats, breakout, cameltry), then for SECONDS a place
# picked at random in one of them, a left click, a space and the arrows.
# A screen is written at the start, every five rounds and at the end
# (DIR/start.ppm, t5.ppm..., end.ppm), the console's bytes to
# DIR/console.txt. Nothing is compared: the screens are to be looked at
# (a window that stopped moving), the console searched (Thread,
# exception, raised at, panic, fault). live.py and graphics.py wait for
# one program or for a still screen; this one wants several programs
# that never stand still.
#
#   busy.py DIR SECONDS -- EMULATOR ARGS...
#
# The four cores at once: QEMU's raspi2b and a kernel built SMP=1
# (make check-cores says how), the three loaders for the other cores
# on the command line as kernel.mk's BOOT.

import os, subprocess, sys, tempfile, time, random
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../lib_machine"))
from session import Qmp
d, secs = sys.argv[1], float(sys.argv[2]); cmd = sys.argv[sys.argv.index("--") + 1:]
os.makedirs(d, exist_ok=True)
sock = os.path.join(tempfile.mkdtemp(), "qmp.sock")
serial = open(os.path.join(d, "console.txt"), "wb")
p = subprocess.Popen(cmd + ["-qmp", "unix:%s,server,nowait" % sock], stdin=subprocess.PIPE, stdout=serial, stderr=subprocess.DEVNULL)
try:
    for _ in range(100):
        if os.path.exists(sock): break
        time.sleep(0.1)
    m = Qmp(sock)
    pos = [0, 0]
    def ev(e): m.cmd({"execute": "input-send-event", "arguments": {"events": e}})
    def to(x, y):
        dx, dy = x - pos[0], y - pos[1]
        while dx or dy:
            sx = max(-40, min(40, dx)); sy = max(-40, min(40, dy))
            ev([{"type": "rel", "data": {"axis": "x", "value": sx}}, {"type": "rel", "data": {"axis": "y", "value": sy}}])
            dx -= sx; dy -= sy; time.sleep(0.05)
        pos[0], pos[1] = x, y
    def btn(down, b="right"): ev([{"type": "btn", "data": {"down": down, "button": b}}]); time.sleep(1.0)
    def typ(s):
        for ch in s + "\n": m.key(ch, 0.3)
    def dump(n): m.cmd({"execute": "screendump", "arguments": {"filename": os.path.abspath(os.path.join(d, n + ".ppm"))}})
    t0 = time.time()
    while time.time() - t0 < 300 and b"% " not in open(os.path.join(d, "console.txt"), "rb").read(): time.sleep(1)
    time.sleep(2); to(-2000, -2000); pos[0] = pos[1] = 0
    typ("rio"); time.sleep(6)
    for (x0, y0, x1, y1, line) in [(20, 20, 500, 380, "stats"), (520, 20, 1000, 380, "breakout"), (20, 400, 500, 750, "cameltry")]:
        to(x0, y0); btn(True); btn(False); btn(True); to(x1, y1); btn(False); time.sleep(2)
        typ(line); time.sleep(5)
    dump("start")
    random.seed(1); t0 = time.time(); k = 0
    while time.time() - t0 < secs:
        x, y = random.choice([(260, 200), (760, 200), (260, 575), (760, 575)])
        to(x + random.randint(-150, 150), y + random.randint(-120, 120))
        btn(True, "left"); btn(False, "left")
        m.key(" ", 0.3)
        for q in ["left", "right", "right", "left"]:
            m.cmd({"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": q}], "hold-time": 300}}); time.sleep(0.4)
        k += 1
        if k % 5 == 0: dump("t%d" % k)
    dump("end")
    m.close()
finally:
    p.kill(); p.wait()
