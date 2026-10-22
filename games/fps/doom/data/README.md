# mini-doom's WAD

`freedoom.wad` is made from [Freedoom](https://freedoom.github.io/)'s
source, its git repository (`github.com/freedoom/freedoom`, here its
commit `d14dbbee`, "levels: fix DM24 and DM25 vanilla issues"), by
`tools/Mkwad.ml`:

    dune build ./games/fps/doom/tools/Mkwad.exe
    ./_build/default/games/fps/doom/tools/Mkwad.exe FREEDOOM-DIR games/fps/doom/data/freedoom.wad E1M1

It holds what a walk through the levels named needs, in Doom's own
format (an IWAD): Freedoom's first level of Phase 1 (E1M1, its nodes as
Freedoom's builder made them), the 121 textures its sides name (with
the switches' other face and the animations' other frames) and their
170 patches, its 49 flats, the 315 pictures of the sprites of its
things, the palette and COLORMAP (computed as Freedoom's
`lumps/colormap/colormap` does). 2 MB; Freedoom's `freedoom1.wad` is
28 MB, and has the sounds, the music, the menus, the status bar, the
other levels.

Freedoom is under the BSD license that `COPYING.freedoom` says, whose
notice goes with it in any binary form: this file is that notice.

Any other WAD of Doom's format works the same (`mini-doom
wad=doom1.wad`: id's shareware one, 9front's has it in
`sys/games/lib/doom`); none of id's is in ix.
