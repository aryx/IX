#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# The clips Unit_avi and mini-play's frames read, which make test does not
# remake: by ffmpeg, a second of its test pattern, with a tone in the AVI; by
# dune's Make_fli, the one format ffmpeg does not write.
cd "$(dirname "$0")"
ffmpeg -y -v error -f lavfi -i testsrc=size=64x48:rate=10 -f lavfi -i sine=frequency=440:sample_rate=8000 \
  -t 1 -c:v mjpeg -q:v 5 -huffman 0 -c:a pcm_s16le -ac 1 -f avi testsrc_mjpeg.avi
ffmpeg -y -v error -f lavfi -i testsrc=size=32x24:rate=10 -t 0.8 -pix_fmt yuv420p testsrc.y4m
ffmpeg -y -v error -f lavfi -i testsrc=size=32x24:rate=10 -t 0.8 testsrc.gif
../../../../_build/default/lib_graphics/videos/tests/Make_fli.exe square.flc
