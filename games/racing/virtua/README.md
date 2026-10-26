# games/racing/virtua: mini-virtuaracing

Virtua Racing (Sega AM2, 1992) by a renderer of its own: the scene's
flat faces kept in arrays, culled by pieces, turned, cut by the near
plane, projected, filled by spans with a depth for each pixel, a byte a
pixel and a palette for each course. The plan, its survey and its
stages: [`plan_virtuaracing.md`](../../../docs/plans/plan_virtuaracing.md).

Stages 1 and 2 and stage 3's first two parts are here: Big Forest, its
road, land and landmarks, and its race: the countdown, the player's
car by the arrows, the fifteen rivals, the clock and its checkpoints,
the laps, the goal; the four views (`v`); the race's display, the
title, the course select (the course's miniature), the end's screen.
Not yet the other two courses, the sound.

    make && ./bin/mini-virtuaracing          # in a window (SDL; scale=, view=, course=0)
    dune build ./games/racing/virtua/Virtua.exe
    ./_build/default/games/racing/virtua/Virtua.exe -dump-frame 3 grid.ppm view=behind
    ./_build/default/games/racing/virtua/Virtua.exe -dump-frame 900 race.ppm -script up:1-900 stats
    (cd games/racing/virtua && mini-mk)      # by ix's tools, after mini-mk libs at the top

The folders (`dune` says which module is where):

| folder | what |
|---|---|
| `render/` | `Mesh` (the playground's shape functions, made arrays once), `Palette` (median cut), `Render` (cull, turn, cut, project, spans) |
| `course/` | `Track3d` (the road a ribbon), `Heightmap`, `Land`, `Scenery`, `Course` (Big Forest) |
| `race/` | `Cars` (the car's model, the grid), `Topdown` (a car on a plane), `Driving` (the player's car on the road), `Rivals`, `Race` (the countdown, the clock, the laps), `Screens` (the race's display, the scenes' texts) |
| `tests/` | `compare.sh`: the title and the grid against the playground's golden frames |
| `sdl/` | `Virtua.ml` linked with the platform that has a window (dune's alone: `bin/mini-virtuaracing`) |

Its frames are checked by `games/tests/frames.sh` (the sessions
`racing/virtua/Virtua|...`), the same sums by OCaml's build and mini-ml's.

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
  Big Forest and its scenery, the land, the road's segments and chunks,
  the sky (`course/Scenery.ml`, `Land.ml`, `Course.ml`), its car and
  grid (`race/Cars.ml`), its views (`Virtua.ml`), its car, rivals and
  race (`race/Driving.ml`, `Rivals.ml`, `Race.ml`).
- `race/Topdown.ml(i)`: `gamekits/racing/Topdown`, its car, `drive`,
  `bounce` and `push` (not its waypoint track: the rivals drive on the
  road).
- `lib_graphics/geometry/`'s `Vec3`, `Camera`, `Lighting`:
  `libs/graphics/3d/geometry` (`../../../lib_graphics/software/README.md`).

### What changed

- The race's sounds are events (`Race.event`), for stage 4 to play;
  its scenes (title, select, goal) are the game's, at 3b. A rival's
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

The sound, the other two courses, TinyOutRun's coast (`Road`):
stages 3 and 4 of the plan.
`Topdown`'s waypoint track and its computer driver.
`Mat4`, `Material`, `Ray` of `libs/graphics/3d/geometry` (the GPU's and
the ray tracer's), and Playground3d and its rasterizer, which this game
does not draw with.
