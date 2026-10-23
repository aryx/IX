# lib_playground: the author's playground's library

Elm's Playground in OCaml (`picture`, `animation`, `game`, and Elm's
architecture under them), from the author's playground
(`~/playground`, [ocaml-elm-playground](https://github.com/aryx/ocaml-elm-playground)):
its `playground/`, and the `libs/core` and `libs/random` it stands on.
What ix's games (`games/`), examples (`examples/`) and mini-drscheme
(`editors/drscheme/`) are written with. The plans:
[`plan_playground.md`](../docs/plans/done/plan_playground.md),
[`plan_gui.md`](../docs/plans/done/plan_gui.md).

Each copied file says in one line where it comes from and what changed
(`ix: the author's playground's <path>; ...`). The lists and the
numbers below are `scripts/playground_copies.sh lib_playground`'s,
against the playground at `ff335663` (2026-10-23).

## What was copied

43 files, 8,796 lines there and 8,634 here, in the playground's
folders:

| here | there | what |
|---|---|---|
| `Playground`, `Playground_platform.mli` | `playground/` | the API; what a platform is |
| `core/` | `libs/core` | Elm's: `Basics`, `Color`, `Time`, `Cmd`, `Sub`, `Set` |
| `random/` | `libs/random` | `Lehmer` |
| `layers/` | `playground/layers` | what games are made of: `Camera2d`, `Scene2d`, `Sprite`, `Tilemap` |
| `apis/` | `playground/apis` | its face of a library: `Physics` (`lib_physics`), `Gui` (`lib_gui`), `Audio` and `Audio3d` (`lib_audio`), `Juice` (`lib_juice`), `Multiplayer` (`lib_networking/netcode`), `Ai` (`lib_ai`) |
| `ways/` | `playground/ways` | `Bigbang`, How to Design Programs' world |
| `platforms/Shape_render_software` | `playground/platforms/software` | shapes to pixels, over `lib_graphics/software` |
| `platforms/Input_script` | `playground/platforms/native_common` | the keys and the mouse of a script, for the tests |
| `platforms/software/Playground_platform` | `playground/platforms/software` | the platform that computes its pixels: written again, below |

## What changed

Most files only by their header line. The others, because mini-ml has
not what the playground's OCaml uses, or because ix's machine is not a
PC:

- **Optional arguments are said** (mini-ml has none): `Physics`,
  `Gui`, `Juice`, `Scene2d`, `Shape_render_software`; `Bigbang`'s handlers and
  its tick rate are a record.
- `Playground`: less its `Http` and its `any_app` and `capture` (a
  GADT; the launcher's hook), its `include` and its `Stdlib.` written
  otherwise.
- `Playground_platform.mli`: 168 lines there, 34 here. No clipboard,
  cursor, pictures loaded ahead, stored documents nor pixels read back
  yet; `run_app` takes the flags and ix's capabilities, so a program's
  last line is ix's.
- `Cmd`: no `Http_get` nor `Http_post`. `Sub`: a key is a string. `Set`:
  over ix's `Set_` (`lib_core/commons`).
- `Lehmer`: the state is a float, exact on the Pi1's ints of 31 bits;
  the same numbers come out.
- `Shape_render_software`: a `Bitmap` is drawn (`Blit`: the nearest
  pixel where it is neither scaled nor turned, else its neighbours
  blended); an `Image`, a picture by its file's name, is its grey box:
  no file is fetched. No debug views. No `render_region`: `Redraw`
  draws a box that changed into `lib_graphics`' `Framebuffer.part`, a
  framebuffer that is that part of the window, by `render` (the
  window's moved transform gave other floats: pixels at edges
  differed). `Shape_render_pdf` beside it is ix's own: the same shapes
  as a PDF's operators.
- `Sprite`: a picture's bytes are a `Bytes`, not a Bigarray.
- `platforms/software/Playground_platform`: the playground's software
  platform, SDL's window become Plan 9's draw device's (the pixels
  computed, given to the device as a picture): 84 of its 92 lines are
  ix's.

- `Audio`: less the live effects not copied (`chorus`, `flanger`,
  `phaser`, `rotary`: `lib_audio` has not their modules; `drive` and
  `compressed` are over its `Drive` and `Dynamics`); **a loop is
  rendered as it is played** (`lib_audio`'s `Synth.pieces`), not whole
  before its first sample; its optional arguments said, its
  constructors with their module. The same samples come out
  (`games/tests/audio.sh`). And ix's `play_ogg` (2026-10-23, for
  mini-quake's music, LibreQuake's `.ogg` tracks), `loop_from`'s
  `.ogg`: an Ogg Vorbis file decoded a packet at a time as the mixer
  pulls it (`lib_audio`'s `Vorbis_player`), as `play_module` plays a
  module.
- `Audio3d` (2026-10-23, for mini-doom): ix has no `Playground3d`, so
  the listener is made from a camera's eye, target and up said by
  their labels (`listener`), or from an eye and a yaw in a world whose
  z is up (`facing`, ix's: Doom's and Quake's); `heard`'s optional
  arguments said.

- `Ai` (2026-10-23, for mini-doom's monsters): its ways through a map
  and `aim_error` only, not its steering, its opponent, its state
  machine nor the rest of its bots (`lib_ai/README.md`); `diagonal` and
  `settle` said, its functions annotated.

- `Multiplayer` (2026-10-13): its optional arguments said (`network`
  an option, `split`); the network's capability is one that forks too
  (Plan 9's packets are read by a process); the rollback's peer, which
  its own callback names, is a reference set after, not a `lazy`
  value; no `netcode=server` (its `Snapshot` and `Prediction`, and the
  server's screen of `net=simulate`) nor `net=relay`; the flag
  `ticks=on` (each second of a game over a network, its tick and
  whether the two agree, on the standard error) is ix's, for
  `games/tests/network.sh`. The ppm platform's `pace=n` (frames by the
  clock) is for the same.

## What is ix's own

18 files, 2,003 lines:

- `Audio_source`: where a platform finds a program's sound, set by
  `Audio` when it is linked: a program without sound is not linked
  with the synthesizer. Each platform plays it its way: `ppm` writes
  a WAV (`-dump-audio`), `sdl` queues it to the sound card, Plan 9's
  two write it to `/dev/audio` (`Plan9_loop`), three frames ahead of
  the clock;

- the interfaces of `core/`'s `Basics`, `Color`, `Set`, `Sub`, `Time`
  (the playground has none for them);
- three platforms, each a `Playground_platform.ml` after one of the
  playground's: `platforms/ppm` (no window: a frame written to a file,
  what the tests run, as its `-dump-frame`), `platforms/draw` (a
  message to Plan 9's draw device for each shape: its native platform,
  Cairo become the draw device) and `platforms/sdl` (a window on Linux,
  the pixels computed here: its software platform; the window may be
  given another size, the picture drawn again for it; dune's alone,
  `bin/mini-drscheme`'s);
- `platforms/Plan9_loop` (the loop on mini-9pi: the mouse, the keys
  held, the clock), `Redraw` (only what changed between two frames),
  `Session` (a program stepped, the command line's flags).

## What remains in the playground

168 files. By what they are:

- **3D**: `Playground3d`, `Gpu_scene`, the layers `Camera3d`,
  `Character3d`, `Portal3d`, `Ragdoll3d`
  ([`plan_gpu.md`](../docs/plans/plan_gpu.md)).
- **The other apis**: `Ai`'s other families, `Juice3d`,
  `Multiplayer`, `Multiplayer3d`, `Physics3d`, and the debug views
  (`Ai_debug` among them).
- **The other ways**: `Karel`, `Logo`, `Logo3d`, `Povray`,
  `Puzzlescript`, `Teletype`, `Textmode`, `Universe`.
- **Its platforms**: native (SDL, Cairo, OpenGL), web (js_of_ocaml,
  WebGL), svg, and its own software platform's window and help.
- `libs/core`'s `Base64`, `Keyboard`, `Program` and `time/` (`Civil`,
  `Clock`, `Julian`, `Recur`).
- Its tests (`playground/tests`, `libs/core/tests`,
  `libs/random/tests`): ix's are the frames of `games/tests` and
  `examples/tests`.
