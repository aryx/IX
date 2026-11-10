# Plan: one system interface for the tiny programs, TinyLibSystem, and TinyCalls private to tiny-kernel's side

Status: **stages 0 to 4 done (2026-11-10): one interface, TinyLibSystem; stage 5 (no user/) to do.**
Written 2026-11-10, after the author's question: "now since we have
TinyLibSystem.mli, do we need TinyCalls.mli? seems they offer similar
services", and then: "It seems confusing to have both those
TinyLibSystem.mli rethought system interface, free of unix and sys, and
yet another TinyCalls.mli with similar content like fd_stdin which could
go also in TinyLibSystem.mli; u_read seems very similar to reading
function in TinyLibSystem"; and: "yes, write the plan".

Companions: [`../../tiny/system/README.md`](../../tiny/system/README.md),
the two interfaces as they are; [`done/plan_tiny_windows.md`](done/plan_tiny_windows.md),
where TinyCalls was born, for the window programs tested on the host.

## Context

`tiny/system/` has two interfaces a tiny program asks its system through:

| interface | what it is | its users | its implementations |
|---|---|---|---|
| `TinyLibSystem.mli` (314 lines) | a tool's system, rethought: `Fpath.t` paths, capabilities, `Failure` with a reason, one module where OCaml has `Sys` and `Unix` | the tools: tiny-shell, tiny-utils, tiny-editor, tiny-c, tiny-ml, the assembler and the linker, tiny-build, tiny-db, tiny-vcs, tiny-prof | `unix/` (OCaml's `Unix`, lib_core), `tinykernel/` (over TinyCalls, by tiny-ml) |
| `TinyCalls.mli` (120 lines) | tiny-kernel's calls as they are: ints for descriptors and flags, `-1` for an error, no capabilities, strings for paths | the graphical side: TinyLibPlayground, TinyLibGUI, TinyBrowser (and TinyBrowserScreen), TinyEditorScreen, TinyPlay, the mains in `user/`; and, with the calls only tiny-kernel has, TinyDebugger and TinyTracer | `tinykernel/` (externals, `mlsys.c`), `sdl/` (a window on the host), `stub/` (the tests') |

The split is history, not design: TinyCalls came first (2026-10-08,
plan_tiny_windows.md), for a game tested on the host; TinyLibSystem
later, for the tools, and was thought out as an interface of its own
(its header: why not a `Sys` and `Unix` subset). Next to it TinyCalls is
the odd one: what it offers overlaps (`u_open`, `u_read`, `u_write`,
`u_close`, `u_stat` against `open_in`, `read`, `write`, `close`, `stat`),
in a lower style, and the overlap is written twice more:

- `sdl/TinyCalls.ml` opens, reads, writes and stats the host's files
  itself, which `unix/TinyLibSystem.ml` already does;
- `TinyLibGUI.read_file` and `write_file` exist because a graphical
  program links no TinyLibSystem (TinyLibGUI.mli says so).

Plan 9 has one layer here: libdraw opens `/dev/draw` and reads the
mouse with libc's `open` and `read`; the system calls' stubs are libc's
inside. The counterpart here: TinyLibDraw, TinyLibPlayground and
TinyLibGUI on TinyLibSystem, and TinyCalls tiny-kernel's side's own, a
detail of `tinykernel/` as Plan 9's stubs are of libc.

## Goal

- One interface a program sees, `system/TinyLibSystem.mli`, for the
  tools and the graphical programs alike.
- `TinyCalls` private to `system/tinykernel/`: the externals that file
  is written over, no `.mli` in `system/`, no `tiny_calls` library.
- On the host, the window one more implementation of TinyLibSystem,
  sharing the Unix code (files, processes) with `unix/`, adding the
  window's descriptors 0, 3 and 4; the stub one more, as small as now.
- Nothing a program does changes: the same screens, sounds and outputs
  (`make -C tiny/TinyKernel check`'s screens and samples, the tests'
  outputs), but for addresses (`debug.cksum`, `check.expected`).

## What TinyLibSystem gains

What the graphical side asks of TinyCalls that TinyLibSystem has not:

| TinyCalls | TinyLibSystem, proposed | who |
|---|---|---|
| `fd_stdin` ... `fd_mouse` | the same names (the descriptors a window gives: its keys, console, errors, drawing, mouse) | all |
| `u_ready fds n until` | `ready : fd list -> milliseconds option -> fd option` (the first that can be read, until a deadline from `millis`, None then) | the GUI's loops, the playground, the browser, the debugger and the tracer |
| `u_ticks` (400 a second) | `millis`, there already | the playground's frames, the GUI's waits |
| `u_seed` | `seed : unit -> int` | the playground |
| `u_rawcons` | `raw_console : < Cap.tty?; .. > -> bool -> unit` | the GUI (^C a key) |
| `u_dial address port` | `dial : < Cap.network; .. > -> string -> int -> fd` (Failure when refused) | the browser |
| `u_spawn path args` | `spawn : < Cap.exec; .. > -> Fpath.t -> string list -> pid option` (shell has the same road, by rc) | the browser (play, page) |
| `u_argc`, `u_arg` | `main`'s arguments, there already | the mains |
| `u_open` and its flags, `u_read`, `u_write`, `u_close` | `open_in`, `open_out`, `read`, `write`, `close`, there already; `/dev/audio` opened by `open_out` | the playground's speaker, TinyPlay, the GUI's files |

TinyDebugger and TinyTracer also ask for `u_trace`, which no other
system has, and for fork, exec, waits, kill, pipe, dup and seek, which
TinyLibSystem has in its own words. See question 3.

## Stages

Each stage builds and passes the checks alone (below), and is a commit.

0. **The layout first**, a move only (the author: "keep TinyLibCore/
   and have a TinyLibSystem/ and have even the tiny/TinyLibSystem.mli
   interface file ... and then TinyLibSystem/ could get subdirs for each
   virtual modules instantiations"): `tiny/system/` becomes
   `tiny/TinyLibSystem.mli`, beside the tools that name it, and
   `tiny/TinyLibSystem/`, its parts, as TinyC.ml and TinyC/ are, with
   `unix/`, `tinykernel/`, `sdl/` and `teststub/` (old: `stub/`), and
   TinyCalls.mli until stage 4. The virtual library's stanza goes to
   `tiny/dune`, beside its `.mli`, as dune wants. The stages below say
   `system/`'s names, the plan's when it was written.

1. **TinyLibSystem.mli grows** the rows above (descriptors, `ready`,
   `seed`, `raw_console`, `dial`, `spawn`), implemented in
   `tinykernel/` (over its TinyCalls) and `unix/` (`ready` by
   `Unix.select`; `dial` refused, as the stub's: no wire on the host
   but the window's; `spawn` by `Unix.create_process`). No caller yet.
2. **The host's implementations share the Unix code.** `unix/`'s body
   moves into a plain library (a module of another name, say
   `TinyHostSystem`), which `unix/TinyLibSystem.ml` includes;
   `sdl/` becomes an implementation of `tiny_lib_system` too: that
   library for files and processes, the window for descriptors 0, 3 and
   4, the wire's port 70 for `dial`, the speaker for `/dev/audio`
   (today's `sdl/TinyCalls.ml`, its file code dropped). `stub/` becomes
   an implementation of `tiny_lib_system`: no files (Failure), what is
   drawn kept, no key, no clock; still compiled by tiny-ml too, for the
   tests on tiny-cpu (question 1). The test hook, `drawn`, leaves the
   interface (question 2).
3. **The graphical side moves**, a library or a program at a time:
   TinyLibPlayground (`run caps g`), TinyLibGUI (`run_canvas caps ...`,
   its own `read_file` and `write_file` gone for TinyLibSystem's),
   TinyBrowser and TinyBrowserScreen, TinyEditorScreen, TinyPlay, the
   mains in `user/` (`TinyLibSystem.main`, as the tools'), the tests'
   `Host.ml`. Each passes capabilities as the tools do; on tiny-kernel
   they are read and forgotten (`tinykernel/`'s `type Cap.all_caps =
   < >`), on the host they are OCaml's checks.
4. **TinyCalls private.** `system/TinyCalls.mli` and the `tiny_calls`
   library go; `tinykernel/TinyCalls.ml` stays, the externals
   `tinykernel/TinyLibSystem.ml` is written over (and the debugger's and
   the tracer's, question 3); `system/README.md`, `tiny/README.md`,
   `docs/manuals/t-ix.md` (7.10) and the headers that name TinyCalls
   say the new shape.
5. **No user/.** The author: "maybe we can get rid of user/ at some
   point if TinyCalls.ml disappear and get merged in TinyLibSystem,
   maybe the TinyXxx.ml do not need a user/xxx.ml". A window program's
   last file is in `user/` for one reason: TinyOffice.ml,
   TinyEditorScreen.ml, TinyBrowser.ml... are also libraries that the
   tests link and drive in the same process (`TinyOffice_tests` types
   keys at the office, with no window), so a `let () = ...` at their end
   would start the program in the test. The tools have no such file:
   TinyShell.ml ends with `let () = TSys.main "tiny-shell" main`, and
   its tests run the executable. In two steps:
   - **Each program gets a `main`**, as the tools have:
     `TinyOffice.main : caps -> string array -> Exit.t` does what
     `user/office.ml` does now (the arguments, the file read and
     written, `run_canvas` wired), on TinyLibSystem, and its `.mli`
     lists it with the program's heart. The tests link the library and
     do not call it. Each file of `user/` is then one line,
     `let () = TinyLibSystem.main "office" TinyOffice.main`.
   - **That line made by the builds** (question 6): a rule in
     `user/sdl/`'s dune writes it for the host's executables, and
     TinyKernel/Makefile writes it for tiny-kernel's, for each program
     (emacs, office, www, troff, play, calc, temp, tetris; debug, trace
     and bigmem, tiny-kernel's alone). `user/` is then empty but for
     `sdl/`, whose dune file moves beside the window it links
     (`TinyLibSystem/sdl/`), and `user/` goes.

What is not touched: TinyWindows.ml, which names the kernel's calls by
its own externals (OCaml only checks it); TinyLibDraw.ml, which makes
messages and calls nothing.

## Questions to decide

Decided by the author, 2026-11-10: 1, the stub a whole TinyLibSystem,
its files and processes failing; 2, `drawn` in a test-only module of
the stub's library; 3, the debugger and the tracer on
`tinykernel/TinyCalls.ml`'s externals; 4, a write to `fd_draw` with no
window a Failure. 5 and 6 as proposed (`raw_console` takes
`Cap.keyboard`, `seed` `Cap.random`, `dial` `Cap.network`, `spawn`
`Cap.fork` and `Cap.exec`; the one line made by the builds).

1. **The stub on tiny-cpu.** Three tests (`TinyEditorScreen_test.sh`,
   `TinyOffice_test.sh`, `TinyTroff_test.sh`) compile
   `stub/TinyCalls.ml` with tiny-ml with the GUI and run it on
   tiny-cpu, which has three system calls. The stub must stay a file
   tiny-ml compiles, with no Unix: proposed, `stub/TinyLibSystem.ml`, a
   whole TinyLibSystem where every file and process call fails and the
   clock does not move (about 100 lines, today's 47 and the tools'
   functions as failures).
2. **The test hook.** `drawn`, what was written to `fd_draw`, is in
   TinyCalls.mli for the tests alone. Proposed: out of the interface; the
   stub's library has a second module, `TinySystemTest.drawn`, which
   the tests that link the stub name.
3. **The debugger and the tracer.** They run on tiny-kernel alone (dune
   builds neither). Proposed: they stay on `tinykernel/TinyCalls.ml`'s
   externals, as tiny-kernel's own tools, which may ask what only it
   has (`trace`), as Plan 9's debuggers read `/proc`; their headers say
   so. Or TinyLibSystem gains `trace`, and every other implementation
   refuses it.
4. **A window program on Unix with no window.** `unix/`'s descriptors
   3 and 4 are not open: proposed, a write to `fd_draw` fails, Failure
   "no window: run it in one, tiny-office... (user/sdl/)", rather than
   drawing nowhere as the stub does.
5. **Capabilities for the new calls**: which of lib_core's `Cap`
   objects `ready`, `raw_console`, `dial` and `spawn` take (`Cap.network`
   for dial, `Cap.exec` for spawn; `ready` none, as `read`).
6. **Stage 5's one line: written or made?** Eleven files of one line
   each, `user/office.ml`..., are where a reader finds a program's
   start; two rules (dune's, the Makefile's) make them instead, and
   take a directory away, as the tools have none. Proposed: made, the
   rules saying in a comment where each program starts (its `main`).

## Checks, at each stage

`dune build`; `make test-tix`; `analyzers/datalog/tests/tiny_check.sh
-bugs -caps -dead -check` (the caps' report will change where the GUI
takes capabilities: recorded after a look); mini-mk in `tiny/`;
`make -C tiny/TinyKernel check` (screens and sounds the same; addresses
in `debug.cksum` and `check.expected`, looked at, then recorded); `make
self-quick-tix`; the window programs run by hand on the host
(tiny-office, tiny-emacs, tiny-www, tiny-tetris, tiny-play); at the end,
`make self`.

## Size, estimated

TinyLibSystem.mli about +60 lines; `tinykernel/` and `unix/` +80;
`sdl/` −80 (its file code is the shared library's); `stub/` +50;
TinyCalls.mli −120; the graphical side about ±150 lines changed, mostly
`caps` passed and calls renamed. About the same lines in all, one
interface less. Stage 5: `user/`'s 11 files, about 200 lines, become
`main`s in their TinyXxx.ml (about the same lines, the `TinyCalls` words
gone) and two rules of a few lines.

## Status

Stage 0, 2026-11-10: `tiny/system/` moved, `TinyLibSystem.mli` to
`tiny/`, its parts to `tiny/TinyLibSystem/` (`unix/`, `tinykernel/`,
`sdl/`, `teststub/`, and TinyCalls.mli); `tiny_lib_system`'s stanza in
`tiny/dune`, `tiny_calls_stub` renamed `tiny_calls_teststub`; mini-mk's
and compile_ix.sh's `-I` with `tiny/` before `unix/`, so that the
interface is found first. Checked as the stages are, `make self` but.

Stage 1, 2026-11-10: TinyLibSystem.mli has `fd_stdin` ... `fd_mouse`,
`ready` (a deadline in `millis`'s milliseconds, None then), `seed`,
`raw_console`, `spawn` and `dial`; `unix/`'s by Unix (`select`,
`tcsetattr`, `create_process`; `dial` a Failure: no wire on the host
but a window's), `tinykernel/`'s by its calls (`ready`'s deadline in
ticks, rounded up, as `sleep`'s; a dial's descriptor not given to a
program run). No caller yet: `dead_tiny.txt` has them, until stage 3.
`debug.cksum`: the debugged program's registers (TinyLibSystem's five
globals), the screen looked at. Checked: dune; `make test-tix`;
`tiny_check.sh`; mini-mk; the kernel's check and self-quick in
`_make2`.

Stages 2 to 4, 2026-11-10, as one (the author's choice: no scaffolding
for the window to serve two interfaces at once). `sdl/TinyLibSystem.ml`,
the window's implementation: `unix/`'s code (a copy dune makes,
`TinyLibSystemUnix`) and the window for the rest, its descriptors
real ones of /dev/null's so that a file opened never takes their
number. `teststub/`: a whole TinyLibSystem, files and processes a
Failure, `TinySystemTest.drawn` beside it. The graphical side on
TinyLibSystem, with capabilities: TinyLibPlayground's `run`,
TinyLibGUI's `run_canvas` and `window_size`, TinyBrowser's `browse`
(its functions passing `caps`), TinyPlay; TinyLibGUI's own `read_file`
and `write_file` gone; the mains on `TinyLibSystem.main`, their
messages as before (the kernel's check records them); a frame 33 ms
(the kernel's 13 ticks before). `TinyCalls.mli` and `tiny_calls`
gone; `tinykernel/TinyCalls.ml`, the externals, stays: its
TinyLibSystem's, and the debugger's and the tracer's for `trace`.
`unix/`'s `ready`, `raw_console`, `seed`, `spawn` and `dial` a Failure
(the author: "get rid of it and fail if unused"). Checked: dune;
`make test-tix`; `tiny_check.sh`; mini-mk; the kernel's check (no
expectation changed) and self-quick in `_make2`; tiny-calc,
tiny-tetris and tiny-office run in a window (SDL's dummy driver),
their screens looked at.
