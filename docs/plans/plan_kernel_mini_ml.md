# Plan: the kernels built by ix (mini-ml in place of ocaml-light)

Companion of [`plan_mkfiles.md`](plan_mkfiles.md) (ix built by ix: the
eleven programs, the fixed point) and of [`plan_ml.md`](plan_ml.md),
whose decision 8 and phase 6 this plan takes up ("the kernel's route:
through ix's toolchain"). The kernels are what ix's tools do not build
yet. The author (2026-10-02): "maybe we can try to use mini-ml to
compile the kernels? ... in addition to ocaml-light, so we can compare
... and let's build this one using mkfile again, so it's easy to spot
the difference with when ocaml-light is used instead (using regular
Makefile and/or adhoc scripts)".

**Status**: the plan agreed (2026-10-02: "I like your plan; let's do
Pi 4 indeed, raw, mkfile inside each"); the steps below as they are done.

## Where the kernels are

mini-xv6 (`kernel/xv6`, 1,736 lines of OCaml) and mini-9pi
(`kernel/9pi`, 9,696) over `kernel/lib` (891), on two boards: the Pi 1
(arm) and the Pi 4 (arm64). `kernel/lib/kernel.mk`, a Makefile, builds
an image from:

| piece | today | lines |
|---|---|---:|
| the OCaml | ocaml-light's `ocamlopt -output-obj` (cross-built by `kernel/ocaml-light.sh`) | 12,323 |
| the OCaml runtime | ocaml-light's `asmrun/` and `byterun/`, 32 files of C and `arm.S` or `arm64.S`, by gcc, freestanding | (ocaml-light's) |
| the kernel's C | `lib/libc.c` (a C library for that runtime), `lib/runtime.c` (the processes' kernel side, the calls into OCaml), `lib/usb.c`, the board's `machine.c`, by gcc | 1,075 for a board |
| the start, the vectors, the switch | the board's `start.s`, by GNU's as | 309 (Pi 4) |
| the disk image, the font | `.incbin` in `start.s` | 1.5 MB (xv6's, Pi 4) |
| the link | GNU's ld with the board's `kernel.ld` | |

`kernel/census.sh` prints these numbers and the ones below.

Every one of the kernels' 72 OCaml files already compiles by mini-ml
(`languages/ml/tests/compile_ix.sh`: "kernel 72 files, 0 fail"). What
is missing is everything around the OCaml.

## What the build by ix's tools must give or replace

1. **The runtime's interface to the kernel's C.** That C is written
   against ocaml-light's (`mlvalues.h`, `callback.h`, `memory.h`,
   `roots.h`): `Long_val` 77 times, `Val_unit` 41, `Val_long` 28,
   `String_val` 10, `alloc_string` 4, `modify` 5 ..., and the hard
   ones: `callback` 5 and `caml_named_value` 4 (C calls OCaml: a
   process's start, `trap`, `irq`, `fault`), `CAMLparam`/`CAMLlocal`
   (6 uses), and the five globals that describe a stack to the
   collector (`caml_bottom_of_stack`, `caml_last_return_address`,
   `caml_gc_regs`, `caml_exception_pointer`, `local_roots`) with
   `scan_roots_hook`: one set per process's kernel stack, saved at each
   switch. mini-ml's runtime has named values and no callback yet; a
   stack for it is the value stack, from its base to `ml_vsp`, and
   `ml_handler`.
2. **A system under the runtime.** mini-ml's runtime asks its C library
   for memory copies, formats (the floats') and Linux's system calls
   (`_syscall6`: read, write, open, sigaction...). On the bare board
   there is the UART. Its heap is two static arrays (512 MB each on
   arm64) and a value stack of 32 MB: the board's sizes instead.
3. **The C by mini-cc.** The kernel's C has gcc's own: `__asm__` 17
   times (`msr`, `mrs`, `wfi`, `tlbi`: all in the boards' `machine.c`
   but one), `__attribute__((aligned))` 5, `unsigned long long` 7,
   `va_list` 4, 16 `#include <...>`. And one trap: a `long` is 32 bits
   for 7c on arm64 (bugs/goken.md), 64 for gcc: every `unsigned long`
   that holds an address.
4. **The assembly by mini-asm.** `start.s` is GNU's syntax, with
   macros, `.rept`, `.incbin`, and the system instructions: `msr` 18,
   `mrs` 11, `isb` 6, `eret` 3, `tlbi` 2, `dsb` 2, `wfi`, `wfe`.
   mini-ld's arm64 knows `SVC` only; goken's 7a and 7l, its references,
   have `MSR`, `MRS`, `ERET`, `WFI` and more.
5. **The image by mini-ld.** A kernel is linked at an address
   (0x80000 on the Pi 4), with no system's header or with an ELF's that
   QEMU's `-kernel` and mini-qemu take; mini-ld writes Linux's ELF,
   a.out and Mach-O today, at their own addresses.
6. **The disk image inside the kernel**, without `.incbin`.

## Decisions

1. **Two builds, side by side.** The Makefiles stay as they are:
   ocaml-light, gcc, GNU's as and ld, the reference. A `mkfile` beside
   each (`kernel/xv6/mkfile`, later `kernel/9pi/mkfile`, over a
   `kernel/lib/mkkernel`) is the build by ix's tools only: mini-mk,
   mini-ml, mini-cc, mini-asm, mini-ld. Its image goes under
   `_mk/7/kernel/`. So which build an image comes from is which file
   made it, and what differs between the two is what differs between
   the Makefile and the mkfile.
2. **The same checks for both.** A kernel's `make check` boots its
   image under mini-qemu and QEMU and compares a session with the
   recorded one (xv6's C kernel's: `expected-pi4`; 9pi's: `tests/`).
   The mkfile's image must pass the same, the image's path the only
   thing that changes. Then the numbers, both builds: the image's
   size, the boot's time, the collector's work. They feed the
   optimization phase (plan_mkfiles.md, step 5).
3. **The Pi 4 first, arm64.** ix's toolchain is whole there: the
   eleven programs and the fixed point are arm64's. On arm, mini-ld
   encodes 5c's FPA floats and not the Pi 1's VFP, and mini-ml's
   programs with floats do not run yet (plan_mkfiles.md, step 4): the
   Pi 1 comes after that. `mini-ml -gas` (plan_ml.md's route B: GNU's
   assembly for arm, gcc's runtime) is not used here: it is arm only,
   and it would be a third build.
4. **mini-xv6 first**, 8 modules over `kernel/lib`'s 5; then mini-9pi
   on the Pi 4 (65 modules, with the pixels in OCaml: `PIXEL=ocaml`,
   so principia's C pixel libraries are not needed).
5. **One C source for the two builds**, as mini-ml's own runtime is
   (`runtime.c` by mini-cc, and by gcc through `gnu.h`). The kernel's
   C is brought to what both compilers take: the system instructions
   move out of `machine.c` into the board's assembly (functions:
   `set_ttbr0`, `counter`, `wait_interrupt`...), a word is a `value`
   and never a `long`, the aligned buffers are rounded by hand, and the
   runtime's interface is a header with two sides: ocaml-light's own
   names, or the same names over mini-ml's runtime. The Makefile's
   build must still pass its check after each such change: that is the
   guard.
6. **Two assembly files for a board**: `start.s` (GNU's, the
   Makefile's) and `l.s` (Plan 9's syntax, the mkfile's; the name
   Plan 9's kernels give theirs). The same code twice, about 300 lines: the price
   of two assemblers. mini-asm and mini-ld gain the system
   instructions as goken's 7a and 7l have them, the same bytes (they
   stay twins).
7. **mini-ml's runtime gains what a kernel needs, in the runtime's own
   file**, under one switch (as `__GNUC__` is one): C calling ML
   (`callback`, by pushing the arguments on the value stack: no
   assembly, plan_ml.md's decision 5), several value stacks (a process
   is its value stack's pointer and its handler; the collector scans
   each: "processes are two pointers"), and the heap's size from the
   board. `CAMLparam` becomes pushes on the value stack, `modify` a
   store (the collector copies: nothing to remember).
8. **A kernel's C library is goken's**, the files already in
   `lib_core/libc/`, with a shim of a page in the kernel's place of
   Linux: `write` to the UART, `exits` halts, `_syscall6` says "no such
   call". `kernel/lib/libc.c` stays the Makefile's (it is the same
   thing for ocaml-light's runtime and gcc).
9. **The kernel links the whole stdlib**, as every program by the
   mkfiles (plan_mkfiles.md, decision 4): simpler, and its size is one
   of the numbers to compare.
10. **Interrupts stay as they are**: taken from user mode only, the
    kernel runs with them masked. So the collector and the value
    stack are never interrupted, and nothing of mini-ml's signal
    handlers is needed.

## Steps

Each ends with something that runs under mini-qemu and under QEMU's
`raspi4b`, and is left for review before the next.

1. **Assembly on the bare Pi 4.** mini-asm and mini-ld: the system
   instructions (`MSR`, `MRS`, `ERET`, `WFI`, `ISB`, `TLBI`, `DSB`...),
   their bytes goken's; mini-ld: an image at an address. A page of
   Plan 9 assembly prints a line on the UART. The first `mkfile` under
   `kernel/`.
2. **C on the bare Pi 4.** The same line from C by mini-cc, over
   goken's libc and the shim (decision 8).
3. **OCaml on the bare Pi 4**: `kernel/step1`'s `Main.ml` as it is (a
   list of 100,000, a collection, an exception, Printf), by mini-ml on
   its runtime with the board's heap; the same four lines as
   `kernel/step1/expected`.
4. **The runtime for a kernel** (decision 7): callbacks, the value
   stacks and their switch, the interface's header (decision 5); tried
   with `kernel/step2` and `step3`'s programs moved to the Pi 4 (a
   trap handled in OCaml, two processes on their own stacks with the
   collector running).
5. **The kernel's C for both compilers** (decision 5), `l.s` for the
   Pi 4 (decision 6), the disk image in the kernel (open question 2):
   the Makefile's check still passing.
6. **mini-xv6 on the Pi 4 by its mkfile**: boots to `sh`; its session
   as `expected-pi4`, under mini-qemu and QEMU; `usertests`. In
   `mkfiles/check.sh`.
7. **The numbers**, both builds: size, boot, collections.
8. **mini-9pi on the Pi 4** by its mkfile: its sessions (`tests/`).
9. **The Pi 1** (arm), after plan_mkfiles.md's step 4.

## Decided since

1. **mini-ld's image is raw**, as Plan 9's kernels are linked (5l's
   `-H6 -T -R` there), at the address the board loads it (0x80000 on
   the Pi 4): what the real board takes (`kernel8.img`), and QEMU's
   `-kernel` when the file is not an ELF.
2. **A mkfile in each step's directory** (`kernel/step1/mkfile`...),
   with the Pi 4's `l.s`: each step has its two builds, the Makefile's
   for the Pi 1 by ocaml-light and the mkfile's for the Pi 4 by ix.
3. **No `mini-ml -gas`**: it was plan_ml.md's detour (mini-ml's code in
   the kernel with gcc's build around it); arm only, and a third build.

## Open questions

1. **The disk image in the kernel** (1.5 MB): an assembly file of
   `DATA` lines written by the recipe (no new feature, perhaps slow:
   to measure), or the image put after the kernel's by the recipe and
   found at `end` (no assembler, but the bss is there: the start must
   move it), or left outside and loaded by the emulator (not the real
   board's way). Proposed: measure the first in step 5.
2. **The size of a process's value stack**, and of its kernel stack: a
   call of mini-ml's takes 32 bytes of the C stack, ocamlopt's 16
   (bugs/ix.md), and a kernel stack is 16 KB today.

## What it costs (estimated)

| piece | lines |
|---|---:|
| mini-asm, mini-ld: system instructions, an image at an address | 100-150 |
| mini-ml's runtime: callbacks, value stacks, the board's heap | 150 |
| the interface's header, the shim | 150 |
| `l.s` for the Pi 4 (the same code as `start.s`) | 300 |
| the mkfiles | 80 |

About 800 lines, 300 of them a second spelling of the assembly; the
kernel's C and OCaml change little. ocaml-light's runtime, which the
other build compiles, is 32 files of C.
