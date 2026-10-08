#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A game's keys as a person's at an emulator's window, looking for a
# release that was lost (docs/plans/bugs/ix.md: a key that stays down,
# the maze of TinyCameltry turning by itself). A key held on the host is
# its press again and again (the host's repeat, HZ times a second),
# which QEMU's USB keyboard keeps in a queue of 16, an arrow two places
# each; who reads it too slowly loses what came when it was full. One
# key at a time is held here, a random one of three for a random time,
# for SECONDS; the game says the keys down at each message of /dev/kbd
# (its flag keys=on): a message with two keys is a release lost, and
# the last one must have none.
#   make ix-usb ix-kernel card     first
#   usage: tests/perf/held.py DIR GAME SECONDS [HZ]
#     KIMG=kernel-pi1-ixk.img in the environment: the keyboard read by
#     the kernel itself (Kusb), not by usbd
# The same game with the fix off (Usbdwc.epread's, 2026-10-08), 60
# seconds at 30: 14 messages with two keys, and two keys down at the end.
import hashlib, os, subprocess, sys, tempfile, time, random
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../lib_machine"))
from session import Qmp
d, game, secs = sys.argv[1], sys.argv[2], float(sys.argv[3])
hz = float(sys.argv[4]) if len(sys.argv) > 4 else 30
os.makedirs(d, exist_ok=True)
K = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
sock = os.path.join(tempfile.mkdtemp(), "qmp.sock")
cmd = ["qemu-system-arm","-M","raspi1ap","-device","loader,file=%s/%s,addr=0x8000,cpu-num=0,force-raw=on"%(K,os.environ.get("KIMG","kernel-pi1-ixu.img")),
 "-serial","mon:stdio","-display","none","-device","usb-kbd","-device","usb-mouse","-drive","file=%s/build/card.img,if=sd,format=raw,snapshot=on"%K,
 "-qmp","unix:%s,server,nowait"%sock]
serial = open(d+"/console.txt","wb")
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=serial, stderr=open(d+"/qemu.err","wb"))
try:
    while not os.path.exists(sock): time.sleep(0.1)
    m = Qmp(sock)
    def dump(name):
        f = os.path.abspath(os.path.join(d, name + ".ppm"))
        m.cmd({"execute": "screendump", "arguments": {"filename": f}})
        return hashlib.md5(open(f, "rb").read()).hexdigest()[:8]
    def ev(k, down): m.cmd({"execute":"input-send-event","arguments":{"events":[{"type":"key","data":{"down":down,"key":{"type":"qcode","data":k}}}]}})
    t0=time.time()
    while time.time()-t0 < 600 and b"% " not in open(d+"/console.txt","rb").read(): time.sleep(1)
    time.sleep(2)
    for ch in game+" 'keys=on'\n": m.key(ch, 0.3)
    time.sleep(6)
    m.key(" ", 0.5)
    random.seed(1)
    t0=time.time()
    while time.time()-t0 < secs:
        k = random.choice(["left","right","up"])
        hold = random.choice([0.05, 0.3, 1.0, 2.5])
        t1=time.time(); ev(k, True)
        time.sleep(min(0.25, hold))
        while time.time()-t1 < hold:
            ev(k, True); time.sleep(1/hz)
        ev(k, False)
        time.sleep(random.choice([0.0, 0.02, 0.2]))
    time.sleep(3)
    m.cmd({"execute":"send-key","arguments":{"keys":[{"type":"qcode","data":"ctrl"},{"type":"qcode","data":"q"}]}})
    time.sleep(2)
    m.cmd({"execute":"quit"})
finally:
    time.sleep(0.5); p.kill()
lines = [l.rstrip("\r") for l in open(d+"/console.txt","rb").read().decode("latin1").split("\n")]
msgs = [l[6:].split(",") if len(l) > 6 else [] for l in lines if l.startswith("keys: ")]
# (the last two are Ctrl-Q's)
msgs = [m_ for m_ in msgs if "Control" not in m_ and "q" not in m_]
two = len([m_ for m_ in msgs if len(m_) > 1])
print("%d messages, %d with two keys, the last: %s" % (len(msgs), two, msgs[-1] if msgs else None))
sys.exit(1 if two or not msgs or msgs[-1] else 0)
