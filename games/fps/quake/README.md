# games/fps/quake: mini-quake

Quake (id Software, 1996): its software renderer, its lightmaps and
its game, a program of ix's playground, on Linux and on mini-9pi. A
level of a .bsp (LibreQuake's lq_e0m1 by default, compiled by qbsp and
vis, lit by `tools/Light.ml`), textured and lit as Quake drew it, its
doors, buttons and lifts, its monsters, weapons, sounds and music. The
keys, the flags and how a frame is made: `Quake.ml`'s header
(`mini-quake -help`); the plan, its stages and its measures:
[`plan_quake.md`](../../../docs/plans/done/plan_quake.md).

## The PC of 1996, and the Pi 2

Quake was made for a Pentium: it asked for one at 75 MHz, and was
smooth at 320 by 200 on a Pentium at 90 to 133; a 486 was too slow
(it needs the Pentium's fast floating point). Still no 3D hardware:
the first 3D cards came after (GLQuake, 1997). How it drew a true 3D
world on the processor alone:

- **What can be seen, computed before**: the level's BSP and its PVS
  (`vis`: for each leaf, the leaves seen from it), so a frame visits
  only the rooms that can be seen.
- **Each pixel of the world drawn once**: the edges of the visible
  polygons sorted into spans (the edge list), the nearest surface
  each span's; no depth tested for the world, written only for the
  models (the monsters) to be drawn over it.
- **The light computed before, and cached**: each surface's lightmap
  (`light`) mixed with its texture once into a "surface cache", kept
  while the surface is seen; a pixel is then a read from it.
- **The perspective's division every 16 pixels**, by Michael Abrash's
  assembly: the Pentium's floating-point divider running for the next
  16 pixels while its integer pipes drew these, a few instructions a
  pixel.

(As usually told, from memory, not checked against a source here: a
Pentium 90 ran around a hundred million instructions a second, two at
a time when they paired.)

mini-quake on the Pi 2 runs on one of its four cores (a Cortex-A7 at
900 MHz, about 280 million arm instructions a second under mini-9pi):

| a frame, arm instructions by mini-5i | | a pixel of the 64,000 |
|---|---:|---:|
| at the level's start (2026-10-23) | 23.2M | 360 |
| a fight (`frames.expected`'s, frames 200 to 220), 2026-10-27 | 34.7M | 540 |
| the same, the models' triangles by their gradients (`Alias.gradients`; `models=simple` the old way) | 21.8M | 340 |
| the same without the monsters (`nomonsters`) | 15.0M | 235 |

On the board (the author, 2026-10-22): about 15 frames a second,
outside rio; 2026-10-27, 18 with `graphics=only`, and under 7 when
the dogs came, with the sound: their models were 20M of the fight's
34.7M (each triangle's rows by closures along its edges, a list sorted
a triangle, six vectors made a vertex), now 7M (id's gradients). The
sound is 2.1M a sixtieth of a second, 126M a second: near half the
processor. Why it needs more than a Pentium's instructions:

- **Floats in mini-ml's code**: a float given to a function, or put in
  a `float array`, a block of its own (`plan_ml_floats.md`,
  `plan_ml_speed.md`); Quake's floats were the FPU's registers.
- **No inner loop by hand**: the spans, the surface cache and the
  models drawn by mini-ml's code, the bounds of each array tested; no
  division overlapped with the drawing (one processor, in order).
- **What Quake did not do**: the picture made the platform's pixels
  and shown by the kernel's draw device, the sound mixed in floats.

The algorithms are id's (the PVS, the edge list, the surface cache:
`render/`); what is slow is the code. GLQuake's lesson came next: the
spans and their depth given to a 3D processor, which the Pi 2 has and
mini-9pi does not use yet ([`plan_gpu.md`](../../../docs/plans/plan_gpu.md)).
