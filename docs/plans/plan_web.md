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

1, then 2 or 3 by 1's numbers (the guess: 3 is what makes the screen
feel right, 2 is worth doing anyway for mini-pi), 4 whenever wanted,
wasm last.

## To confirm by the author

- where in `~/github/assets/` the card and the page's files go, who
  writes them there (a `make` target of ix, by hand), and where the
  page is served from;
- which card: the full one (documents, pictures, ix's sources: 12.9 MB
  by gzip), or a smaller one for the page;
- `raspberry/web/` for stage 1's directory;
- stage 3's board built by OCaml 5 only, if effects are what carries
  `swtch`.

## Status

2026-10-10: the plan, and `machine/tests/bench_js.sh` with its
numbers above. Nothing else done.
