# lib_playground/juice: a game's feel

The author's playground's (`~/playground`, its `libs/juice`): what
makes a game feel alive beyond what it does, "juice" (Martin Jonasson
and Petri Purho, "Juice it or lose it", GDC Europe 2012), one idea a
module, each `.mli` with its diagram, its worked example and its
references:

| module | what |
|---|---|
| `Ease` | the curves: how a thing gets from here to there |
| `Tween` | a value as a function of when it started |
| `Squash` | squash and stretch, the area kept |
| `Trauma` | a screen's shake, from a hit that fades |
| `Emitter` | particles: a burst from a recipe |
| `Follow` | a spring that chases a target |
| `Hash` | the random numbers they share, the same at each run |

Pure OCaml, over nothing, a library of its own (`ix_juice`; old: the
top's `lib_juice/`, moved here, its only user the playground). A
program calls it through `apis/`'s `Juice`; the first is TinyBreakout
(`games/arcade/`): its bricks pop in, the ball and the paddle squash,
a broken brick bursts into pieces, the screen shakes, and `juice=off`
is the game without any of it.

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_playground/juice`'s,
against the playground at `33f4e668` (2026-10-12).

## What was copied

Its 7 modules: 14 files, 768 lines there and 768 here.

## What changed

- Optional arguments are said, mini-ml having none: `Emitter` (a
  cap of 400 particles), `Follow` (a frequency of 2, a damping of 1),
  `Trauma` (1 a second; smooth, 40 pixels, 5 degrees).
- `Hash` computes on floats and an `Int32` where the playground's
  computes on ints: its numbers go up to 2^31 - 2, and an int of the
  Pi 1's, under mini-ml, has 31 bits, its sign among them (as
  `lib_playground`'s `Lehmer`). The numbers are the same: `Hash.mli`'s
  worked example, and the frames of TinyBreakout, pixel for pixel
  against the playground's (`games/tests/frames.sh`).
- `Ease`, `Squash`, `Tween`: the playground's but for their header.

## What remains in the playground

Its tests: 16 files, 352 lines (`libs/juice/tests`). And over it,
`Juice3d` (`playground/apis`), the same effects for a scene in three
dimensions.
