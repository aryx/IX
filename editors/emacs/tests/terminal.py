#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-emacs-tty in a terminal that is this script (a pty): it asks the
# terminal's size (Tty_unix.run_sized), is answered 30 rows of 100
# columns, and must draw its status line on row 29, 100 columns wide;
# keys typed, the file saved, C-x C-c: the file is changed and the
# program ends, the terminal given back. What keys.sh does not run:
# the host. (The cells' places are not checked: no terminal emulator
# here; a person looks at a real one.)
# usage: editors/emacs/tests/terminal.py [mini-emacs-tty]
import os, pty, select, sys, tempfile, time

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..')
prog = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, '_build/default/editors/emacs/tty/Main.exe')
d = tempfile.mkdtemp()
f = os.path.join(d, 'f.txt')
open(f, 'w').write('one\ntwo\n')

pid, fd = pty.fork()
if pid == 0:
    os.chdir(d)
    os.execv(prog, [prog, 'f.txt'])

def read(wait):
    out = b''
    end = time.time() + wait
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: out += os.read(fd, 65536)
            except OSError: break
    return out

failures = 0
def check(what, ok):
    global failures
    print(('ok ' if ok else 'FAIL ') + what)
    if not ok: failures += 1

out = read(0.3)
check('the size is asked', b'\x1b[999;999H\x1b[6n' in out)
os.write(fd, b'\x1b[30;100R')
out = read(0.5)
status = b'-----  f.txt  (Fundamental)  L1 C0 ' + b'-' * 65
check('the status line on row 29, 100 columns', b'\x1b[29;1H' in out and status in out)
# C-n, M-f as Escape then f, text, C-x C-s
os.write(fd, b'\x0e\x1bf=2\x18\x13')
out = read(0.5)
check('saved', open(f).read() == 'one\ntwo=2\n' and b'Wrote f.txt' in out)
os.write(fd, b'\x18\x03')
out = read(0.5)
_, st = os.waitpid(pid, os.WNOHANG)
check('ended by C-x C-c, the first screen back', st == 0 and b'\x1b[?1049l' in out)
sys.exit(1 if failures else 0)
