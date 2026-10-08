# Plan: the 3D playground on mini-9pi, and TinyVirtuaRacing fast on the Pi1 by its 3D processor: `Playground3d` as 2D shapes, with a depth for each pixel, then by the processor; a 2D platform on the processor (`lib_playground/`, `lib_graphics/`, `kernels/9pi/`, `raspberry/`)

The author (2026-10-08): "do the Pi1 and Pi4 GPU have 3d
capabilities?"; then: "would it be possible to get the ~/playground
Playground3d.ml working on the Pi in mini-9pi? (and even possibly have
a playground 2d platform that instead of software or draw device would
leverage the GPU)?"; and, offered this plan: "yes, let's write
plan_playground3d.md or maybe call it plan_gpu.md?"; it was written
under the first name, and: "I thought I said to call the plan
plan_gpu.md": this name. Then, the
plan read: "**ideally I would like TinyVirtuaRacing to run quickly
under the Pi1, thx to the GPU**"; "and I have a Pi 2B"; "so definitely
would love to have mini-9pi running on it"; "Pi2 should go in
separate plan document, that can be linked from this one":
[`plan_pi2.md`](plan_pi2.md).

**The goal is that game on that board**, and it decides what the
processor is asked (the survey's "TinyVirtuaRacing"): its frame is not
slow by its pixels but by its scene, so the processor must place the
vertices too, and keep the scene that does not change in its memory.

The short answer: **yes to both, and not the same yes.** The 3D
playground in software is the 2D port again
([`plan_playground.md`](plan_playground.md)): files copied, a
platform written, checked on Linux and under both emulators. The 3D
processor is **the Pi1's only** (and the Pi2's, the same one), it is
documented, and **nothing but the board can say that it works**: QEMU
has the device's name and nothing behind it. The Pi 2B has the same
processor and four faster cores: a board of mini-9pi's to add
([`plan_pi2.md`](plan_pi2.md)), and the better one for this game.

Its numbers are `games/survey3d.sh`'s (run 2026-10-08). What is said
of the processors was read in Linux's driver and the firmware's list
(below, each with where); **nothing here was run on a board.**

## The survey (2026-10-08, checked)

### The playground's 3D

- **The library is small and stands on three modules.**
  `Playground3d.ml` is 485 lines (its interface 497) and names, beside
  `Playground`, only `Vec3`, `Camera` and `Lighting`: the geometry,
  334 lines in five files (`Vec3 Mat4 Camera Lighting Material`). In
  it already: `render3d_to_2d rendering camera screen shape3d`, a
  scene made one `Playground.shape`, the farthest face first.
- **Four platforms there**, one interface (`Playground3d_platform`:
  `run_app3d` and `preload_texture`):

  | the platform | lines | how a scene is drawn |
  |---|---:|---|
  | svg | 97 | `render3d_to_2d`, then the 2D platform's `run_app`: nothing of its own |
  | software | 427 + 138 | triangles with a depth for each pixel (`libs/graphics/3d`, 482 lines in seven files), or rays (1,256 lines more) |
  | native | 526 + 157 | OpenGL: `Gpu_scene` (193) makes the scene arrays of vertices, a group a texture |
  | web | 433 | WebGL, the same arrays |

  The first three share a loop over SDL (`Native_loop_3d`, 461).
- **`Gpu_scene` is the half a 3D processor's platform needs and that
  is already written**: 11 numbers a vertex (a place, a normal, a
  colour, a texture's two), triangles in groups.
- **mini-ml compiles 7 of the 18 files as they are** (`Vec3 Material
  Mesh_cache Cull Painter Clip Zbuffer`). The others' first refusals
  are the 2D port's: optional arguments (15 definitions: `Mat4`,
  `Camera`, `Playground3d.camera`, `Render.render`, the platforms'
  `run_app3d`), `Bigarray` (11 lines: a texture's pixels, the depths),
  `Stdlib.max`, and the GADT `any_app3d` (the playground's tests).
- **What the programs ask**: 24 examples (2,782 lines) and 38 games
  (22,010). Files using each value, the games then the examples:

  | | games | examples | |
  |---|---:|---:|---|
  | `box`, `cube`, `plane`, `polygon3d` | 35, 15, 20, 23 | 17, 13, 11, 4 | flat faces of one colour: every platform's |
  | `sphere` | 13 | 10 | faces too (cut in bands) |
  | `hud` | 35 | 13 | 2D shapes over the scene: the 2D renderer after the 3D one |
  | `cached3d` | 25 | 3 | a scene kept between frames: a `group3d` where nothing keeps it |
  | `fade3d` | 7 | 1 | a face seen through |
  | `capture_mouse` | 6 | 0 | the mouse hidden and not stopped: rio's to give |
  | `split3d` | 3 | 0 | several views a screen |
  | `textured_quad`, `textured_cube` | 0, 1 | 1, 2 | **a picture on a face: one game** |
  | `shiny`, `glassy` | 0 | 2, 1 | the ray tracer's |

  So **textures and rays can wait**: one game and five examples. And
  beside the library the games name `Scene2d` (32 files) and `Set_`
  (24), which ix has, `Camera3d` (25), `Physics3d` (7), `Track3d`,
  `Heightmap`, `Character3d`, `Skeleton`, which it has not.
- **161 golden frames** of the 3D examples
  (`~/playground/tests/3d/golden`): what a copy here is held against.

### What a frame costs

The playground's software platform, built by OCaml, on this machine (a
Neoverse N1), no window, 640 by 480 (20 frames, the program's start
taken out):

| | ms a frame |
|---|---:|
| `Triangle3d` (one triangle) | 15 |
| `TexturedCube3d`, `Cube3d` | 16, 18 |
| `Spheres3d` | 23 |
| `Cubes3d` | 49 |
| `Corridor3d` | 93 |
| `StarCollector3d` (a small game) | 104 |

- **15 ms with one triangle**: a frame's floor is the pixels and the
  depths cleared and the picture made the window's, before a shape is
  drawn. (What of it is `-dump-size`'s own path was not taken apart.)
- **These are OCaml's, on a fast machine.** By mini-ml the same kind
  of code (floats, a byte at a time) was 12 to 55 times OCaml's when
  [`plan_playground_speed.md`](plan_playground_speed.md) measured it,
  less since its floats are computed in place (not measured again
  here); and a Pi1 is several times slower than this machine. **A
  guess, to be measured at stage 2: a second or more a frame for
  `Corridor3d` on the Pi1, at this size.** The depth for each pixel is
  floats for each pixel, mini-ml's weakest.
- **Against that**: TinyWolfenstein, shapes given to the draw device,
  is 30 ms a frame under QEMU (the speed plan's table): the kernel
  fills polygons fast. A scene made 2D shapes goes that way.

### TinyVirtuaRacing

- **1,665 lines, and the processor's kind of picture**: "flat-shaded,
  no textures" (its header); its last line asks `shading = Flat;
  backface_culling = false`. Four golden frames there
  (`TinyVirtuaRacing.png`, `_select`, `_grid`, `_curve`).
- **What it stands on that ix has not**: `Track3d` (254 lines),
  `Heightmap` (143), `Topdown` (106), `Road` (86), `Camera3d` (82);
  `Audio` and `Sfx` (the sound: [`plan_audio.md`](plan_audio.md), not
  built; left out as Tetris's was); four tables that are `Lazy`
  (a `ref` in the 2D port); 53 lines with a label.
- **A frame by the playground's software platform, by OCaml on this
  machine: 320 to 390 ms**, in the race and on its first screen, **and
  as much at 320 by 240** as at 640 by 480. So it is the scene (every
  face of a course turned, placed, cut and sorted into the picture at
  every frame), not the pixels. `Cube3d` is 18.
- **Its scene is mostly kept**: the landscape, the land's tiles and
  the road's chunks of 40 segments are `cached3d` ("the road is
  static"); what is made again at each frame is the sky, the cars and
  the words over the picture.
- **So, for a 3D processor**: one that is given vertices already
  placed (the "NV" state below) leaves the program all of that
  placing, at every frame, in mini-ml's floats on a Pi1: seconds a
  frame (a guess from the 320 ms). The playground's OpenGL platform
  does what is needed (`Mesh_cache`, 50 lines and its notes: "build a
  mesh once, keep it in GPU memory, and on each frame only ask the GPU
  to draw it again"): **a kept scene's vertices stay in the
  processor's memory, a shader of the processor's places them, and a
  frame sends one matrix.**
- **Not taken apart: the game's own part of a frame** (its `view`
  makes lists at each frame: the tiles near, the chunks near, sixteen
  cars; its `update`). That part stays the program's whatever draws,
  and is the Pi1's to compute by mini-ml's code. Stage 3 measures it
  before the processor's stages are begun.

### The boards' 3D processors

| | Pi1, Pi 2B (and Pi3) | Pi4 |
|---|---|---|
| the processor | VideoCore IV's V3D | VideoCore VI's V3D 4.2 |
| its registers | the bus's 0x7EC00000, 4 KB: 0x20C00000 on the Pi1, 0x3FC00000 on the Pi2 (its peripherals are at 0x3F000000; not checked on a board) | 0xFEC00000 and 0xFEC04000 ("hub", "core0") |
| its manual | **Broadcom's, public** (2014: *VideoCore IV 3D Architecture Reference Guide*) | none: Mesa's `v3d` and Linux's `drm/v3d` are what there is |
| the memory it reads and writes | **physical addresses, any**: it has no table of pages | its own table of pages |
| vertices | by a shader, or **already placed by the program** (the "NV" shader state) | by a shader |
| Linux's driver | `drm/vc4` | `drm/v3d` |

Read for this (in the scratchpad that day, the links to read again at
stage 4):

- **The lists the Pi1's processor runs**, Linux's
  [`vc4_packet.h`](https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/vc4/vc4_packet.h):
  two lists a frame. The first (the binner's) is given the triangles
  and writes, for each tile of the picture, the list of those that
  touch it; the second (the renderer's) says where the picture is in
  memory and, a tile after the other, runs the first's lists. In it:
  the picture's format is **`BGR565`, `BGR565` dithered or `RGBA8888`**
  (`VC4_RENDER_CONFIG_FORMAT_*`: the first is the screen's 16 bits
  today, to check on the board, red and blue being where the firmware
  puts them or not); **four samples a pixel**
  (`VC4_RENDER_CONFIG_MS_MODE_4X`): smooth edges, the processor's own;
  `VC4_PACKET_NV_SHADER_STATE` (65), the state for vertices already
  placed: no shader for them, the program computes where each goes;
  and `VC4_PACKET_GL_SHADER_STATE` (64), the one this game needs:
  three shaders (the vertices' place for the binner, their place and
  colour for the renderer, a pixel's colour), the vertices read from
  memory by the processor, and **the processor cuts what goes behind
  the eye** (the "NV" state leaves that to the program too).
- **Its registers**, Linux's `vc4_regs.h`: `V3D_CT0CA` and `V3D_CT0EA`
  (0x110, 0x108: the first list's start and end, written to run it),
  `V3D_CT1CA` (0x114), `V3D_BFC` and `V3D_RFC` (0x134, 0x138: the
  frames binned and rendered, to wait on), `V3D_BPOA` (0x308: more
  memory for the binner when it asks).
- **What the firmware is asked**
  ([its list of tags](https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface),
  and Linux's `raspberrypi-firmware.h` for the last): memory that
  does not move, 0x0003000C (allocate), 0x0003000D (lock), 0x0003000F
  (free); **0x00030012, "set enable QPU"**, which turns the processor
  on. The kernel's `property` (`lib_machine/pi1/machine.c`) sends two
  tags today (0x00028001, 0x00030002) and is what sends these.
- **The firmware on ix's card cannot do it**: it is the cut-down one
  (`start_cd.elf`, chosen by `gpu_mem=16` in `kernels/9pi/conf/config.txt`),
  and "the cut-down firmware removes support for codecs, 3D and debug
  logging" (the Foundation's
  [config.txt pages](https://www.raspberrypi.com/documentation/computers/config_txt.html)).
  Stage 4 wants `start.elf` and `fixup.dat` and a larger `gpu_mem`
  (the memory the firmware gives the processor's lists and pictures
  is taken there: how much, to find). [`plan_pi2.md`](plan_pi2.md)'s
  stage 3 renews the firmware's files for one card on the Pi1 and the
  Pi2: the full one is to be taken then.
- **A shader is a program** of the processor's own (the QPU's
  instructions, 64 bits each; the guide has them). A pixel's colour,
  one a face or one a vertex, is a dozen instructions; a vertex placed
  by a matrix is some tens (not written: a guess). Constants in the
  kernel either way; by hand or by an assembler is an open question. **Mixing with what is under
  (a face seen through) is the program's too**: this processor has no
  blending but a shader that reads the tile.
- **Programs that do it with no Linux**, to read at stage 4:
  [PeterLemon/RaspberryPi](https://github.com/PeterLemon/RaspberryPi)
  (assembly; its V3D directory) and
  [kumaashi/RaspberryPI](https://github.com/kumaashi/RaspberryPI)
  ("V3D Triangle with NV Primitive", on a Zero: the Pi1's processor).
- **QEMU**: `hw/arm/bcm2835_peripherals.c` has
  `create_unimp(s, &s->v3d, "bcm2835-v3d", V3D_OFFSET, 0x1000)`: a
  name, reads of zero. Its mailbox answers none of the tags above. And
  **mini-pi** (`raspberry/`): no file names v3d; its mailbox answers
  28 tags, none of these.
- **ix**: no file of `kernels/` names v3d. The screen is 640 by 480,
  16 bits (`Swconsole`).

### The Pi 2B

A BCM2837 by the author's word (a V1.2: four Cortex-A53 run as 32-bit ones; a V1.1 is a BCM2836, four Cortex-A7), the Pi1's peripherals at 0x3F000000, the
same VideoCore IV. mini-9pi has no board for it today:
[`plan_pi2.md`](plan_pi2.md) is that port, its survey and its stages.

## Four ways to draw a scene

| | where the work is | what it shows | checked where |
|---|---|---|---|
| A. **2D shapes**, the farthest first | the program: a face a polygon; then the 2D platform (the draw device fills, or the program) | flat faces, no picture on them; two faces that cross are wrong (`PaintersAlgorithmFail3d`) | Linux, both emulators, the boards |
| B. **A depth for each pixel**, in the program | the program, every pixel | all but rays | the same |
| C. **The Pi1's and Pi2's processor** | the processor: it keeps the scene that does not change, places the vertices, fills, keeps the depths, smooths the edges; the program gives a matrix and what moved | all but rays (pictures on faces: a later step) | **the boards only**; mini-pi if D |
| D. the processor in mini-pi | B's code, reading C's lists | what C's lists say, as the guide is read | Linux |

A is what makes the small games playable on every board with what the
speed plan built. B is the lesson (what a depth buffer is, and what it
costs), the pictures C is held against, and what D stands on. **C is
the goal**: the only one that can draw TinyVirtuaRacing's scene on a
Pi1 at a game's rate, if the game's own part lets it (stage 3).

## Decisions (proposed, for the author)

1. **Copied, not depended on; the playground's names kept** (the 2D
   plan's decisions 1 and 7): the modules, the values and their types
   are the playground's, so that a 3D game there compiles here with
   its last line changed. `run_app3d rendering capture_mouse flags
   app`, its optional arguments said (mini-ml has none). Left out, a
   name unbound: `preload_texture`, the textures by URL, `any_app3d`.
2. **Where the files go.**
   - `lib_graphics/software/`: `Vec3 Mat4 Camera Lighting Material`
     at stage 1; `Clip Interpolate Shading Zbuffer Triangle Render` at
     stage 2 (`Texture` with the pictures, later). Pixels and numbers
     in the program's memory, nothing of Plan 9's, as its 2D files.
   - `lib_playground/`: `Playground3d`, `Playground3d_platform.mli`;
     `Gpu_scene` at stage 5.
   - `lib_playground/platforms/`: **a 3D platform beside each 2D
     one**, chosen at link time with it (the 2D plan's decision 3).
     For `draw`, `software` and `ppm`, stage 1's is the same file, the
     svg platform's 97 lines over that directory's `run_app`.
   - `games/` and `examples/`: `Cube3d` first, then by the table.
3. **A before B**, and A kept: it is the 3D of the draw platform for
   good (the device has no depth), and the first thing to run on the
   Pi4.
4. **B at the picture's size that the board can draw**, said by a
   flag (`size=320x240`, the picture made the window's by the 2D
   path's scale), the simple path first; what makes it faster is the
   speed plan's (floats that do not leave a function not boxed, its
   M4) and stays there.
5. **The kernel's device takes a scene, not lists.** A list names
   physical addresses and the processor has no table of pages: a
   program that wrote its own lists could read and write all of the
   memory. Linux checks each list and each shader a program gives
   (`vc4_validate.c`, `vc4_validate_shaders.c`); here **the kernel
   writes the lists itself, and the three shaders are its own
   constants**: nothing to check but that an index is inside its
   mesh. What a program says, the draw device's messages the model:
   - *a mesh kept*: a number, and its triangles, each vertex a place
     in the scene and a colour (`cached3d`'s; the playground's
     `Mesh_cache` says which are still drawn, and frees the others);
   - *a frame*: the picture's colour, a matrix (the eye's), then
     meshes by their numbers, each with its own matrix (a car's
     place), and triangles given on the spot for what changes at each
     frame;
   - *show*: the frame run, and drawn in the window.
   The vertices stay in the processor's memory; a frame of this game
   is a matrix, sixteen cars and a sky. And the same messages serve a
   2D platform (triangles on the spot, one depth). A file of its own
   (`/dev/v3d`) or messages of the draw device's ("this scene into
   this image", which gives a window of rio's for nothing): to design
   at stage 5.
   **The light is the program's**: a face's colour under the sun is
   computed once, when its mesh is made (as A and B compute it at each
   frame); a vertex carries a colour, no normal: the simplest shaders.
6. **Where the processor draws**: memory asked of the firmware, the
   picture made an image of the draw device and drawn in the window as
   any other (one copy a frame, in the kernel). The screen's own
   memory, no copy, only for a program alone on the screen: later, if
   the copy is what is slow.
7. **The 2D platform on the processor is the same device**: a shape
   made triangles by the program (a polygon cut in triangles, a circle
   a fan, a word's strokes thin rectangles), every one at the same
   depth, the edges smoothed by the four samples. It is a third 2D
   platform, **after** the 3D one and only if the board says that a
   whole frame of shapes is faster by it than by the draw device.
8. **The Pi4's processor: not in this plan.** No manual, a table of
   pages to keep, shaders of another kind: Mesa's work again. The Pi4
   has A and B, on a processor that may be fast enough for B's small
   scenes (a guess).
9. **The Pi 2B is its own plan** (the author):
   [`plan_pi2.md`](plan_pi2.md). It waits for nothing here, and
   nothing here waits for it but the last stage's second column. The
   processor's driver is one file for both boards, the registers'
   address the board's.
10. **The shaders by hand** (the author: "by hand sounds ok v0"):
   three tables of numbers written from the guide, each instruction
   said in a comment. A small assembler of ix's for them is for when
   there are more (a face seen through, pictures on faces).
11. **D, the processor in mini-pi: later** (the author: "I don't fully
   understand v3d so we can see that later once things get more
   concrete"). To ask again at stage 4, with the lists in hand (the open
   questions): it makes stage 4 and after checkable by `make check`,
   and what it checks is the kernel against our reading of the guide,
   not against the board.

## The stages (each checked before the next)

1. **A, on Linux then on mini-9pi.** The geometry, `Playground3d`, the
   3D platform over each 2D one; `examples/Cube3d.ml`, `Cubes3d`,
   `Spheres3d`, `Corridor3d`; mini-ml compiles all of it;
   `games/survey3d.sh` gains the copies' table (lines gained and
   lost). Check: by the `ppm` platform, each example's frame, its
   sum recorded (the playground draws this way in a browser only, its
   svg platform: **no golden frame to hold it against**; looked at by
   the author once, and beside stage 2's picture after); OCaml's build
   and mini-ml's the same bytes; on mini-9pi under both emulators,
   the frame test with these in its list; **ms a frame, draw and
   software platforms, in a table here**.
2. **B.** The seven files of the rasterizer, the software platform's
   3D (its loop is `Plan9_loop`'s; no rays, no pictures on faces, no
   debug views), the `hud` drawn after by the 2D renderer. Check: the
   playground's golden frames (`Cube3d.png`, `Cubes3d.png`,
   `PaintersAlgorithmFail3d_z.png`, `Corridor3d.png` if it has no
   picture), 0 pixels differing or the difference said; ms a frame at
   640 by 480 and 320 by 240, by OCaml, by mini-ml on Linux, under
   QEMU; `games/speed.sh`'s instructions a frame. That table says
   whether C is wanted for more than the lesson.
3. **TinyVirtuaRacing, on Linux and on mini-9pi, slow.** Its
   libraries (`Camera3d Track3d Heightmap Topdown Road`), the game
   with its sound left out (its header saying so), `cached3d` a group.
   Check: its four golden frames by B; and **the frame taken apart**
   (`games/speed.sh`'s instructions: the update, the view, the
   placing, the pixels), by A and by B, in a table here. If the view
   and the update alone are more than a frame's time on a Pi1, the
   game is made lighter there first (the speed plan's candidates), or
   the goal is the Pi2's: said before stage 4.

4. **C, one triangle, on the Pi1.** The guide and the two programs
   read; the card with the firmware that has the 3D (the survey);
   in the kernel: the processor turned on, memory asked, the two
   lists for one triangle of three colours written by a function,
   run, the picture drawn on the screen: first with its vertices
   already placed (the "NV" state, the fewest things that can be
   wrong), **then by the three shaders and a matrix, turning**: what
   the game needs. **No device yet, no program's part**: a kernel that
   shows a triangle at its start, by a flag. Check: the author's
   board, a photo. What is found wrong in our reading goes in
   `docs/plans/bugs/ix.md`.
5. **C, the device and the platform.** Decision 5's messages; depths;
   meshes kept and freed; a platform `v3d` beside the three (the `hud`
   by the 2D software renderer over the picture, or its shapes made
   triangles: decision 7's first use). Check: `Cube3d`, `Cubes3d`,
   `Corridor3d` on the board against stage 2's pictures (photos; or
   the picture read back from the device and compared, the smoothed
   edges apart); ms a frame beside stage 2's.
6. **TinyVirtuaRacing on the Pi1, by the processor**: the goal. Its
   frames a second on the author's Pi1, and on the Pi 2B when
   [`plan_pi2.md`](plan_pi2.md) has it boot, the frame taken
   apart as at stage 3 (the program's part, the messages, the
   processor's), in this file's Status; then what the table says is
   next.
7. **After, each the author's to ask**: the other 3D games, by the
   survey's table (`capture_mouse`, 6: what rio gives a window is to
   look at; `Physics3d`, 7); the 2D platform on the processor
   (decision 7); pictures on faces (the processor's texture memory is
   laid out its own way: the guide's "T-format"); a face seen through
   (a second shader for a pixel); D if not done before 4.

Not in this plan: the ray tracer, the Pi4's processor, the sound
([`plan_audio.md`](plan_audio.md): the engine and the tyres are half
of this game), the Pi 2B's kernel ([`plan_pi2.md`](plan_pi2.md)).

## Open questions

- **D, the processor in mini-pi** (decision 11): asked again at
  stage 4. With it stages 4 and 5 are checked on Linux first and the
  board says only what the guide did not; without it each try is a
  card, a boot and a photo.
- **The device's shape** (decision 5): a file of its own, or the draw
  device's messages?
- **The game's own part on a Pi1** (stage 3 says): if it is too much,
  is the Pi 2B the goal's board?

## Status

2026-10-08: plan written, after the survey (`games/survey3d.sh`).
Nothing built. The same evening, the author's goal (TinyVirtuaRacing
on the Pi1 by its processor) and the Pi 2B: the game surveyed, the
device made one that keeps meshes and places vertices (decision 5),
stages 3, 4 and 6 written for it; the Pi 2B's port its own plan
([`plan_pi2.md`](plan_pi2.md)); the shaders by hand, and the
processor in mini-pi left for later (the author).
