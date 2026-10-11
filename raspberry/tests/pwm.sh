#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The Pi 1's jack under mini-qemu (docs/plans/plan_audio.md, stage 2):
# pwm/tone.c, a bare-metal program built by ix's tools (mini-mk O=5 in
# pwm/), plays a tenth of a second by hand then one by DMA and times
# each; mini-qemu -audiodev wav writes what its PWM played. Against
# pwm/expected: the program's two lines (100 ms each: the sound paced
# the writes), then the file's rate, its samples and their MD5 (a run
# is the same on any host). QEMU has no such device: nothing to hold
# this against but the numbers (pwm/tone.c says what they should be).
# usage: pwm.sh [mini-qemu]
cd "$(dirname "$0")/../.."
M=${1:-_build/default/raspberry/Main.exe}
(cd raspberry/tests/pwm && mini-mk O=5 > /dev/null 2>&1) || { echo "pwm.sh: mini-mk O=5 failed in raspberry/tests/pwm"; exit 1; }
T=$(mktemp -d); trap 'rm -rf $T' EXIT
timeout 3 $M -M raspi1ap -device loader,file=_mk/5/raspberry/tests/pwm/tone.img,addr=0x8000,cpu-num=0,force-raw=on -nographic -audiodev wav,path=$T/tone.wav < /dev/null > $T/got 2> /dev/null
[ -f $T/tone.wav ] || { echo "pwm.sh: no WAV written"; exit 1; }
echo "wav: $(od -An -tu4 -j24 -N4 $T/tone.wav | tr -d ' ') a second, $(( ($(wc -c < $T/tone.wav) - 44) / 4 )) samples, $(tail -c +45 $T/tone.wav | md5sum | cut -d' ' -f1)" >> $T/got
diff raspberry/tests/pwm/expected $T/got && echo "pwm.sh: ok"
