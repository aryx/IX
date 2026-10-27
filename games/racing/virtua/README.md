# games/racing/virtua: mini-virtuaracing

Virtua Racing (Sega AM2, 1992) by a renderer of its own: the scene's
flat faces kept in arrays, culled by pieces, turned, cut by the near
plane, projected, filled by spans with a depth for each pixel, a byte a
pixel and a palette for each course. The plan, its survey and its
stages: [`plan_virtuaracing.md`](../../../docs/plans/plan_virtuaracing.md).

Stages 1 to 3 are here: the arcade's three courses (Big Forest, Bay
Bridge and its suspension bridge, Acropolis), their roads, land and
landmarks, and the race: the countdown, the player's car by the
arrows, the fifteen rivals, the clock and its checkpoints, the laps,
the goal; the four views (`v`); the race's display, the title, the
course select (the course's miniature), the end's screen; and the
sound (stage 4): the engine through its gears, the tyres, the wind,
the countdown, the checkpoints' jingles, the fanfare.

    make && ./bin/mini-virtuaracing          # in a window (SDL; scale=, view=, course=0)
    dune build ./games/racing/virtua/Virtua.exe
    ./_build/default/games/racing/virtua/Virtua.exe -dump-frame 3 grid.ppm view=behind
    ./_build/default/games/racing/virtua/Virtua.exe -dump-frame 900 race.ppm -script up:1-900 stats
    (cd games/racing/virtua && mini-mk)      # by ix's tools, after mini-mk libs at the top

The folders (`dune` says which module is where):

| folder | what |
|---|---|
| `render/` | `Mesh` (the playground's shape functions, made arrays once), `Palette` (median cut), `Render` (cull, turn, cut, project, spans) |
| `course/` | `Track3d` (the road a ribbon), `Heightmap`, `Land`, `Scenery`, `Course` (the three courses) |
| `race/` | `Cars` (the car's model, the grid), `Topdown` (a car on a plane), `Driving` (the player's car on the road), `Rivals`, `Race` (the countdown, the clock, the laps), `Screens` (the race's display, the scenes' texts), `Sound` |
| `tests/` | `compare.sh`: the title, the grid and the course select against the playground's golden frames; `perf.sh`: a race frame's instructions on arm (Speed, below) |
| `sdl/` | `Virtua.ml` linked with the platform that has a window (dune's alone: `bin/mini-virtuaracing`) |

Its frames are checked by `games/tests/frames.sh` (the sessions
`racing/virtua/Virtua|...`), the same sums by OCaml's build and mini-ml's;
its sound by `games/tests/audio.sh`, the same bytes as the playground's
own `-dump-audio` (the countdown, and the start to 6 seconds: after,
the rivals, whose speeds have a part by our hash, part the races).

## The arcade's hardware, and the Pi 2

How did a 1992 game run smoothly on machines far less powerful than a
Pi 2 (the author's question)? The arcade did not draw it with its
processor either. Sega's Model 1 was a board of chips, each made for
its part:

- **the game**: its processor, an NEC V60 at about 16 MHz, ran the
  cars, the race, the rules, and nothing of the picture;
- **the geometry**: Fujitsu's geometry processors (the TGP, a DSP:
  floats fast) turned, lit, cut and projected the vertices;
- **the pixels**: Sega's own drawing chips filled the polygons and hid
  the hidden ones (`render/Render.mli`'s cs-history).

It is usually quoted at about 180,000 polygons a second, a few
thousand a frame. The Mega Drive's version (1994) needed a chip in its
cartridge, Sega's SVP (a DSP of Samsung's), and still drew fewer
polygons, smaller and slower. (These numbers as they are usually told,
from memory, not checked against a source here.)

mini-virtuaracing on the Pi 2 does all three parts on one of its four
cores (a Cortex-A7 at 900 MHz, about 280 million instructions a second
under mini-9pi):

| the arcade's part | Model 1 | here |
|---|---|---|
| the game | the V60 | the program (`race/`), about 10M instructions a frame |
| the geometry | the TGP | `Render`'s front (`draw`, `faces`, `face`), about 10M |
| the pixels | Sega's drawing chips | `Render`'s back (`fill`, `span`), about 14M; the Pi 2's own 3D processor unused |

and by mini-ml's code (a teaching compiler: floats in blocks, calls by
closures, the bounds tested), on a scene made for a PC (the
playground's: 7,000 faces a frame, the land and the trees to 1,300 m,
where the arcade's designers counted each polygon). So the Pi 2 is not
too slow for the game: the part of it made for this, its VideoCore IV's
3D processor, far more than Model 1's drawing chips, is not used yet.
That is [`plan_gpu.md`](../../../docs/plans/plan_gpu.md)'s way (its
"2026-10-27" section): the arcade's own division, the processor for the
game and the geometry, the 3D processor for the pixels (`render=gpu`,
beside the software's three ways).

## Speed

The game is made for the Pi 2 (mini-9pi): about 280 million arm
instructions a second there (6 frames of 46M in the race), so 60 frames
a second would be 4.7 million a frame, and 20 frames 14 million. The
optimizations so far, each with its number, in the order they were made.
A frame's numbers are arm instructions by mini-5i, at -O3; the same
pictures before and after unless the line says otherwise. The measures
and their history are in
[`plan_virtuaracing.md`](../../../docs/plans/plan_virtuaracing.md)'s
Status. Each one can be read or turned off as the last column says
(`old:` comments in the code give the code before).

The grid's frame (frames 3 to 23, the camera turning around the car),
2026-10-26:

| what | where | a frame | off |
|---|---|---|---|
| the start: a frame by the first renderer | | 201.1M | |
| corners, normals and rows in `Float.Array`s, mini-ml's floats in registers | `Mesh`, `Render`; mini-ml (`plan_ml_floats.md`) | 111.0M | `old:` |
| the faces turned away not drawn: 6,485 faces of 10,738 | `Render.cull` | | `cull=off` |
| `Float.min` and `Float.max` without their `Int64` | lib_core's `Float` | | |
| the start's two searches (`Track3d.locate_near`, `Land.make`): the start to frame 3 5.3 billion to 2.9 | `Track3d`, `Land` | | `old:` |
| (the three above together) | | 63.5M | |
| mini-ml's `floor` and `ceil` without a call | mini-ml | 53.3M | |
| fog at 600 m: tried, not kept (the hills cut) | | | |

The race (frames 250 to 270 of `course=0`, the throttle held,
`sound=off`; `tests/perf.sh`), 2026-10-27, both by mini-ml at
afcb6f03:

| what | where | a frame | off |
|---|---|---|---|
| before | | 49.0M | |
| a face's rows found first, a face with none (a third of them) left before its plane; the ints' `min` and `max` inlined, not Stdlib's polymorphic calls; no float ref (a block each) | `Render.fill`, OPTIMIZATION (setup) | -6.5% (46.7M to 43.6M by the mini-ml before) | `old:` |
| the corner and row arrays read without their bounds' test, `fill`'s taken from the record once (8 instructions a read, then 1 or 2) | `Render.get`, OPTIMIZATION (get) | | `old:` |
| (the two together) | | **37.0M** (-24.5%) | |
| far chunks (more than 150 m away) drawn with their pines a cone each, 5 faces where a pine has 17 (a level of detail): 6,818 faces a frame to 5,546, 476 pixels apart at frame 250; the trees' places found once for the two meshes; the start 2.31 billion to 2.60 (Bay Bridge's, without far trees, 1.82 to 1.84) | `Course.lod`, `Scenery.pine_far` | **33.9M** (-8.3%) | `lod=off` |
| the painter's algorithm instead of the depth, to compare: the faces kept, sorted by their mean distance in whole centimetres (the same order by OCaml and mini-ml), drawn from the farthest with no depth to test or clear; its errors where long faces meet (12,182 pixels apart at frame 250: a kerb under its verge) | `Render.algorithm`, `finish` | 41.4M (+22% against 34.0M by the same build): the sort about 6M (`Array.stable_sort`, a million comparisons), the faces kept 2.2M; the depth's `span` 6.3M became a `Bytes.fill` 1.6M | `render=painter` |
| the painter's faces by an ordering table, the PlayStation's: 4,096 slots of 64 cm (a face's distance shifted, as the PS1 shifted its z), a face put at the head of its slot's list, the slots walked from the farthest; no sort; the faces of a slot drawn in the order opposite to their coming (the road's line under its tarmac: 11,544 pixels apart from the depth's at frame 250) | `Render.Table`, `finish` | **33.1M** (-2.6% against the depth's 34.0M; by `/ 50`, a call on arm, 33.7M) | `render=table` |

What is left in a race frame (37.0M before the level of detail):
`fill_rows` 21%, `face` 20%, `span` (the pixels) 17%, `draw` 8%. About
7,000 faces a frame, most a row or two: a face costs more than its
pixels. Two-thirds of them were the five road chunks ahead, each drawn
whole (about 830 faces, near or far): hence the far chunks' pines.

The sound, a sixtieth of a second of the race's (the loop makes the
sound of the time a frame took, so it costs the same each second
whatever the frames):

| what | where | instructions | off |
|---|---|---|---|
| before | | 3.2M | `sound=off` (`Sound.on`) |
| mixed in `Float.Array`s, a continuous voice without a block a sample, the filter's memory flat | lib_audio's `Mixer`, `Synth`, `Filter` | 1.8M | `Mixer.flat := false` |
| libc's `exp` without its calls of `floor` and `ldexp` (`tanh`'s two calls a sample) | `lib_core/libc/port/exp.c` | 1.6M | `old:` |

On the Pi 2 (the author): 11 frames a second at the title, 3 in the
race with the sound, 6 without (`sound=off`), 9 while the camera
turns around the car (2026-10-26, before the race's -24.5%).

## From the author's playground

Each copied file says where it comes from in its `ix:` line. The
numbers are `scripts/playground_copies.sh games/racing/virtua`'s
(2026-10-25).

### What was copied

- `course/Track3d.ml(i)`: `gamekits/racing/3d/Track3d` (254 lines
  there, 224 here).
- `course/Heightmap.ml(i)`: `gamekits/heightmap/Heightmap`, what the
  land asks of it (143 lines there, 99 here).
- From `games/racing/TinyVirtuaRacing.ml` (1,665 lines): its shapes,
  its three courses and their scenery and landmarks, the land, the
  road's segments and chunks, the sky (`course/Scenery.ml`, `Land.ml`,
  `Course.ml`), its car and
  grid (`race/Cars.ml`), its views (`Virtua.ml`), its car, rivals and
  race (`race/Driving.ml`, `Rivals.ml`, `Race.ml`).
- `race/Topdown.ml(i)`: `gamekits/racing/Topdown`, its car, `drive`,
  `bounce` and `push` (not its waypoint track: the rivals drive on the
  road).
- `lib_graphics/geometry/`'s `Vec3`, `Camera`, `Lighting`:
  `libs/graphics/3d/geometry` (`../../../lib_graphics/software/README.md`).

### What changed

- The race's sounds are events (`Race.event`), played by `Sound`
  (the playground's, in its order within a frame); its scenes (title,
  select, goal) are the game's. A rival's
  top speed has a part by `Scenery.jitter`, not `Hashtbl.hash`: a race
  is not the playground's to the hundredth.
- The player's car is not drawn from its cockpit (the playground draws
  it without its shadow, which is part of our car's mesh).
- The texts over the picture are the playground's, placed for a screen
  1000 high: drawn on one, then scaled to the window. The course
  select's miniature (its land a quad of two cells) is made when asked
  for, and its colours, not counted in the palette, are the nearest.
- A course is built when it is first needed (the title's, the one
  raced), its palette with it; `course=n` races on it at once.
- A shape is a list of faces made into a mesh at the course's start
  (`Mesh`), not the playground's `shape3d` made triangles at each
  frame; `Track3d.strip` and `wall` give them. Its corners and normals,
  and `Render`'s corners and rows, are `Float.Array`s: each float in
  the array, not a block of its own (docs/plans/plan_ml_floats.md).
- Faster at the start, the same answers: `Track3d.locate_near` skips
  a segment whose box is farther than the nearest found, and takes no
  `mod` of an index already in range; `Land.make` finds a point's
  nearest road sample by squares of samples, not all of them.
- Faces turned away from the eye are not drawn (`Render.cull`); the
  playground's game draws them all. `Track3d.wall` is seen from both
  sides (`Mesh.two_sided`).
- No optional arguments (mini-ml has none): `Track3d.control`'s
  `~y ~width ~bank` said, `build`'s step, `locate` and `locate_near`;
  `Scenery.cone`'s seed and snow; `Camera.basis`'s `up`.
- The scenery's and the land's hash is `Heightmap.random`, not OCaml's
  `Hashtbl.hash` (whose numbers mini-ml's runtime does not give): the
  trees and the facets' colours are not where the playground has them.
- `Track3d.of_road` and the coast left out (stage 3 and after); Bay
  Bridge and Acropolis too, and their landmarks.
- `Float.infinity` is `infinity`, `Stdlib.max` `Float.max`
  (`lib_core`'s Float, mini-ml's Pervasives).

### What is ix's own

`render/` (`Mesh`, `Palette`, `Render`), the interfaces of `course/`
and `race/`, `Virtua.ml`'s program, `tests/compare.sh`, `dune`,
`mkfile`.

### What remains there

TinyOutRun's coast (`Road`; decision 7), its `tree`, `mesa` and
`flat`.
`Topdown`'s waypoint track and its computer driver.
`Mat4`, `Material`, `Ray` of `libs/graphics/3d/geometry` (the GPU's and
the ray tracer's), and Playground3d and its rasterizer, which this game
does not draw with.
