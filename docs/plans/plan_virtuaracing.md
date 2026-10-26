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
9. **The Pi 2's 3D processor later** (the author, 2026-10-26: "at some
   point on the Pi2 we might leverage the GPU, so let's also plan that
   the code later will need to adapt and use GPU features from the
   Pi2"). The VideoCore IV takes vertices **already placed by the
   program** (its "NV" shader state, [`plan_gpu.md`](plan_gpu.md)'s
   survey): the program turns, cuts by the near plane and projects;
   the processor bins the triangles by tile, fills them and keeps their
   depth. That is where `Render` is cut already, and the cut is kept:
   - **The front, the game's on every board**: the meshes near the
     eye (`Course`), culled by their sphere and by the faces turned
     away, turned, cut by the near plane, projected; a face out of it
     as its corners on the screen (sx, sy) and 1/z (iz), a convex
     polygon, and its colour. The NV state wants the same: X and Y on
     the screen (12.4 fixed point), Z and 1/W, a triangle fan.
   - **The back, the one to replace**: `Render.fill` (spans, the
     depth for each pixel, a byte a pixel). The processor's would
     write a fan of a face into its lists instead, and the picture
     would be its own (`BGR565` or `RGBA8888`, four samples a pixel),
     not `Playground.Pixels`' bytes.
   - **What follows for the code until then**: `face`'s call of
     `fill` stays the one place a face leaves the front (no pixel
     work in the front, no mesh work in `fill`); a face's colour is
     known as RGB lit (`Palette.lit`) before it is a palette's index,
     which only the software back needs; the near plane's cut stays
     the program's (the NV state does not cut); and nothing in the
     game reads the picture back (the processor's is in its memory).
     The frames of a processor's back are not the software's bytes
     (its own edges' rules, its four samples): its own recorded
     frames, compared by `tests/compare.sh`'s difference, not a sum.
   - **What the budget would become**: the back is a third of the
     frame now (`fill`, `span`, `first`, measured at stage 2); with
     the processor, the front alone and the lists' writing, so more
     faces a frame (a farther horizon, the faces not culled by
     distance) become affordable. The order: the software's frame
     first (stage 5), then the processor, as plan_gpu.md's stages 3
     and 4 make it work on the Pi1 and the Pi 2 (same VideoCore IV).

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

2026-10-25: **stage 1 done** (the author: "let's start mini virtua
racing"; the decisions taken as proposed, the palette by a median cut).
`games/racing/virtua/` (its `README.md`): `render/`'s `Mesh`, `Palette`,
`Render`; `course/`'s `Track3d` and `Heightmap` (copied), `Land`,
`Scenery`, `Course` (Big Forest); `race/Cars`; `Virtua.ml`, the
program, its four views (`v`). `Vec3`, `Camera`, `Lighting` in
`lib_graphics/geometry/` (`Mat4` not copied: the renderer turns a
corner by `Camera.basis`'s three vectors). The sixteen cars stand on
the grid, still.
- Checked: the frames by OCaml and by mini-ml (mini-mk, in a copy of
  the tree) the same bytes, the four views; `games/tests/frames.sh`'s
  three sessions (`grid`, `start`, `views`) on both builds.
- Against the playground's golden `TinyVirtuaRacing_grid.png`
  (`games/racing/virtua/tests/compare.sh`): 884,197 pixels of 1,000,000
  differ, 33,999 by more than a level of 64, a mean difference of 6.7.
  The far ones are the playground's race screen (time, position,
  tachometer, map, the countdown's 2) and the trees, placed by a hash
  of ours (`Scenery.jitter`: OCaml's `Hashtbl.hash` is not mini-ml's);
  the many near ones the palette's 256 colours. The road's line shows
  here (a tie in depth goes to the face drawn last), not in the
  playground's.
- A first measure, for stage 2 (this host, the ppm platform, frames 3
  to 43): **7.5 ms a frame by OCaml** (the playground's: 312), **185 ms
  by mini-ml**, 25 times OCaml's where mini-doom's is about 3: the
  first thing stage 2 takes apart (the floats, most likely: the corners
  turned, the spans' setup). 10,738 faces reach the spans a frame from
  the grid (none dropped for facing away yet), not the survey's guess
  of 2,000 to 3,000.
- Not run: mini-5i's count, mini-9pi, the board. games/mkfile builds
  it with the games (`CATEGORIES`); not on the card's image yet.

2026-10-26: **stage 2, the frame measured** (arm, mini-ml -O3, mini-5i,
the grid's view, the default 320 by 240): a frame **197 million
instructions** (5 frames less 3, by 2), the budget's 10 to 12 about 17
times; the start (the course built, the palette, the first frame)
**7.5 billion**, ten seconds or more on the Pi 2. By `mini-5i -prof`
and `mini-prof -diff` (3 frames less 1, by 2):

| a frame's part | million | % | what |
|---|---|---|---|
| `fill` | 41.5 | 21 | the edges and the rows' setup, floats |
| `face` | 33.6 | 17 | the frustum's test, the near plane, the projection |
| the collector (`copy`, `ml_modify`, `ml_alloc`, `minor`, `scan_copies`) | 48 | 25 | every float boxed: each one stored in `vx`, `sx`, `lefts`... a block and a barrier |
| `draw` | 19.5 | 10 | the corners turned |
| `span` | 8.5 | 4 | the pixels themselves |
| `first`, `floor`, `ceil` | 15 | 8 | `Float.ceil` a call of C |
| the rest | 29 | 15 | `cmp`, `min`, `max`, the cars' `draw_at` |

The pixels are not the cost; the faces are (10,738 a frame, a few
thousand instructions each), and mini-ml's boxed floats in them: OCaml
keeps a `float array` flat and a float in a register, mini-ml does
neither (`plan_playground_speed.md`'s M4, not done). That is the 25
times OCaml's.

The start: `Track3d.project` 21% and `div` 18% (its `mod`, arm's
division in software), `hypot` 5%: the trees placed by `Track3d.locate`
over the whole course for each one (`Course`'s rows), and `Land.make`
searching every road sample for each point of its grid.

What is cut (the author's choice, 2026-10-26: "mini-ml floats unboxed
(M4)", over fixed point in `Render`): mini-ml's floats not boxed, a
`float array` flat and a float kept in a register inside a function
(`plan_playground_speed.md`'s M4), for every float program, not this
game's renderer alone; stage 3 waits for it. Besides, in the game:
the faces turned away dropped, and the start's two searches (the
trees' `Track3d.locate`, `Land.make`'s samples) made near ones.
M4's plan: [`plan_ml_floats.md`](plan_ml_floats.md).

2026-10-26, later: M4 done (`plan_ml_floats.md`, its stages 3 and 4):
mini-ml's floats in registers, `Float.Array`, the collector's table
of old fields; `Mesh` and `Render` on `Float.Array`. A frame **111.0
million instructions** on arm (frames 3 to 23; 201.1 before), the
start to frame 3 5.3 billion (7.9). Still about ten times the budget:
the game's own cuts next (the faces turned away, the start's searches,
`Float.min` and `Float.max`).

2026-10-26, then: **the game's own cuts** (the author: "yes let's
commit and move forward"):
- **The faces turned away** not drawn (`Render.cull`, `cull=off` to
  compare): 6,485 faces a frame from the grid of 10,738. Open shapes
  are marked seen from both sides (`Mesh.two_sided`): `Track3d.wall`,
  found by comparing the four views with and without (a strip of the
  right verge missing). What is left between the two: 1 to 22 pixels a
  view, the hills' summits and the horizon seen at a grazing angle.
  The frames recorded again (`frames.expected`, the three sessions);
  OCaml's and mini-ml's still the same bytes.
- **`Float.min` and `Float.max`** in lib_core without their `Int64`
  but where the signs choose (`plan_ml_floats.md`); OCaml's answers,
  the bits (`tests/runtime/float_min_max.ml`); mini-ml's `floats` bench
  0.63, `samples` 0.60.
- **The start's two searches**, the same answers (each checked whole
  once, every land point and every locate against the old search):
  `Track3d.locate_near` skips a segment whose box is farther than the
  nearest found, no `mod` of an index in range; `Land.make` by
  squares of samples searched in rings.

Arm, mini-5i, -O3 (the other session's division of de5c01b3 in too):

| | this morning | M4 | now |
|---|---|---|---|
| a frame (3 to 23) | 201.1 million | 111.0 | **63.5** |
| the start to frame 3 | 7,872 | 5,327 | **2,909** |

Still 5 to 6 times the frame's budget. What is next, by the profile:
the faces' cost in `face` and `fill` (each a few thousand
instructions), the land's tiles and the trees as far as 1,300 m (a
nearer far plane with fog, decision 9's processor later), and the
start's `Land` and meshes.

2026-10-26, last: a frame profiled (arm, frames 3 to 13): `fill` 26%,
`face` 20%, ceil's call 22% (`first`'s, 85,600 a frame), `span` 10%,
`draw` 8%. mini-ml's floor and ceil now without a call, and a loop's
float constants unboxed once (`plan_ml_floats.md`): **53.3 million a
frame** (63.5). Left: `fill` and `face`, a few thousand instructions
a face; the far plane (1,300 m of land and trees) the author's to
choose.

**Fog at 600 m, tried and not kept** (the author: "let's try fog at
600 m, then the race"; then, with the numbers, "drop it, start the
race"). Seven levels of fog from 200 m to 600 m, a face by its nearest
corner, one past 600 m not drawn, the land's tiles within 782 m, the
sky ending at 650 m over a background of the fog's colour; each mesh's
shades at each level (`Mesh.light_fogged`), the palette's median cut
over the fogged colours too (then 192 entries for the clear ones and
64 for the fogged: in one cut the sky's blue went to the fogged
greens). Arm, mini-5i: a frame **52.75 million against 53.3** (6,485
faces to 5,841, the far ones small and cheap, and each face paying its
nearest corner and level), the start to frame 3 **6.7 billion against
2.85** (seven copies of every colour counted and lit); Big Forest's
mountains gone, the golden's mean difference 14.0 (6.7 without). The
frame's cost is in the faces near the road (`fill`, `face`), not in
the distance. The code discarded; this note keeps the measure.

**Stage 3, its first part (3a): the race on Big Forest** (the author:
"then the race"). `race/`: `Topdown` (the playground's kit's car,
`drive`, `bounce`, `push`; not its waypoint track), `Driving` (the
player's car on the road: the wheel a little at a time, the grass, the
rail, the spins), `Rivals` (on the road, by lane, slower before a
corner, passing; bumped as discs), `Race` (the countdown, the clock and
its checkpoints, the laps, the goal, the car steering itself to a stop
after it; the sounds as events, for stage 4). `Virtua`: the camera
following the car (a wider angle at speed, the shake off the road and
at the rail), the braking car's lights, `stats` saying the race (its
time, clock, the car's distance, speed, place, lap). Found on the way:
the Ferris wheel's rim, spokes and legs, one face thick, culled from
behind since the cull (`Mesh.two_sided` now; the playground's comment
names them, my comparison had looked from the grid only).
- Checked: `frames.sh`'s sessions (the three again: the palette counts
  the braking car's colours; a new one, `race`, 900 frames of the
  throttle); by mini-ml the same bytes, and a race of 2,400 frames
  (throttle and two turns) the same frame by frame in `stats` by OCaml
  and by mini-ml (the floats of the car the same, no fused product
  between them here); culling on and off along it, 4 pixels apart in
  one of 14 frames.
- Not yet: the race's screens and the scenes (3b), Bay Bridge and
  Acropolis (3c), the comparison with the playground's race (by its
  display, at 3b; a rival's speed has a part by our hash, so near, not
  the same).

**Stage 3, its second part (3b): the screens.** `race/Screens` (the
playground's `time_text`, `minimap`, `tachometer`, `hud_race` and its
scenes' texts); `Virtua`'s scenes by `Scene2d` (the title, a camera
round the player's car on the grid; the course select, the course's
miniature on a table, `Course.miniature`, the land of `Land.tiles`
with its stride again; the race; its end), a course built when first
needed with its palette (`course=n` to race at once: the sessions).
The texts placed for a screen 1000 high, drawn on one and scaled to
the window (at 640 by 480 the title's were off it).
- Against the playground's golden frames, by its own sessions
  (`-fixed-time 1000`, `seed=1`; `tests/compare.sh title|grid`): the
  title a mean difference of **5.1**, the grid (its display, the
  countdown's 2) **5.2** (stage 1's grid, without the display: 6.7).
  The select's golden is Bay Bridge (3c); the curve's is on TinyOutRun's
  coast (decision 7: left out).
- `frames.sh`: seven sessions (the four with `course=0`; title,
  golden_grid, select as the goldens' sessions), the same bytes by
  mini-ml.

**Stage 3, its third part (3c): Bay Bridge and Acropolis** (the
author: "let's do it"). `Course.bay_bridge` (the suspension bridge,
`Course.bridge`: towers, cables and hangers; piers under it and under
the overpass; the tunnel's portals; palms, a lighthouse, two
windmills turning) and `Course.acropolis` (the dry land, `Land.dry`;
the temple, twelve houses, cypresses and rocks, three sailboats on its
sea), from the playground's; `Scenery`'s `column`, `roof`, `palm`,
`cypress`, `rock`, `windmill`, `sailboat`, `lighthouse`, `temple`,
`house`. One face thick, so seen from both sides (`Mesh.two_sided`):
the palms' fronds, the sail, the bridge's cables and hangers. The
course select goes round the three, each built when first shown.
- The select's golden (Bay Bridge): a mean difference of **6.8**
  (`compare.sh select`); the title 5.1, the grid 5.2 as before.
- `frames.sh`: `select` by the golden's keys, `race_bay` and
  `race_acropolis` new (900 frames of throttle); by mini-ml the same
  bytes but one pixel of `select`, a level of blue apart in the
  platform's meter's text (a second sum, `RECORD=2`).
- A course built in 0.2 s by OCaml here, each of the three: on the Pi
  2, a few seconds the first time it is selected (Big Forest's start
  was 2.85 billion instructions on arm).
- Not checked by a picture: the bridge and the tunnel from the road
  (the scripted car does not reach them); culling on and off on both
  miniatures, no pixel apart. The curve's golden (on the coast) is
  left out with the coast.

Stage 3 done but the coast. Next: stage 4, the sound.

**Stage 4 done: the sound** (the author: "let's do it"). `race/Sound`:
the playground's V12 (two voices through seven gears, a tunnel's
room), the road (the grass, the tyres' squeal, the wind), and the
race's events played (the countdown's beeps, GO, a gear up, a crash,
the checkpoints' three jingles in turn, the final lap, the fanfare,
game over), the course select's pick; `Virtua.update` plays them in
the playground's order within a frame (a gear and a crash, the engine
and the road, the rest), the engine revving with the pedal during the
countdown. The game's mkfile links the playground's apis (Audio) and
what they stand on, as mini-quake's.
- Checked by `games/tests/audio.sh`, two sessions: `countdown` (300
  frames from the title) and `start` (370 frames, the clock held, the
  throttle from frame 100: GO and the climb through the gears), the
  **same bytes as the playground's own `-dump-audio`**
  (`games/racing/software/TinyVirtuaRacing.exe`, which `audio.sh` now
  finds in the playground's software folder), by OCaml's build and by
  mini-ml's. Past 6.3 s the two races part (a rival's speed, a part of
  it by our hash: a bump at another frame), so no longer session is
  compared with the playground's; without the clock held, the engine's
  revving at the countdown follows each platform's clock.
- Not heard: the sound played through a speaker, here or on the board.

Next: stage 5, on mini-9pi (QEMU, then the Pi 2), its frame measured
there.
