# tiny/TinyLibSystem/

What a tiny program asks of the system it runs on. The same source of
a tiny program runs on two systems: on the host (Linux, macOS), built
by OCaml, and on tiny-kernel (tiny-machine), built by tiny-ml. It can,
because it never names either system: it names one interface,
[`../TinyLibSystem.mli`](../TinyLibSystem.mli), and the interface has
an implementation for each system, a directory here. This directory is
the parts of that `.mli`, beside the programs that name it, as
`../TinyC/` is the parts of `../TinyC.ml`.

| implementation | what it is over | who runs on it |
|---|---|---|
| `unix/` | OCaml's `Unix` and lib_core (Linux, macOS) | the tools on the host: tiny-shell, tiny-utils, tiny-editor, tiny-cc, tiny-ml, tiny-as, tiny-ld, tiny-build, tiny-db, tiny-vcs, tiny-prof |
| `tinykernel/` | tiny-kernel's calls (externals, `mlsys.c`'s functions) | every ML program on tiny-kernel, tools and windows alike |
| `sdl/` | `unix/`'s code for files and processes, and an SDL window for the rest: the drawing on `fd_draw` by tiny-kernel's own `KGraphics.ml`, the keys and the mouse, the speaker, the wire's port 70 | the window's programs on the host (`../user/sdl/`: tiny-emacs, tiny-office, tiny-www, tiny-calc, tiny-tetris, tiny-play) |
| `teststub/` | nothing: what is drawn kept (`TinySystemTest.drawn`), no key, a still clock, every file a `Failure`; compiled by tiny-ml too | the tests of the window's programs, on the host and on tiny-cpu |

On tiny-kernel, `tinykernel/TinyLibSystem.ml` starts with the kernel's
calls themselves (externals: ints, `-1` for a refusal) and is written
over them (`Fpath.t`, capabilities, `Failure` with a reason, and what
the kernel lacks made up: `dup2`, a wait for one child, descriptors
closed at an exec). The debugger and the tracer, tiny-kernel's alone,
declare the one more they call, `u_trace`, which no other system has.

```
     a tool (TinyShell.ml...)       a window's program (user/office.ml...)
               |                         on TinyLibGUI, TinyLibPlayground
               |                                    |
               `--------- TinyLibSystem.mli --------'
                 /          |          \          \
             unix/     tinykernel/     sdl/      teststub/
       OCaml's Unix   TinyLibSystem.ml  unix/'s   the tests
       Linux, macOS         |           + a window
                       mlsys.c, tiny-kernel
```

Who builds what:

- dune builds the host's sides: `tiny_lib_system` is a virtual library
  in `../dune`, beside its `.mli`, its default implementation `unix/`;
  `../user/sdl/`'s programs link `sdl/`'s, the tests `teststub/`'s.
  `sdl/` includes `unix/`'s code under another name, `TinyLibSystemUnix`,
  a copy dune makes (an implementation cannot include another of its
  virtual module): one source, two modules.
- tiny-ml builds `tinykernel/` for each ML program of tiny-kernel
  (`../TinyKernel/Makefile`: `SYS`, the units' files, `mlsys.c`);
  `tinykernel/` has no dune file.
- mini-mk (`../mkfile`) builds the tools with `unix/`.

What only a window's program asks (`ready`, `raw_console`, `seed`,
`spawn`, `dial`) is a `Failure` on `unix/`: no program on plain Unix
asks it, a window's runs on `sdl/`.

Why the names: `unix/` is written against OCaml's `Unix` library,
which is what makes it run on Linux and macOS; `tinykernel/` against
tiny-kernel. "The host" in t-ix's other files is the machine a
program is built on, which is one of the first.

What is not here: a C program of tiny-kernel calls the kernel through
`../TinyKernel/libc/` (`user.h`, `sys.s`), as C programs only run
there. tiny-machine's memory for tiny-kernel's own parts tested on the
host is `../TinyKernel/host/KRaw.ml`: no program uses it.
TinyWindows.ml, tiny-kernel's window system, names the kernel's calls
by externals of its own.
