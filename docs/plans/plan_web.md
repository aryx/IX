# Plan: ix in a web page (`raspberry/`, `machine/`, `kernels/lib_machine/`, `lib_playground/platforms/`)

The author (2026-10-10): "how hard would it be to make the whole IX
OS testable from the web? To have IX in the browser, like copy.sh/v86
allows also other operating systems. We already have a raspberry pi
emulator in OCaml, and when using the playground, we can use jsoo and
the ~/playground managed to compile lots of things to js to get the
games played directly on the web". Then: "using mini-pi -q has been
definitely a better experience, because mini-qemu is still slow,
especially for graphics stuff, so we need to find a better solution
there"; "but hopefully we could use on the web the graphics stack of
the web for some things"; "the ~/playground/ experience can probably
be useful, and the web and webgl platform in ~/playground/playground/";
"ideally we would put the card.img somewhere in ~/github/assets/ and
it would be loaded from the emulator compiled to js and running from
the web". Of the routes below: "I like your plan and suggestions".
Then: "ideally we also make tiny-machine working on the web! booting
tiny-kernel and tiny-programs and graphics and tiny-window".

What remains for tiny-machine's page (stage 0, and stage 2's part on
it) is in plan_tiny_web.md.

This is plan_pi.md's phase H' ("the web: mini-qemu by js_of_ocaml, a
Pi1 in a page"), postponed there, taken up here and made larger.

**The short answer: a page that boots ix is a few hundred lines; a
page that is pleasant to use is the real work, because the emulator
compiled to JavaScript is about a third of the speed of the one found
slow.** So four stages: the plain port first (cheap, and it gives the
browser's own number and the card's loading, which every later stage
needs), then either a faster interpreter or a kernel that is itself
JavaScript, with the web drawing its pixels.

## What was measured

`machine/tests/bench_js.sh` (run 2026-10-10, js_of_ocaml 6.2.0 with
`--opt 3`, node 18.19.1, OCaml 4.14.2): mini-5i linked as bytecode,
turned into JavaScript (251 KB), and `bench.py`'s loop of 140 million
instructions run by both.

| | arm32 | arm64 |
|---|---|---|
| native (dune's default profile) | 20.3 MIPS | 20.2 MIPS |
| js_of_ocaml under node | 8.7 MIPS | 5.0 MIPS |

The checksum's bytes are the same four ways. Release's native is
plan_arm.md's 30 MIPS: the ratio is then about 3.5 for arm32 and 6 for
arm64 (Arm64 goes through `Int64`, which js_of_ocaml emulates).

Not measured: anything in a browser (node only); a kernel booted this
way; wasm_of_ocaml (not installed here).

**tiny-machine** (same day, by hand: TinyMachine's bytecode through
js_of_ocaml, 146 KB): `tiny/TinyKernel`'s recorded sessions, natively
(dune's default profile), `windows.events` 230.6 million instructions
in 18.2 s and `tetris.events` 216 million in 17.3 s, 12.6 MIPS, the
screens' sums the recorded ones. **By JavaScript the kernel stops at
once** ("no memory for an image", its own message): `TinyLibCPU` keeps
a word as an int from 0 to 2^32-1 (`m32`, `signed`, `Sltu` and `Ltu`
by a plain `<`), which is right where an int has 63 bits and wrong
where it has 32. So no speed by JavaScript yet; if the ratio is
`machine/`'s, 4 to 5 MIPS, under the 8 million a second -window gives
the machine.

What is known besides:

- **The cores were written for it.** `Bits` holds what depends on an
  int's width (63 bits or js_of_ocaml's 32; plan_arm.md, decision 3),
  `Disasm` has been built by js_of_ocaml since phase 1
  (`machine/tests/dune`), and the cores and devices call nothing of
  `Unix`. To link mini-5i for the benchmark one primitive was missing,
  `unix_environment` (`bench_js_stubs.js`).
- **What of `raspberry/` calls `Unix`**: Main (the terminal, the
  clock, sleeping), Storage (the card's file), Usernet (the host's
  sockets), Status (the clock), Qmp; and Sdl_display links tsdl. Status
  and Usernet are in `ix_raspberry`, which names `unix`.
- **The card**: `kernels/9pi/build/card.img` is 134 MB and 12.9 MB by
  gzip. `~/github/assets/` has `js/`, `pdfs/`, `pngs/`.
- **The kernel is OCaml behind two interfaces**: `Arch.mli` (70
  lines; pi1's is 65 lines of .ml) and `Machine.mli` (34 externals:
  the trap frame, `swtch`, the MMU, the timer, the UART, the
  framebuffer, the registers of a device). Under them for the Pi1:
  `start.s` 426 lines, `l.s` 411, `machine.c` 315, and
  `kernels/lib_machine`'s C (`runtime.c`, `libc.c`, `machine.c`,
  `usb.c`, `shim.c`: 1,354). The pixels are OCaml already
  (`PIXEL=ocaml`, the default: `lib_memdraw`, `lib_memlayer`).
- **mini-5i runs Plan 9's programs without a kernel** (`Plan9.ml`,
  578 lines: the system calls answered by the host).
- **The playground's web platform**:
  `~/playground/playground/platforms/web`, 2,451 lines, WebGL in it.
  ix's `lib_playground/platforms/` has draw, ppm and sdl.

## Stages

### 0. tiny-machine in a page

The smallest whole: tiny-kernel, its programs, its screen and
tiny-windows, in an image of 1.2 MB (`tiny/TinyKernel/boot.img`; no
disk, no card), on a machine of 598 lines and a CPU of 445.

- `TinyLibCPU` right where an int has 32 bits: the unsigned
  comparisons, `signed`, the load of a word, the multiply (what
  `Bits` is to `machine/`, here a few lines of the one file; counted,
  the file being a tiny one). Checked by `tiny/tests` natively, and by
  the recorded sessions' sums under node.
- The window: today another program, `TinyMachineWindow`, fed PPMs by
  a pipe so that TinyMachine links nothing of C's. In a page, a file
  beside it (`tiny/web/`, or `TinyMachineWeb.ml`): the screen's bytes,
  a colour of Plan 9's 256 each, to a canvas; the mouse and the keys
  from the page's events, as `window_poll` reads them from the pipe;
  the console on a text area; a slice of instructions per animation
  frame. TinyMachine's loop, the console's `Unix.select` and the
  window's pipes are what must come apart from the machine for it:
  the machine a library the terminal's program and the page's both
  call.
- The speed: 8 million instructions a second is the machine's with a
  window, and a program's time is the instructions counted. If
  JavaScript gives less, tetris falls slower: then stage 2's kind of
  work on `TinyLibCPU` (it decodes each word at each step), or a
  slower machine in the page, said so.
- The image: `boot.img` beside the page (in `~/github/assets/`), and
  v6's or t6's `kernel.img` with its `fs.img` the same way.

### 1. mini-qemu in a page (the spike)

The machine as it is, compiled by js_of_ocaml.

- `ix_raspberry` without `unix`: Status's clock and Usernet's sockets
  behind records of functions as the rest (or in a library of their
  own, the web's build without them).
- `raspberry/web/` (new): a `Display` on a canvas (the framebuffer's
  RGB16 to an `ImageData`), the keyboard's and mouse's events to
  `Usb`, the card's bytes fetched and kept in memory (`Storage`'s two
  functions; what is written is lost with the page), the UART on a
  text area, a loop that runs a slice of instructions per animation
  frame.
- The card: a gzip of `card.img` and `kernel-pi1-ix.img` in
  `~/github/assets/` (where, and how it gets there, is the author's:
  see "To confirm"), fetched by the page; the browser undoes the gzip
  if the server says `Content-Encoding`, the page's `DecompressionStream`
  if not.
- Measured: MIPS in Firefox and Chrome, the seconds to the shell's
  prompt and to rio's screen, against mini-qemu's and QEMU's.

Expected: the console and the shell usable, rio at a third of
mini-qemu's speed. A few hundred lines.

### 2. A faster interpreter

For the page and for `mini-pi` without `-q` alike. The simple path
kept, each step switchable and measured (the optimization style of
`notes_opti_ocaml.md`), by `bench.py`, `bench_js.sh` and a boot's
seconds:

- where the time goes first, native and JavaScript (callgrind, node's
  `--prof`): the guess is the fetch and decode of each instruction,
  the MMU's walk on every access, the devices' polling;
- blocks of decoded instructions kept by physical page, forgotten
  when the page is written;
- a small table of the last translations in front of `Mmu32`'s walk;
- Arm64 under JavaScript without `Int64` on its common path;
- the graphics apart: what the framebuffer's copy costs per frame
  (`Sdl_display`, the canvas), and whether the guest's time is in
  memdraw's loops (then stage 3 is the answer, not this one).

### 3. A third board, "web": the kernel itself as JavaScript

What "the graphics stack of the web" allows. Beside pi1 and pi4,
`kernels/lib_machine/web/`: mini-9pi's own sources compiled by
js_of_ocaml, its machine a page.

- `Screen` and `fb_init` on a canvas: memdraw, memlayer and Devdraw
  run as JavaScript, not as interpreted ARM. Later, perhaps, Devdraw's
  images as canvases and its draw as the canvas's (the web's
  compositing where its rule is memdraw's; not all of them are).
- The disk: the fetched card, the same one.
- The processes: the card's ARM binaries, run by `Arm32` as mini-5i
  runs them, a system call handed to the kernel (`tf_get`, `tf_set`
  on the interpreter's registers); the user's memory the
  interpreter's, `Mmu` a table per process and no walk.
- The timer and the keyboard: the page's events.

Same card, same binaries, same kernel but the board. To find out
before promising it:

- **`swtch`**: a process asleep inside a system call has a kernel
  stack of its own. JavaScript has one stack. OCaml 5's effects
  compiled by js_of_ocaml (`--effects`) give a stack per process; ix
  builds with 4.14 and 5.x, the kernel by mini-ml, so this board
  would be the one built by OCaml 5 only. The other way, the kernel
  written so that nothing sleeps below a system call's top, is a
  rewrite and not wanted.
- what of the 34 externals and of `runtime.c`, `libc.c` the kernel
  calls that has no obvious meaning in a page (`io_get16`, the FIFO:
  the USB host's registers; here the keyboard is not USB);
- 31 bits: the kernel is written for mini-ml's ints on arm, so
  js_of_ocaml's 32 should be the easy direction; to check by the
  kernel's tests.

Two weeks if effects carry `swtch` and the externals are few; much
more if not. The first step is a week's spike: the kernel to its
console's prompt in node, no screen.

### 4. The programs alone, by the playground's web platform

mini-rio, mini-office, mini-netscape, the games are Playground
programs. The playground's web and WebGL platforms
(`~/playground/playground/platforms/web`) copied to
`lib_playground/platforms/web/`, with a README as each copied
directory has: a program in a page with no kernel under it. It shows
the programs and not the system, and can be done at any time; its
`Web_store` and `Web_http` say how a page keeps and fetches files,
of use to stage 1 too.

### Later, perhaps: wasm_of_ocaml

The author (2026-10-10): "add to the plan as possible future step to
use wasm_of_ocaml and generate wasm stuff".

- What it should give: `Int64` is the machine's (Arm64's loss above),
  and a tighter loop than JavaScript's.
- What it asks: an int there has **31 bits**, and `Bits` knows 63 and
  32 only: a 32-bit word does not fit an int. Either the cores'
  words in `Int32` (boxed natively, C calls by mini-ml: slower
  everywhere else), or two halves as lib_compression's CRC. The Pi1's kernel is written for 31 already, so stage 3's
  kernel is the part that would pass most easily.
- A browser with WasmGC; the page's glue stays JavaScript.

To do after stages 1 and 2 give numbers to compare with: install it,
`bench_js.sh` with a third column on a program that needs no 32-bit
word in an int, then decide.

## Order

0 first (the smallest, and the page's canvas, events and loop are
then written once for 1), then 1, then 2 or 3 by 1's numbers (the guess: 3 is what makes the screen
feel right, 2 is worth doing anyway for mini-pi), 4 whenever wanted,
wasm last.

## To confirm by the author

- where in `~/github/assets/` the card and the page's files go, who
  writes them there (a `make` target of ix, by hand), and where the
  page is served from;
- which card: the full one (documents, pictures, ix's sources: 12.9 MB
  by gzip), or a smaller one for the page;
- `raspberry/web/` for stage 1's directory, `tiny/web/` or one more
  `tiny/TinyMachineWeb.ml` for stage 0's;
- `TinyLibCPU`'s few lines more for 32-bit ints, in a file whose
  lines are counted;
- stage 3's board built by OCaml 5 only, if effects are what carries
  `swtch`.

## Status

2026-10-10: the plan, and `machine/tests/bench_js.sh` with its
numbers above; tiny-machine looked at (stage 0), its CPU found
wrong by JavaScript's 32-bit ints.

2026-10-10, **stage 0 works** (the author: "it's fine adding a few
lines to TinyLibCPU and we can have a tiny/TinyMachineWeb.ml I
think"): tiny-kernel, tiny-windows, and tiny-os v6 and t6 with their
disks, in a page.

- `TinyLibCPU.ult` (5 lines more: an unsigned comparison right for
  63 and 32 bits), used by `sltu`, `bltu`, `bgeu` and by the
  machine's timer, window, pages, disk and events. Nothing else was
  wrong: `m32` and `signed` change nothing where an int has 32 bits.
- `tiny/TinyLibMachine.ml` (new, 342 lines): the machine without a
  host, out of TinyMachine.ml (598 lines, now 306: its terminal, its
  window, its loop). What a host gives: `put`, `on_open`; what it
  calls: `create`, `env`, `tick`, `console_type`, `mouse_set`.
  tiny/mkfile links it; mini-ml compiles it.
- `tiny/TinyMachineWeb.ml` (new, 193 lines) and `TinyMachineWeb.html`:
  a canvas (the screen's byte one store of 32 bits through the 256
  colours), the page's text for the console, its keys and mouse, a
  frame's instructions by requestAnimationFrame, the image fetched
  (`?image=`, `&disk=`). By js_of_ocaml's library, without its ppx;
  92 KB of JavaScript. `./tiny-machine -web dir tiny-kernel` (or v6,
  t6) makes the directory to serve.
- Checked: the five recorded sessions of tiny/TinyKernel under node
  (TinyMachine by js_of_ocaml), their screens' sums the recorded
  ones; `tiny/tests/TinyMachineWeb_test.py` (new: Chrome 151 without
  a screen, by its debugging protocol): the prompt, ls, tiny-windows,
  a window swept, ls in it, the picture looked at; v6 and t6, the
  prompt and ls. Natively: TinyMachine_test, TinyCPU_test,
  TinyGraphics_test, tiny-kernel's, v6's and t6's check; tiny-machine
  built by ix's tools (mini-mk LIB=tiny, a private directory):
  TinyMachine_test and windows.events' sum.
- **The speed, in Chrome: 4.9 million instructions a second for
  tiny-kernel, 3.8 for t6, 2.2 for v6 (its pages), where the machine
  wants 8.** Under node 18, 4.2. So tetris falls at six tenths of its
  speed: stage 2's work, on `TinyLibCPU.step` (each word decoded at
  each step into a fresh value, `load` a closure per access) and on
  `translate`.
- Not done: Firefox, a phone (no keyboard there); tetris played by
  hand; the page in `~/github/assets/`; the test in make test (it
  needs a browser); `js_of_ocaml` in dune-project's depends (the
  executable is `(optional)`); docs/loc.md's line for tiny-machine.

2026-10-10, **stage 2 on tiny-machine, a first round** (the author,
asked whether to start on its speed: "yes"). In Chrome the page goes
from 61% of the machine's speed to **92% for tiny-kernel** (t6 48 to
67%, v6 28 to 39%); under node 4.5 million instructions a second to
8.1, natively 11.5 to 22.0 (`tiny/tests/TinyMachine_bench.sh`, new:
a recorded session by both, node's profile with -prof). Three
changes, each measured alone, the two that are not plain rewrites
behind a switch:

- `TinyLibCPU.load` and `set`: no closure made at each access and each
  step (4.5 to 5.2 under node);
- `TinyLibCPU.keep_decoded`: decode's answers kept by the word, with
  nothing to forget (6.8 to 8.1 under node; natively nearly nothing);
- `TinyLibMachine.ticks`, `batched`: after a tick that looked at the
  events and the interrupts, bare steps to the nearest moment
  something can change (the next event's time, timecmp, a device or
  a control register touched: `touched`); 6.8 to 8.1 under node, 15.2
  to 22.0 natively. TinyMachine's loop and the page's call it.

Checked: tiny-kernel's check (the five recorded screens, which depend
on the instruction an interrupt is taken at; 46 s where it took 75),
v6's and t6's, TinyMachine_test, TinyCPU_test, TinyGraphics_test; the
page's test in Chrome for the three kernels. Left: the address
translation at each fetch (the fetch's closure and `translate`, 30% of
node's time now), which for tiny-kernel and t6 is a window that
changes only with a control register; v6's pages (two loads an
access); Firefox. The playground's notes_opti_ocaml.md has the three
as its section 24.

2026-10-10, **on the website** (the author: "let's make this
available for real on ix website, adding stuff in ~/github/assets/
and referencing it from the IX website"; "maybe we can have a
separate page for t-ix on the website"; "maybe a link from the
toplevel README.md of the project too"): `docs/t-ix.html`, t-IX's
page, the machine in it, the three kernels by `?kernel=`; `make
website` writes `~/github/assets/js/ix/TinyMachineWeb.bc.js` and
`ix/tiny-kernel/boot.img`, `ix/v6/` and `ix/t6/` (kernel.img, fs.img):
5.4 MB. TinyMachineWeb reads the page's variable `tiny_machine` for
its files' addresses. Linked from docs/index.html (the top, the news)
and README.md (the top, tiny-machine's row, now two files and 650
lines). The assets are committed and pushed first, by hand, then the
page.

2026-10-10, **stage 1 works, as a spike** (the author: "let's start
the plan_web.md plan"): mini-9pi boots from its card in a page, to
the shell's prompt on the serial line, and rio on the canvas by the
USB keyboard.

- Nothing of `raspberry/` or `machine/` was changed: the board
  (`Board`) is already apart from its host (`Main`), and what
  `ix_raspberry` calls of `Unix` (Status's clock, Usernet's sockets)
  links by js_of_ocaml, the sockets missing and never called without a
  usb-net. (The library still names `unix`: not separated.)
- `raspberry/tests/Boot_bench.ml` and `boot_bench.sh` (new): the board
  alone, the card in memory, a session on the console; natively and
  under node. **The same 301 million instructions to the prompt both
  ways**; release: native 20.4 million a second (14.7 s), node 18 5.9
  (51.5 s). Dune's default profile compiles the JavaScript file by
  file: 3.3 (91 s).
- `raspberry/web/MiniQemuWeb.ml` (new, 270 lines) and
  `MiniQemuWeb.html`: the framebuffer on a canvas (RGB565 through a
  table), the UART as the page's text, the keys the UART's or, the
  screen clicked, the USB keyboard's by the event's code; the mouse
  relative, the pointer kept in the screen (pointer lock); the kernel
  and the card fetched (`?kernel=`, `&card=`, or the page's variable
  `mini_qemu`), a `.gz` undone by DecompressionStream; a frame's
  instructions by the board's clock, `ips` 6 here (`?ips=`) where a
  terminal's is 30. 163 KB of JavaScript.
- `raspberry/tests/MiniQemuWeb_test.py` (new): Chrome 151 without a
  screen. **The prompt 87 s after the page is opened** (the card's 13 MB
  by gzip fetched from this machine in it), `ls /bin | wc` on the
  serial line, the screen clicked and `rio` typed on the USB keyboard:
  its screen 21 s later. 3.5 million instructions a second in the page
  (a frame gives the board 12 ms of 16.7, and the screen's megabyte is
  read and compared every third frame).
- node's profile of the boot: `Arm32.execute` 37% of the time itself,
  `Board.run` 19%, `Mmu32.translate` 6%, the collector 5%, strings made
  from bytes 5% (the card's blocks, `Memory.read_string`), `decode` 3%,
  the decode cache emptied 3%. No closure per instruction as
  tiny-machine had: stage 2 here is the interpreter's own work.
- Not done: the mouse tried (the test clicks once; no menu, no window
  swept); Firefox; a real browser by hand; the page on the website and
  the card in the assets (13 MB: the author's to say); `mini-pi -web`;
  the screen read without a string of it at each look; the card's
  writes kept; `ix_raspberry` without `unix`.

2026-10-10, **stage 1 on the website, as a baseline** (the author:
"let's add a make website and start an m-ix.html page like we did for
t-ix"; "so we have a baseline"): `docs/m-ix.html`, m-IX's page, the
board in it; `make website-mini` (and `make website` through it)
writes `~/github/assets/js/ix/MiniQemuWeb.bc.js` (release) and
`ix/mini-9pi/kernel.img.gz`, `card.img.gz` (gzip -9 -n: 2.3 and 13.2
MB; each new card is as much again in the assets' history).
MiniQemuWeb takes a `.gz` name with a `?v=1` after it. Linked from
docs/index.html (the top, the news), docs/t-ix.html and README.md.
The page served from this machine with the assets' files: the prompt
after 110 s (the card's eleven binds at boot now), rio's screen 23 s
after it is typed, 3.6 million instructions a second.
The live page (https://aryx.github.io/IX/m-ix.html), Chrome 151
without a screen: the prompt after 115 s, rio's screen 23 s after it
is typed, 3.4 million instructions a second. The author, in a
browser of his own: "ok it works! But it is super slow as we
expected." Next: stage 2 on `machine/` and `raspberry/` (the profile
above), measured by `boot_bench.sh` and the page's test.
