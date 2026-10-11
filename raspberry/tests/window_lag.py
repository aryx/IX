#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Does the board keep the host's clock while the mouse moves?
# (docs/plans/plan_mini_qemu_speed.md's numbers of 2026-10-11.) mini-qemu
# with its window (SDL's dummy driver: no screen needed) and its loop
# as mini-pi -g runs it, mini-9pi booted, rio typed on the USB
# keyboard, then the USB mouse moved HZ times a second for ten seconds
# over QMP, there and back. -status's lines are printed: the board's
# time each second of ours ("+1.0s": it keeps up; "+0.5s": the cursor
# is half a second later each second), and how idle it was. The screen
# two seconds after the last move is written (s.ppm in the directory
# said last), to compare two kernels' or two emulators'.
#
#   window_lag.py EMULATOR KERNEL CARD [HZ [ARGS...]]
#   window_lag.py _build/default/raspberry/Main.exe kernels/9pi/kernel-pi1-ixu.img kernels/9pi/build/card.img 30
#   (the emulator built by: dune build --profile release ./raspberry/Main.exe)
import os, subprocess, sys, tempfile, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../kernels/lib_machine"))
from session import Qmp
emu, kernel, card = sys.argv[1:4]; hz = int(sys.argv[4]) if len(sys.argv) > 4 else 30
extra = sys.argv[5:]
d = tempfile.mkdtemp(); sock = d + "/qmp.sock"
out = open(d + "/console.txt", "wb"); err = open(d + "/err.txt", "wb")
env = dict(os.environ, DISPLAY="x", SDL_VIDEODRIVER="dummy")
p = subprocess.Popen([emu, "-M", "raspi1ap", "-device", "loader,file=%s,addr=0x8000" % kernel, "-drive", "file=%s,if=sd,format=raw,snapshot=on" % card,
    "-serial", "mon:stdio", "-device", "usb-kbd", "-device", "usb-mouse", "-status", "1", "-qmp", "unix:%s,server,nowait" % sock] + extra,
    stdin=subprocess.PIPE, stdout=out, stderr=err, env=env)
try:
    while not os.path.exists(sock): time.sleep(0.1)
    m = Qmp(sock)
    t0 = time.time()
    while time.time() - t0 < 300 and b"% " not in open(d + "/console.txt", "rb").read(): time.sleep(0.5)
    print("prompt after %.1f s" % (time.time() - t0)); time.sleep(1)
    for ch in "rio\n": m.key(ch, 0.2)
    time.sleep(5)
    n0 = len(open(d + "/err.txt").read().splitlines())
    time.sleep(4)
    n1 = len(open(d + "/err.txt").read().splitlines())
    t = time.time(); i = 0
    while time.time() - t < 10:
        dx = 3 if (i // 60) % 2 == 0 else -3
        m.cmd({"execute": "input-send-event", "arguments": {"events": [{"type": "rel", "data": {"axis": "x", "value": dx}}, {"type": "rel", "data": {"axis": "y", "value": dx}}]}})
        i += 1
        time.sleep(max(0, t + i / hz - time.time()))
    print("%d moves sent in %.1f s" % (i, time.time() - t))
    time.sleep(2)
    m.cmd({"execute": "screendump", "arguments": {"filename": d + "/s.ppm"}})
    lines = open(d + "/err.txt").read().splitlines()
    print("-- rio waiting"); print("\n".join(l[:150] for l in lines[n0:n1]))
    print("-- the mouse moving"); print("\n".join(l[:150] for l in lines[n1:]))
    print(d)
finally:
    p.kill()
