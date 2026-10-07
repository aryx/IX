# Plan: the playground on mini-9pi: a Plan 9 platform for `Playground`, twice (the draw device's shapes, and ix's own pixels), and `games/` (`lib_playground/`, `lib_graphics/`, `games/`)

The author (2026-10-07): "I would like now to 'port' the playground
(see ~/playground), but really just adding a plan9 platform for
Playground.mli, so that I can then compile games like Tetris.ml and
have them work under mini-9pi. I don't know if the Draw device is
powerful enough to implement all the things needed by the playground
platform. Also I wonder, for teaching purpose, if we want also to copy
some of the graphics software library code of the playground in ix,
under lib_graphics/ and have also, like for Cairo, tetris with the
rendering user-side and then send to the draw device as a full image.
Is it possible?" Then: "we probably need a plan_playground.md
document"; "I don't want to depend at compile time from the
~/playground/, so we would copy the necessary files (and sometimes
shorten if needed)"; "and have also in ix a games/ directory (so we
have utilities/ applications/ games/)". And, of this plan's first
version: "I like the toplevel lib_playground"; "hopefully at some point
later we can compile many of the ~/playground/games/ easily under ix
too"; and of the sound, that the boards may have a device for it:
[`plan_audio.md`](plan_audio.md).

The short answer: **yes to both.** The draw device has what a Tetris
asks and most of what `Playground.shape` is (filled polygons, ellipses,
lines, an image combined through a mask); what it has not is said
below, and is exactly what the second platform shows: pixels computed
by the program (the playground's software rasterizer, about 800 lines
of it) and given to the device as one image. The two platforms side by
side are the playground's own pair (Cairo, and its software backend)
on Plan 9.

Its numbers are `games/survey.sh`'s (run 2026-10-07).

## The survey (2026-10-07, checked)

- **A platform is one module**, `Playground_platform` (in the
  playground a dune virtual module, four implementations: Cairo 1,341
  lines, software 1,286, web 2,451, and 1,421 of SDL loop shared by
  the first two). Its interface: `run_app flags utc_offset pixel_ratio
  framebuffer set_cursor clipboard set_clipboard preload_image store
  fetch stored export`. A game needs the first two.
- **What Tetris.ml (550 lines) stands on**: `Playground` (801 lines,
  its interface 1,273, mostly the documentation), and under it
  `Color`, `Basics`, `Time`, `Keyboard`, `Cmd`, `Sub`, `Program`
  (377 lines), `Lehmer` (49), `Rgba_image` (22). Of the events, two:
  `Sub.on_key_down` and `Sub.on_animation_frame`. And two things that
  are not the library's core: **`Audio`** (the theme, four sounds: the
  synthesizer is 1,800 lines and more under it) and
  `Unix.gettimeofday` (the seed).
- **TinyTetris.ml (393 lines)** asks more: `Scene2d` and `Juice`
  (shakes, flashes, debris), `Random`.
- **The software rasterizer**: `Framebuffer` 93, `Vec2` 25, `Affine`
  48, `Fill` 275 (polygons, antialiased by coverage), `Line` 139
  (Bresenham, Wu), `Circle` 80, `Stroke` 53, `Hershey` 76 (the words:
  a font of strokes, so that they scale and turn) and its data
  (`futural.jhf`); and the platform's `Shape_render_software` 410,
  shapes to those. 1,199 lines, interfaces apart (612).
- **mini-ml compiles 6 of these 20 files as they are** (`Color`,
  `Time`, `Keyboard`, `Sub`, `Program`, `Affine`). The others' first
  refusals: optional arguments (9 definitions: `Fill`, `Circle`,
  `Shape_render_software`), `Bigarray` (`Framebuffer`'s pixels, 8
  lines), `Lazy` (`Hershey`), `Float.pi` and `Float.hypot` (not in
  lib_core's `Float`), `Cap.network` in `Cmd` (its Http command), a
  unary plus (`let dx = + 1`, Tetris), and two not understood yet
  (`Playground.ml` at its `shape`, `Lehmer.ml`: neither a record with
  a variant, a punned field, an `0x..l` nor a labelled pun, each tried
  alone and accepted). `Playground.ml` also has a GADT (`any_app`, for
  the playground's tests) and a module in the file (`Http`): both go
  with what a game on mini-9pi has no use for.
- **mini-9pi's draw device** (`Devdraw`, 812 lines; under it
  `lib_memdraw` and `lib_memlayer` in OCaml) answers these messages:
  `b f c v N n d O L p P e E s x l i y Y r A F S t o D`. So: an
  image made (`b`), one combined into another through a mask, with a
  Porter-Duff operator (`d`, `O`), a line (`L`), a polygon and a
  filled one (`p`, `P`), an ellipse and a filled one, an arc (`e`,
  `E`), a string in a font (`s`, `x`), an image's pixels given and
  read back (`y`, `Y`, `r`). **ix's client library has less than the
  device**: `lib_graphics` (742 lines) `Draw.mli` is `draw draw_mask
  fill border line`; no program of ix's has sent `p`, `P`, `e`, `E`.
- **The screen** is 640 by 480 (`Swconsole`), 16 bits a pixel; the
  playground's is 1,000 by 1,000 units. A window of mini-rio's is
  smaller still.
- **The input.** `Mouse` gives the place, the buttons, a time in
  milliseconds, and `resized`. `Keyboard` gives **characters, as they
  are typed** (`/dev/cons`, raw): the arrows as Plan 9's runes; **no
  key released**, the kernel's `Kbd.kbdputsc` sees the releases and
  keeps them. Tetris needs presses only; `Playground.game`'s
  `keyboard.left` (a key held) needs releases.
- **The clock.** Plan 9's `Unix.time` reads `/dev/bintime`
  (nanoseconds) and floors it to a second; `Unix.sleepf` is there. No
  `gettimeofday`.
- **No sound**: mini-9pi has no audio device
  ([`plan_audio.md`](plan_audio.md): the boards have one).
- **The playground's other games**: 153 files, 70,443 lines. Of them
  127 use `Scene2d` (45 lines: a game's scenes and its keys pressed),
  82 `Set_` (the set of keys down: so, keys held), 53 `Audio`, 40
  `Tilemap`, 36 `Sprite` (pictures), 32 `Camera2d`, 35 the 3D
  playground. Tetris.ml, the elm port, is not the common case: a game
  there is `Scene2d`, keys held, and often a sound.
- **A message of the library's is sent whole**: `Display.load` puts an
  image's pixels in one write; a frame of 480 by 480 at 32 bits is
  921,600 bytes. Not tried.

## Is the draw device enough? Form by form

| `Playground.form` | the draw device | what is lost |
|---|---|---|
| `Rectangle`, `Ngon`, `Polygon` | `P`, its points transformed by the program (`Affine`: moved, turned, scaled, grouped); a rectangle not turned is `d` | antialiasing |
| `Circle` | `E` | antialiasing |
| `Oval` | `E`; turned, a polygon of its outline (as the software platform does) | antialiasing |
| `Words` | the font of strokes (`Hershey`) as lines (`L` or `p`): scaled and turned as the playground's; or the device's own font (`s`): one size, upright | with `s`, the size and the angle |
| `Image`, `Bitmap` | `y` then `d`: as its pixels are | scaled or turned: the device does neither; the program would do it, which is the other platform |
| `Group` | nothing to ask: the transforms are composed by the program | |
| `fade` (alpha) | `d` through a mask of one grey, for what `d` draws; for `P` and `E` a colour with an alpha as their source | to check: memdraw's loop has the operators, no program of ix's has drawn a translucent polygon |
| a frame without flicker | drawn in an image off the screen, then one `d` to the window, then `flush` | |

So the device draws every shape but a scaled or turned picture,
without smooth edges; and nothing of it is missing for Tetris, whose
view is rectangles and words. The transforms are the program's on both
platforms: the device is given points.

## Decisions (proposed, for the author)

1. **Copied, not depended on.** As mini-smalltalk's `St_*`: the files
   are ix's, each header says where it comes from and what changed;
   `games/survey.sh` holds the copy against the playground's. Changed
   where mini-ml asks (the survey's list: about 9 optional arguments
   said, `Bigarray` a `Bytes`, `Lazy` a `ref`, `Float.pi` and `hypot`
   added to lib_core's `Float` since OCaml's has them), and
   **shortened**: `Cmd` to `none` and `batch` (no Http), `Playground`
   without `Http`, `any_app` and the image by URL; the platform's
   interface to `run_app` and `flags`; `Shape_render_software` without
   the debug options (bounding boxes, wireframe), which are the
   playground's teaching, not this one's.
2. **Three directories.**
   - `lib_playground/`: `Color Basics Time Keyboard Cmd Sub Program
     Lehmer Playground`, `Playground_platform.mli`, and
     `platforms/draw/`, `platforms/software/`, `platforms/ppm/`
     (below), each a `Playground_platform.ml`. The loop the two Plan 9
     platforms share (the mouse, the keys, the clock, the window made
     another size) is one module beside them.
   - `lib_graphics/software/`: `Framebuffer Vec2 Affine Fill Line
     Circle Stroke Hershey`: pixels in the program's memory, nothing
     of Plan 9's (as the kernel's `lib_memdraw` names nothing of the
     kernel's). `lib_graphics/` itself stays the device's client and
     gains what the device already answers: `Draw.poly`, `fillpoly`,
     `ellipse`, `fillellipse` (about 30 lines).
   - `games/`: `Tetris.ml` first. One source, a program per platform.
3. **A platform is chosen at link time**, by the directory given to
   the build (mk's variable, dune's library), as `UNIXDIR` chooses
   Plan 9's `Unix`: no virtual module, which mini-ml has not.
4. **A third platform for Linux and the tests: `ppm`**, no window: a
   script of keys and a number of frames in, the last frame out as a
   PPM (mini-smalltalk's Display does the same). It is the software
   renderer on a `Framebuffer` with nothing under it, so the library,
   the rasterizer and the game are built by dune and tested on Linux
   with no SDL (out of mini-ml's scope) and before a kernel runs them.
5. **The picture is scaled to the window**: 1,000 units on the
   smaller of the window's sides, centred (the software renderer has
   the scale already; the draw platform puts it in its `Affine`).
6. **Tetris's sound: left out at first, back with
   [`plan_audio.md`](plan_audio.md)** (its stage 4). Until then the
   copy is without its "Sound" section and four calls, its header
   saying so; no silent `Audio`.
7. **The playground's games are to compile here "easily"** (the
   author; and: "ideally we want to keep the same API names than in
   the ~/playground/ so porting a game (or app) from the playground to
   ix would be easy"). The modules' names, the values' names and their
   types are the playground's. So what is shortened is what no game sees (a platform's
   inside, the debug views, the network), and **an interface a game
   calls keeps the playground's names and types**; a part left out is
   a name unbound, not a function that does nothing. The changes
   mini-ml asks of a game's own text (a unary plus) are few, and each
   is a question first: is it the game or mini-ml that should change
   (mini-ml's feature policy). **One name cannot be kept as it is**:
   `Playground_platform.run_app ?rendering ?flags ?network ?window
   app`, optional arguments, which mini-ml has not and ix has rewritten
   out of itself; a game's last line is `run_app
   ~flags:(Playground_platform.flags ()) app` or `run_app app`. The
   author (2026-10-07): "let's have the copied game last line change
   for now": here `run_app flags app`, a line a game, said in the
   copy's header.
8. **Optimizations apart and switchable**, the simple path first: a
   frame is all drawn, all sent. Then, measured: a frame whose view
   did not change not drawn (the playground's `skip_same_view`), the
   rectangle that changed only (`pixel_bounds`), the pixels in the
   screen's 16 bits.

## The stages (each checked before the next)

1. **The library and the rasterizer in ix, on Linux** (`ppm`).
   `lib_playground/`, `lib_graphics/software/`, `games/Tetris.ml`,
   built by dune and by mini-mk; mini-ml compiles all of it. Check: a
   frame of Tetris at 1,000 by 1,000 against the playground's
   `tests/2d/golden/Tetris.png` (the same code: the same pixels, or
   the difference said); the survey's table again, every file
   compiling.
2. **The software platform on mini-9pi.** `Unix.gettimeofday` for
   Plan 9 (`/dev/bintime`, not floored); the loop (`Event`: the mouse,
   the keys, a tick); the frame as an image, `y` in as many messages
   as the device wants, `d` to the window. Check: `kernel/9pi`'s `make
   check-tetris`, a session of keys and the screen compared, under
   mini-qemu and QEMU, alone on the screen and in a window of
   mini-rio's; **frames a second, measured** (QEMU; the Pi1 by the
   author), which says how much of decision 8 is needed.
3. **The draw platform.** `Draw`'s four shapes, checked first by a
   test program beside `Hellodraw` (and a translucent one: the table's
   "to check"); then shapes to messages (the counterpart of
   `Shape_render_software`, much shorter: the device fills). Check: the
   same session, the two screens side by side; the two platforms'
   lines and frames a second in a table here. That table is the
   lesson: what a device that draws saves a program, and costs it.
   (This stage before the draw platform's, if the author would
   rather have more games sooner: 82 of the 153 game files hold keys.)
4. **Keys held.** A file of the kernel's with the keys down and their
   releases (9front's `/dev/kbd` is the model: principia's Plan 9 has
   none), from `Kbd.kbdputsc`; mini-rio gives it to the window that
   has the keyboard. Then `Playground.game` and its `keyboard`, and a
   game that needs them.
5. **More games**, by the census: `Scene2d` and `Set_` first (127
   and 82 files), TinyTetris with them (and `Juice`); then `Tilemap`,
   `Sprite`, `Camera2d` and pictures (`Bitmap`, on the software
   platform first); the sound by [`plan_audio.md`](plan_audio.md).
   `games/survey.sh` to say, for each of the playground's games, what
   it still misses here.

Not in this plan: the 3D playground, the sound (its own plan), the network
(Multiplayer), the apps and their widgets.

## Open questions

- The games' names as programs: `tetris` and `tetris-soft`? (mini-xxx
  is a faithful twin's name, tiny-xxx a one-file variant's: neither is
  this.)
- Stage 4 (keys held) before stage 3 (the draw platform)?
- The words on the draw platform: the font of strokes (the two
  platforms' pictures alike), or the device's font (Plan 9's look, and
  what a Plan 9 program would do)?

## Status

2026-10-07: plan written, after the survey (`games/survey.sh`).
Nothing built.
