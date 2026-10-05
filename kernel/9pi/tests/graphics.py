#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
#
# mini-9pi's graphics against the C 9pi's (plan_9pi.md, stage D): a
# kernel booted with QEMU's USB keyboard and mouse, then
# raspberry/tests/9pi_graphics.py's steps -- lines typed at the console,
# the mouse moved, rio started from it, its menu (button 3 on "New"), a
# window swept out, a command typed in it -- each followed by a still
# screen (screendumps every few seconds until three alike), written to
# DIR as boot.ppm, step1.ppm... The console's bytes to DIR/console.txt.
# With --expect, a file of the screens' MD5s (md5sum's lines: tests/rio-c.md5),
# a screen is also taken as soon as it is the expected one, twice a second
# apart: no waiting for three alike (40 seconds a screen under mini-qemu,
# eleven screens). A screen that never is the expected one is still the
# first one still, as without it: the caller compares.
#
# With --steps, other steps than rio's: a file with a Python list of
# them (("type", line), ("key", "up"), ("move", dx, dy), ("buttons", [("down", "right"),
# ("move", dx, dy), ("up", "right")])): plan_rio.md's checks.
#
#   graphics.py [--step SECONDS] [--steps FILE] [--expect MD5S] DIR -- EMULATOR ARGS...

import ast, hashlib, os, shutil, subprocess, sys, tempfile, time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../lib"))
from session import Qmp  # noqa: E402

STEPS = [("type", "ls /"), ("type", "echo hi"), ("move", 200, 100), ("move", -50, 120),
         ("type", "rio"), ("move", -50, -140), ("buttons", [("down", "right")]), ("buttons", [("up", "right")]),
         ("buttons", [("down", "right"), ("move", 300, 200), ("up", "right")]),
         ("type", "echo hello from rio")]

def main():
    global STEPS
    args = sys.argv[1:]
    step = 4.0
    expect = {}
    if args[0] == "--step":
        step = float(args[1]); args = args[2:]
    if args[0] == "--steps":
        STEPS = ast.literal_eval(open(args[1]).read()); args = args[2:]
    if args[0] == "--expect":
        expect = {l.split()[1]: l.split()[0] for l in open(args[1])}
        args = args[2:]
    d, cmd = args[0], args[2:]
    os.makedirs(d, exist_ok=True)
    sock = os.path.join(tempfile.mkdtemp(), "qmp.sock")
    serial = open(os.path.join(d, "console.txt"), "wb")
    p = subprocess.Popen(cmd + ["-qmp", "unix:%s,server,nowait" % sock], stdin=subprocess.PIPE, stdout=serial,
                         stderr=subprocess.DEVNULL)
    try:
        for _ in range(100):
            if os.path.exists(sock): break
            time.sleep(0.1)
        m = Qmp(sock)
        def still(name):
            # old: a dump every step seconds, until three alike:
            #   time.sleep(step); ...; same = same + 1 if h == last else 0; if same >= 3: ...
            # now a dump every second: done when it is the expected one twice,
            # or when it has not changed for three steps (the same rule)
            last, since, hits, k, t0 = None, 0.0, 0, 0, time.time()
            f = os.path.join(d, name + ".ppm")
            want = expect.get(name + ".ppm")
            tick = 1.0 if want else step
            while time.time() - t0 < 900:
                time.sleep(tick)
                t = os.path.join(d, "tmp%d.ppm" % k); k += 1
                m.cmd({"execute": "screendump", "arguments": {"filename": os.path.abspath(t)}})
                if not os.path.exists(t): continue      # no screen yet (the framebuffer not asked for)
                h = hashlib.md5(open(t, "rb").read()).hexdigest()
                now = time.time()
                if h != last: last, since = h, now
                hits = hits + 1 if h == want else 0
                if hits >= 2 or now - since >= 3 * step - 0.5:
                    shutil.move(t, f)
                    break
            for x in os.listdir(d):
                if x.startswith("tmp"): os.remove(os.path.join(d, x))
        def mouse(events):
            m.cmd({"execute": "input-send-event", "arguments": {"events": events}})
        def move(dx, dy):
            mouse([{"type": "rel", "data": {"axis": "x", "value": dx}}, {"type": "rel", "data": {"axis": "y", "value": dy}}])
        still("boot")
        for i, s in enumerate(STEPS):
            if s[0] == "type":
                for ch in s[1] + "\n": m.key(ch)
            elif s[0] == "key":         # a key by QEMU's name for it: "up", "down"
                m.cmd({"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": s[1]}]}}); time.sleep(0.5)
            elif s[0] == "move":
                move(s[1], s[2])
            else:
                for e in s[1]:
                    if e[0] == "move": move(e[1], e[2])
                    else: mouse([{"type": "btn", "data": {"down": e[0] == "down", "button": e[1]}}])
                    time.sleep(2)
            still("step%d" % (i + 1))
        m.close()
    finally:
        p.kill(); p.wait()

main()
