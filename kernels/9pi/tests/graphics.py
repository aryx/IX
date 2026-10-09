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
# first one still (for a minute), and the session stops there: the
# caller compares, and sees which screen it was.
#
# With --steps, other steps than rio's: a file with a Python list of
# them (("type", line), ("key", "up"), ("move", dx, dy), ("buttons", [("down", "right"),
# ("move", dx, dy), ("up", "right")])): plan_rio.md's checks. A third
# element of a "buttons" step is its own pause, in seconds (a double
# click: two presses within half a second).
#
# --pause KEY,BUTTON: the seconds after a key and after a button's
# change or a move in a "buttons" step (0.5 and 2 by default, the C
# rio's check's; the guest must have seen one before the next comes: a
# mouse's state read late is its last one, and a click is missed).
#
#   graphics.py [--step SECONDS] [--steps FILE] [--pause KEY,BUTTON] [--expect MD5S] DIR -- EMULATOR ARGS...

import ast, hashlib, os, shutil, subprocess, sys, tempfile, time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../lib_machine"))
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
    key_pause, button_pause = 0.5, 2.0
    # (the options, in any order, before the directory)
    while args[0].startswith("--"):
        if args[0] == "--step": step = float(args[1])
        elif args[0] == "--steps": STEPS = ast.literal_eval(open(args[1]).read())
        elif args[0] == "--pause": key_pause, button_pause = [float(x) for x in args[1].split(",")]
        elif args[0] == "--expect": expect = {l.split()[1]: l.split()[0] for l in open(args[1])}
        else: sys.exit("graphics.py: " + args[0] + "?")
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
            tick = 0.4 if want else step
            while time.time() - t0 < 900:
                time.sleep(tick)
                t = os.path.join(d, "tmp%d.ppm" % k); k += 1
                m.cmd({"execute": "screendump", "arguments": {"filename": os.path.abspath(t)}})
                if not os.path.exists(t): continue      # no screen yet (the framebuffer not asked for)
                h = hashlib.md5(open(t, "rb").read()).hexdigest()
                now = time.time()
                if h != last: last, since = h, now
                hits = hits + 1 if h == want else 0
                # (a screen is expected: one that stays another is waited on
                # for a minute, not three steps: a boot under load stands
                # still for longer than that before it goes on, and the
                # steps would start before the prompt)
                if hits >= 2 or now - since >= (max(60, 3 * step) if want else 3 * step) - 0.5:
                    shutil.move(t, f)
                    # (not the screen expected: what follows would be typed
                    # at the wrong place; the session ends here, said)
                    if want and h != want: raise SystemExit("graphics.py: %s is not the screen expected: stopped" % name)
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
                for ch in s[1] + "\n": m.key(ch, key_pause)
            elif s[0] == "key":         # a key by QEMU's name for it: "up", "down"; ("key", "x", 1000): held a second
                                        # ("key", "ctrl+f9"): keys down together
                hold = {"hold-time": s[2]} if len(s) > 2 else {}
                m.cmd({"execute": "send-key", "arguments": dict({"keys": [{"type": "qcode", "data": k} for k in s[1].split("+")]}, **hold)})
                time.sleep(key_pause + (s[2] / 1000 if len(s) > 2 else 0))
            elif s[0] == "move":
                move(s[1], s[2])
            elif s[0] == "unplug":      # a device taken out, by its id (-device usb-mouse,id=...)
                m.cmd({"execute": "device_del", "arguments": {"id": s[1]}}); time.sleep(1)
            elif s[0] == "plug":        # ("plug", "usb-mouse", "its-id"): a device put in
                m.cmd({"execute": "device_add", "arguments": {"driver": s[1], "id": s[2]}}); time.sleep(1)
            else:
                for e in s[1]:
                    if e[0] == "move": move(e[1], e[2])
                    else: mouse([{"type": "btn", "data": {"down": e[0] == "down", "button": e[1]}}])
                    time.sleep(s[2] if len(s) > 2 else button_pause)
            still("step%d" % (i + 1))
        m.close()
    finally:
        p.kill(); p.wait()

main()
