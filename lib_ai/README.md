# lib_ai: the author's playground's game AI, its ways through a map

Game AI written to be taught, one idea a module, each `.mli` with its
diagram, its worked example and its references, from the author's
playground (`~/playground`,
[ocaml-elm-playground](https://github.com/aryx/ocaml-elm-playground)):
of its `libs/ai`, what mini-doom's monsters ask, through the
playground's `Ai` (`lib_playground/apis/Ai.mli`): a way to the player,
one flow field for all of them (`Ai.flow`, `Ai.next_step`). Pure OCaml;
nothing here knows the playground, a screen or a device.

Copied is what mini-doom needs, a whole module where the part needed is
most of it (the author, 2026-10-23: "we don't have to copy all of the
code from the ~/playground; for now we can just copy what we think we
need", "unless copying the whole module or lib does not add much more
code, in that case it's simple to copy the whole thing").

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_ai`'s, against the
playground at `a6fd655f` (2026-10-23).

## What was copied

- `movement/Pathfind` (235 lines there, 232 here): breadth-first,
  Dijkstra and A*, the same search with a different queue, and the
  flow field, a search from the goal outward.
- In `lib_playground/apis/`, `Ai`'s ways through a map (`way`,
  `way_over`, `flow`, `next_step`, `steps_to_go`), and its bots'
  `aim_error`, with the wobble it stands on from `bots/Bot.ml` (8
  lines of its 178): `Ai.mli` 70 lines here (292 there), `Ai.ml` 96
  (272).
- The tests (`tests/`, dune's only: Testo and Alcotest): `Pathfind`'s,
  and of the playground's `playground/tests/Unit_ai.ml` the ways' and
  `aim_error`'s.

The folders are the playground's (`movement/`), folders only: one
library, `ix_ai` for dune, `lib_ai` for mini-mk.

## What changed

- **Optional arguments are said** (mini-ml has none), `Ai.mli` saying
  the defaults: `way`, `way_over` and `flow`'s `diagonal` (false),
  `aim_error`'s `settle` (30). `tests/Unit_ai.ml` gives them back by a
  module at its top, its tests as they were.
- `Ai.ml`: each function annotated (mini-ml infers less than OCaml);
  `infinity`, the stdlib's, for `Float.infinity`; `aim_error` is
  `Bot.aim_error` itself, where it called it.
- Our own: `tests/mini_ml.sh`, `tests/mini_ml/Main.ml` (a flow field
  walked downhill, a way with corners, A*, Dijkstra and breadth-first,
  aim errors) compiled by mini-ml with `Pathfind` and `Ai` (and
  `mini_ml/Playground.ml`, the one type `Ai.mli` takes of the
  playground), run on arm64 and on arm (an int of 31 bits), its output
  OCaml's (`tests/mini_ml/Main.out`).

## What remains in the playground

| there | files | lines | what |
|---|---:|---:|---|
| `movement/` | 4 | 366 | `Steering` (seek, flee, arrive, wander, pursue, avoid, follow), `Flock` |
| `decision/` | 6 | 293 | `Fsm`, `Behavior`, `Utility` |
| `bots/` | 4 | 314 | `Sense`, `Bot` (its `aim_error` copied into `Ai`) |
| `search/` | 8 | 1,009 | `Minimax`, `Deepening`, `Zobrist`, `Mcts` |
| `learning/` | 22 | 2,972 | a neuron, backpropagation, autodiff, Q-learning, DQN |
| `language/` | 12 | 1,274 | makemore's names, a GPT |
| `selfplay/` | 8 | 997 | AlphaZero |
| `tests/` | 42 | 2,849 | theirs |

and of `playground/apis/`, `Ai`'s other families (steering, an
opponent, what a character is doing, a bot) and `Ai_debug`. A first
copy had `movement/`, `decision/`, `bots/` and `search/` (2,193 lines
and their tests), made to build by mini-ml too: taken out the same day,
no game of ix's asking them yet.

## Tests

    dune build ./lib_ai/tests/Test.exe && ./_build/default/lib_ai/tests/Test.exe
    lib_ai/tests/mini_ml.sh        # by mini-ml, on arm64 and on arm
