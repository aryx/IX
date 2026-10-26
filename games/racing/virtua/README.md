# games/racing/virtua: mini-virtuaracing

Virtua Racing (Sega AM2, 1992) by a renderer of its own: the scene's
flat faces kept in arrays, culled by pieces, turned, cut by the near
plane, projected, filled by spans with a depth for each pixel, a byte a
pixel and a palette for each course. The plan, its survey and its
stages: [`plan_virtuaracing.md`](../../../docs/plans/plan_virtuaracing.md).

Stage 1 is here: Big Forest still, its road, land and landmarks, the
sixteen cars on the grid, the four views (`v`). No race yet.

    dune build ./games/racing/virtua/Virtua.exe
    ./_build/default/games/racing/virtua/Virtua.exe -dump-frame 3 grid.ppm view=behind
    (cd games/racing/virtua && mini-mk)      # by ix's tools, after mini-mk libs at the top

The folders (`dune` says which module is where):

| folder | what |
|---|---|
| `render/` | `Mesh` (the playground's shape functions, made arrays once), `Palette` (median cut), `Render` (cull, turn, cut, project, spans) |
| `course/` | `Track3d` (the road a ribbon), `Heightmap`, `Land`, `Scenery`, `Course` (Big Forest) |
| `race/` | `Cars` (the car's model, the grid) |
| `tests/` | `compare.sh`: the grid against the playground's golden frame |

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
  grid (`race/Cars.ml`), its views (`Virtua.ml`).
- `lib_graphics/geometry/`'s `Vec3`, `Camera`, `Lighting`:
  `libs/graphics/3d/geometry` (`../../../lib_graphics/software/README.md`).

### What changed

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

The race (`Topdown`, the rivals, the clock, the laps, the screens of
`Scene2d`, the sound), the other courses, the course select's
miniature, TinyOutRun's coast (`Road`): stages 3 and 4 of the plan.
`Mat4`, `Material`, `Ray` of `libs/graphics/3d/geometry` (the GPU's and
the ray tracer's), and Playground3d and its rasterizer, which this game
does not draw with.
