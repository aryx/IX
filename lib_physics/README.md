# lib_physics: a physics engine in two dimensions

The author's playground's (`~/playground`, its `libs/physics/2d`), the
part a first game asked (TinyCameltry, `games/arcade/`): bodies
(`Body`), their shapes (`Shape`), the forces on them (`Force`), a step
of time (`Integrate`), what may touch what (`Broadphase`), what does
(`Collide`, `Contact`), what happens then (`Resolve`), all of it each
frame (`Solver`), and joints (`Joint2d`). Over
`lib_graphics/software`'s `Vec2` only. A program calls it through
`lib_playground/apis`'s `Physics`. The plan:
[`plan_playground.md`](../docs/plans/plan_playground.md).

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_physics`'s, against
the playground at `028d8abf` (2026-10-06).

## What was copied

10 modules of its 15 in two dimensions: 20 files, 1,654 lines there and
1,682 here.

## What changed

Optional arguments are said, mini-ml having none: `Body`,
`Broadphase`, `Joint2d`, `Resolve`, `Shape`, `Solver`. 66 lines are not
the playground's, the 20 header lines among them. `Collide`, `Contact`,
`Force` and `Integrate` are the playground's but for their header.

## What remains in the playground

88 files of `libs/physics`:

- `2d/`: `Energy`, `Kepler`, `Planets` (orbits), `Particles`, `Springs`.
- `3d/`: the same engine in three dimensions (`Body3d`, `Collide3d`,
  `Solver3d`, `Quat`, `Mat3`...), 28 files.
- Its tests (50 files, 3,263 lines).
