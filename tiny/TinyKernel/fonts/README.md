# tiny-kernel's fonts

The fonts t-IX draws its text with, on tiny-machine (tiny-kernel's
`font.tm`, made by the Makefile) and on the host (tiny-office,
tiny-emacs, tiny-www... in an SDL window: `../../sdl/`, its
`TinyFont.ml`). `TinyKernelGraphics.ml` makes a mask of each face, and
a character is a draw through it.

| file | what |
|---|---|
| `plan9.font` | the font used: Plan 9's default font, mini-9pi's console's (`Mkfont.ml -plan9`) |
| `lucm.latin1.9` | Plan 9's default font, its subfont (a copy) |
| `grey.font` | Ubuntu Mono, grey edges (`Mkfont.ml -grey`) |
| `tiny.font` | the same letters, a pixel set or not, made by `Mkfont.ml` |
| `terminus.font` | the one before it: Terminus Font, made by `mkfont.sh` |
| `UbuntuMono-Regular.ttf`, `UbuntuMono-Bold.ttf` | Ubuntu Mono (copies) |
| `UFL.txt` | Ubuntu Mono's licence |
| `Uni2-Terminus16.psf.gz` | Terminus Font, regular, 8 by 16 (a copy) |
| `Uni2-TerminusBold16.psf.gz` | bold, 8 by 16 (a copy) |
| `Uni2-Terminus32x16.psf.gz` | regular, 16 by 32 (a copy) |
| `Uni2-TerminusBold32x16.psf.gz` | bold, 16 by 32 (a copy) |
| `OFL.txt` | Terminus Font's copyright and licence |
| `Mkfont.ml` | makes a font from a TrueType regular and bold |
| `mkfont.sh` | makes `terminus.font` from the four `.psf.gz` |
| `preview.py` | a sheet of fonts as t-IX would draw them, to choose one by looking (Pillow; not the build's) |

Another font is chosen when the image is made, or when a program on
the host starts; tiny-kernel reads none from a file:

    make FONT=fonts/grey.font                        # tiny-kernel's image
    TINY_FONT=tiny/TinyKernel/fonts/grey.font tiny-office   # the host's

(`tiny.font`, `terminus.font` and `font1.bin`, below, the same way.)

## The format

Four faces of 128 characters each (ASCII's codes; a byte beyond 127 is
drawn as a `?`), one after the other, 20,480 bytes:

    offset   face                  a character
    0        regular, 8 by 16      16 rows of a byte
    2048     bold, 8 by 16         16 rows of a byte
    4096     large, 16 by 32       32 rows of two bytes
    12288    large bold, 16 by 32  32 rows of two bytes

A row's left pixel is the low bit of its first byte, as in `font1.bin`
(below), so that `font1.bin` is a font of the same format with its
first face alone. Italic is no face of its own: the kernel slants the
upright face, its top rows 3 pixels right (6 when large).

`grey.font` has the same faces with two bits a pixel, its level: 0 none,
3 the ink, 1 and 2 a third and two thirds of it (the letters' edges); a
row's left pixel the two low bits of its first byte. Each face is twice
as large, 40,960 bytes in all, which is how the kernel knows it:

    offset   face                  a character
    0        regular, 8 by 16      16 rows of two bytes
    4096     bold, 8 by 16         16 rows of two bytes
    8192     large, 16 by 32       32 rows of four bytes
    24576    large bold, 16 by 32  32 rows of four bytes

The kernel mixes a level with the colour under it by a table made for
each ink (TinyKernelGraphics' `mix`, draw.tm's `mix_table`): a pixel
is a colour of Plan 9's table, so a mix is the nearest of its 256.

## plan9.font: Plan 9's default font

The font of mini-9pi's console, and of Plan 9's when no other is
chosen (libdraw's `defont.c`, `lucm/latin1.9`): Bigelow & Holmes'
Lucida, drawn by hand for the screen, 9 by 15, strokes of two pixels.
At 1024 by 768 it looked best of all (the author, after comparing it
with mini-9pi's console: "let's make the plan9 font the default one
for now"). `Mkfont.ml -plan9` makes it in `tiny.font`'s format, 1 bit
a pixel: each character's rows with its baseline on row 12
(tiny.font's), its 15 rows in 16; its ink moved left into 8 columns
when past them (`@` and `_` are 9 wide and lose a column; `m` and `w`
are tight). Its bold (smeared) and large (doubled) are made as the
kernel makes `font1.bin`'s, but by Mkfont: made by the kernel when
first asked for, in the middle of the recorded office session, they
took the time of a click, which was missed.

    ../../../_build/default/tiny/TinyKernel/fonts/Mkfont.exe -plan9 \
      lucm.latin1.9 plan9.font

## grey.font and tiny.font: Ubuntu Mono

The author's Emacs font. A narrow monospaced font: at 16 pixels its
characters are 8 wide, the cell. `Mkfont.ml` draws each of its first
128 characters with ix's own TrueType reader and filler
(lib_graphics's `Truetype`, `Outline`, `Fill.scan`), regular and bold,
at 8 by 16 and 16 by 32, a pixel set where 0.6 of it is covered. ix
runs no hinting (the font's programs that move a letter onto the
pixels); instead, as FreeType's autohinter: the baseline, the x's
height and the H's made whole rows, the round letters' overshoot past
them flattened onto them, a shift of the face and of each
character across (and down for what is no letter) by eighths of a
pixel to put stems on whole pixels, and a bar split on two rows kept
on one. `Mkfont.ml`'s header says how; `Mkfont.exe -coverage c
file.ttf` shows a character as it is made.

`grey.font` then has, besides `tiny.font`'s pixels, those it leaves out
grey by how much of them is covered (a third or two thirds, rounded,
the part raised to 0.6 first: darker edges, the strokes less thin at
1024 by 768): the same letters, the grey around them where the outline
passes.

    dune build ./tiny/TinyKernel/fonts/Mkfont.exe
    cd tiny/TinyKernel/fonts
    ../../../_build/default/tiny/TinyKernel/fonts/Mkfont.exe \
      UbuntuMono-Regular.ttf UbuntuMono-Bold.ttf tiny.font
    ../../../_build/default/tiny/TinyKernel/fonts/Mkfont.exe -grey \
      UbuntuMono-Regular.ttf UbuntuMono-Bold.ttf grey.font

The two are kept in the repository, so a build needs neither the
`.ttf` files nor `Mkfont`.

What 8 by 16 does to it: the wide capitals of the bold (M, N, W) are
tight; the m's middle stem is short by design.

## terminus.font: Terminus Font

A bitmap font, drawn by hand for each size, regular and bold.
`mkfont.sh` takes each face's first 128 characters out of its
`.psf.gz` (after the header: 4 bytes in PSF 1, the 8 by 16 files; 32
in PSF 2, the 16 by 32 ones; in these files a character's place is its
ASCII code) and reverses each byte's bits (PSF puts the left pixel in
the high bit). `./mkfont.sh`, then `git diff terminus.font`: nothing
when unchanged. It was tiny.font from 95995739 until Ubuntu Mono
took its place, the same day (2026-10-28).

## Where the fonts come from

**Plan 9's default font**: `lucm.latin1.9` is `defontdata`'s 5,958
bytes, of principia-softwarica's `lib_graphics/libdraw/defont.c` (the
same as Plan 9's 4th edition's), as ix already had them in
`kernels/9pi/lib_graphics/Memdata.ml`, the bytes checked equal on
2026-10-28. SHA-256:

    lucm.latin1.9
        5f522259d5e17cd61120a49ffc8c780c3f14cb998106c8b6990b4feb8376d0c8

Plan 9's own notice for its Lucida fonts (`/lib/font/bit/lucm/NOTICE`)
says "These fonts are Copyright © 1985 Bigelow & Holmes Inc."; they
came with Plan 9 and its default font is in its `libdraw`, which the
Plan 9 Foundation released under the MIT licence in 2021
(principia's `copyright.txt`). That the MIT licence covers the font,
B&H's, is not said in so many words: to be checked before `plan9.font`
goes beyond ix (as `Memdata.ml` already does).

**Ubuntu Mono**, version 0.80, by Dalton Maag for Canonical (2011),
the Ubuntu font family's monospaced one
(https://design.ubuntu.com/font). The two `.ttf` files and `UFL.txt`
are copied byte for byte from Google Fonts' repository
(https://github.com/google/fonts, `ufl/ubuntumono/`, as it has been
since its commit 90abd17b, 2015) on 2026-10-28. Ubuntu's own
`fonts-ubuntu` package has only the variable font, `UbuntuMono[wght].ttf`
(its `-R.ttf` and `-B.ttf` are links to it), whose bold ix's reader
cannot make. SHA-256:

    UbuntuMono-Regular.ttf
        b35dd9d2131d5d83a9b87fe9ad22c6288fa3d17688d43302c14da29812417d63
    UbuntuMono-Bold.ttf
        11f15c3a6bbd998a8695fdefb3475931c3789aa035d7546f2efe78e83b352f6b

Copyright 2011 Canonical Ltd., under the Ubuntu Font Licence 1.0, not
ix's LGPL: `UFL.txt`. `tiny.font` and `grey.font` are Modified
Versions in the licence's sense (a format changed), not Substantially
Changed (they look like the font), so they are under the same licence
and their names are "Ubuntu Mono derivative tiny" and "Ubuntu Mono
derivative tiny grey" (the licence's 2c). Ubuntu and Canonical
are trademarks of Canonical Ltd.

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
`terminus.font` is a Modified Version in the licence's sense (a part
of the font, in another format), so it is under the same licence and
does not carry the Reserved Font Name: it is called `terminus.font`,
made from Terminus Font.

**font1.bin**, the font before both (until 2026-10-28), kept in
`kernels/lib_machine/font1.bin`: the 8 by 16 font of xv6's Raspberry
Pi ports (`xv6_rpi_port`, `xv6_rpi2_port`; ~/github/xv6-multiarch's
arm-pi forks have it), which mini-9pi's and mini-xv6's consoles draw
with. 2,048 bytes, one face: the kernel then makes the others from it,
bold its strokes a pixel wider, large its pixels doubled. Simpler to
read than four faces, and kept for that:

    make FONT=../../kernels/lib_machine/font1.bin    # tiny-kernel's image
    TINY_FONT=kernels/lib_machine/font1.bin tiny-office    # the host's

The host tests of `TinyKernelGraphics`, `TinyLibGUI`, `TinyAppTetris`
and `TinyLibPlayground` draw with `font1.bin` (their recorded screens
are of it; `TinyKernelGraphics`' also with `grey.font`, on the host
and on tiny-machine); tiny-kernel's sessions (`make check`) with
`plan9.font`.
