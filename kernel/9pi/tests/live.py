#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A program that never stands still (a game: docs/plans/plan_playground.md,
# stage 2), looked at while it runs: mini-9pi booted under an emulator
# with a USB keyboard, a line typed at its prompt, then for each KEY a
# wait of SECONDS, the screen written (DIR/live1.ppm...), and the key
# pressed. graphics.py's sessions want a still screen after each step;
# this one wants none, and compares nothing: its screens are to be read
# (a game's frames a second are written on them).
#
#   live.py DIR SECONDS LINE KEYS -- EMULATOR ARGS...
#   KEYS: QEMU's names, with commas: left,up,spc,down; keys held together
#   with a dash: ctrl-q; a key held some milliseconds: right:3000 (the
#   screen is written in the middle of them too, DIR/held1.ppm...)

import hashlib, os, subprocess, sys, tempfile, time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../lib_machine"))
from session import Qmp  # noqa: E402

def main():
    d, seconds, line, keys = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4].split(",")
    cmd = sys.argv[sys.argv.index("--") + 1:]
    os.makedirs(d, exist_ok=True)
    sock = os.path.join(tempfile.mkdtemp(), "qmp.sock")
    serial = open(os.path.join(d, "console.txt"), "wb")
    p = subprocess.Popen(cmd + ["-qmp", "unix:%s,server,nowait" % sock], stdin=subprocess.PIPE, stdout=serial, stderr=subprocess.DEVNULL)
    try:
        for _ in range(100):
            if os.path.exists(sock): break
            time.sleep(0.1)
        m = Qmp(sock)
        def dump(name):
            f = os.path.abspath(os.path.join(d, name + ".ppm"))
            m.cmd({"execute": "screendump", "arguments": {"filename": f}})
            return hashlib.md5(open(f, "rb").read()).hexdigest() if os.path.exists(f) else None
        # the boot: its prompt is on the serial line too
        t0 = time.time()
        while time.time() - t0 < 600 and b"% " not in open(os.path.join(d, "console.txt"), "rb").read(): time.sleep(1)
        time.sleep(2)
        for ch in line + "\n": m.key(ch, 0.3)
        for i, k in enumerate(keys):
            time.sleep(seconds)
            dump("live%d" % (i + 1))
            # (a key and a time, right:2000: held that many milliseconds, the screen written while it is)
            k, _, hold = k.partition(":")
            m.cmd({"execute": "send-key", "arguments": dict({"keys": [{"type": "qcode", "data": q} for q in k.split("-")]},
                                                             **({"hold-time": int(hold)} if hold else {}))})
            if hold:
                time.sleep(int(hold) / 2000); dump("held%d" % (i + 1)); time.sleep(int(hold) / 2000)
        time.sleep(seconds)
        dump("live%d" % (len(keys) + 1))
        m.close()
    finally:
        p.kill(); p.wait()

main()
