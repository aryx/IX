# games/fps/doom: mini-doom

Doom (id Software, 1993): its renderer, its data and its game, a
program of ix's playground, on Linux and on mini-9pi. A level of a WAD
(Freedoom's E1M1 by default), its walls, floors, ceilings and sky
textured and lit as Doom drew them, its doors and lifts, its monsters
and weapons. The keys, the flags and how a frame is made:
`Doom.ml`'s header (`mini-doom -help`); the plan, its stages and its
measures: [`plan_doom.md`](../../../docs/plans/done/plan_doom.md). Its
modules follow id's files (`render/` the `r_*.c`, `play/` and
`actors/` the `p_*.c`), to be read beside Fabien Sanglard's *Game
Engine Black Book: Doom*.

## The PC of 1993, and the Pi 2

Doom was made for a 486: smooth on a 486DX2 at 66 MHz, playable on a
386DX at 33 (its minimum), and with no 3D hardware at all. The
processor did everything, at 320 by 200 pixels of 256 colours, 35
frames a second at most (the game's 35 tics). How:

- **Whole numbers only**: every coordinate a 16.16 fixed-point
  number (`fixed_t`), so it ran on a 386 or a 486SX, which have no
  floating point; sines, tangents and angles in tables.
- **Each pixel of the walls drawn once**: the level's BSP, built once
  by the level's tool (the node builder), walked from the eye, the
  nearest walls first; the columns already drawn kept (`solidsegs`,
  the clip arrays), so nothing is drawn under them, and no depth for
  each pixel. The floors and ceilings gathered in "visplanes", drawn
  after a row at a time.
- **The inner loops by hand, in assembly**: a wall's column
  (`R_DrawColumn`) and a floor's row (`R_DrawSpan`), a handful of
  instructions a pixel: a texel read by a step in fixed point, its
  light by a table (`COLORMAP`: 32 levels of each colour, precomputed).

(As usually told, from memory, not checked against a source here: the
486DX2-66 ran some tens of millions of instructions a second.)

mini-doom on the Pi 2 runs on one of its four cores (a Cortex-A7 at
900 MHz, about 280 million arm instructions a second under mini-9pi:
several times the 486's), and is slower:

| a frame, arm instructions by mini-5i (2026-10-26) | | a pixel of the 64,000 |
|---|---:|---:|
| the drawing alone (`graphics=only`) | 9.6M | 150 |
| a fight, monsters and sound | 17.0M | 265 |

On the board (the author): 24 frames a second where the level starts,
4 in a room full of monsters and their sounds (before the sound was
made cheaper, 2026-10-26). Why the difference:

- **Floats where Doom had whole numbers**: mini-doom computes in
  OCaml's floats (`norm`, `ifloor`), and mini-ml's code puts a float
  given to a function in a block of its own (`store_wall_range` is a
  quarter of a frame by that: `plan_ml_speed.md`'s item 6).
- **No inner loop by hand**: mini-ml's code, the bounds of each array
  tested, a call through a closure from one unit to another; a
  teaching compiler's, not a 1993 assembler programmer's.
- **What Doom did not do**: the picture made the platform's pixels and
  shown by the kernel's draw device (a frame's copy), the sound mixed
  in floats (`lib_audio`).

The algorithms are id's (the BSP, the clipping, the visplanes, the
colormaps: `render/`); what is slow is the code they are written in. A
486's lesson: the same algorithms in whole numbers and by hand.
