#!/usr/bin/env python3
# Claude Code
#
# Copyright (C) 2026 Yoann Padioleau
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public License
# (LGPL) as published by the Free Software Foundation; either version
# 2 of the License, or (at your option) any later version.
#
# The wall time of one command typed at rc's prompt, N times (default
# 10), each time printed: mini-9pi's console speed, the drawn console
# included (docs/notes_performance.md, case 1).
#
#   N=3 timecmd.py "ls -l /bin" -- EMULATOR ARGS...
#
# The boot's time first, then one line per run. It waits for rc's
# prompt ("% ") after each; at most 600 s. With mini-qemu -prof F
# among the arguments, F is the profile of the whole run.

import fcntl, os, subprocess, sys, time

i = sys.argv.index("--")
line, cmd = " ".join(sys.argv[1:i]).encode(), sys.argv[i + 1:]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
fcntl.fcntl(p.stdout, fcntl.F_SETFL, fcntl.fcntl(p.stdout, fcntl.F_GETFL) | os.O_NONBLOCK)
out = b""

def until_prompt(timeout):
    global out
    end, start = time.time() + timeout, len(out)
    while time.time() < end:
        d = p.stdout.read()
        if d: out += d
        if len(out) > start and out.endswith(b"% "): return True
        time.sleep(0.02)
    return False

t0 = time.time(); until_prompt(600); print("boot %.1f" % (time.time() - t0), flush=True)
for _ in range(int(os.environ.get("N", "10"))):
    t0 = time.time(); p.stdin.write(line + b"\r"); p.stdin.flush()
    until_prompt(600); print("%.1f" % (time.time() - t0), flush=True)
p.terminate(); p.wait()  # SIGTERM: mini-qemu -prof writes its profile
