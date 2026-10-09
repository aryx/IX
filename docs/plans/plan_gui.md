# Plan: the playground's GUI toolkit and the 7GUIs in ix (`lib_gui/`, `examples/`)

The author, 2026-10-08, starting [`plan_scheme.md`](done/plan_scheme.md)'s
stage 3 (mini-drscheme, the playground's TinyDrScheme, which uses two modules of the playground's
`libs/gui`): "and maybe we can copy more of the playground gui? So we
can port the 7gui stuff to ix ? in a toplevel examples/ we could add
again?"

The [7GUIs](https://eugenkiss.github.io/7guis/) are seven small tasks
(Counter, Temperature Converter, Flight Booker, Timer, CRUD, Circle
Drawer, Cells) that a toolkit is judged by. The playground has them
over its own toolkit, written from scratch to teach how a program is
built around the person using it, and has five of them four ways
(immediate mode, retained widgets with callbacks, MVC, MVU).

## What was copied

The playground's file, where it is here, its lines (.ml and .mli).
`apps/survey.sh` holds each copy against the playground's.

| the playground's | here | lines |
|---|---|---:|
| `libs/gui`, its 12 modules: `Widget Theme Text Text_edit Focus Layout Grid Look Immediate Retained Mvc Mvu` | `lib_gui/` | 3,480 |
| `playground/apis/Gui` (the toolkit on the playground: a computer in, shapes out) | `lib_playground/apis/` | 369 |
| `playground/ways/Bigbang` (How to Design Programs' world) | `lib_playground/ways/` | 304 |
| `examples/Gui7Counter Gui7Temperature Gui7Flight Gui7Timer Gui7Crud Gui7Circles Gui7Cells`, `GuiFourWays`, `GuiWidgets`, `BigBangRocket`, `BigBangWorm` | `examples/` | 1,373 |
| `examples/gui4`: `Gui4` and five tasks four ways | `examples/gui4/` | 856 |
| its tests (Testo, dune's only) | `examples/gui4/tests/` | 231 |
| `languages/formula/Formula` (a sheet's formulas: Cells) | `languages/formula/` | 361 |
| `appkits/document/Undo` (Circles), `appkits/sheet/Sheet`, `appkits/sheet_view/Sheet_view` (Cells) | `apps/kits/` | 767 |

With `editors/drscheme/DrScheme.ml` (786,
[`plan_scheme.md`](done/plan_scheme.md)): 8,527 lines, 242 gained and 169
lost against the playground's.

Not copied: `GuiEditor` (it wants the playground's `appkits/editor`),
`Typing`, the other appkits.

## Decisions taken (for the author to undo)

1. **`lib_gui/` whole**, a library of its own for dune (`ix_gui`); it
   speaks `Color` only, so `lib_playground/core/` is a dune library too
   (`ix_playground_core`), as `random/` became for Pascal.
2. **`examples/`, top-level**, the playground's name; `examples/gui4/`
   under it as there.
3. **`apps/kits/`** for the playground's `appkits/` (three
   modules of its three folders, in one); **`languages/formula/`** as
   there.
4. **`Map_` in lib_core/commons**: `Sheet`'s cells were a `Map.Make`,
   the second after the Scheme machine's. `Scheme_map` (47 lines, an AVL
   tree compared by `compare`) moved there, as `Set_` is OCaml's `Set`
   without its functor, and gained `remove`. This undoes
   [`plan_scheme.md`](done/plan_scheme.md)'s decision 4 ("not in lib_core").
5. **The build is the games'**: `games/mkgames` takes `WITH=gui ways
   scheme formula kits gui4` beside `physics`; `editors/drscheme`
   and `examples` each have a mkfile of five lines over it, and are made
   after `games` (they share its libraries' objects).

## What mini-ml asked

- **Optional arguments said** (labels kept): `Immediate.button` and
  `field`, `Mvu.button` and `field`, `Gui.button`, `field` and their
  `_in` (`~enabled`); `Layout.row` and `column` (`~gap`); `Grid.item`
  and `make`; `Undo.start` (`~limit`) and `record` (`~name`, an
  option); `Sheet_view.draw` (`~selection`, an option);
  `Gui4.retained` (`~before`); `Bigbang.big_bang`, whose handlers are
  `Some f` or `None`.
- **Polymorphic variants made types**: a context menu's answer
  (`Immediate.menu_answer`), and the MVU way's messages in the five
  `Gui4*` (a `type msg` each, `On_tick`, `On_duration`...: the
  playground wrote them where they are used, `` `Tick ``).
- A `Map.Make` (decision 4), three `Option.value ... ~default`, two
  uses of `Seq`.

## Status

2026-10-08, **done on Linux**: the 11 programs of `examples/` built by
dune and by mini-mk; mini-ml compiles the 83 files of the playground's
part of ix (`compile_ix.sh`).

Checked, `examples/tests/frames.sh` (the games' test, its list
`examples/tests/frames.expected`): 20 sessions, the playground's golden
frames of the eleven programs and its nine scripted scenes of them
(circles drawn and adjusted, a slider dragged, a cell picked, a name
updated and a list filtered, GuiFourWays' flight, timer and circles),
**no pixel differing from the playground's, by dune's build**. By
mini-ml's build (arm64), 13 the same and 7 with 1 to 3 pixels of a
million a level of grey apart, kept as a second sum (below). gui4's 5
unit tests pass (dune).

Two things found:

- **The platform without a window took the view of the last frame
  only** (it is the only one drawn). The playground's `Gui` keeps an
  update's widgets until the view that draws them, so five frames'
  labels were drawn at once, one over the other, and their smoothed
  edges came out bolder than the playground's (58 to 2,500 pixels a
  frame). The view is now taken at each frame, and drawn at the last.
- **OCaml on arm64 computes `a *. b +. c` in one instruction**
  (`fmadd`: one rounding), which mini-ml does in two. A blend's last
  bit may differ, and with it a pixel's level by one. None in the
  games' frames nor mini-drscheme's; 7 of the examples' 20. Not changed:
  mini-ml would have to choose the same expressions as OCaml's
  selection does. `frames.sh` takes a second sum on a line
  (`RECORD=2`), mini-ml's frame.

Not done: on mini-9pi (the draw platform, the mouse: with
[`plan_scheme.md`](done/plan_scheme.md)'s stage 4); arm (a Pi1's floats);
`GuiEditor`. `make loc` counts `lib_gui/` and sets apart `examples/`,
`apps/`, `languages/formula/` and `editors/drscheme/` (the author:
"let's not count examples and apps as part of make loc").
