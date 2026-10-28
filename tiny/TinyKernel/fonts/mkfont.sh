#!/bin/sh
# Claude Code
# Copyright (C) 2026 Yoann Padioleau. LGPL 2.1: see license.txt.
#
# Makes terminus.font from the four Terminus Font files beside it
# (README.md): the first 128 characters of each face, one face after
# the other, regular 8 by 16, bold 8 by 16, large 16 by 32, large bold
# 16 by 32. Each row's bits are reversed into font1.bin's order, where
# the left pixel is the low bit of the row's first byte (a PSF font's
# is the high bit): tiny.font's format (tiny.font is now Ubuntu Mono's:
# README.md). Run by hand after a font is changed; terminus.font
# is kept in the repository, so the build needs neither gzip nor this.
#
# usage: ./mkfont.sh   (then git diff terminus.font: nothing when unchanged)
set -e
export LC_ALL=C
cd "$(dirname "$0")"

# [face file header n]: n bytes of a .psf.gz after its header (PSF 1's
# is 4 bytes, PSF 2's 32), each byte's bits reversed
face() {
  gzip -dc "$1" | tail -c +$(($2 + 1)) | head -c "$3" | od -An -v -tu1 |
  awk '{ for (i = 1; i <= NF; i++) {
           b = $i; r = 0
           for (k = 0; k < 8; k++) { r = (r * 2) + (b % 2); b = int(b / 2) }
           printf "%c", r } }'
}

{
  face Uni2-Terminus16.psf.gz 4 2048
  face Uni2-TerminusBold16.psf.gz 4 2048
  face Uni2-Terminus32x16.psf.gz 32 8192
  face Uni2-TerminusBold32x16.psf.gz 32 8192
} > terminus.font
