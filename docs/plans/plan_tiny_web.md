# Plan: what remains for tiny-machine in a web page (`tiny/`, `docs/t-ix.html`)

The author (2026-10-10): "ok let's put what remains in a
plan_tiny_web.md document; right now it runs at 100% on my macbook
pro. Also what you mean 100%? because the goal is 8 millions
instructions per second? so 8 MIPS? How does it compare to the host
machine?"

plan_web.md is the whole of ix in a page; its stage 0 (tiny-machine in
a page) is done and on the website
(https://aryx.github.io/IX/t-ix.html), and a first round of its stage
2 was done on tiny-machine. This plan is what is left of that for the
tiny system; mini-qemu in a page (plan_web.md's stages 1, 3 and 4) is
not here.

## What "100%" means

- **The machine has a speed of its own: 8 million instructions a
  second** (`TinyLibMachine.rate`), so 8 MIPS, yes. A program's time
  on it is the instructions counted (the timer counts them), and the
  host that shows it to a person, the SDL window or the page, lets it
  run that many each second and no more: tetris falls the same on a
  fast host and on a slow one. Without a window (`./tiny-machine
  tiny-kernel` in a terminal, the recorded sessions) nothing holds it
  back.
- **The page's line is the part of that pace the browser kept** over
  the last second: instructions run, over 8 million times the seconds.
  "Full speed" is 97% and more. It can never say more than 100%: at
  each frame the page runs what is due and stops.
- **What full speed asks of the browser**: a frame is 16.7 ms and the
  machine may take 12 of them (`budget`), so the 133,000 instructions
  of a frame must fit in 12 ms: about 11 million a second, unheld.
- **Why 8**: chosen with the window, by hand, for tetris and the
  window system to feel right; it is not a measure of anything.

## Against the host

Measured here (a Neoverse-N1 at 2.2 GHz, dune's default profile,
`tiny/tests/TinyMachine_bench.sh`, the machine not held):

| tiny-machine | instructions a second |
|---|---|
| native | 22.0 million |
| js_of_ocaml under node 18 | 8.1 million |
| the page in Chrome 151 | 7.4 million shown (92% of 8), so about 10 unheld |
| the page in Firefox 157 | 2.1 to 2.6 million (26 to 33%), before the first round |

- The host itself runs a few thousand million instructions a second
  on one core (not measured: no `perf` here; 2.2 GHz and two to three
  instructions a cycle). So the machine at its pace is **about a
  thousandth of the host**, and the interpreter spends some hundreds
  of the host's instructions on each of the machine's natively, more
  by JavaScript.
- 8 MIPS is the order of a workstation or a PC of about 1990 (a 386
  at 25 to 33 MHz, a 68030), with a simpler instruction set.
- Not known: how far over 11 million the author's MacBook Pro is. The
  page says "full speed" and nothing of the margin (step 1 below).

## What remains

### 1. The speed

The simple path kept, each change behind a switch and measured alone
(`TinyMachine_bench.sh`, then the page's test), as the first round.

- **The margin, shown.** The page measures what it could do: the
  milliseconds a frame's instructions took, so "full speed, using 40%
  of a frame". Or `?rate=0`: not held, the instructions a second said.
  A number from the author's machine and from Firefox then costs a
  look, and it is this plan's measure.
- **The address translation at each fetch**: 30% of node's time. For
  tiny-kernel and t6 the translation is a window that changes only
  with a control register (`touched` knows when); for v6, the page of
  the program counter kept until it leaves it or the pages change.
  Expected: tiny-kernel at full speed in Chrome here, t6 (67%) near
  it.
- **v6's pages**: two loads an access; a small table of the last
  translations, forgotten when `satp`'s register or a page table is
  written (39% today).
- **Firefox**: measured again after the first round, then its own
  profile if it stays far under Chrome.
- **Or the pace lower in the page** (6 million?), said on the page:
  only if the above does not reach it, since the recorded sessions and
  the window's feel are tuned to 8.
- wasm_of_ocaml: plan_web.md's "Later, perhaps"; `TinyLibCPU`'s words
  do not fit its 31-bit ints.

### 2. More to run on tiny-kernel's image

Today: the shell and its tools, tiny-windows, tetris, paint, square.
Candidates, for the author to pick:

- the TinyPlayground games that fit the screen and tiny-ml's subset;
- small C tools by tiny-c (as t6's and v6's user programs);
- demos in ML that draw (a clock, life, a Mandelbrot in integers);
- tiny-editor on a file of the image;
- tiny-db with a toy file: not as it is (modules, `Seq`, `Hashtbl`,
  `Int64`, `lseek` are outside tiny-ml's subset and the kernel's
  calls); a port is a rewrite of its storage.

Each one is a line of `tiny/TinyKernel/Makefile`, bytes in `boot.img`
(1.2 MB today) and a line of "What to try" in `docs/t-ix.html`.

### 3. The page

- a phone: no keys there; a row of keys on the page, or the system's
  keyboard by a hidden input;
- text pasted into the console;
- v6's and t6's disk: what is written is lost with the page; kept in
  the browser's storage, with a way to start afresh;
- a recorded session played in the page (`?events=`), as a demo and
  as a test whose screen can be compared with the recorded one.

### 4. Leftovers

- `js_of_ocaml` in dune-project's depends (the executable is
  `(optional)` today);
- `docs/loc.md`'s line for tiny-machine (two files now, and the
  page's);
- `make website` and the `?v=` number: bumped by hand in
  `docs/t-ix.html` today, the assets pushed by hand first;
- `TinyMachineWeb_test.py` is not in make test (a browser, half a
  minute); Firefox has no test (driven by hand once);
- tiny-machine built by mini-ml since `keep_decoded` and `ticks`: not
  checked;
- tetris played by hand in the page: the author's to say;
- the playground's `notes_opti_ocaml.md`, section 24: written, not
  committed there.

## Order

1's first item (the margin shown: a few lines, and it says whether
the rest of 1 matters on a given machine), then the fetch's
translation, then 2 by the author's choice; 3 and 4 as wanted.

## To confirm by the author

- which programs for 2;
- whether the page's line should say the margin always, or only with
  a parameter;
- whether 8 million stays the pace everywhere.

## Status

2026-10-10: the plan. Done before it (plan_web.md's Status): the
machine in a page, the three kernels, the website, the first round of
speed (61 to 92% in Chrome here; full speed on the author's MacBook
Pro).
