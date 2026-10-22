# Plan: mini-quake, Quake's software renderer and its lightmaps, on ix's playground (`games/fps/quake/`)

The author (2026-10-22): "we recently added mini-doom (and its BSP).
we should add mini-quake to finish the trilogy, and again take
inspiration from TinyQuake in the playground, ocamlquake in
~/github/ocamlquake, and ioquake and other OSS original quake code.
Quake is famous for its fast lightning system so again, like for
mini-doom, which can be used as a teaching resource to learn about game
engine, we could also explain well those light map and other nice
things introduced by quake."

The trilogy: TinyWolfenstein (rays through a grid), mini-doom (a 2D BSP
walked front to back, columns and spans), mini-quake (a 3D BSP, the
PVS, the edge list and its spans, the surface cache, the lightmaps).

## The survey (2026-10-22)

| | what | lines | what it gives mini-quake |
|---|---|---:|---|
| the playground's `games/fps/TinyQuake.ml` | three rooms of boxes; qbsp, vis and light run at start, small (CSG, a BSP of solid space, a PVS by sampled rays, a lightmap as patches of polygons); playground3d's z-buffer draws | 622 | the explanation of the three tools (its header), not the renderer: no textures, no surface cache, no edge list |
| `~/github/ocamlquake` (François Pessaux, 1998-99; ported 2026) | a `.bsp` (version 29) read, the PVS decompressed, the BSP walked back to front, polygons clipped and filled (painter's), perspective-correct textures and lightmaps sampled per pixel; LibreQuake's two hubs compiled, with `light` of ericw-tools built from source | 3,172 | the proof the format reads simply; the maps' build (its `maps/librequake/README.md`); not id's drawing (no edges, no spans, no surface cache) |
| chocolate-quake (`software-src/game/chocolate-quake`, GPL: id's WinQuake 1.09, its assembly's C versions) | the whole game, in C | 47,603 (the renderer's `r_*.c`, `d_*.c` 9,000) | id's renderer, its order and its numbers: r_bsp.c, r_draw.c (a face's edges clipped, projected, emitted), r_edge.c (the scan of edges, the surfaces' stack, the spans), r_surf.c and d_surf.c (the surface cache: texture times lightmap), d_scan.c (spans, perspective every 16 pixels), r_light.c (light styles), r_alias.c, d_polyse.c (models), world.c (the hulls' trace), sv_phys.c, sv_user.c (the walk) |
| id's quake tools (qutils, 1996: `qbsp`, `vis`, `light`, GPL) as ericw-tools (`/nix/store/...-ericw-tools-0.18.1`) | the map compilers | | `qbsp` and `vis` run (0.5 s and 0.1 s on LibreQuake's lq_e0m4); its `light` does not ("no backend available": nix's built without embree) |
| LibreQuake (`software-src/game/LibreQuake`, BSD-3, at `4d2da523`) | Quake's Freedoom: maps as `.map` sources (91, no `.bsp`), texture WADs (some built, all as indexed PNGs), `gfx/palette.lmp` (id's palette), `colormap.lmp`, models (`progs/*.mdl`); no `progs.dat` | | the data, free to copy |

ioquake3 is Quake III's (curved patches, shaders, OpenGL only): not
this renderer's ancestor; Quake's own source (WinQuake, id 1999) is,
read through chocolate-quake, which keeps its C paths.

## Decisions (mine, for the author's review)

1. **The level as Quake's tools make it**: a `.bsp` of version 29,
   compiled from LibreQuake's `lq_e0m1.map` ("Baseless Base Banter",
   the first level of its first episode, a base as id's E1M1: 1,074
   brushes, 104 lights, 11 of them styled). `qbsp` and `vis` are
   ericw-tools' (as Freedoom's node builder made mini-doom's nodes),
   run by hand, said in `data/README.md`.
2. **`light` is ours** (`tools/Light.ml`, `mini-light`): id's
   `light` (ltface.c), what bakes the lightmaps, in OCaml. It is the
   half of Quake's lighting that runs before the game, and the one the
   author asked to explain: a face's samples every 16 texels, each
   asked of every light whether a ray reaches it through the BSP
   (the hull's trace), the light falling linearly with the distance,
   by the angle, a lightmap a style (up to 4 a face). Extensions of
   ericw's the map asks, kept small: `_sunlight` (a ray towards the
   sun that ends in the sky), `mangle` spotlights, `wait`, `delay`'s
   falloffs. Not `_bounce`, `_dirt` (ambient occlusion), colour (the
   `.lit`): vanilla Quake's lightmaps are one byte a sample.
3. **The texture WADs from LibreQuake's PNGs** (`tools/Mkwad.ml`,
   `mini-mkwad2`, WAD2): the PNGs are already of Quake's palette,
   indexed; each miptex's four mips made as id's `qlumpy` did (2 by
   2, 4 by 4, 8 by 8 averages, the palette's nearest). Only the WADs
   the map names; three of them (`lq_terra`, `lq_legacy`,
   `lq_utility`) have no `.wad` built in LibreQuake.
4. **The renderer is id's software one, in its order**, each module a
   group of id's files, the names in comments id's (to read beside
   Abrash's *Graphics Programming Black Book*, chapters 59-70, and
   Sanglard's Quake source review):
   - `Bsp` (model.c): the lumps read into OCaml's records
     (adts-over-c-layout): a node's children a variant, a leaf's
     contents a variant, the PVS decompressed on demand.
   - `Bsp` (r_bsp.c, r_main.c's R_MarkLeaves): the leaves the eye's
     leaf may see, and their parents, marked by the frame's number;
     the tree walked front to back, the boxes outside the frustum
     skipped; the brush models cut by the world's leaves.
   - `Edges` (r_draw.c): each face's edges clipped by the four planes
     of the view, projected, and put in the scanlines' lists; a
     surface's key the walk's order.
   - `Scan` (r_edge.c): the scanlines, the active edges sorted by
     their u, the surfaces' stack (the nearest by key, then by 1/z):
     spans, each pixel of the world drawn once, no z-buffer.
   - `Surfcache` (r_surf.c, d_surf.c, r_light.c): a face's texture
     times its lightmaps, at a mip level, made once and kept until a
     light style it uses changes: the trick that made texture times
     light cost nothing a pixel. The lightmap's 16-texel samples
     interpolated across each 16 by 16 block, the light a row of the
     colormap (64 levels).
   - `Spans` (d_scan.c, d_sky.c): a span's texels, u/z, v/z, 1/z
     interpolated, the true division every 16 pixels (Abrash's
     overlap of the FPU's divide); the turbulent water (the sine
     table), the sky's two layers.
   - `Alias` and `Things` (r_alias.c, d_polyse.c; QuakeC's spawn
     functions): the `.mdl` monsters and items, standing, lit by the
     lightmap under them (R_LightPoint), drawn by the z-buffer the
     world's spans wrote.
   - *Geometry in floats, pixels in integers*, as mini-doom: what is
     done once an edge, a span's start, a face is floats; a span's
     pixels and the cache's texels integers (16.16, values that fit
     31 bits).
   - *The cache*: id's is a ring of blocks in a fixed memory, the
     oldest evicted; here an array a face a mip, emptied whole when
     the total passes a budget. Same pictures, simpler, said.
5. **The picture is 320 by 200 bytes of the palette**, as mini-doom's
   and Quake's own default mode, made the platform's pixels n by n.
6. **The game is a walk, as mini-doom's**: Quake's moves
   (sv_user.c's friction and acceleration, sv_phys.c's gravity, steps
   of 18, sliding along walls), the player's hull (32 by 32 by 56:
   hull 1, its clipnodes) traced (SV_RecursiveHullCheck); the doors,
   buttons, plats and triggers that QuakeC's doors.qc, plats.qc and
   triggers.qc made (no QuakeC here: no `progs.dat` is free, and its
   VM is another plan); the light styles animated (world.qc's
   strings, "mmnmmommommnonmmonqnmmo"). Not in it: weapons,
   monsters moving, sound, the network, the console, the status bar.
7. **Its place**: `games/fps/quake/`, the program `mini-quake`, built
   by dune (ppm; `sdl/` for a window) and mini-mk (mini-9pi: `quake`,
   `/lib/quake/e0m1.bsp`), its headers teaching (header-comments-teach).

## The stages

1. **The data**: `mini-mkwad2`, `qbsp`, `vis`, `mini-light`: the
   `.bsp` checked in with its lightmaps, the palette and colormap
   (`data/`); `mini-quake -lumps`.
2. **The view**: `Bsp`, `Edges`, `Scan`, `Surfcache`, `Spans`:
   the start, textured and lit; frames looked at, the lightmaps alone
   (`lightmaps` flag: the texture grey), the PVS's count of leaves.
3. **The walk**: the hull's trace, the moves, the doors, the light
   styles; a recorded session's frames in `games/tests/frames.expected`.
4. **The models**: the monsters and items standing, the z-buffer.
5. **mini-9pi**: mini-mk, the card, the frames a second under QEMU.
6. **The reference** (later): chocolate-quake built without a window,
   as mini-doom's id reference, to count the pixels that differ; it
   needs a `progs.dat` (LibreQuake's QuakeC compiled: no compiler of
   QuakeC here yet).

## Status

2026-10-22, the first day: stages 1 to 4 done, 5 built (not run on
mini-9pi), 6 not started.

- **The data** (stage 1): `tools/mklevel.sh` makes `data/e0m1.bsp`
  (1.6 MB) from LibreQuake's source: seven texture WADs by
  `tools/Mkwad.ml` (5 s), ericw-tools' `qbsp` (0.6 s) and `vis` (0.2
  s), then `tools/Light.ml` (2 s: 104 lights, 3,182 of 3,507 faces
  lit, 159 KB of lightmaps). Reproducible but for `vis`'s threads (a
  few bytes of the PVS). `data/README.md`, `data/COPYING.librequake`;
  `data/progs/`: nine of LibreQuake's models (1.3 MB).
- **Our light against ericw's**: on ocamlquake's `lq_start_e0.bsp`
  (lit by ericw's `light` from source), the same views drawn by
  mini-quake with either lightmap: the same shapes of light and
  shadow, ours darker (the samples' mean 35 against 56). The map asks
  ericw for `_bounce 3` (light reflected by the walls, a radiosity id's
  tool never had); id's light is kept (decision 2), the bounce a
  possible stage.
- **The view** (stage 2) is id's renderer in its order, its modules
  named in the plan (`View`, `Bsp`, `Edges`, `Scan`, `Surfcache`,
  `Spans`, `Render`; `Model` and `Bspfile` the data), each `.mli` a
  header that teaches. Deviations, each said in its module: square
  pixels (yscale = xscale); u in 16.16 (id's 12.20 does not fit 31
  bits); a face's edges not shared with its neighbour (id's edge
  cache); the surface cache a table emptied oldest first, not a ring;
  the liquids' s and t taken modulo the texture (id's extents of 16,384
  overflow 31 bits). The flag `lightmaps` draws the lightmaps alone,
  the textures grey: the circles of each light's falloff and the
  shadows, Quake's lighting shown.
- **The walk** (stage 3): `Trace` (world.c: the hulls), `Play`
  (sv_user.c, sv_phys.c: friction, acceleration, air control, gravity,
  steps of 18, sliding, water), `Brushes` (QuakeC's doors.qc,
  plats.qc, buttons.qc, triggers.qc in OCaml: linked doors and their
  fields, key doors, secret doors, buttons and their textures' other
  frames, lifts, trigger_once/multiple/secret/teleport/changelevel,
  switched lights, skill flags). The shot that opened secret doors and
  shot buttons is the use key `e`. The light styles animate (world.qc's
  strings); a surface is made again only when its styles' values change.
- **The models** (stage 4): `Alias` (an `.mdl` read; r_alias.c's
  lighting by the lightmap under the model, R_LightPoint; d_polyse.c's
  affine triangles against a z-buffer the world's spans fill) and
  `Things` (QuakeC's classnames to models, dropped to the floor, the
  monsters' stand frames, the items turning). Vertex normals computed
  from each frame's triangles, not id's table of 162 (not copied).
  Not drawn: the items QuakeC made brush models (health, ammunition,
  barrels: LibreQuake has their sources, not their `.bsp`).
- The frames' test: seven sessions in `games/tests/frames.expected`
  (the start, a walk, the same drawn by what changed, a door opened, the
  soldiers, the lightmaps alone, the water); mini-ml's frames are
  OCaml's, byte for byte.
- Linux (OCaml, arm64): 300 frames of the start 0.59 s, about 2 ms a
  frame; mini-ml's build 5 times slower.
- **mini-9pi** (stage 5): built (`mini-mk O=5 OS=plan9`), on the card
  (`kernels/9pi/Makefile`: `quake`, `/lib/quake/`). By mini-5i, mini-ml's
  arm code at 320 by 200 (`-dump-frame` 1 and 3, the difference
  halved): 55 million instructions a frame at the start (the rock, the
  sky), 116 million in the soldiers' room (its surfaces made, three
  models); Doom's frame was 40 million. To start: 382 million (the
  .bsp read), 586 with the models (2,517 million before the models'
  normals were made only for the frames drawn). So a few frames a
  second on the Pi 2, below mini-doom's 8, until what plan_doom.md's
  stage 6 and the compiler's plans give.
- 4,521 lines of `.ml` at 80 columns (ocamlformat's margin; 3,159 before
  it, Doom's 3,348 with its longer lines), 1,111 of `.mli`; the tools 610.
- Not run: mini-9pi under QEMU or mini-qemu, the Pi 2; the card not
  remade; `make test-lite`; the reference (stage 6).
