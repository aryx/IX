# games: the author's playground's games

Six of the games of the author's playground (`~/playground`, its
`games/`), on its library (`lib_playground/`), in its folders:

| here | what |
|---|---|
| `puzzle/Tetris.ml` | Tetris (`4s` on mini-9pi) |
| `fps/TinyWolfenstein.ml` | a walk in a maze, seen from inside, in the 2D playground |
| `fps/doom/` | mini-doom: Doom's renderer and data, a walk through a WAD's level (Freedoom's E1M1), textured; ix's own, not the playground's ([`plan_doom.md`](../docs/plans/done/plan_doom.md); `doom` on mini-9pi) |
| `fps/quake/` | mini-quake: Quake's software renderer (the PVS, the edge list, the surface cache) and its lightmaps, baked by a `light` of ours, a walk through a `.bsp` (LibreQuake's lq_e0m1) ([`plan_quake.md`](../docs/plans/done/plan_quake.md); `quake` on mini-9pi) |
| `arcade/TinyCameltry.ml` | the maze turns, the ball rolls: on `lib_physics/` |
| `arcade/TinyBreakout.ml` | Breakout, with its sounds and its juice: on `lib_juice/` (`breakout` on mini-9pi; `juice=off` is the dry game) |
| `arcade/TinyTronscroll.ml` | light cycles on a map bigger than the screen, for two: on one keyboard, or on two computers over UDP, on `lib_networking/netcode/` (`tronscroll` on mini-9pi; the author's own network game of 1997) |
| `shmup/TinyMissileCommand.ml` | missiles on six cities, three bases to answer; with its sounds (`missilecommand` on mini-9pi) |
| `shmup/kit/Shots` | its `gamekits/shmup`: what shooters share, a shot as a value that moves |

On Linux a game is built by dune with the platform that writes a frame
to a file (`tests/frames.sh`); on mini-9pi, by `mkgames`, with the one
that computes its pixels or the one that asks the draw device, in a
window of mini-rio's or on the bare screen. Tetris,
TinyMissileCommand and TinyBreakout have their sound (`lib_playground`'s `Audio`, over
`lib_audio/`): to `/dev/audio` on mini-9pi, and on Linux in a window
with SDL (`dune exec games/puzzle/sdl/Tetris.exe`,
`games/shmup/sdl/TinyMissileCommand.exe`). The plans:
[`plan_playground.md`](../docs/plans/done/plan_playground.md),
[`plan_playground_speed.md`](../docs/plans/plan_playground_speed.md),
[`plan_audio.md`](../docs/plans/done/plan_audio.md).

Each game says at its top where it comes from and what changed
(`ix: the author's playground's <path>. What changed: ...`). The lists
and the numbers below are `scripts/playground_copies.sh games`'s,
against the playground at `514f259c` (2026-10-13).

## What was copied

8 files, 2,569 lines there and 2,588 here. A game's text is the
playground's: what it leaves unused stays.

## What changed

- All six: the last line is ix's, `Playground_platform.run_app` given
  the flags and the capabilities (`lib_playground`'s
  `Playground_platform.mli` says why).
- `Tetris`: two
  spellings mini-ml has not, the only ones of their kind in the
  playground's games (`+ 1`, and `let rec (stamp : ...) =`).
- `TinyWolfenstein`: an `Option.value ~default` is written out.
- `TinyBreakout`: its assistant is not here (the `a` key: a network
  that learned the game from the screen, on the playground's `Dqn` and
  a file of weights, which ix has not), 118 of its lines, with the
  line of the title that offered it; its keys are printed at its
  start, as TinyCameltry's.
- `TinyTronscroll`: a direction and its two functions are in the game
  (the playground's are its lightcycles kit's, TinyTron's, whose
  rules, arenas and computer players are not in ix); `Multiplayer`'s
  optional arguments are said; `map=` is read without `Scanf`; its
  keys and its network's flags are printed at its start.
- `TinyCameltry`, `TinyMissileCommand`, `Shots`: nothing else.

## What is ix's own

- `mkfile`, `mkgames`, each folder's `mkfile`: the games built by
  mini-mk for mini-9pi (`arcade/`'s links TinyBreakout apart: a program
  linked with the sound has one, and TinyCameltry has none; and
  TinyTronscroll, with the netcode: `WITH=multiplayer`).
- `tests/frames.sh`, `frames.expected`: each game run some frames by a
  script of keys, its last frame's sum.
- `tests/audio.sh`, `audio.expected`: the same sessions' sound
  (`-dump-audio`), the WAV's sum, and byte for byte against the
  playground's own `-dump-audio` where it is built.
- `tests/network.sh`: TinyTronscroll played by two programs on this
  machine over UDP, one that hosts and one that joins, with each
  netcode: both reach their ticks and their checksums agree (the ppm
  platform's `pace=`, `Multiplayer`'s `ticks=on`). And on mini-9pi,
  `make -C kernels/9pi check-tron`: the game in a guest against this
  machine's, each way, and two guests against each other.
- `puzzle/sdl/`, `shmup/sdl/`, `arcade/sdl/`: the two games with sound,
  and TinyTronscroll, in a window on Linux (dune's alone).
- `survey.sh`, `survey3d.sh`, `speed.sh`: the numbers behind the plans
  (what of the playground a game stands on, what mini-ml refuses of
  it, what a frame costs).

## Two boards, one cable

TinyTronscroll on two Raspberry Pis that run mini-9pi, an Ethernet
cable from one to the other (no switch: either end crosses the pairs).
Each board has its address by itself (`kernels/9pi/conf/boot.rc`:
192.168.9.1 a Pi 1, 192.168.9.2 a Pi 2, or the card's `ip.txt`), said
at its boot (`ip: ...`). A flag is quoted for rc, which reads `=`:

    tronscroll 'net=host'                       on the Pi 1
    tronscroll 'net=join' 'host=192.168.9.1'    on the Pi 2

Each plays with its arrows and space; space on either starts the
round. `'netcode=rollback'` and `'netcode=1997'` on both for the other
two netcodes. The line at the bottom says who is there and whether the
two games agree. **Not run on a board yet**: the boards' Ethernet
(SMSC's LAN9512 and LAN9514, mini-9pi's `Etherusb`) was written from
principia's driver and has met no board; under QEMU the adapter is
another (CDC Ethernet), and that is what `check-tron` plays over.

## What remains in the playground

162 files, 70,025 lines: the other games of `arcade/` (17), `fps/`
(12), `puzzle/` (23) and `shmup/`, the folders `adventure`, `cards`,
`fighting`, `flight`, `platform`, `programming`, `racing`, `rhythm`,
`rpg`, `sports`, `strategy`, and the shooters' kit's `Path`. Most ask
what `lib_playground` has not yet: pictures, 3D
([`plan_gpu.md`](../docs/plans/plan_gpu.md); TinyVirtuaRacing as
mini-virtuaracing,
[`plan_virtuaracing.md`](../docs/plans/plan_virtuaracing.md)).
