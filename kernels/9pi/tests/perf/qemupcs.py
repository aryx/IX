#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# A guest profile under QEMU itself, as mini-qemu's -prof gives one
# under mini-qemu: each core's PC and mode read 50 times a second by
# QEMU's monitor (QMP's human-monitor-command "info registers -a"),
# until QEMU exits. The kernel is not changed, and QEMU runs at its
# speed between two reads. Written to OUT as pcprof.py reads it, one
# core's ("pc count" lines, hexadecimal), with the modes' shares as
# comments first ("# usr32 33%": user programs; svc32: the kernel). QEMU
# is given the socket by -qmp unix:SOCK,server=on,wait=off; this waits
# for it (plan_9pi_self_speed.md, step 0).
#
#   qemupcs.py SOCK OUT [CORE]       (CORE: 0 by default)
#   cd kernels/9pi && (tests/perf/qemupcs.py /tmp/qmp.sock /tmp/pcs.txt &) && \
#     make self-quick QEMU="qemu-system-arm -qmp unix:/tmp/qmp.sock,server=on,wait=off"
#   tests/perf/pcprof.py /tmp/pcs.txt ../../_make/9pi/pi2-ocaml-ix/kernel.elf

import collections, json, os, re, socket, sys, time

sock_path, out = sys.argv[1], sys.argv[2]
core = int(sys.argv[3]) if len(sys.argv) > 3 else 0
while not os.path.exists(sock_path):
    time.sleep(0.2)
time.sleep(0.5)
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
f = s.makefile("rw")
f.readline()                                    # QMP's greeting

def cmd(c, args=None):
    m = {"execute": c}
    if args: m["arguments"] = args
    f.write(json.dumps(m) + "\n"); f.flush()
    while True:
        l = f.readline()
        if not l: raise EOFError
        r = json.loads(l)
        if "return" in r or "error" in r: return r

cmd("qmp_capabilities")
pcs = collections.Counter(); modes = collections.Counter(); n = 0
try:
    while True:
        text = cmd("human-monitor-command", {"command-line": "info registers -a"}).get("return", "")
        cpu = pc = None
        for line in text.splitlines():
            m = re.match(r"CPU#(\d+)", line)
            if m: cpu = int(m.group(1)); pc = None; continue
            m = re.search(r"R15=([0-9a-f]{8})", line)
            if m: pc = m.group(1)
            m = re.search(r"PSR=[0-9a-f]+ .* (\w+32)", line)
            if m and cpu == core and pc:
                pcs[int(pc, 16)] += 1; modes[m.group(1)] += 1
        n += 1
        time.sleep(0.02)
except (EOFError, OSError, ValueError):
    pass                                        # QEMU is gone
total = max(1, sum(modes.values()))
with open(out, "w") as o:
    o.write(f"# {n} samples of core {core}\n")
    for mode, k in modes.most_common():
        o.write(f"# {mode} {100 * k // total}%\n")
    for pc, k in pcs.most_common():
        o.write(f"{pc:x} {k}\n")
