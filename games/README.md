# games: the author's playground's games

Three of the games of the author's playground (`~/playground`, its
`games/`), on its library (`lib_playground/`), in its folders:

| here | what |
|---|---|
| `puzzle/Tetris.ml` | Tetris (`4s` on mini-9pi) |
| `fps/TinyWolfenstein.ml` | a walk in a maze, seen from inside, in the 2D playground |
| `arcade/TinyCameltry.ml` | the maze turns, the ball rolls: on `lib_physics/` |

On Linux a game is built by dune with the platform that writes a frame
to a file (`tests/frames.sh`); on mini-9pi, by `mkgames`, with the one
that computes its pixels or the one that asks the draw device, in a
window of mini-rio's or on the bare screen. The plans:
[`plan_playground.md`](../docs/plans/plan_playground.md),
[`plan_playground_speed.md`](../docs/plans/plan_playground_speed.md).

Each game says at its top where it comes from and what changed
(`ix: the author's playground's <path>. What changed: ...`). The lists
and the numbers below are `scripts/playground_copies.sh games`'s,
against the playground at `028d8abf` (2026-10-06).

## What was copied

3 files, 1,107 lines there and 1,075 here. A game's text is the
playground's: what it leaves unused stays.

## What changed

- All three: the last line is ix's, `Playground_platform.run_app` given
  the flags and the capabilities (`lib_playground`'s
  `Playground_platform.mli` says why).
- `Tetris`: its sound is not here yet (its section "Sound", the four
  sounds played and the theme's loop, the model's music, the flag
  `music=off`: [`plan_audio.md`](../docs/plans/plan_audio.md)); and two
  spellings mini-ml has not, the only ones of their kind in the
  playground's games (`+ 1`, and `let rec (stamp : ...) =`).
- `TinyWolfenstein`: an `Option.value ~default` is written out.
- `TinyCameltry`: nothing else.

## What is ix's own

- `mkfile`, `mkgames`, each folder's `mkfile`: the games built by
  mini-mk for mini-9pi.
- `tests/frames.sh`, `frames.expected`: each game run some frames by a
  script of keys, its last frame's sum.
- `survey.sh`, `survey3d.sh`, `speed.sh`: the numbers behind the plans
  (what of the playground a game stands on, what mini-ml refuses of
  it, what a frame costs).

## What remains in the playground

154 files, 69,400 lines: the other games of `arcade/` (17), `fps/`
(12) and `puzzle/` (23), and the folders `adventure`, `cards`,
`fighting`, `flight`, `platform`, `programming`, `racing`, `rhythm`,
`rpg`, `shmup`, `sports`, `strategy`. Most ask what `lib_playground`
has not yet: pictures, sound, 3D
([`plan_gpu.md`](../docs/plans/plan_gpu.md): TinyVirtuaRacing).
