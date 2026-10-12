#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# mini-play on a file of each format (data/), the samples it writes
# against play.expected: a file's name, its samples, their MD5. The
# expected ones are dune's build's, and were held against the
# playground's own decoders, each file decoded whole (README.md); the
# same bytes are asked of mini-ml's build, on arm64 and arm.
# usage: play.sh [command that runs mini-play]
#   lib_audio/tests/play.sh
#   lib_audio/tests/play.sh _mk/7/apps/music/play/mini-play
#   lib_audio/tests/play.sh "mini-5i _mk/5/apps/music/play/mini-play"   (minutes)
cd "$(dirname "$0")/../.."
run=${1:-_build/default/apps/music/play/Play.exe}
T=$(mktemp -d); trap 'rm -rf $T' EXIT
for f in lib_audio/tests/data/*; do
  $run -c $f > $T/out 2> $T/err || { echo "$(basename $f): $(cat $T/err)"; continue; }
  echo "$(basename $f) $(( $(wc -c < $T/out) / 4 )) $(md5sum < $T/out | cut -d' ' -f1)"
done > $T/got
diff lib_audio/tests/play.expected $T/got && echo "play.sh: $(wc -l < $T/got) files, the same samples"
