#!/bin/bash
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-play's window: a session a line of film.expected: its name, its last
# frame, its script, its clip, the frame's SHA-256. And what only a run can
# tell: that the sound's clock runs the picture, that a sound is still a
# sound, that a broken film is said so. RECORD=1 writes the sums again.
# usage: apps/music/tests/film.sh [dir]
#   dir: where the program is (default: dune's, _build/default/apps)
cd "$(dirname "$0")/../../.."
D=${1:-_build/default/apps}/music/play
F=$D/Play.exe; [ -x $F ] || F=$D/mini-play
F=$(realpath $F)
C=lib_graphics/videos/tests/clips
E=apps/music/tests/film.expected
T=$(mktemp -d); trap 'rm -rf $T' EXIT
r=0
run() { # frames script file out [more flags]
  local n=$1 s=$2 file=$3 out=$4; shift 4
  HOME=$T timeout 30 $F -dump-frame $n $out "$@" ${s:+-script "$s"} $file > $T/said 2>&1
}
[ -n "${RECORD:-}" ] && : > $T/new
while IFS='|' read -r name frames script clip sum; do
  [ -z "$name" ] && continue
  # (JPEG's and MPEG-1's inverse DCT is floats, and OCaml's arm64 fuses a*b+c
  # where mini-ml does not: a colour off by one here and there, 681 pixels of
  # a million in the AVI's frame. Recorded by dune's alone; on ix's build the
  # checks below read them)
  [ -n "${1:-}" ] && case $name in avi-*|m1v-*|mpg-*|changes|blocks-*|residual) continue;; esac
  run "$frames" "$script" $C/$clip $T/f.ppm
  got=$(sha256sum < $T/f.ppm | cut -d' ' -f1)
  if [ -n "${RECORD:-}" ]; then echo "$name|$frames|$script|$clip|$got" >> $T/new
  elif [ "$got" = "$sum" ]; then echo "ok $name"
  else echo "FAIL $name: another frame than the recorded one"; r=1; fi
done < $E
[ -n "${RECORD:-}" ] && cp $T/new $E
check() { if [ "$2" = "$3" ]; then echo "ok $1"; else echo "FAIL $1: [$2], not [$3]"; r=1; fi; }
differ() { if cmp -s $2 $3; then echo "FAIL $1: the same frame"; r=1; else echo "ok $1"; fi; }
alike() { if cmp -s $2 $3; then echo "ok $1"; else echo "FAIL $1: another frame"; r=1; fi; }

run 10 '' $C/testsrc.y4m $T/a.ppm; run 40 '' $C/testsrc.y4m $T/b.ppm
differ "a film goes on: the frame at 2/3 of a second is not the first's" $T/a.ppm $T/b.ppm
run 40 'space:2' $C/testsrc.y4m $T/p.ppm; run 4 'space:2' $C/testsrc.y4m $T/q.ppm
alike "paused from frame 2: the same picture 36 frames later" $T/p.ppm $T/q.ppm
run 45 'space:2,space:6' $C/testsrc.y4m $T/c.ppm; run 41 '' $C/testsrc.y4m $T/d.ppm
alike "paused for 4 frames, it goes on from where it was" $T/c.ppm $T/d.ppm

# the analyzer's keys: each another picture of the same frame, and back
run 40 '' $C/ball_and_square.m1v $T/n.ppm
run 40 'type(a):5' $C/ball_and_square.m1v $T/k.ppm
differ "a: the blocks over the picture" $T/n.ppm $T/k.ppm
run 40 'type(r):5' $C/ball_and_square.m1v $T/k2.ppm
differ "r: what was sent, not what is shown" $T/n.ppm $T/k2.ppm
run 40 'type(d):5' $C/ball_and_square.m1v $T/k3.ppm
differ "d: what changed, the rest dimmed" $T/n.ppm $T/k3.ppm
run 40 'type(a):5,type(a):9,type(r):13,type(r):17,type(d):21,type(d):25' $C/ball_and_square.m1v $T/k4.ppm
alike "each key again: the plain picture" $T/n.ppm $T/k4.ppm
# seeking: a film of 2 s, so 5 s on is its end
run 20 'right:8' $C/ball_and_square.m1v $T/j.ppm
differ "the right arrow goes on" $T/n.ppm $T/j.ppm
run 39 'right:8,left:12' $C/ball_and_square.m1v $T/j3.ppm
differ "and the left arrow comes back: not the end" $T/j.ppm $T/j3.ppm

run 2 '' $C/ball_and_square.m1v $T/e.ppm; run 40 '' $C/ball_and_square.m1v $T/f.ppm
differ "MPEG-1: a P or a B frame on is not the first" $T/e.ppm $T/f.ppm
run 40 '' $C/ball_and_square.mpg $T/g.ppm -dump-audio $T/g.wav
[ -s $T/g.wav ] && echo "ok an .mpg's MP2 is played" || { echo "FAIL an .mpg's MP2 is not played"; r=1; }
run 40 "" $C/ball_and_square.mpg $T/h.ppm
alike "an .mpg, 2/3 of a second in: the sound's clock and the timer's show one frame" $T/g.ppm $T/h.ppm

# the sound's clock: dumping the sound is what pulls it here
run 30 '' $C/testsrc_mjpeg.avi $T/s.ppm -dump-audio $T/s.wav
[ -s $T/s.wav ] && echo "ok an AVI's sound is played" || { echo "FAIL an AVI's sound is not played"; r=1; }
run 30 '' $C/testsrc_mjpeg.avi $T/t.ppm
alike "half a second in, the sound's clock and the timer's show one frame" $T/s.ppm $T/t.ppm

check "a sound is still a sound: its samples on standard output" \
  "$(HOME=$T timeout 30 $F -c -s 1 lib_audio/tests/data/bell.mp2 | wc -c)" 176400
head -c 200 $C/testsrc_mjpeg.avi > $T/broken.avi
HOME=$T timeout 30 $F -dump-frame 2 $T/x.ppm $T/broken.avi > $T/said 2>&1
[ $? != 0 ] && echo "ok a broken film: a failure, no window" || { echo "FAIL a broken film ran"; r=1; }
exit $r
