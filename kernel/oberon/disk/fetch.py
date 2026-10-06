#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Where disk/'s files of Project Oberon come from: a disk image of the
# 2013 system (oberon-risc-emu's DiskImage/Oberon-2020-08-18.dsk), read
# as FileDir.Mod and Files.Mod lay it out. Run once; not in the build.
#
#   fetch.py image            its directory: each file's name and length
#   fetch.py image NAME...    those files written in this directory
#
# The file system: sectors of 1 KB, an address 29 times a sector's
# number; the image starts at sector 1, the directory's root. A
# directory page (mark 9B1EA38D): m entries of 40 bytes at 64 (a name
# of 32, the file's header's address, the page of the names after it),
# p0 the page of the names before the first. A file's header (mark
# 9BA71D86): its name, aleng and bleng (its end: a sector and a byte in
# it, the header's 352 bytes counted), 12 addresses of index sectors,
# 64 of the first sectors (the header's own the first).
import os, struct, sys

image = open(sys.argv[1], 'rb').read()
def sector(adr):
    assert adr % 29 == 0, adr
    o = (adr // 29 - 1) * 1024
    return image[o:o + 1024]

def directory(adr=29):
    page = sector(adr)
    mark, m, p0 = struct.unpack_from('<III', page, 0)
    assert mark == 0x9B1EA38D
    if p0: yield from directory(p0)
    for i in range(m):
        name, fadr, p = struct.unpack_from('<32sII', page, 64 + 40 * i)
        yield name.split(b'\0')[0].decode('latin1'), fadr
        if p: yield from directory(p)

def contents(fadr):
    head = sector(fadr)
    mark, name, aleng, bleng, date = struct.unpack_from('<I32sIII', head, 0)
    assert mark == 0x9BA71D86
    ext = struct.unpack_from('<12I', head, 48)
    sec = list(struct.unpack_from('<64I', head, 96))
    for e in ext:
        if e: sec += struct.unpack_from('<256I', sector(e), 0)
    data = b''.join(sector(sec[i]) for i in range(aleng + 1))
    return data[352:aleng * 1024 + bleng]

files = dict(directory())
if len(sys.argv) == 2:
    for name in sorted(files): print('%8d %s' % (len(contents(files[name])), name))
for name in sys.argv[2:]:
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)), name), 'wb').write(contents(files[name]))
