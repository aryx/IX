# m-ix: the switches of its programs

m-ix is the mini half of ix: the programs that are twins of real ones
(mini-netscape, mini-office, mini-doom, mini-quake,
mini-virtuaracing, mini-emacs, DrScheme, the games), run on Linux in
a window or under mini-9pi on the Pi. This
manual gathers what can be changed when one is started, without
editing a source: the `name=value` flags, the options, the
environment, and the device files of mini-9pi that switch a
behaviour. Most of these switches are there to measure: a speed's
gain is seen by turning it off
([notes_opti_inventory.md](../notes_opti_inventory.md) says what each
one buys). The programs' headers and usage lines are the first
source; where this manual and a header differ, the header is right.

The author, 2026-10-22: "maybe we can have a docs/manual/m-ix.md where
we document all those heap=mode, redraw=top, etc."

## 1. How a flag is written

A program of the playground takes options (`-frames n`, ...), then
words: a word `name=value` is a flag, a word without `=` a flag of
value "" (`Playground.flags_of_strings`). A program sees its flags in
`computer.flags`; the platform it runs on reads some of them too.

On Linux, `bin/` holds the SDL builds:

    bin/mini-doom map=E1M2 scale=3
    dune exec games/arcade/TinyCameltry.exe -- rotation=off

Under mini-9pi, `=` is rc's: each flag is quoted.

    cameltry 'stats=on'
    netscape 'stats=on' 'redraw=top' news.ycombinator.com
    tronscroll 'net=join' 'host=192.168.9.1'

The platform reads its flags from the command line, not from the ones
the program passes on (section 8 says where that differs).

## 2. Every playground program

Options (Session):

| option | what |
|---|---|
| `-frames n` | n frames at once, no clock, the script's keys in them; then the picture stays (a test's session) |
| `-dump-frame n file` | the ppm platform: frame n written to a PPM file; elsewhere the same as `-frames n` |
| `-fixed-time s` | the program's clock stays at s seconds |
| `-script script` | what is pressed, frame by frame (Input_script.mli) |
| `-dump-audio file` | the session's sound: a WAV on Linux; on mini-9pi raw 16-bit samples (`-dump-audio /dev/audio` plays it) |
| `-v`, `-debug` | the log's level: Info, Debug |

Flags of the platforms:

| flag | default | what | where |
|---|---|---|---|
| `size=n` | SDL: the screen's height less 40, at most 1000; ppm: 1000; draw: the window's | the picture's side in pixels (draw: at most) | SDL, ppm, draw |
| `window=WxH`, `window` | the 1000-unit square | the program's screen is the window's, a unit a pixel, following its size (draw: the window's starting size when it fits, F4) | SDL, ppm, draw |
| `pace=n` | as fast as computed | n frames a second by the clock (two programs over a network) | ppm |
| `heap=modest` | the games' collector (`space_overhead` 700, eight times what is alive) | the collector's default: a program that keeps much (office, page, netscape, doom, quake and virtuaracing pass it themselves) | mini-9pi |
| `heap=game` | the collector's default | the games' setting, as on mini-9pi, to count a board's instructions | ppm |
| `keys=on` | off | the keys down at each of /dev/kbd's messages, on the standard error | mini-9pi |

## 3. Speed and measuring

| flag | default | what | where |
|---|---|---|---|
| `stats=on` | off | every 40 frames, on the standard error: the frames' time, the update, the view, the showing, the heap; on the draw platform also the messages against the device's time (white, shapes, copy) and the letters sent | mini-9pi |
| `redraw=all` | what changed only | each frame drawn whole: what Redraw saves | all |
| `redraw=top` | inside the groups | what changed looked for at the top of the list only, a group compared whole (Redraw before 2026-10-22) | all |
| `redraw=each` | the last frame only | the ppm platform draws every frame through Redraw, as a window does: the same picture (games/tests/frames.sh) | ppm |
| `late=N` | 8 | a late program's ticks before a frame, at most (`late=30`: as before 2026-10-11) | mini-9pi |
| `fps=off` | on | no frames-a-second counter at the bottom (a recorded session waits for a still screen) | draw |
| `font=hershey` | Plan 9's font for an upright word of 11 to 16 pixels | a word always in Hershey's strokes | draw |
| `letters=strokes` | a letter loaded once into the kernel, then one message | each letter's strokes sent as lines and polygons | draw |
| `letters=bits` | smoothed letters, a byte a pixel | a bit a pixel, ragged | draw |
| `kscale=off` | the device scales | a picture at its own size made larger by the program, k by k, not by the draw device's 'z' (F5: the largest whole multiple that fits, centred) | draw |

"draw" is the draw platform, mini-9pi's default (the kernel draws);
"mini-9pi" is it and the software platform (the program draws, the
kernel copies). The scripts that use these: kernels/9pi/tests/perf/
(`frames.sh`, `hover.sh`, `redraw.sh`).

## 4. The programs' own flags

**mini-netscape** (its usage line: `mini-netscape -h`):

| flag | default | what |
|---|---|---|
| an address, `url=` | about:home | the page; a word with `:`, `/` or `.` is one |
| `scripts=off` | on | no JavaScript |
| `console=on` | off | the scripts' prints and errors on the standard error |
| `strict=on` | off | a script that does not parse refused whole; a missing DOM method a TypeError |
| `helpers=off` | on | no helper program (mini-page for a PDF, mpv) |
| `keep=off` | on | a connection a request |
| `worker=wait`, `worker=off` | a worker beside the window | wait: the window waits for each of its pieces (tests); off: done in the window's |
| `profile=DIR`, `profile=off` | ~/.config/mini-netscape | where cookies, zooms, history, bookmarks are kept |
| `window=WxH` | the last size | the window at first |
| `settle=off` | on | a layout made at each of the scripts' changes, not once when the page's work is done (Tab.settles: an optimization off) |
| `draw=all` | lazy | a line's shapes built at once, not when first shown (Browser_draw.lazily) |
| `view=each` | kept | the view made again at each frame, not kept while what it shows is the same |

Its helpers are given the file only: mini-page sees none of these
flags.

**mini-page**: `mini-page file`, `-t file` (text), `-ppm n file out`.
**mini-office**, **DrScheme**: no flag of their own; the platform's
apply.

**mini-doom**:

| flag | default | what |
|---|---|---|
| `wad=file` | /lib/doom/freedoom.wad, else games/fps/doom/data/ | the WAD |
| `map=E1M1` | the WAD's first | the level |
| `scale=n` | 2 (1 to 4); on mini-9pi the largest whole n the window holds | each of Doom's 320 by 200 pixels n by n |
| `x=`, `y=`, `angle=` | the level's start | the player placed there (a test's camera) |
| `nomonsters` | the monsters | the level without them (Doom's -nomonsters) |
| `ai=ways` | id's (Enemy) | the monsters find their way by the playground's AI (Ways) |
| `things=off` | on | no item, decoration nor monster drawn or moved (tests/compare.sh) |
| `sound=off`, `sound=3d` | id's | no sound; the playground's Audio3d |
| `music=on`, `music=off` | on; off on mini-9pi (mini-ml's MIDI too slow) | the level's music |
| `graphics=only` | | `nomonsters things=off sound=off music=off`: the renderer alone |
| `status=off` | on | no status line (tests/compare.sh) |
| `lumps` | | the WAD's lumps listed, then the end |

**mini-quake** (its header's usage):

| flag | default | what |
|---|---|---|
| `bsp=file` | /lib/quake/e0m1.bsp, else games/fps/quake/data/e0m1.bsp | the level; its palette and colormap beside it |
| `scale=n` | 2 (1 to 4); on mini-9pi the largest whole n | each pixel n by n |
| `x=`, `y=`, `z=`, `angle=`, `pitch=` | the level's start | the eye placed there (a test's camera) |
| `gamma=g` | 0.7 (0.3 to 1) | the brightness; 1 the palette as it is |
| `lightmaps` | | the textures grey: the lightmaps alone |
| `models=simple` | by gradients | the models' triangles the first way (Alias.gradients) |
| `nomonsters`, `things=off`, `ai=ways`, `sound=off\|3d`, `music=on\|off`, `graphics=only` | | as mini-doom's (music: the level's Ogg track, off on mini-9pi) |
| `weapons=all` | | every weapon and its ammunition (Quake's impulse 9) |
| `entities`, `precache` | | the level's entities, or what the game reads beside it, listed, then the end |

**mini-virtuaracing** (its header's usage):

| flag | default | what |
|---|---|---|
| `view=` | close | `behind`, `overhead`, `cockpit`: the view at the start |
| `picture=WxH` | 320x240 | the picture's size, each pixel `scale=n` by n (2; on mini-9pi the largest whole n) |
| `course=n` | the title | a race on the n-th course at once (0: Big Forest) |
| `stats` | | each frame's faces and the race on the standard error |
| `sound=off` | on | no sound |
| `render=` | depth | `painter`, `table` (the PlayStation's ordering table): how hidden faces are hidden |
| `cull=off`, `lod=off`, `layers=off` | on | the faces turned away drawn; the far road whole; the ground sorted with the rest (painter, table) |

**The games**:

| program | flag | what |
|---|---|---|
| Tetris | `seed=n` | the first pieces (default: the clock) |
| Tetris | `music=off` | no theme |
| TinyCameltry | `rotation=off` | the moon upright (also the key U) |
| TinyCameltry | `hitboxes` | what the physics sees, drawn |
| TinyBreakout (Juice) | `juice=off` | the dry game |
| TinyTronscroll | `map=WxH` | the arena (800x600; 640x400 to 1600x1200) |
| ReBirth | `skin=NAME` | rb-338, night, plain |
| ReBirth | `meters=off` | no spectrum, no scope |

**Two players** (Multiplayer: TinyTronscroll):

| flag | default | what |
|---|---|---|
| `net=` | local | `simulate` (two in one window), `host`, `join` |
| `netcode=` | lockstep | `rollback`, `1997` |
| `delay=` | 3 (lockstep), 0 | ticks before a key applies |
| `latency=`, `jitter=`, `loss=` | 50 ms, 10 ms, 5 % | `net=simulate`'s network |
| `seed=` | 1 | `net=simulate`'s chance |
| `bind=`, `host=`, `port=` | 127.0.0.1, 127.0.0.1, 7777 | the addresses (`bind=0.0.0.0`: a LAN; not on mini-9pi) |
| `ticks=on` | off | each second, the tick and whether the two agree, on the standard error |

**mini-emacs** is not a playground program: options, not flags. On
Linux `-q` (no configuration), `-scale n` (2), `-rows n` (40), `-cols n`
(100), `-nocache`; on mini-9pi `-q`, `-time` (each painting's ms on
the console), `-nocache`.

## 5. The environment

| variable | what |
|---|---|
| `ML_HEAP=words` | a program by mini-ml: a heap half's first size, in words (1M on Plan 9, 256K on Linux); it doubles when needed |
| `ML_TRACE` | a program by mini-ml on Linux: the raise's trace when an exception escapes (always on Plan 9) |
| `IX_LOG=level` | the log's level of a program that sets one up (mini-netscape) |
| `HOME`, `PATH`, `TMPDIR` | mini-netscape's helpers: ~/.mailcap, where they are found, where a file is written for them |

Chosen when the kernel or the card is built, not when a program
starts: `PIXEL=ocaml|c` (the kernel's pixels: ours, or principia's C),
`COMPILER=ocaml` (the kernel by OCaml, not mini-ml), `BOARD=`
(kernels/9pi/Makefile); on the card's FAT, `config.txt` (the board's
clock) and `ip.txt` (its address).

## 6. mini-9pi's device files

| write | to | what |
|---|---|---|
| `draw N` (0 to 7) | /dev/swap | which of the kernel's pixel copies give its lock back: 1 a copy, 2 a fill's rows, 4 a flush; 0 none, 7 all (the default) |
| `swap`, `scrollswap`, `buttonmap m`, `accelerated a`, `linear` | /dev/mousectl | the buttons swapped, the wheel turned over, the acceleration |

## 7. Switched in the source only

Each optimization keeps its slow way in an `old:` comment, and some a
switch, but a ref set in the source, not by a flag: `Opti.enabled`
(lib_graphics), the draw platform's `fast`, the kernel's
`Memdraw.fast` and its `fast_*` (each path of the pixels),
`Swcursor.enabled`, `Mini_opti.enabled` and `compiled` (mini-netscape's
JavaScript), `Synth.band_limited`, `Space.ears_apart`, `Mixer.stereo`.

## 8. The toolchain: how the programs are compiled

The author, 2026-10-29: "let's explain those register allocation (and
what 'gives to allocator' mean) in m-ix.md", "a section on the
toolchain in addition to sections on hardware". Every program of m-ix
is compiled by ix's own tools: its ML by mini-ml, its C (mini-ml's
runtime, the C library, the kernels' C) by mini-cc, then mini-asm,
mini-ar and mini-ld.

### The compilers' levels

| compiler | flag | what | where it is chosen |
|---|---|---|---|
| mini-ml | `-O3` | every optimization: Opti's passes, constants folded, the back end in SSA form (`-ssa`), inlining | the mkfiles' `MLOPT` (mkfiles/mkconfig), `-O3` unless set |
| mini-ml | `-O0` | none: the stack machine's code as Lower makes it | `MLOPT=-O0` |
| mini-cc | (none), `-O0` | 5c's code byte for byte, 5c `-O0`'s: every variable in memory (compat) | the default |
| mini-cc | `-simple` | the stack machine, its depth k in the k-th register | |
| mini-cc | `-simple -O` | Opti's passes on it, variables in registers by loop weight (regs), Peep | |
| mini-cc | `-O3` | `-simple -O -ssa`: values in registers by SSA form's coloring (languages/c/ssa/) | lib_core's mkfile (the runtime, the libc's C), the kernels' mkkernel (`COPT=-O3`; `COPT=` for compat's) |

The tests' switches of the same: `RUNTIME_FLAGS` (mini-ml's
tests/run.sh: mini-cc's flags for the runtime, `-O3` by default, empty
for compat's), `CC_FLAGS` (languages/c/tests/bench.sh), `SIMPLE_FLAGS`
(languages/c/tests/simple.sh), `ML_FLAGS` (mini-ml's tests).

### The registers on arm

A register allocator decides which values of a function live in the
machine's registers, and which in its frame (a slot, loaded at each
use and stored where the value is made). "The allocator's registers"
are those it may give a value; a scratch register is one the code
generator keeps for itself, to load a value that lives in a slot just
for the instruction that reads it, or to compute a value that goes to
a slot; a reserved register has a role of its own for the whole
program, which no compiler touches. Plan 9's arm convention (5c's
txt.c, 5l's 5.out.h) gives each register its role:

| register | role | mini-cc -O3 (ssa/) |
|---|---|---|
| R0 | the result, the first argument | the scratch |
| R1-R8 | the compiler's: 5c allocates R0-R8 | the allocator's (R8 the second scratch in a function that needs one) |
| R9 | an external register (`extern register`: a Plan 9 kernel's `up`, the current process); in ix, mini-ml's temporary | reserved |
| R10 | an external register (a Plan 9 kernel's `m`, principia's `cpu`, this processor's state); in ix, mini-ml's value stack's top for a program's whole run | reserved |
| R11 | the linker's temporary (a long constant, a far branch) | reserved |
| R12 | the static base, SB | reserved |
| R13 | the stack pointer | reserved |
| R14 | the link register, the return address | reserved |
| R15 | the PC | reserved |
| F1-F6 | floating point (VFP) | the allocator's |
| F0, F7 | | the scratch |

Why R9 and R10 stay reserved though no C in ix declares an `extern
register`: mini-ml's code keeps its value stack's top in R10 (R26 on
arm64) for the whole run, across the C it calls. Before a call it
stores it to `ml_vsp` (the runtime's, for the collector) and never
loads it back after; nothing declares this, it holds because 5c and
mini-cc never allocate R9 and R10 (5c's `txt.c` reserves them in every
file). C that used R10 would lose the ML caller's values. R9 is
mini-ml's temporary, used only between calls as far as its code was
read, but nothing guarantees it: the rule keeps both. The kernels'
`swtch` keeps R10 across a switch too (kernels/lib_machine/pi1/l.s).
Where it is written: mini-ml's Emit (its machine records), the
runtime's `ml_vsp`, mini-cc's Ssa_gen (its registers).

No register is saved across a call by the one called (Plan 9's
convention: the caller saves): a value live across a call is either
in a slot for its whole life, or in a register stored to its slot
where it is made and loaded after each call, whichever costs fewer
instructions by the loops they are in (languages/c/ssa/Alloc.mli).
On arm64 the allocator has R1-R15 and R19-R25, F1-F15 and F17-F23;
R0 and R16 are the scratch. mini-ml's back end has its own: its
values live on a value stack the collector scans
(languages/ml/ssa/Alloc.mli).

## 9. What does not hold yet

Found while writing this page (2026-10-22), not changed:
- A flag of the platform is read from the command line on SDL, the
  draw platform and Plan9_loop (`stats`, `late`, `keys`), but from the
  program's flags for `heap`, `window` and the ppm platform's. So
  mini-doom's `size=320n`, given for mini-9pi, reaches only ppm; and
  TinyWolfenstein, which passes no flag, takes none of ppm's.
- `heap=` is `modest` on mini-9pi, `game` on ppm, nothing on SDL.
- `stats=` and `late=` exist only on mini-9pi; `fps=`, `font=` and
  `letters=` only on the draw platform; `size=` not on the software
  platform.
- Said, not read: `letters=segments` (Mini_opti.mli), `netcode=server`
  (Multiplayer.mli).
- `-dump-audio` writes a WAV on Linux, raw samples on mini-9pi.
