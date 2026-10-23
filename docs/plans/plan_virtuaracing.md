# Plan: mini-virtuaracing, Sega's polygon racer by a renderer of its own, at a game's rate on the Pi 2 without its 3D processor (`games/racing/virtua/`)

The author (2026-10-23): "I recently added mini-doom and mini-quake.
Maybe we can make a mini-virtuaracing, taking TinyVirtuaRacing from
the playground as inspiration. I dunno if we want to also start to
import the playground3d and physics3d lib from the playground, and
also whether it will be fast enough without GPU (for now) on the Pi
2." Offered this plan: "let's do it!".

The short answer: **a renderer of the game's own, as mini-doom and
mini-quake have theirs; not Playground3d, not Physics3d.** The
playground's 3D draws this game in about 320 ms a frame by OCaml on
this host, which would be seconds on the Pi 2 by mini-ml's code. The
same scene of flat faces, kept in arrays and filled span by span,
should fit a Pi 2's frame: a guess below, measured at stage 2.

[`plan_gpu.md`](plan_gpu.md) had this game as its goal, by the
boards' 3D processor. This plan takes the game off that road: the
processor stays the way to the playground's other 3D games, and
mini-virtuaracing is something it may draw later, not what waits for
it.

Its numbers are `games/survey_virtua.sh`'s (run 2026-10-23).

## The survey (2026-10-23)

### TinyVirtuaRacing

The playground's `games/racing/TinyVirtuaRacing.ml`, 1,665 lines:
three courses of the arcade's (Big Forest, Bay Bridge, Acropolis)
traced from the Mega Drive manual's maps, and TinyOutRun's coast;
sixteen cars, five laps, the clock and its checkpoints, the four
views, the tachometer and the map; flat-shaded, no textures. Its
header says what is the arcade's and what is not.

- **Its scene is few kinds of things**: `polygon3d` (27 lines),
  `box` (50), `cone` (8), grouped (`group3d`, 23), moved and turned
  (`move3d` and its kin, 72; `rotate3d`, 20), `cached3d` (5: the
  road's chunks of 40 segments, the land's tiles, the landmarks).
  No sphere, no texture, no face seen through.
- **What it names besides**: `Track3d` (77 uses), `Audio` (57),
  `Scene2d` (19), `Topdown` (12), `Camera3d` (5), `Sfx` (4), `Road`
  (4), `Heightmap` (2); `Lazy` (11: its tables).
- **Not physics**: "an arcade car is a few rules (Topdown.mli), and
  the rivals fewer". No `Physics3d`.
- **Four golden frames** (`~/playground/tests/3d/golden/TinyVirtuaRacing*.png`:
  the title, the course select, the grid, a curve), by its software
  platform's depth buffer.

### What a copy needs from the playground

| | .ml | .mli | ix has it |
|---|---:|---:|---|
| `gamekits/racing/3d/Track3d` (the course walked into a ribbon in space) | 254 | 176 | no |
| `gamekits/heightmap/Heightmap` (the land) | 143 | 101 | no |
| `gamekits/racing/Topdown` (the player's car) | 106 | 166 | no |
| `gamekits/racing/Road` (the coast's road) | 86 | 98 | no |
| `playground/layers/Camera3d` (the views) | 82 | 184 | no |
| `libs/graphics/3d/geometry/Vec3`, `Mat4`, `Camera` | 257 | 179 | no |
| | **928** | | |
| `Scene2d`, `Audio`, `Sfx` | | | yes (`lib_playground/layers`, `apis`, `lib_audio`) |

Not needed: `Physics3d` (609 lines), `Playground3d` (485), the
rasterizer `libs/graphics/3d/*.ml` (570). `Track3d.strip` and `wall`
and `Camera3d`'s values give and take Playground3d's `shape3d` and
`camera`: the copy gives the renderer's meshes instead (decision 3).

### Its frame by the playground

By the playground's software platform, OCaml, this host (a Neoverse
N1), no window, frames 5 to 25:

| | ms a frame |
|---|---:|
| 640 by 480 | 312 |
| 320 by 240 | 318 |

A quarter of the pixels, the same time: the time is not the picture's
size. Where it goes, by callgrind (frames 2 to 7, 320 by 240, millions
of instructions a frame):

| | millions |
|---|---:|
| the pixels: the rasterizer (`Triangle`, `Interpolate`, `Zbuffer`, `Framebuffer`, `Shading`) | 910 |
| OCaml's runtime: the GC, allocation | 342 |
| Stdlib's `List` and `Array`: the scene's lists | 193 |
| the scene: shapes made triangles, placed, cut (`Playground3d`, `Render`, `Clip`, `Project`) | 175 |
| other (the window, the PNG's deflate, the 2D hud) | 145 |
| **the game**: the car, the rivals, the view's lists, `Track3d.locate` | **9** |
| | **1,775** |

and **14,239 triangles filled a frame** (calls of `Triangle.fill`).

- **The game's own part is 9 million instructions, half of one
  percent** of the playground's frame; but it is not small beside a
  Pi 2's (below): what [`plan_gpu.md`](plan_gpu.md)'s stage 3 asked
  of the update and the view's lists is still open.
- **The rest is how the playground draws**, not what it draws: the
  rasterizer is half of it, yet a quarter of the pixels costs the same
  (above), so it is a cost for each triangle (64,000 instructions
  each: interpolation set up by closures, a box of pixels walked),
  not for each pixel; the GC and the lists are a third, the scene
  made again at each frame from `cached3d`'s groups.
- **14,239 triangles is everything within the playground's distance**
  (1,300 m of land around the eye, the road's chunks near the car),
  behind the eye and beside it included, both sides of each face
  (`backface_culling = false`). A view of 60 degrees sees a sixth of
  a disc around the eye: **2,000 to 3,000 triangles if the tiles and
  chunks outside the view are not drawn** (a guess, counted at stage
  1).

### What the Pi 2 gives

What is known of the board, from
[`plan_playground_framebuffer.md`](done/plan_playground_framebuffer.md)'s
Status (the author's card, 2026-10-22): mini-quake about 15 frames a
second, mini-doom 15 to 24, outside rio, by mini-ml's code on one
core. mini-quake's frame was then 27.8 million arm instructions by
mini-5i (since, 23.2: 19b70c51). So **a frame of about 10 to 12
million instructions by mini-5i would be 25 to 30 frames a second**
there, the showing of the picture (the same as mini-quake's, 320 by
200 bytes) included. That is the budget. mini-5i's count is the
yardstick of every stage (exact, and a minute where the board is a
card and a photo).

A guess at the frame, to be measured at stage 2:

- **The scene's faces**: the 2,000 to 3,000 triangles in view (the
  survey's 14,239 less the tiles and chunks outside the view's
  pyramid, a box's test each; the faces turned away from the eye
  dropped where a mesh is closed or seen from one side: the land, the
  boxes). Each face's corners turned by the eye's matrix (shared
  corners once), cut by the near plane, projected: a few hundred
  instructions a corner by mini-ml's floats. **1 to 4
  million.** The weakest part, and floats are mini-ml's weakest
  ([`plan_mini_toolchain_optimization.md`](plan_mini_toolchain_optimization.md));
  fixed point, as mini-doom's, if they are too slow.
- **The pixels**: 320 by 240 is 77,000 pixels, drawn about twice
  (sky, land, road, cars over it). A face is flat: a span is one colour
  and a depth that changes by a constant from pixel to pixel. **1 to
  2 million** with a depth buffer (decision 4), less without.
- **The game**: the car, fifteen rivals, `Track3d.locate`, the clock.
  9 million by OCaml in the playground (above), its lists and the
  view's included; mini-ml's code is about 3 times OCaml's on
  mini-doom's frame (16.1 million against 5.5: cfee472d,
  [`notes_profiling_techniques.md`](../notes_profiling_techniques.md)),
  so as it is, **more than the whole budget by itself: the first
  risk**, before the renderer. To be cut by arrays where lists are
  made at each frame (the tiles near, the chunks near, the cars), and
  taken apart at stage 2 by mini-5i -prof.

## Decisions (mine, for the author's review)

1. **A game of its own, in the mini-doom and mini-quake mold**, the
   playground's game its inspiration, not its source to be copied
   whole. Sega never published Virtua Racing's code: mini-doom
   follows id's files ([`plan_doom.md`](done/plan_doom.md)), this
   one has no files to follow. What it teaches is **how a polygon
   game drew without a 3D processor**: a scene of flat faces kept in
   memory, culled by pieces, turned, cut, projected, filled by spans,
   in a frame's time. What is the arcade's (the rules, the courses,
   the views, the screen) is TinyVirtuaRacing's list, kept.
2. **Where the files go**: `games/racing/virtua/`, with `games/racing/mkfile`
   and `dune` as `games/fps/`'s; the program `mini-virtuaracing`.
   Folders by part, as mini-quake's: `course/` (the courses as
   TinyVirtuaRacing writes them, `Track3d`, `Heightmap`, `Road`, the
   scenery), `render/` (the meshes, the view, the faces, the spans),
   `race/` (`Topdown`, the rivals, the clock, the laps), `sound/`.
   The playground's modules copied with a `README.md` saying what was
   copied and changed (`scripts/playground_copies.sh`); `Vec3`,
   `Mat4`, `Camera` in `lib_graphics/geometry/`, where
   [`plan_gpu.md`](plan_gpu.md)'s decision 2 wanted them too.
3. **The scene as the playground writes it, made arrays once.** A
   module `Mesh` with the names the game uses (`polygon3d`, `box`,
   `cone`, `group3d`, `move3d`, `rotate3d`, `scale3d`), so the
   courses read as TinyVirtuaRacing's; but a mesh is made once into
   arrays (the corners, the faces as indices, each face's colour
   already lit by the sun: `Lighting`'s formula, flat shading), and
   a frame does not build lists. What moves (the cars) is a mesh and
   a matrix. `Track3d.strip` and `wall` give meshes.
4. **A depth for each pixel, first**: the game leans on it (its
   comments: the land "winning the depth test" near the road, a
   road over itself, the bridge, the tunnel), and the playground's
   golden frames are a depth buffer's. A flat face's 1/z is linear on
   the screen: a span is a start and a step, as ints, a compare and
   two stores a pixel. The faces sorted, farthest first, with no
   depth (the painter's) is the option to measure after, switchable
   beside it: fewer instructions a pixel, wrong where faces cross.
5. **The picture is `Playground.Pixels`**: a byte a pixel, 320 by 240,
   the platforms' scale making it the window's (as mini-doom and
   mini-quake). **The palette is the problem**: about 120 colours
   before the light, every face lit its own way after, 256 indices.
   First a palette for each course, made once at its start from the
   lit colours of its meshes and the cars' (a median cut), each face
   given its nearest index then. The golden frames say how far that
   is; a cube of 6 by 7 by 6 levels is the simpler fallback.
6. **The sound, as mini-doom's and mini-quake's**: `Audio` and `Sfx`,
   the engine, the tyres, the jingles. The playground's synthesized
   ones (TinyVirtuaRacing's `Audio.abc` and `Sfx`), no recordings.
7. **What is left out at first** (the header saying so): TinyOutRun's
   coast (`Road`, `Track3d.of_road`) until the three circuits run,
   the course's miniature on the select screen if it is slow.
8. **Not Playground3d, not Physics3d, here.** Playground3d stays
   [`plan_gpu.md`](plan_gpu.md)'s, for the playground's other 38 3D
   games; this game's renderer is not a platform of it. If the boards'
   processor is done, it can draw this game's meshes (they are what
   its decision 5's "mesh kept" asks), as a later step there.

## The stages (each checked before the next)

1. **The course, still.** `Vec3 Mat4 Camera` copied; `Track3d` and
   `Heightmap` copied with meshes out (decision 3); one course (Big
   Forest), its road, land and landmarks, seen from the grid; the
   renderer: the meshes culled by chunk and tile, turned, cut by the
   near plane, filled with a depth for each pixel; the palette.
   Check: by the ppm platform, beside the playground's golden
   `TinyVirtuaRacing_grid.png` (the difference said:
   `games/tests/frames.sh`'s measure); OCaml's frame and mini-ml's
   the same bytes, or the difference said (fused multiply-add,
   `games/tests/frames.sh`'s second sum).
2. **The frame measured**: instructions by mini-5i, the frame taken
   apart (cull, corners, faces, spans, show), against the budget
   above, in a table here. If over it, what is cut first (fixed point
   for the corners, the painter's for the pixels, a nearer far
   plane) is said and done before stage 3.
3. **The race.** `Topdown`, the rivals, the clock, the laps, the four
   views, the screen (`Scene2d`: title, select, race, goal), the
   other two courses. Check: the four golden frames, the frames'
   test's sessions (a lap held down), recorded; a race by a script
   ends where it ended in the playground (its place and time, said).
4. **Sound.** Check: `games/tests/audio.sh`'s way.
5. **On mini-9pi.** Under QEMU, then the author's Pi 2: its frames a
   second, the frame taken apart again, in Status. Then what the
   table says is next (the coast, the painter's, the processor by
   [`plan_gpu.md`](plan_gpu.md)).

## Open questions

- **Floats or fixed point for the corners?** Stage 2 says.
- **The palette** (decision 5): is a median cut near enough the
  golden frames, or does the game want more than 256 colours (a 16-bit
  `Pixels`, which no platform has)?
- **The far plane**: the playground draws land within 1,300 m of the
  eye. A nearer one, with fog to hide it, is the period's answer if
  the faces are too many.

## Status

2026-10-23: plan written, after the survey
(`games/survey_virtua.sh`). Nothing built.
