# tiny-kernel's fonts

The fonts t-IX draws its text with, on tiny-machine (tiny-kernel's
`font.tm`, made by the Makefile) and on the host (tiny-office,
tiny-emacs, tiny-www... in an SDL window: `../../sdl/`, its
`TinyFont.ml`). `TinyKernelGraphics.ml` makes a mask of each face, and
a character is a draw through it.

| file | what |
|---|---|
| `tiny.font` | the font used, 20,480 bytes, made by `mkfont.sh` |
| `Uni2-Terminus16.psf.gz` | Terminus Font, regular, 8 by 16 (a copy) |
| `Uni2-TerminusBold16.psf.gz` | bold, 8 by 16 (a copy) |
| `Uni2-Terminus32x16.psf.gz` | regular, 16 by 32 (a copy) |
| `Uni2-TerminusBold32x16.psf.gz` | bold, 16 by 32 (a copy) |
| `OFL.txt` | Terminus Font's copyright and licence |
| `mkfont.sh` | makes `tiny.font` from the four copies |

## tiny.font

Four faces of 128 characters each (ASCII's codes; a byte beyond 127 is
drawn as a `?`), one after the other:

    offset   face                  a character
    0        regular, 8 by 16      16 rows of a byte
    2048     bold, 8 by 16         16 rows of a byte
    4096     large, 16 by 32       32 rows of two bytes
    12288    large bold, 16 by 32  32 rows of two bytes

A row's left pixel is the low bit of its first byte, as in `font1.bin`
(below), so that `font1.bin` is a font of the same format with its
first face alone. Italic is no face of its own: the kernel slants the
upright face, its top rows 3 pixels right (6 when large).

`mkfont.sh` takes each face's first 128 characters out of its `.psf.gz`
(after the header: 4 bytes in PSF 1, the 8 by 16 files; 32 in PSF 2,
the 16 by 32 ones; in these files a character's place is its ASCII
code) and reverses each byte's bits (PSF puts the left pixel in the high
bit). `tiny.font` is kept in the repository, so a build needs neither
gzip nor the script; after a change, `./mkfont.sh` and `git diff
tiny.font`.

## Where the fonts come from

**Terminus Font**, by Dimitar Toshkov Zhekov, a bitmap font designed
for long work on a screen (https://terminus-font.sourceforge.net/). The
four `.psf.gz` files are Linux's console fonts built from it by Debian's
console-setup. They are copied byte for byte from
`/usr/share/consolefonts/` of Ubuntu 24.04's `console-setup-linux`,
version 1.226ubuntu1, on 2026-10-28; their SHA-256:

    Uni2-Terminus16.psf.gz
        76b38323e80e09cd44a4ca4b0eaa681101874f208b8b5ba00c8c594cfd3b91c2
    Uni2-TerminusBold16.psf.gz
        e47636ab76907452e449194dd4c3cd47f7a2c72afcdd9597d3eb8c8f95a0ebed
    Uni2-Terminus32x16.psf.gz
        223d2ef308818682a664a8f640e319c9328a16f7db647d47576f9788579a8ac3
    Uni2-TerminusBold32x16.psf.gz
        7923369ee8eac3e9d597f6e8a952ba205963a6354548e6ef2d17850b6781fdff

Copyright (c) 2010 Dimitar Toshkov Zhekov, with Reserved Font Name
"Terminus Font". It is under the SIL Open Font License 1.1, not ix's
LGPL: `OFL.txt`, the text from console-setup's `copyright.fonts`.
`tiny.font` is a Modified Version in the licence's sense (a part of
the font, in another format), so it is under the same licence and does
not carry the Reserved Font Name: it is called `tiny.font`, made from
Terminus Font.

**font1.bin**, the font before tiny.font (until 2026-10-28), kept in
`kernels/lib_machine/font1.bin`: the 8 by 16 font of xv6's Raspberry
Pi ports (`xv6_rpi_port`, `xv6_rpi2_port`; ~/github/xv6-multiarch's
arm-pi forks have it), which mini-9pi's and mini-xv6's consoles draw
with. 2,048 bytes, one face: the kernel then makes the others from it,
bold its strokes a pixel wider, large its pixels doubled. Simpler to
read than four faces drawn by hand, and kept for that:

    make FONT=../../kernels/lib_machine/font1.bin    # tiny-kernel's image
    TINY_FONT=kernels/lib_machine/font1.bin tiny-office    # the host's

The host tests of `TinyKernelGraphics`, `TinyLibGUI`, `TinyAppTetris`
and `TinyLibPlayground` draw with `font1.bin` (their recorded screens
are of it); tiny-kernel's sessions (`make check`) with `tiny.font`.
