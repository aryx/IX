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
   - `lib_playground/`: `Color Basics Time Cmd Sub Set Lehmer
     Playground` (not `Keyboard` nor `Program`: the Status says why),
     `Playground_platform.mli`, and
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
   - `games/`: `puzzle/Tetris.ml` first; the playground's directories
     (the author: "let's start to organize games/ and applications/
     like in the playground, with subfolders"). One source, a program
     per platform.
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
   `lib_playground/`, `lib_graphics/software/`, `games/puzzle/Tetris.ml`,
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

2026-10-07, **stage 1 done**: Tetris is a program of ix's, on Linux,
without a window. `lib_graphics/software/` (11 units), `lib_playground/`
(8 units, the renderer, the platform `ppm` and its script of keys) and
`games/puzzle/Tetris.ml`: 5,429 lines, 3,140 of them .ml, built by dune and by
mini-mk (`games/mkfile`: the libraries once, then each directory of
games by `games/mkgames`; in the top mkfile's list); mini-ml compiles
the 33 files. `games/survey.sh` says, for each file, the lines it
gained and lost against the playground's.

Checked: `games/tests/frames.sh` (in `make test-lite`, by dune's build
and by ix's own): **frame 5 of Tetris is the playground's golden frame,
0 pixels of a million differing**, by OCaml's build and by mini-ml's,
whose two files are the same bytes; and a session played by a script
(400 frames: pieces moved, turned, dropped), its frame's sum recorded.

What the copy changed beyond the survey's list (each file says):

- `include Color` (Playground.ml) written out; `type t = private int`
  (Lehmer) abstract; `Stdlib.( - )` where Basics' operators are the
  floats' respelt with Basics' own `-..`; `Arg.Tuple` done without; an
  `(Error _ as err)` given back as another type's error. In Tetris: a
  `+ 1` and a `let rec (stamp : ...) =`, the only ones of their kind in
  the playground's games.
- Interfaces written for `Color`, `Basics`, `Time`, `Sub`, `Set`,
  which have none there.
- lib_core gained `Float.pi`, `Float.hypot`, `Float.rem` and
  `Result.map`, OCaml's.
- `Playground.Http` and `any_app` are out, and `Cmd`'s two Http
  commands; a picture (`Image`, `Bitmap`) is drawn as its box, grey,
  until `Blit` is copied; the renderer has no debug view.
- A `Framebuffer`'s pixels are a `Bytes`, four a pixel in the order
  Plan 9's `x8r8g8b8` wants them: stage 2 gives them to the device as
  they are.

**Three names of the playground's that are not kept, for the author to
see:**

1. **`Cmd`.** ix had a `Cmd` already, `lib_core/commons/Cmd.ml`: xix's
   (a command and its arguments, run), imported with `Exception`,
   `Exit`, `Chan` and `FS` on the author's word, and **named by no
   program of ix's**. Two units of one name cannot be linked in a
   program. Done, for the build to go on: it is out of the two lists
   that linked it into everything (`lib_core/commons/dune`,
   `mkfiles/mkconfig`'s `COMMONS`), **its file left where it is**, and
   the games' `-I` has `lib_playground` first. To decide: the file
   removed, or renamed, or the playground's `Cmd` the one renamed.
2. **`Keyboard`.** The playground's is one line (`type key = string`),
   named by `Sub` only and by no game or app there; ix's is
   lib_graphics's (Plan 9's keyboard), which a Plan 9 platform links.
   The playground's is not copied; `Sub` says `string`.
3. **`Program` and a game's last line.** `Program` is the playground's
   launcher's (a program's main collected rather than run): not
   copied. And `run_app` takes the capabilities, as every function of
   ix's that reaches the system does:
   `let () = Cap.main (fun caps -> Playground_platform.run_app caps (Playground_platform.flags caps) app)`.

Found on the way:

- **ix's libc's `cos(0)` was not 1** (Plan 9's `sin.c`: 4 ulp short),
  so a rotation by no angle moved every point by its last bits, and
  mini-ml's frame differed from OCaml's in 99 pixels. Fixed in
  `lib_core/libc/port/sin.c` (`bugs/goken.md`, 35).
- **A frame is slow by mini-ml**: Tetris's, 1,000 by 1,000, on this
  arm64 machine: 1.36 s where OCaml's build takes 0.06 (clearing the
  million pixels 0.56 s, drawing the shapes 0.22, writing the PPM
  0.57: 55, 12 and 24 times OCaml's). Clearing is now one `Bytes.fill`
  for a grey (`Opti.enabled`: 0.86 s the frame). At mini-9pi's 480 by
  480 that is a quarter of the pixels, and a Pi1 is not this machine:
  stage 2 measures first, and decision 8 (only what changed drawn) is
  likely not optional there. It is also the draw platform's argument.

Left of stage 1: nothing.

2026-10-07, **stage 2 done: Tetris runs on mini-9pi**, on the bare
screen and in a window of mini-rio's, 51 to 52 frames a second under
QEMU; the arrows, the turn and the drop answer.
`lib_playground/platforms/software/` (Plan 9's platform: the picture
computed by the program, loaded into an image of the kernel's, that
image drawn on the window), over what the platforms now share
(`platforms/`: `Session`, a program stepped and the command line's
words; `Input_script`; `Redraw`). `games/mkgames` links a game with it
for `OS=plan9`; `tetris` is on mini-9pi's card (`kernel/9pi`'s
`CARD_BIN`).

Checked: `make -C kernel/9pi check-tetris`: two sessions, `tetris-bare`
(400 frames played by a script at once, `-frames` and `-script`, their
last picture) and `tetris-win` (the same in a window of mini-rio's,
then the window made larger: drawn again at that size), 16 screens,
the same under mini-qemu and under QEMU. And **the screen under QEMU is
the frame of the same session on Linux** (`size=480`), every pixel, in
the screen's 16 bits. `kernel/9pi/tests/live.py` plays a game that
does not stand still and writes its screens, to be read.

What it took, in the order found:

- **A Pi1's int has 31 bits**: the playground's `Lehmer` (modulus
  2^31 - 1) died at its start. Its state is a float here, the numbers
  the same (the frames did not change). Two things of mini-ml's on the
  way, not fixed (`bugs/ix.md`): a literal too large is another
  number, silently; a division by zero on arm is a segmentation fault.
- **mini-9pi's clock lost its ticks under load** (one counted a look
  at the timer): 9 seconds in 30 with Tetris running, the pieces three
  times too slow. Counted by the timer's own microseconds now
  (`Machine.timer_now`).
- **mini-9pi did not keep a process's floats through an interrupt**
  (d0-d7 and the FPSCR were not in the trap frame): one pixel of a
  frame wrong under mini-qemu. In the frame now (Pi1; the Pi4's entry
  to be looked at).
- **The kernel's draw of a 32-bit picture on the 16-bit screen was its
  general loop**: 2.1 s of a frame's 2.9 under QEMU. A path of its own
  in `Memdraw` (as its fill and its copy have): 0.02 s.
- **A key waited behind the frames owed**: the ticks that came while a
  frame was drawn each drew another before the keyboard was looked
  at. The loop takes what waits first: the keys, the mouse, and the
  ticks as one look at the clock.
- **Only what changed is drawn** (`Redraw`, decision 8, sooner than
  planned: the author, having tried it: "very slow and not super
  responsive to the keys"; "this is a simple game so this should be
  fast"). The shapes of a frame that were not in the one before, and
  the other way, are what changed; the boxes round them are drawn
  again, loaded and drawn on the window, nothing else. The pixels are
  the same as a whole frame's (`games/tests/frames.sh`: the `ppm`
  platform draws every frame so, and its last one has the recorded
  sum). `redraw=all`, a flag, is the simple way.

The numbers (QEMU on this machine, a picture of 480 by 480):

| | frames a second |
|---|---|
| whole frames, the kernel's general loop (the first version) | 0.3 (2.9 s a frame: shapes 0.6, load 0.2, draw 2.1) |
| whole frames, `Memdraw`'s path (`redraw=all`) | 2 (0.8 s: shapes 0.6, load 0.2, draw 0.02) |
| what changed only (`Redraw`) | 43 to 46 |
| the same with principia's C pixels (`make PIXEL=c`, mini-pi's `-p c`) | 42 to 43; whole frames: 2 |
| the loop woken each tick of the kernel's, not each sixtieth of a second | 51 to 52 |

Why not 60 (the author: "so what prevents to reach 60fps? like I have
on Linux"). Two things. The loop is woken by a process that sleeps,
and mini-9pi counts a sleep in its own ticks, a hundredth of a second:
a sleep of 16 ms was 20 or more. It sleeps one tick now, and the clock
says at each waking whether a frame is due. What is left: a frame
whose work is longer than a tick (the shapes compared, the piece's box
drawn, loaded, drawn on the window, under an emulator) finds two ticks
of the game due at the next waking and draws them as one. The game's
own time is right either way: 60 ticks of it a second.

So the C pixels are no faster now: what is left of a whole frame is
the program's own drawing (0.6 s of 0.8), mini-ml's code under an
emulator, and `Redraw` is what took that away. On Linux a whole frame
of 1,000 by 1,000 is 0.86 s by mini-ml and 0.06 by OCaml.

2026-10-07: Ctrl-Q ends a program on the Plan 9 platform, as on the
playground's (the author: "does not answer to Ctrl-Q to quit, like I
do on Linux"); Delete still does. Tried on the bare screen under QEMU
(`tests/live.py`, its keys now `ctrl-q` too), not in a window of
mini-rio's.

2026-10-07, **stage 4 done (keys held), before stage 3; and a second
game, TinyWolfenstein** (the author, of what to make fast after
Tetris: "maybe there is an intermediate game simpler than TinyDoom that
also would exercise the whole screen?"; "TinyWolfenstein is a good
idea!").

- **`lib_playground/` has the playground's folders** (the author:
  "let's try to use the same folder structure than in
  ~/playground/playground/ with those apis/ layers/ subfolders", "and
  maybe add a lib_playground/core/"): `core/` (its libs/core),
  `random/` (`Lehmer`), `layers/` (`Camera2d`, `Sprite`, `Tilemap`,
  copied for the game; `Xpm` with them, in `lib_graphics/software/`),
  `apis/` (empty yet), `platforms/`; `Playground` and
  `Playground_platform.mli` at its top. One dune library
  (`include_subdirs`); `games/mkgames` names each folder's units.
- **`games/fps/TinyWolfenstein.ml`** (306 lines: 200 rays, a
  rectangle a screen column, a map, words): copied, its last line ix's
  and one `Option.value ~default` written out. **Its two golden frames
  are the playground's, no pixel differing** (the start; the walk to a
  treasure, keys held by a script), by dune's build and mini-ml's
  (arm64, arm): `games/tests/frames.sh`, 4 sessions now. lib_core
  gained `String.mapi`.
- **The keys held: `#c/kbd`**, 9front's /dev/kbd's `k` and `K`
  messages (the keys down, at each press and release), made by the
  kernel's `Kbd` where the scan codes are translated (the author: "I
  prefer small version (file in kernel)", not 9front's kbdfs);
  `Kbd.mli` says why the console, raw or not, is not enough. (The
  file is opened by its name and not listed in `#c`: the C 9pi's
  recorded sessions list that directory.)
  `lib_graphics`'s `Keyboard.held`, `message`, `keys`; mini-rio gives
  each window a `kbd`, the messages to the one that has the keyboard
  (and a `K` of no key when it loses it); the Plan 9 platform reads it
  where it is and makes of it a key's down and up, the console's
  characters being then what was typed only.
- Checked: `make -C kernel/9pi check-kbd`: `hellokbd`
  (lib_graphics/tests: a line a message) on the bare screen and in a
  window, a key held a second and a half two lines as the others, 17
  screens the same under mini-qemu and QEMU. And TinyWolfenstein played
  under QEMU by `tests/live.py` (a key held: `right:4000`): the view
  turns while right is down.
- **It is slow there: under a frame a second** when the view turns
  (every column changes: `Redraw` has the whole picture to draw). It
  is [`plan_playground_speed.md`](plan_playground_speed.md)'s meter
  now. On the card it is `wolfenstein`: a name there is 14 characters
  at most (xv6's file system).
- A key held does not repeat for a program that asks for presses
  (Tetris's left, held, moves once; on Linux SDL repeats it): the
  repeats are the console's characters, and are not made presses.

2026-10-07, **stage 3 done: the draw platform, now the games' own on
mini-9pi; and a third game, TinyCameltry, with `lib_physics/`.**

- **`lib_playground/platforms/draw/`** (179 lines): a frame is
  messages to the draw device, a shape each: a rectangle that is not
  turned a fill, the others polygons (`P`), circles and ovals ellipses
  (`E`), a word the strokes of its letters (`p`: lines as wide as the
  pen), in an image off the screen that is then copied to the window.
  A colour is an image of one pixel, kept. `Draw` gained `poly`,
  `fillpoly`, `ellipse`, `fillellipse` (the kernel had them; no
  program of ix's had sent them). What it does not do: an edge is not
  smoothed; a picture is its box.
- **The loop is one**, `platforms/Plan9_loop` (the clock, the keys,
  the mouse, a session played by a script), for the two Plan 9
  platforms: each gives it a window and a way to show a frame.
- **The numbers** (QEMU, a picture of 480 by 480; a frame's time by
  the loop's own clock round it, twenty frames at a time, a key held:
  taken out since):

  | every frame the whole picture | software (the program's pixels) | draw (the device's) |
  |---|---:|---:|
  | TinyWolfenstein, the view turning | under 1 frame a second | 9 to 10 (104 ms a frame) |
  | TinyCameltry, the maze turning | 2 to 3 | 9 (its physics 20 to 32 ms, the frame 74 to 85) |
  | Tetris (little changes) | 51 to 52 | 51 |
  | its lines: the platform, and what is under it that the other has not | 91, with `Shape_render_software` 351, `Redraw` 85, and of the rasterizer `Framebuffer`, `Fill`, `Line`, `Stroke`: 585 | 179 |

  (The frames a second written on the picture counted, until this
  stage's end, the frames the loop asked for, drawn or not: 28 and 44
  were read there first, and were wrong. Only a frame drawn is counted
  now.)

  **With principia's C pixels (`make PIXEL=c`) the turned maze is the
  same**: 16 frames for 15 where the two were read side by side, 151 ms
  for 139 over a first forty. So what a frame costs on the draw
  platform is not the kernel's filling (the author: "can we optimize
  this rotation? What when using -p c and the C graphics library?"):
  it is on the program's side, mini-ml's code (the view made: 200 rays;
  each shape's place, floats; the messages, a byte at a time), or in
  `Devdraw`, which is OCaml with either. Not split yet:
  [`plan_playground_speed.md`](plan_playground_speed.md)'s to say.

  So the lesson the plan asked of this stage: a device that draws
  saves the program its pixels (1,021 lines, and the time of code that
  mini-ml compiles), and costs it the smooth edges. The kernel that
  draws is ocaml-light's ocamlopt's code; the program is mini-ml's.
- **The draw platform is the default** for a game on Plan 9 (the
  author, having seen the numbers: "let's default to the draw-device
  platform then when building games, for now"): `mini-mk O=5 OS=plan9`
  in games/; `PLATFORM=software` makes the other beside
  (`games/puzzle-soft`). On the card: `tetris`, `wolfenstein`,
  `cameltry` (draw) and `tetris-soft`, `wolf-soft`, `camel-soft`.
- Checked: `make -C kernel/9pi check-games-draw` (`draw-tetris`, the
  session of `tetris-bare`; `draw-wolf`, the playground's walk to a
  treasure): 4 screens, the same under mini-qemu and QEMU;
  `check-tetris` still the software platform's.
- **`lib_physics/`** (the author: "we can also maybe copy TinyCameltry
  and start lib_physics/ port too", "just enough for cameltry for
  now"): the playground's libs/physics/2d, ten modules of its sixteen
  (`Body Shape Contact Collide Broadphase Resolve Joint2d Solver Force
  Integrate`, 848 lines), with `Physics` (lib_playground/apis) and
  `Scene2d` (layers) over them. Changed where mini-ml asks: the
  optional arguments said (`Body.make`, `Shape.place`,
  `Resolve.separate`, `Broadphase.grid`, the joints', `Solver.solve`,
  and `Physics`'s `bounce_all`, `simulate`, `pin`, `rope`); the
  solver's `Map.Make` a list of pairs; and three functions of more
  than seven parameters, which mini-ml for arm does not take, their
  arguments grouped (`Joint2d`'s `make_row`, `pulley`, `rope`).
- **`games/arcade/TinyCameltry.ml`**: its last line changed, no more.
  **Its four golden frames are the playground's, no pixel differing**
  (the start; the maze turned; the moon rolling, and sliding), by
  dune's build and by mini-ml's: the physics is the same to the bit.
  Played on mini-9pi under QEMU with keys held: the maze turns while
  right is down.
- A game is linked with the physics when its directory's mkfile says
  `WITH=physics` (a program is its units whole: 1.2 MB with it, 1.05
  without).
- The frame-writing platform draws the last frame only (`redraw=each`:
  every frame, by what changed; two sessions of `frames.sh` hold
  `Redraw` to the same picture): Cameltry's 200 frames each drawn by
  mini-ml's code were minutes.

**mini-9pi's card was full**: 43 programs, 30.9 MB of its 31 (each
program of ix's is 0.7 to 1.2 MB, its library linked whole). It is 128
MB now, its second partition 95 (the author: "we can extend the card
to more than 31MB; an SD card is actually usually many GB"; `CARD_MB`
and `CARD_FS_MB` in kernel/9pi's Makefile; the file system needed no
change, its sizes are its superblock's); the recorded sessions that
say the card's geometry say the new one. `wolf-soft` and `camel-soft`
are on it too. A file system that is full is said by mini-mkfs as an
`Invalid_argument` of `Bytes.blit`, not by a sentence: to fix.

Not done, not measured: a real Pi1; the mouse in a game (its events are given,
no game here reads them yet).

Next: more games (stage 5), and [`plan_playground_speed.md`](plan_playground_speed.md).
