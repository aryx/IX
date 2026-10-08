# The projects inside ix

ix is several projects in one repository, and they cross two ways: by
**size** (a faithful mini program or a free tiny one) and by
**machine** (real ARM, or a machine of our own). Most of ix is OCaml
that runs on the host; some of it is code that runs *inside* an
emulated machine, in assembly or C. This page says which is which.
Names in italics are planned.

## Who builds what

Three toolchains build ix, and each has its scope:

![Who builds what in ix: OCaml and dune build everything; the m-ix toolchain rebuilds itself and t-ix's tools; the t-ix toolchain builds what runs on the tiny machine](pics/toolchains.svg)

- **OCaml and dune**, from outside ix, build every OCaml program of
  ix the first time, and are the only ones to build mini-qemu and
  tiny-machine-window (SDL) and the tests.
- **The m-ix toolchain** (mini-mk and the mkfiles; mini-ml, mini-cc,
  mini-asm, mini-ld...) then builds all of that again, itself
  included, to the same bytes; t-ix's tools too, which are OCaml
  programs.
- **The t-ix toolchain** (tiny-c, tiny-ml, tiny-cpu, tiny-machine)
  builds only what runs on the tiny machine: tiny-os, TinyKernel.ml
  and their programs. It does not build its own tools. Its arm64 side
  (tiny-assembler) builds test programs only.

[manuals/t-ix.md](manuals/t-ix.md), section 2, has the details of the
tiny side.

## Two kinds of code

- **Host programs, in OCaml.** Every executable ix builds with dune
  (`make`, then `bin/`): the mini programs, the tiny programs, the
  emulators themselves. They run on Linux.
- **Guest code, not OCaml.** What an emulated machine runs: ARM
  executables for mini-5i and mini-qemu (from mini-cc and mini-ld, or
  from goken's compilers, or kernels like xv6 and 9pi); arm64
  executables and a kernel's page from tiny-assembler for tiny-arm and
  tiny-pi; `.tm` assembly and C compiled by `tiny-c -tm` for
  tiny-cpu and tiny-machine. Only the last kind lives mostly in ix, in
  `tiny/tiny-os/` and the tests.

## Two sizes of host program

- **mini-xxx** (m-ix): a Plan 9 program's faithful twin, named after
  it, its output the original's byte for byte (`builder/`, `shell/`,
  `editors/ed/`, `assembler/`, `linker/`, `languages/c/`, `database/`,
  `version_control/`, `machine/`, `raspberry/`).
- **tiny-xxx** (t-ix): a free variant in one file under `tiny/`,
  named after what it does, keeping the idea and redesigning the rest.
  Two of them keep their core in a library for a second program
  (`TinyLibArm.ml`, `TinyLibCPU.ml`).

Both share `lib_core/` (files, processes, the console, logging),
`lib_crypto/` and `lib_compression/`.

## Two families of machine

Real ARM, whose guest code comes from real toolchains, and a machine
of our own, designed to teach, whose guest code ix writes itself:

|                      | CPU, user mode                        | machine, with devices, for a kernel |
|----------------------|---------------------------------------|-------------------------------------|
| real ARM, faithful   | mini-5i (`machine/`: arm32, arm64)    | mini-qemu (`raspberry/`: the Pi1, the Pi4; `./mini-pi`) |
| real ARM, free       | tiny-arm (`TinyCPUArm.ml`, `TinyLibArm.ml`: arm64) | tiny-pi (`TinyMachinePi.ml`: the Pi4; `./tiny-pi echo`) |
| our own, free        | tiny-cpu (`TinyCPU.ml`, `TinyLibCPU.ml`) | tiny-machine (`TinyMachine.ml`; `./tiny-machine v0`, `v6`) |

Each machine, with what makes its guest code and what runs on it:

| machine      | its toolchain                                     | what runs on it |
|--------------|---------------------------------------------------|-----------------|
| mini-5i      | mini-cc, mini-asm, mini-ld (goken's 5c/5l, 7c/7l the reference) | Linux and Plan 9 user programs, arm and arm64 |
| mini-qemu    | outside ix: the kernels' own builds               | xv6 (`~/xv6`), 9pi (`~/principia`), as QEMU runs them |
| tiny-arm     | tiny-assembler; tiny-c and tiny-ml through it     | their arm64 Linux executables, goken's libc included (`tiny/tests/TinyCPUArm_tests/`, `tiny/tests/TinyC_tests/`) |
| tiny-pi      | tiny-assembler `-raw` (mrs, msr, eret, wfi)       | a page of kernel (`tiny/tests/TinyMachinePi_tests/tick.s`), bare-metal Pi4 programs |
| tiny-cpu     | TinyLibCPU's assembler; `tiny-c -tm` for C        | `.tm` programs; C programs with `tiny-os/libc/` |
| tiny-machine | the same, plus csrr, csrw, eret                   | tiny-os's kernels and their programs |

tiny-assembler, tiny-c and tiny-ml (without `-tm`) are free variants
of the real toolchain: they make arm64 Linux executables with goken's
libc, for arm64 Linux, mini-5i and tiny-arm. The tiny side has one
real architecture, arm64 (plans/plan_tiny_arm64.md); the mini side has
arm32 too.

## The kernels

Several different projects, not versions of one (tiny-os's v0 and v6,
and how they relate to the others: [plans/plan_tiny_os.md](plans/plan_tiny_os.md)):

| kernel | what | in | runs on |
|---|---|---|---|
| tiny-os v0 (`tiny/tiny-os/v0/`) | a page of kernel: traps, a timer, round robin, protection by a window; its four programs linked with it | TinyCPU assembly | tiny-machine |
| tiny-os t6 (`tiny/tiny-os/t6/`) | v6's free variant: spawn and no fork (descriptors given, none inherited), one kernel stack and calls that rerun, a partition a process, a FAT, a lottery | C, by `tiny-c -tm`, and a page of `.tm` | tiny-machine, its window relocating |
| tiny-os v6 (`tiny/tiny-os/v6/`) | xv6 on tiny-machine, its structure and names (the riscv32 fork the model), multicore-ready; its history told in the tutorial | C, by `tiny-c -tm`, and a page of `.tm` | tiny-machine, with pages, a disk, device interrupts |
| TinyKernel.ml (tiny-kernel, `tiny/TinyKernel.ml`) | the Kernel row's free variant (README's series): fork and exec, round robin, a partition a process, a waiting call a closure the scheduler retries, the files ML values in memory (no disk); [notes_tiny_kernel.md](notes_tiny_kernel.md) | ML, by `tiny-ml -tm`, a page of `.tm`, 80 lines of C | tiny-machine, its window relocating |
| *mini-9pi* | 9pi's twin, the Kernel row's mini program (README) | OCaml, with a thin C/asm shim | the Pi (mini-qemu, real boards) |
| *mini-xv6* | mentioned by the author; not planned yet | | |

One more, an idea, maybe a project of its own outside ix: *tiny-bootstrap*, principia's
"Bootstrapping from Scratch" appendix made runnable on tiny-machine: a
loader, a file system, time-sharing, then C, with the tools rebuilt on
the machine itself (plan_tiny_os.md).

xv6 and 9pi themselves are not ix's: they are guest code mini-qemu is
tested with.

## What comes from outside

- **goken** (`~/goken`): principia's Plan 9 toolchain built for Linux,
  the reference for mini-asm, mini-ld, mini-cc and the tests of
  tiny-assembler and tiny-c.
- **principia** (`~/principia`): the books' C, and 9pi with its SD
  card image.
- **xv6** (`~/xv6`): its Pi ports, booted by mini-qemu.
- **xix**: the OCaml ports of the same programs, a source of ideas,
  not of code.
