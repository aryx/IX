#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# lib_crypto's SHA-1 and lib_compression's zlib and CRC-32 against
# Python's hashlib and zlib, on random inputs (text-like, binary, repetitive,
# empty): the digests equal; our deflate's output inflated by Python;
# Python's, at every level, inflated by ours, with bytes after the
# stream (as in a pack) left unread; gzip's file of it (with a name in
# its header one time in two) read back.
#
# Usage: check.py [count] [seed]

import gzip, hashlib, io, os, random, subprocess, sys, zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../..")
CHECK = os.path.join(ROOT, "_build/default/lib_compression/tests/Check.exe")
count = int(sys.argv[1]) if len(sys.argv) > 1 else 200
r = random.Random(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
failures = 0

def run(mode, data):
    p = subprocess.run([CHECK, mode], input=data, capture_output=True)
    return p.stdout, p.stderr

def sample():
    kind = r.randrange(5)
    n = r.choice([0, 1, 2, 3, 10, 100, 1000, 40000, 100000])
    if kind == 0: return bytes(r.randrange(256) for _ in range(n))
    if kind == 1: return bytes(r.choice(b"ab") for _ in range(n))
    if kind == 2: return (b"let x = %d in\n" % r.randrange(100)) * (n // 10 + 1)
    if kind == 3: return b"\0" * n
    words = [b"tree", b"blob", b"commit", b"parent", b"author", b" ", b"\n"]
    return b"".join(r.choice(words) for _ in range(n // 4))

def fail(what, data):
    global failures
    failures += 1
    print("FAIL %s on %d bytes: %r" % (what, len(data), data[:40]))

for _ in range(count):
    d = sample()
    out, _ = run("crc32", d)
    if int(out) != zlib.crc32(d): fail("crc32", d)
    out, _ = run("sha1", d)
    if out.decode() != hashlib.sha1(d).hexdigest(): fail("sha1", d)
    z, _ = run("deflate", d)
    try:
        if zlib.decompress(z) != d: fail("deflate", d)
    except zlib.error as e: fail("deflate (%s)" % e, d)
    lvl = r.randrange(10)
    tail = bytes(r.randrange(256) for _ in range(r.randrange(4)))
    out, rest = run("inflate", zlib.compress(d, lvl) + tail)
    if out != d or rest.decode() != str(len(tail)): fail("inflate level %d" % lvl, d)
    g = io.BytesIO()
    with gzip.GzipFile(filename="a.txt" if r.randrange(2) else "", mode="wb", fileobj=g, compresslevel=lvl) as f: f.write(d)
    out, _ = run("gunzip", g.getvalue())
    if out != d: fail("gunzip level %d" % lvl, d)
print("lib checks: %d inputs, %d failures" % (count, failures))
sys.exit(1 if failures else 0)
