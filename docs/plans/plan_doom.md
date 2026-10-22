# Plan: mini-doom, Doom's renderer with its textures, on ix's playground, on Linux and mini-9pi (`games/fps/doom/`)

The author (2026-10-22): "let's add a mini-doom. You can look at the
TinyDoom in the playground, but also ~/github/ocamldoom/; I would like
especially to have textures in minidoom, like in ocamldoom, so it's
quite close to the original; you have also doom9 in 9front for
inspiration. Note that it maybe be too low fps because of the way the
playground and draw platform work on mini-9pi, but we can maybe think
about a /dev/framebuffer that would provide a faster path (albeit no
rio/windows support), with raw access so less copy and intermediates.
Ideally the games could be run with -framebuffer, -software, -draw,
etc. so lib_playground/ for plan 9 would allow to choose dynamically if
needed"; "for plan 9 I mean for m-ix"; then "if needed, we could even
make a plan_playground_framebuffer.md or something, but first, let's
do mini-doom (feel free to create a plan document for it and follow
it)".

So this plan is the game; the framebuffer and the platform chosen at
run time are a plan of their own, after it (below, stage 6).

## The survey (2026-10-22)

| | what | lines | what it gives mini-doom |
|---|---|---:|---|
| the playground's `games/fps/TinyDoom.ml` | a level of its own (the `Sectors` kit), its own BSP built at start, flat colours drawn as shapes (polygons a run of columns), Doom's light | 499 | the explanation (its header), not the pixels: shapes are what is slow on mini-9pi (plan_playground_speed.md) |
| `~/github/ocamldoom` (François Pessaux, 1997; ported 2026) | a renderer of textured walls and flats over a BSP of its own format (`.world`, compiled by `bspcompmain`), GIF and PNG textures quantized to a palette, a converter of Freedoom's WADs (`tools/wadtoworld`) | 4,608 (renderview.ml 527) | the proof that the textures are what makes it look like Doom; its format is not Doom's, and its BSP is rebuilt from the level |
| 9front's `sys/src/games/doom` (id's source of 1997, linuxdoom, with 9front's i_*.c) | the whole game | 5,212 in `r_*.c` alone | the renderer's structure and numbers (r_bsp.c, r_segs.c, r_plane.c, r_main.c's tables); `i_video.c`: a 320 by 200 picture made in the program, its palette turned to 32-bit pixels, `loadimage`, then `affinewarp` (the device scales it), `flushimage` |
| Freedoom's source (`/media/pad/extradrive1/pad/software-src/game/freedoom`, BSD) | levels as WADs with their nodes built, patches and flats as PNG, `textures.cfg`, the base palette | | the data: free to copy, Doom's format |

## Decisions (mine, for the author's review)

1. **Doom's own data, read as Doom reads it**: a WAD (`Wad`), its
   PLAYPAL, COLORMAP, PNAMES, TEXTURE1, patches, flats between F_START
   and F_END, and a map's lumps with the nodes its builder made
   (THINGS, LINEDEFS, SIDEDEFS, VERTEXES, SEGS, SSECTORS, NODES,
   SECTORS, BLOCKMAP). No BSP built here (TinyDoom's and ocamldoom's
   way): the WAD has it, as id's game had it from idbsp. So the same
   program reads Freedoom's levels and, given one, id's own WADs
   (`wad=doom1.wad`; 9front's shareware one is on the author's disk,
   and is not copied into ix).
2. **The WAD in the repository is made from Freedoom's source** by a
   tool of ours (`games/fps/doom/tools/Mkwad.ml`, OCaml: no Python in
   the build): E1M1, the textures and flats it names, the sky, the
   palette, and COLORMAP computed as Freedoom's script does (each of 32
   levels the palette darkened, the nearest colour of the palette).
   Freedoom's licence beside it (`data/COPYING.freedoom`, its BSD
   terms ask the notice with the binary form).
3. **The renderer is Doom's, in its order** (`Render`): the BSP walked
   nearest first (R_RenderBSPNode), each seg's angles clipped to the
   view (R_AddLine), the columns it covers drawn (R_StoreWallRange),
   upper, lower and one-sided walls textured, the ceiling and floor
   marked into visplanes, then drawn as spans (R_MakeSpans,
   R_MapPlane), the sky by the view's angle; the light by the sector,
   the distance (scalelight, zlight: 16 levels by 48 scales, 128
   distances) and the fake contrast. The names in comments are id's,
   to read beside r_*.c.
   - *Geometry in floats, pixels in integers.* id's fixed point is
     16.16 in 32 bits; ix's integers are 31 bits on the Pi1 (mini-ml
     and OCaml on arm), and a map's coordinates times 65536 overflow
     them. So what is computed once a seg or a column (angles, scales,
     the texture's column) is floats, and the loops of pixels (a
     column of a wall, a span of a flat) are integers, 16.16 there,
     whose values fit (a texture's row; a flat's coordinates taken
     modulo 64 first). Where the floats make another pixel than id's
     integers, it is said.
   - *Columns not covered yet*: id's `solidsegs` (a list of ranges)
     is an array of a flag a column here, and a count; the same
     answer, simpler to read, slower only by a scan a seg.
   - *ADTs*: the level's records are OCaml's, not C's layout
     (adts-over-c-layout): a seg's sides are options, a node's
     children a variant.
4. **The picture is Doom's, 320 by 200 bytes of the palette**, made
   each frame, then turned into the platform's pixels: a `Bitmap` of
   the playground, the picture doubled (640 by 400) by the program,
   so that no platform scales it (`scale=n`, 1 to 3). That is the
   slow way on mini-9pi (the draw platform loads a new picture each
   frame); stage 6 is the fast one.
5. **The game is a walk, as id's first level is**: the player's moves
   (momentum and friction by tics of 1/35 s, as P_Thrust and
   P_XYMovement), collisions with the lines (the blockmap's), steps
   of 24 and the room to stand (56), doors and lifts by the use key,
   the exit. Not in it: monsters, weapons, sound, menus, demos, the
   status bar's numbers. Each could be a stage later; none is asked.
6. **Its place**: `games/fps/doom/`, the program `mini-doom` (a
   faithful twin's name: Doom's renderer and data, not its whole
   game), several modules (`Wad`, `Level`, `Textures`, `Render`,
   `Play`, `Doom`), each with its `.mli` and a header that teaches,
   built by dune (the ppm platform; `sdl/` for a window on Linux) and
   by mini-mk for mini-9pi, on the card as `doom`, the WAD as
   `/lib/doom/freedoom.wad`.

## The stages

1. **The data**: `Wad`, `Mkwad`, the WAD made and checked in, its
   lumps listed (`mini-doom -lumps`).
2. **The view**: `Level`, `Textures`, `Render`: the first room of
   E1M1, textured, at the player's start; a golden frame by the ppm
   platform (`games/fps/doom/tests/frames.sh`), and frames compared by
   eye with ocamldoom's and with Doom's (chocolate-doom or doom9, the
   author's).
3. **The walk**: `Play`: moves, collisions, steps, doors, lifts, the
   exit; a recorded session of keys (`-script`) whose last frame is
   the golden one.
4. **The sprites** (things: barrels, lamps, monsters standing): Doom's
   vissprites, clipped by the walls' columns (drawsegs), and the
   two-sided middle textures (grates), masked. Only if stages 1 to 3
   leave room in the day.
5. **mini-9pi**: built by mini-mk (`mkfile`), the WAD on the card, the
   frames a second under QEMU, the instructions of a frame by mini-5i
   (`games/speed.sh`'s way): what the framebuffer plan starts from.
6. **The fast path**, its own plan
   (`plan_playground_framebuffer.md`, to write): a `/dev/framebuffer`
   of mini-9pi's (the screen's memory, written raw by one program on
   the bare screen, no rio), and lib_playground's platforms chosen at
   run time on Plan 9 (`-framebuffer`, `-software`, `-draw`).

## Status

2026-10-22, the first day: stages 1 to 5 done; stage 6 proposed.

- **The data** (stage 1): `tools/Mkwad.ml` makes `data/freedoom.wad`
  (2 MB: E1M1, 121 textures of 170 patches, 49 flats, 315 sprites'
  pictures, PLAYPAL, COLORMAP) from Freedoom's source at its commit
  `d14dbbee` (`data/README.md`). `Wad` reads any WAD: id's shareware
  `doom1.wad` plays as well.
- **The view** (stage 2) is id's renderer in its order (`Render`), and
  **id's own game is the reference**: `tests/reference/build.sh`
  builds 9front's Doom on Linux with no window (its `i_*.c` replaced
  by `i_ref.c`, Plan 9's two headers by `compat/`, one line of id's
  source changed for 64 bits; id's source read where it is, not
  copied), `tests/compare.sh` puts both eyes at the same place of the
  same WAD and counts the pixels that differ. On `doom1.wad`'s E1M1,
  five views (the start three ways, the hall, the zigzag):

  | | the start, north | east | south-west | the hall | the zigzag |
  |---|---:|---:|---:|---:|---:|
  | angles and scales by `sin`, `tan`, `atan2` | 10,259 | | | | |
  | id's tables (8,192 fine angles, its focal length of 159.76) | 5,599 | | | | |
  | its `R_PointToAngle` and `R_PointToDist` (2,048 slopes an octant) | 4,712 | 2,310 | 1,576 | 4,810 | 8,787 |
  | the sprites and the masked middle textures (stage 4), the things on | 4,388 | 2,266 | 1,534 | 4,810 | 8,348 |
  | the reference's flats held at their first frame | 4,419 | 2,251 | 1,523 | 4,810 | 5,864 |

  of 64,000, the things off (`NOTHINGS=1`) for the last row. What is
  left is a texel or a light level here and there along a flat's rows
  and a wall's rows: id's 16.16 truncated at each product, these
  floats are not (decision 3). Found by it, and kept as id's: a
  texture's column read from the patch's own bytes, rows past its
  height read from what follows (a lower texture of E1M1 is green
  there, black when made from zeros: `Textures.mli`).
- **The walk** (stage 3): moves, collisions with lines and solid
  things, steps, doors (DR, D1, S, W, the keys), lifts, a floor
  lowered, the exit, the lights' specials, the animated flats and
  textures, the switches. A press of use shorter than a tic is kept
  until the next tic (the playground's 60 frames a second against
  Doom's 35 tics).
- **The things** (stage 4): `Things` (info.c's spawn states for Doom's
  decorations, items, keys, gore, and the monsters standing with the
  flag `monsters`), vissprites and drawsegs, the masked middle
  textures.
- The frames' test: `games/tests/frames.expected`, four sessions (the
  start; the lift walked onto, and the same drawn by what changed each
  frame; a door used).
- Linux (OCaml, arm64): a frame 2.3 ms, the picture to the platform's
  pixels included (300 frames walking: 0.69 s); `redraw=each` 17 ms (the
  ppm platform's software renderer drawing the bitmap).
- **Smooth on Linux** (2026-10-22, the author: "mini-doom is not super
  smooth when running under Linux. Why?", then "this machine is 100x
  faster than a 486Dx66 from 1995 where doom was running smoothly").
  SDL's window, a temporary copy of its platform timed, the up arrow
  held:

  | | frames in 6 s | the view | the showing |
  |---|---:|---:|---:|
  | before: the `size=640` mini-doom asked for not read by the SDL platform (its command line's only), the 640 by 400 picture blended up to the window's ~1000 | 35 | 2.3 ms | 167 ms |
  | `size=640` typed: the picture as it is, by `Blit.draw_fast` (a float transform and `plot` a pixel) | 241, 79 frames a tick or two late | 2.5 | 14.3 (Redraw 14.5 of it) |
  | `Blit.draw_copy` (as it is: an image's row copied, no float) and `window=640x400` (no square, no black around) | 335, every one on its tick | 3.9 | 4.6 |

  The three changes: `Blit.draw_copy` (lib_graphics, behind
  `Opti.enabled`, the same pixels: every frames' test the same);
  mini-doom asks `window=` its picture's size (SDL's and ppm's
  platforms follow it; the Plan 9 ones have no `window` yet and keep
  `size=`); and the eye drawn between its last two tics (`Doom.eye`),
  as the ports since id's do: 35 tics shown at 60 frames moved the
  view on some frames and not others. Then Redraw's hash (the author:
  "let's optimize this hash thing"): it read a picture's megabyte at
  each hash, four in a frame that changed it (2.2 ms); now a picture's
  place and size, `compare` telling two apart (a frame where a message
  comes or goes, 5.45 ms to 2.05). Left: the draw and SDL platforms
  read `size=` from the command line only.
- **mini-9pi** (stage 5): runs. mini-ml refused `Render`'s functions
  of more than 7 parameters (`draw_column` has 10); by the author's
  rule (lift the limit, do not reshape the code) mini-ml now passes
  the arguments past the registers on the value stack (Gen, Lower,
  ssa/Emit: the same code as before for 7 or fewer; its own test,
  `languages/ml/tests/runtime/many_params.ml`; bugs/ix.md's rows and
  the bootstrap plan's ledger say it). `Play.command`'s nine
  arguments, eight booleans in a row, were made a record on their own
  merits. The game asks `heap=modest`: with the games' heap of eight
  times what is alive, its WAD's megabytes did not fit ("virtual
  memory allocation failed"). Built by `games/fps/doom/mkfile` (draw)
  and `PLATFORM=software` (`doom-soft`), on the card as `doom`,
  `doom-soft`, `/lib/doom/freedoom.wad`. Under QEMU, the up arrow
  held: **5 to 6 frames a second at 320 by 200 shown as it is** (the
  default on Plan 9: 40 frames in 6.4 to 8 s, the view 46 to 106 ms,
  the showing 70 to 84), under 2 at `scale=2`; the software platform
  under 1 (it draws the whole square). On the author's Pi 2, about 8
  frames a second (the author, 2026-10-22: "under the actual Pi2, doom
  is at around 8fps"), and about 7 in a window of rio's ("I also ran
  doom under rio on the pi2, and it's around 7fps"). Numbers of 15 a
  second were said here first, and were wrong: the eye never moved on
  mini-9pi (the author: "I see 15fps but I can't do anything"). The game took
  the keys; its picture was one of two buffers changed in place, and
  the draw platform keeps the device's image of a picture it has
  shown, found by the value itself (`==`): it showed the first two
  frames again and again, cheaply. Each frame's picture is now a new
  value over the two buffers (`Doom.view`); found by looking at the
  screens of a session, not its meter. By mini-5i, mini-ml's
  arm code: 40 million instructions a frame, 648 million to start (the
  WAD read, its textures made). mini-ml's frames are not OCaml's
  (arm64's fused multiply-add: 2 to 4% of the pixels, a texel apart):
  each frames' session has its second sum.
- What follows is [`plan_playground_framebuffer.md`](plan_playground_framebuffer.md)
  (stage 6): the view is half of a frame (mini-ml's speed, 4 to 5
  times OCaml's here), the path to the screen the other half (a new
  image of the device's each frame, made, loaded) and ruinous as soon
  as the picture is scaled; the picture is made three times before the
  device has it.
- Not run: the recorded mini-9pi sessions (`make check-*`), mini-qemu
  at `-ips 200` (a board's pace), the Pi 1; `make test-lite`; a
  mini-doom session under rio. The main tree's `build/card.img` was
  not remade (the numbers are from a card in the scratchpad).

2026-10-22, **the modules as id's files**, for reading mini-doom beside
id's source and Fabien Sanglard's Game Engine Black Book: DOOM (the
author: "ideally mini-doom reproduce the classic algorithm used by the
original doom, so it can be used as a teaching resource", "so one can
then read the book by Sanglard on doom", "it would make sense to have a
Bsp.ml though; it's such an emblematic feature of Doom"; and "we don't
have to follow exactly what id software did if it complicates the
code", "just if it does not cost much, we can follow a little"):
- `Bsp` (r_bsp.c): the tree's walk out of Render (left with
  R_RenderView), and id's solidsegs, the closed columns as sorted
  ranges, R_ClipSolidWallSegment and R_ClipPassWallSegment, where it
  was a flag a column; a box's check one range, not a scan. id's walk
  too: no early stop once every column is closed (the same frames, no
  slower: 0.98 s for 600 frames either way).
- Play's 628 lines as `World` (the state, the thinkers: d_player.h,
  p_spec.h, p_local.h), `Collision` (p_map.c: where the player can be;
  its `try_move` given what to do with a line crossed, where id's
  calls P_CrossSpecialLine itself), `Specials` (p_spec.c, p_doors.c,
  p_plats.c, p_floor.c, p_switch.c, p_lights.c) and `Play` (p_user.c,
  p_tick.c, G_BuildTiccmd). Not further: a module a file of id's would
  be twelve, of 20 to 60 lines.
- The .ml 2,204 lines to 2,253, the .mli 864 to 1,095 (the headers;
  World's types written in its .mli). Checked: 14 frames (walks,
  turns, the lift, a door, places, scale=1, things=off) the same sums
  before and after; games/tests/frames.sh's four, OCaml's and mini-ml's
  builds; mini-mk O=5 OS=plan9.
