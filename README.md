# <img src="docs/logo.svg" alt="ix" height="48">

**A whole computer system in small, readable OCaml programs: an ARM
emulator, a kernel, a shell, a C compiler, an assembler and a linker,
an editor, a build system, a database, version control, and more.**

Website: **[aryx.github.io/ix](https://aryx.github.io/ix/)**, with a
[code map](https://aryx.github.io/ix/codemap.html) of the whole
repository to explore in the browser.

ix is a way to learn how a computer system works, end to end, by
reading its code. Each part of the system is a separate program, and
each program is small enough to read in a few sittings. None of them
is a toy, though. The emulator runs real ARM binaries, the compiler
makes them, and the kernel boots a real operating system's user
programs, up to its windowing system and the network.

The system ix follows is **Plan 9**, the successor of Unix written at
Bell Labs by Unix's own authors. Plan 9 is small, clean, and complete:
it has its own kernel, compilers, shell (`rc`), build tool (`mk`),
editor and windowing system (`rio`). It is explained program by
program in [Principia Softwarica](https://principia-softwarica.org/), a
series of books I (Yoann Padioleau) wrote, and my
[xix](https://aryx.github.io/xix/) project ports those programs to
OCaml at full size. You don't need to know either to read ix. ix
takes the same programs and makes each of them as small as it can.

## Two sizes of each program: m-ix and t-ix

Each program in ix comes in two versions:

- **mini** (`mini-mk`, `mini-rc`, `mini-cc`, ...): a faithful
  reimplementation of the Plan 9 program, only smaller. It is named
  after the original and does the same thing: its output is the
  original's, byte for byte. The executables `mini-cc` and `mini-ld`
  make are the ones Plan 9's compiler and linker make. Together, the
  mini programs are **m-ix** (a nod to Knuth's MIX computer).
- **tiny** (`tiny-build`, `tiny-shell`, `tiny-c`, ...): a free
  variant, in a single file under [`tiny/`](tiny/). It is named after
  what it does, not after the original. It keeps the idea of the
  original and redesigns the rest, now that compatibility no longer
  matters. Together, the tiny programs are **t-ix**.

For example, `mini-mk` reads real Plan 9 mkfiles and builds all of
xix from them. `tiny-build` is a build system in one file of about
450 lines. It keeps mk's rules and `%` patterns, and uses content
digests instead of timestamps. Reading the two side by side shows
what is essential to a build system and what is history.

## m-ix: the mini programs

The line counts are OCaml, comments and `.mli` files included, tests
excluded. Each program's *map* link opens it in
[ix's code map](https://aryx.github.io/ix/codemap.html), the whole
repository explored in the browser.

| program | what it is | lines | Plan 9 original | code |
|---|---|---:|---|---|
| **mini-5i** | an ARM emulator for user programs, arm32 and arm64, with Linux's or Plan 9's system calls | 5,200 | `5i` | [`machine/`](machine/) ([map](https://aryx.github.io/ix/codemap.html?focus=machine)) |
| **mini-qemu** | a Raspberry Pi 1 and Pi 4 (MMU, interrupts, timer, UART, SD card, framebuffer, USB keyboard, mouse and network), which boots xv6, Plan 9 and ix's own kernels, as QEMU does | 3,600 | QEMU's raspi machines | [`raspberry/`](raspberry/) ([map](https://aryx.github.io/ix/codemap.html?focus=raspberry)) |
| **mini-9pi** | Plan 9's kernel in OCaml, on the Pi 1 and the Pi 4: boots Plan 9's own user programs up to the shell, the `rio` windowing system and TCP | 10,600 | `9pi` | [`kernel/9pi/`](kernel/9pi/) ([map](https://aryx.github.io/ix/codemap.html?focus=kernel/9pi)) |
| **mini-xv6** | MIT's teaching kernel xv6 in OCaml, on the Pi 1 and the Pi 4 | 1,700 | xv6 | [`kernel/xv6/`](kernel/xv6/) ([map](https://aryx.github.io/ix/codemap.html?focus=kernel/xv6)) |
| **mini-cc** | the C compiler for arm and arm64; the same instructions as Plan 9's `5c` and `7c` | 7,500 | `5c`, `7c` | [`languages/c/`](languages/c/) ([map](https://aryx.github.io/ix/codemap.html?focus=languages/c)) |
| **mini-ml** | a native compiler for ML (ocaml-light's dialect), for arm and arm64; meant to compile mini-9pi (in progress) | 4,400 | ocaml-light's `ocamlopt` | [`languages/ml/`](languages/ml/) ([map](https://aryx.github.io/ix/codemap.html?focus=languages/ml)) |
| **mini-asm** | the assembler for arm and arm64 | 800 | `5a`, `7a` | [`assembler/`](assembler/) ([map](https://aryx.github.io/ix/codemap.html?focus=assembler)) |
| **mini-ld** | the linker; the same executables as Plan 9's, byte for byte | 2,600 | `5l`, `7l` | [`linker/`](linker/) ([map](https://aryx.github.io/ix/codemap.html?focus=linker)) |
| **mini-rc** | the shell | 2,100 | `rc` | [`shell/`](shell/) ([map](https://aryx.github.io/ix/codemap.html?focus=shell)) |
| **mini-ed** | the line editor | 1,600 | `ed` | [`editor/`](editor/) ([map](https://aryx.github.io/ix/codemap.html?focus=editor)) |
| **mini-mk** | the build system; builds all of xix from its mkfiles | 2,500 | `mk` | [`builder/`](builder/) ([map](https://aryx.github.io/ix/codemap.html?focus=builder)) |
| **mini-chidb** | a relational database: SQL, a query optimizer, B-trees | 3,100 | chidb, SQLite's teaching twin | [`database/`](database/) ([map](https://aryx.github.io/ix/codemap.html?focus=database)) |
| **mini-git**, **mini-diff**, **mini-merge3** | version control, compatible with git repositories | 4,900 | `git9`, `diff` | [`version_control/`](version_control/) ([map](https://aryx.github.io/ix/codemap.html?focus=version_control)) |

That is **about 50,000 lines** in all (mini-9pi also has about 2,800
lines of C and assembly to boot the machine and run the OCaml runtime).
The shared libraries add 600 more: [`lib_core/`](lib_core/) ([map](https://aryx.github.io/ix/codemap.html?focus=lib_core)) (files,
processes, the console), [`lib_security/`](lib_security/) ([map](https://aryx.github.io/ix/codemap.html?focus=lib_security)) (SHA-1) and
[`lib_compression/`](lib_compression/) ([map](https://aryx.github.io/ix/codemap.html?focus=lib_compression)) (zlib).

## t-ix: the tiny programs

Each one is a single file in [`tiny/`](tiny/) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny)).
[tiny/README.md](tiny/README.md) says what idea each one keeps from
its original and what it redesigns.

| program | what it is | lines | mini twin | file |
|---|---|---:|---|---|
| **tiny-arm** | an arm32 CPU: assembler, interpreter and ELF writer in one | 840 | mini-5i | [`TinyCPUArm.ml`](tiny/TinyCPUArm.ml), [`TinyLibArm.ml`](tiny/TinyLibArm.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyCPUArm.ml)) |
| **tiny-pi** | tiny-arm's CPU in a Pi 1: modes, exceptions, timer, UART; its page of kernel also runs under QEMU | 410 | mini-qemu | [`TinyMachinePi.ml`](tiny/TinyMachinePi.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyMachinePi.ml)) |
| **tiny-cpu** | a CPU of our own design, for teaching, with its assembler | 560 | mini-5i, Knuth's MIX | [`TinyCPU.ml`](tiny/TinyCPU.ml), [`TinyLibCPU.ml`](tiny/TinyLibCPU.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyCPU.ml)) |
| **tiny-machine** | tiny-cpu with what a kernel needs: two modes, traps, a timer, protection, a console, a disk | 420 | mini-qemu | [`TinyMachine.ml`](tiny/TinyMachine.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyMachine.ml)) |
| **tiny-kernel** | a kernel in ML for tiny-machine: fork and exec, preemption, pipes, files | 570 | mini-9pi | [`TinyKernel.ml`](tiny/TinyKernel.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyKernel.ml)) |
| **tiny-c** | a C subset compiler, to arm64 and to tiny-cpu | 1,200 | mini-cc | [`TinyC.ml`](tiny/TinyC.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyC.ml)) |
| **tiny-ml** | an ML compiler (Hindley-Milner types, closures, exceptions, a garbage collector) to arm64 and to tiny-cpu | 1,750 | mini-ml | [`TinyML.ml`](tiny/TinyML.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyML.ml)) |
| **tiny-assembler** | assembler and linker in one, to arm64 executables | 680 | mini-asm, mini-ld | [`TinyAssembler.ml`](tiny/TinyAssembler.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyAssembler.ml)) |
| **tiny-shell** | a shell in rc's spirit: lists as the only value | 670 | mini-rc | [`TinyShell.ml`](tiny/TinyShell.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyShell.ml)) |
| **tiny-editor** | an editor with sam's command language | 800 | mini-ed | [`TinyEditor.ml`](tiny/TinyEditor.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyEditor.ml)) |
| **tiny-build** | a build system: rules, `%`, digests, `-j` | 440 | mini-mk | [`TinyBuildSystem.ml`](tiny/TinyBuildSystem.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyBuildSystem.ml)) |
| **tiny-db** | a database whose query language is the relational algebra, over a copy-on-write B-tree | 620 | mini-chidb | [`TinyDatabase.ml`](tiny/TinyDatabase.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyDatabase.ml)) |
| **tiny-vcs** | version control with git's objects, an undo log, and no staging area | 690 | mini-git | [`TinyVCS.ml`](tiny/TinyVCS.ml) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/TinyVCS.ml)) |

That is **about 10,000 lines** in all. tiny-cpu and tiny-machine also
run [`tiny/tiny-os/`](tiny/tiny-os/) ([map](https://aryx.github.io/ix/codemap.html?focus=tiny/tiny-os)), an operating system written for
them in their assembly and in C for `tiny-c`: a page-long kernel (v0),
an xv6-like kernel with a disk and a shell (v6), and a free variant of
it (t6).

## Build and run

```bash
make          # builds everything; the executables are then in bin/
make test
./bin/mini-mk -h            # every program has -h, with examples
./mini-pi mini-9pi -g       # boot mini-9pi on mini-qemu, then type rio
./tiny-machine v6           # boot tiny-os's xv6-like kernel on tiny-machine
```

`dune install` installs both the mini and the tiny executables.
`make build-docker` builds and tests ix in a fresh Ubuntu (the
[`Dockerfile`](Dockerfile), which GitHub Actions runs with OCaml 4.14.2
and 5.1.1).

The plans, tutorials, manuals and related-work notes are indexed in
[docs/README.md](docs/README.md), and
[docs/projects.md](docs/projects.md) maps the projects inside ix: the
machines (real ARM, or our own) and what runs on each.

## Tiny, not Toy

There is a good tradition of teaching whole computer systems:
Nand2Tetris (*The Elements of Computing Systems*), Minix, xv6. The
Nand2Tetris route makes everything minimal: a made-up machine, a
made-up assembler, a made-up OS. ix aims for the full stack too, but
makes the *programs* tiny, not the things they deal with:

- **The machine is real ARM**, arm32 and arm64. mini-5i runs user
  programs; mini-qemu is a whole Raspberry Pi, so that real kernels,
  not just user programs, run on it. The emulator stops with
  "unimplemented instruction" on what it does not know, so it also
  checks that a binary stays inside what ix handles.
- **The binaries are real.** mini-cc, mini-asm and mini-ld make them as
  Plan 9's compilers do. The same binary runs on ix's emulator, on
  QEMU and on a real ARM machine. Running it on several and comparing
  the results is the main test.
- **The system calls are real.** User programs talk to the kernel
  with Plan 9's system call ABI, and mini-9pi runs Plan 9's own user
  programs, unmodified, from Plan 9's own SD card image.

One group of tiny programs takes the other road on purpose. tiny-cpu
and tiny-machine are a made-up machine, as Knuth's MIX and MMIX and
Nand2Tetris's Hack are, because what they teach is the design of an
instruction set: the choices a real one made for history's reasons,
made again with hindsight. They stand next to tiny-arm and tiny-pi,
the same two programs for real ARM, so that the two roads can be
compared.

## Still to come

The rest of the system, following the Principia Softwarica books (the
names are not final):

| part | mini | tiny | Plan 9 original |
|---|---|---|---|
| Debuggers | mini-db, mini-acid | tiny-debugger | `db`, `acid` |
| Profilers | mini-prof | tiny-profiler | `prof`, `tprof` |
| Graphics stack | mini-draw | tiny-draw | `libdraw`, `libmemdraw`, `devdraw` |
| Windowing system | mini-rio | tiny-windows | `rio` |
| GUI toolkit | mini-panel | tiny-gui | `libpanel` |
| Network stack | mini-ip | tiny-net | `devip`, `libip`, `lib9p` |
| Web browser | mini-mothra | tiny-browser | `mothra`, `webfs` |
| Command-line utilities | mini-cat, mini-ls, mini-grep, ... | | `cat`, `ls`, `grep`, `sed`, `awk` |

mini-9pi already has parts of some of these in its kernel (the draw
device, the IP stack), with Plan 9's C programs running on top.

## Design

- **Everything is OCaml, the kernel included, and it runs as a real
  binary.** Unlike Nachos, where the "OS" is ordinary code running on
  the host, mini-9pi is an actual ARM binary: a thin layer of C and
  assembly boots the machine and starts a stripped-down OCaml runtime,
  and the kernel is OCaml from there on. The same binary boots on
  mini-qemu and on QEMU, and is meant for a real Raspberry Pi too.
  Processes, address
  spaces, context switches, supervisor and user mode and the system
  call boundary are therefore real. Today mini-9pi is compiled by
  ocaml-light's `ocamlopt`; mini-ml is being written to take over.

  ```
   user program (a.out)                          user mode
   ----------------- SWI / trap / irq -----------------------
   mini-9pi (OCaml + thin C/asm runtime shim)     supervisor mode
   ---------------------------------------------------------------
   ARM CPU + CP15 (MMU, modes): a real Raspberry Pi, or
   mini-qemu emulating one, with disk, timer, framebuffer,
   keyboard, mouse and network
  ```

- **Most tools are terminal programs.** They read and write files,
  stdin and stdout, and depend on nothing graphical. They follow
  [xix](https://aryx.github.io/xix/)'s capability style (`Cap.*`) for
  OS access.
- **Only mini-qemu depends on a GUI library** (SDL), to show the
  machine's framebuffer and feed it the keyboard and mouse. The
  machine itself is a pure library, so it also runs in a terminal. The
  graphical programs (rio and those it runs) run *inside* the machine
  and draw into its framebuffer, as on a real computer.

## Who wrote it

ix is mostly written by Claude (Anthropic's AI, in Claude Code), under
my direction: I choose the design and review the code, and Claude
writes most of the lines. xix, on the other hand, I mostly wrote
myself. Putting each mini program next to its xix twin makes a fair
comparison of the two ways of working. The project started on
2026-09-21; [docs/history.md](docs/history.md) tells how.

[docs/yoann_notes/prompt-history.md](docs/yoann_notes/prompt-history.md)
shows the other side of that work: every prompt I wrote to Claude to
build ix, in order and verbatim (typos included), each followed by a
short summary of Claude's answer. Hooks in `.claude/` append the
entries as I work, so the file grows with the repository. Read next to
`git log`, it shows what directing an AI to write a codebase looks like
day to day.

## The name

IX is 9 in roman numerals (Plan 9), and ix is xix with a letter
removed: a smaller xix, as 9 is smaller than 19. It is also the "-ix"
of Unix, Minix and Linux with nothing in front. And it has two
letters, like `rc`, `mk`, `ed` and the other Unix and Plan 9 names,
and like "ai", which writes most of it.

## License

LGPL 2.1 with the OCaml-style linking exception, like
[xix](https://aryx.github.io/xix/): see [license.txt](license.txt) and
[copyright.txt](copyright.txt).
