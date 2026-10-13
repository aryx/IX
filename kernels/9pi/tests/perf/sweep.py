#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A window swept under mini-rio as a person's hand would, looking for
# the band that follows the mouse late (docs/plans/bugs/ix.md: Source
# read ahead of its program). The kernel booted with a USB keyboard and
# mouse, rio typed, New chosen with the right button, then the button
# held and 60 moves sent in 2 seconds: said, how long after the last
# move the screen still changed (a dump every tenth of a second), and
# how long after the release the window was made. 7.7 s and 0.9 s
# before the fix, 1.2 s and 0.7 s after (mini-qemu, the Pi 2).
#
#   sweep.py DIR EMULATOR ARGS...       (DIR: the console's bytes, the last screen)
#   cd kernels/9pi && tests/perf/sweep.py /tmp/sweep ../../_build/default/raspberry/Main.exe \
#     -M raspi2b -device loader,file=kernel-pi2-ixu.img,addr=0x8000,cpu-num=0,force-raw=on \
#     -device loader,addr=0x8000,cpu-num=1 -device loader,addr=0x8000,cpu-num=2 -device loader,addr=0x8000,cpu-num=3 \
#     -drive file=build/card.img,if=sd,format=raw,snapshot=on -display none -serial mon:stdio -device usb-kbd -device usb-mouse
import hashlib, os, subprocess, sys, tempfile, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../lib_machine"))
from session import Qmp
d, cmd = sys.argv[1], sys.argv[2:]
os.makedirs(d, exist_ok=True)
sock = os.path.join(tempfile.mkdtemp(), "qmp.sock")
p = subprocess.Popen(cmd + ["-qmp", "unix:%s,server,nowait" % sock], stdin=subprocess.PIPE,
                     stdout=open(os.path.join(d, "console.txt"), "wb"), stderr=subprocess.DEVNULL)
try:
    for _ in range(100):
        if os.path.exists(sock): break
        time.sleep(0.1)
    m = Qmp(sock)
    k = [0]
    def dump():
        t = os.path.join(d, "tmp.ppm")
        m.cmd({"execute": "screendump", "arguments": {"filename": os.path.abspath(t)}})
        return hashlib.md5(open(t, "rb").read()).hexdigest() if os.path.exists(t) else None
    def still(quiet=3.0, tick=0.25):
        last, since, t0 = None, time.time(), time.time()
        while True:
            time.sleep(tick); h = dump(); now = time.time()
            if h != last: last, since = h, now
            if h and now - since >= quiet: return since - t0
    def mouse(ev): m.cmd({"execute": "input-send-event", "arguments": {"events": ev}})
    def move(dx, dy): mouse([{"type": "rel", "data": {"axis": "x", "value": dx}}, {"type": "rel", "data": {"axis": "y", "value": dy}}])
    def btn(down): mouse([{"type": "btn", "data": {"down": down, "button": "right"}}])
    while b'usb/kb... %' not in open(os.path.join(d,'console.txt'),'rb').read(): time.sleep(0.5)
    still(3)
    for ch in "rio\n": m.key(ch, 0.5)
    still()
    move(150, 80); time.sleep(1)
    btn(True); time.sleep(2); btn(False); still()      # the menu: New
    btn(True); time.sleep(1)
    t0 = time.time()
    for i in range(60): move(10, 8); time.sleep(0.03)
    t1 = time.time()
    lag = still(2.0, 0.1)
    print("%s: moves sent in %.1f s; the band still %.1f s after the last" % (d, t1 - t0, lag))
    btn(False); print("window made %.1f s after the release" % still(2.0, 0.1))
    os.rename(os.path.join(d, "tmp.ppm"), os.path.join(d, "end.ppm"))
finally:
    p.kill(); p.wait()
