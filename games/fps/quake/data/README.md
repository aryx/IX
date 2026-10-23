# mini-quake's level

`e0m1.bsp` is [LibreQuake](https://github.com/lavenderdotpet/LibreQuake)'s
`lq1/maps/src/e0/lq_e0m1.map` ("Baseless Base Banter", the first level
of its first episode), at LibreQuake's commit `4d2da523`, compiled as a
Quake map is, by three tools:

    games/fps/quake/tools/mklevel.sh LIBREQUAKE-DIR e0/lq_e0m1 games/fps/quake/data/e0m1.bsp

1. the texture WADs the map names (its worldspawn's `"wad"` key: seven
   of them), made from LibreQuake's `texture-wads/*/` PNGs by
   `tools/Mkwad.ml` (`mini-mkwad2`): LibreQuake builds them with
   qpakman, not packaged anywhere, and three of them have no `.wad` in
   its tree;
2. `qbsp` then `vis` of [ericw-tools](https://github.com/ericwa/ericw-tools)
   0.18.1 (here nixpkgs': `QBSP=` and `VIS=` the paths to them): the
   BSP tree, the faces with their textures, the hulls; the PVS. `vis`
   runs on several threads, and two runs may differ in a few bytes of
   the PVS (13,036 and 13,043 bytes here), not in what it says;
3. `light`: ours, `tools/Light.ml` (`mini-light`), id's algorithm
   (plan_quake.md, decision 2), with the bounce the map asks
   (`_bounce 3`) and LibreQuake's palette for the textures' colours:
   13 s. ericw-tools' `light` was not used: nixpkgs' is built without
   embree and does not run.

A `.bsp` of version 29, 1.6 MB: 3,507 faces, 108 textures (981 KB with
their mips), 1,053 leaves, 161 KB of lightmaps, 25 brush models.

`palette.lmp` and `colormap.lmp` are LibreQuake's `lq1/gfx/` ones: the
palette is id's (the same bytes), the colormap 64 rows of light by 256
colours.

## What the game reads beside it

`progs/`, `sound/` and `music/` are LibreQuake's `lq1/` files, copied as
they are at the same paths, as Quake's own directory had them, by

    games/fps/quake/tools/mkdata.sh LIBREQUAKE-DIR

which copies what `mini-quake precache` lists: the models of the
monsters, the items, the weapons in hand, the missiles, the gibs and
the backpack (2.2 MB, with the nine the level's things had); the sounds
the monsters, the weapons, the items, the doors, lifts, buttons and
triggers make (93 WAVs, 4.4 MB: LibreQuake's are 8 or 16 bits at
11,025 to 48,000 samples a second, where id's were 8 bits at 11,025);
the level's CD track, `music/track06.ogg` (lq_e0m1's worldspawn says
"sounds" "6"; 3 MB, 6 minutes 8 seconds of Ogg Vorbis at 44,100, two
channels).

LibreQuake's maps, textures and pictures are under the BSD license that
`COPYING.librequake` says, whose notice goes with them in any binary
form (a compiled `.bsp` is one): this file is that notice. Its
`docs/README-IMPORTANT-LICENCE-INFO` says the models, the textures and
the sounds are under it (BSD-3), and only its QuakeC, progs.dat and
pop.lmp under the GPL 2 (none of them here); the music is in the same
tree, credited to its composers in `docs/CREDITS`, under the same
repository's COPYING.

Any other `.bsp` of version 29 works the same (`mini-quake
bsp=file.bsp`, its `palette.lmp` and `colormap.lmp` beside it), id's
own `maps/e1m1.bsp` from the shareware `pak0.pak` among them; none of
id's data is in ix.
