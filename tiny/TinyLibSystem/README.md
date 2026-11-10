# tiny/TinyLibSystem/

What a tiny program asks of the system it runs on. The same source of
a tiny program runs on two systems: on the host (Linux, macOS), built
by OCaml, and on tiny-kernel (tiny-machine), built by tiny-ml. It can,
because it never names either system: it names one of the two
interfaces, and each interface has an implementation for each system,
in a directory here. This directory is the parts of
[`../TinyLibSystem.mli`](../TinyLibSystem.mli), beside the tools that
name it, as `../TinyC/` is the parts of `../TinyC.ml`; `TinyCalls.mli`
is here too, until it joins TinyLibSystem
([`plan_tiny_one_system.md`](../../docs/plans/plan_tiny_one_system.md)).

| interface | what it is | its users | its implementations |
|---|---|---|---|
| `../TinyLibSystem.mli` | a tool's system: files, directories, processes, the clock, cut to what tiny-kernel gives | the tools: tiny-shell, tiny-utils, tiny-editor, tiny-c, tiny-ml, tiny-assembler, tiny-linker, tiny-build, tiny-db, tiny-vcs, tiny-prof | `unix/` (over OCaml's `Unix` and lib_core), `tinykernel/` (over tiny-kernel's calls) |
| `TinyCalls.mli` | tiny-kernel's calls themselves: a descriptor read and written, the drawing on descriptor 3, the mouse on 4, the clock | the graphical programs, through `TinyLibDraw`, `TinyLibPlayground` and `TinyLibGUI` (tiny-emacs, tiny-office, tiny-www, tetris...) | `tinykernel/` (externals, `mlsys.c`'s functions), `sdl/` (a window of SDL's on the host), `teststub/` (the tests': what is drawn kept, no keys) |

The two are layers. On tiny-kernel, `tinykernel/TinyLibSystem.ml` is
written over `TinyCalls`. On the host, `unix/TinyLibSystem.ml` is
written over Unix instead, and `TinyCalls` is only for the graphical
programs, whose window (`sdl/`) is drawn by tiny-kernel's own drawing,
`TinyKernelGraphics.ml`.

```
            a tool (TinyShell.ml...)        a graphical program (office.ml...)
                     |                                   |
             TinyLibSystem.mli                 TinyLibGUI, TinyLibPlayground,
              /            \                          TinyLibDraw
         unix/          tinykernel/                       |
     OCaml's Unix     TinyLibSystem.ml              TinyCalls.mli
     Linux, macOS            \                  /         |         \
                              \           tinykernel/    sdl/      teststub/
                               `------->  TinyCalls.ml   a window  the tests
                                          mlsys.c
                                          tiny-kernel
```

Who builds what:

- dune builds the host's sides: both interfaces are virtual
  libraries, `tiny_lib_system` in `../dune`, beside its `.mli` (its
  default implementation `unix/`), and `tiny_calls` in `dune` here (its
  default `teststub/`; the programs of `../user/sdl/` link `sdl/`'s).
- tiny-ml builds `tinykernel/` for each ML program of tiny-kernel
  (`../TinyKernel/Makefile`: `SYS`, the units' files, `mlsys.c`);
  `tinykernel/` has no dune file.
- mini-mk (`../mkfile`) builds the tools with `unix/`.

Why the names: `unix/` is written against OCaml's `Unix` library,
which is what makes it run on Linux and macOS; `tinykernel/` against
tiny-kernel. "The host" in t-ix's other files is the machine a
program is built on, which is one of the first.

What is not here: a C program of tiny-kernel calls the kernel through
`../TinyKernel/libc/` (`user.h`, `sys.tm`), as C programs only run
there. tiny-machine's memory for tiny-kernel's own parts tested on the
host is `../TinyKernel/host/TinyMemory.ml`: no program uses it.
