#!/usr/bin/env python3
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# What mini-qemu's jack played in make check-audio's session
# (plan_audio.md, stage 3): its -audiodev wav's file, against what
# tests/tone writes to /dev/audio, twice, the second time at half the
# volume (tests/session-audio.cmds). The file must be: silence, the
# tone whole (each sample as Devaudio makes it a PWM word, and as
# mini-qemu's Pwm makes that word a sample), silence, the tone at 50,
# silence; 441 Hz in the left ear. Nothing more, nothing missing: a
# sample lost or played twice by the ring is a difference.
# usage: audio.py file.wav
#        audio.py file.wav --expect linux.wav
# With --expect, make check-audio-game's: the file must be silence, the
# samples of linux.wav (a game's session by -dump-audio on Linux, the
# same session having written its sound to /dev/audio here), silence.
import struct, sys

RANGE = (250000000 + 22050) // 44100
PAIRS, LOUD = 22050, 12000

def triangle(i, period):
    half = period // 2
    p = i % period
    return ((p if p < half else period - p) * 2 * LOUD) // half - LOUD

def heard(v, volume):
    # Devaudio's duty (the volume in 256ths), then Pwm's sample
    scaled = (v * (volume * 256 // 100)) >> 8
    word = ((scaled + 32768) * RANGE) >> 16
    return word * 65535 // RANGE - 32768

def tone(volume):
    return [(heard(triangle(i, 100), volume), heard(triangle(i, 50), volume)) for i in range(PAIRS)]

data = open(sys.argv[1], "rb").read()
rate, = struct.unpack_from("<I", data, 24)
flat = struct.unpack_from("<%dh" % ((len(data) - 44) // 2), data, 44)
got = list(zip(flat[0::2], flat[1::2]))
quiet = (heard(0, 100), heard(0, 100))

def fail(why):
    print("FAIL 9pi: /dev/audio: " + why); sys.exit(1)

def samples(path):
    d = open(path, "rb").read()
    f = struct.unpack_from("<%dh" % ((len(d) - 44) // 2), d, 44)
    return list(zip(f[0::2], f[1::2]))

if rate != 44099: fail("the rate is %d" % rate)
# the start: the PWM is on 2 ms before the DMA gives it its first word
# (Circle's order, and its wait), the pin still low as it was when off
at = 0
while at < len(got) and got[at] == (-32768, -32768): at += 1
if at > 441: fail("%d samples before the DMA's first" % at)
if "--expect" in sys.argv:
    want = [(heard(l, 100), heard(r, 100)) for (l, r) in samples(sys.argv[sys.argv.index("--expect") + 1])]
    while want and want[0] == quiet: want.pop(0)
    while want and want[-1] == quiet: want.pop()
    while at < len(got) and got[at] == quiet: at += 1
    if got[at:at + len(want)] != want:
        bad = next((i for i in range(len(want)) if at + i >= len(got) or got[at + i] != want[i]), 0)
        fail("the game's sound: its sample %d is %s, not %s (of %d; in the file from %d)"
             % (bad, got[at + bad] if at + bad < len(got) else "missing", want[bad], len(want), at))
    rest = [x for x in got[at + len(want):] if x != quiet]
    if rest: fail("%d samples after the game's sound are not silence" % len(rest))
    print("ok 9pi: a game's session through /dev/audio: its %d samples as on Linux, silence around, under mini-qemu" % len(want))
    sys.exit(0)
for volume in (100, 50):
    want = tone(volume)
    while at < len(got) and got[at] == quiet: at += 1
    if got[at:at + PAIRS] != want:
        bad = next((i for i in range(PAIRS) if at + i >= len(got) or got[at + i] != want[i]), 0)
        fail("the tone at %d: its sample %d is %s, not %s (%d samples in the file, the tone from %d)"
             % (volume, bad, got[at + bad] if at + bad < len(got) else "missing", want[bad], len(got), at))
    at += PAIRS
rest = [s for s in got[at:] if s != quiet]
if rest: fail("%d samples after the second tone are not silence" % len(rest))
print("ok 9pi: /dev/audio: the tone whole, twice (the second at half the volume), silence around, %.2f s played, under mini-qemu"
      % (len(got) / rate))
