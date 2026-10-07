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
(`kernel/9pi`, 9,696) over `kernel/lib_machine` (891), on two boards: the Pi 1
(arm) and the Pi 4 (arm64). `kernel/lib_machine/kernel.mk`, a Makefile, builds
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
   `kernel/lib_machine/mkkernel`) is the build by ix's tools only: mini-mk,
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
4. **mini-xv6 first**, 8 modules over `kernel/lib_machine`'s 5; then mini-9pi
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
   call". `kernel/lib_machine/libc.c` stays the Makefile's (it is the same
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
   **Done** (2026-10-02), in `kernel/steps/step0/` (a step before the
   Makefiles' five: `hello.s`, its `mkfile`, `expected`):
   - mini-ld `-H0 -T address`: no header, the text at the address, the
     data right after it (7l's `-H0`: the same file, to the byte);
   - mini-asm reads `SPR(bits)`, a system register by its bits (7a's;
     a `#define` gives it its name: `MPIDR_EL1`), and mini-ld encodes
     `MRS`, `MSR`, `ERET`, `WFI`, `WFE`, `ISB`, `DSB`, `DMB`, `SYS` and
     its names `TLBI`, `IC`, `DC`, `AT`: goken's bytes
     (`linker/tests/golden/system_7.s`, in `golden.sh`), and what
     GNU's objdump reads back. Not yet: `MSR $imm, DAIFSet` (the PSTATE
     form), the registers 7a knows by name;
   - `mini-mk check` there: the image booted under mini-qemu and under
     QEMU's `raspi4b`, each printing the line. The four cores start at
     0x80000 on the real board: all but the first wait (`MRS`, `WFI`).
   About 45 lines more in mini-asm and mini-ld.
2. **C on the bare Pi 4.** The same line from C by mini-cc, over
   goken's libc and the shim (decision 8).
   **Done** (2026-10-02), in `kernel/steps/step0/` too: `l.s`, the start
   (the first core alone, EL3 or EL2 down to EL1, the floating point
   allowed, the bss cleared, a stack of 1 MB in the bss, R28, `main`),
   93 lines of Plan 9 assembly for `start.s`'s first 80 of GNU's;
   `shim.c`, 57 lines: Linux for the library is one function,
   `_syscall6`, here in C with two calls, `write` to the PL011 and
   `exit`, the others ENOSYS; `hello.c` formats a line with a double and
   writes it. The same line under mini-qemu and QEMU. (`print` is not
   in `lib_core/libc`: only what mini-ml's runtime links is.)
3. **OCaml on the bare Pi 4**: `kernel/steps/step1`'s `Main.ml` as it is (a
   list of 100,000, a collection, an exception, Printf), by mini-ml on
   its runtime with the board's heap; the same four lines as
   `kernel/steps/step1/expected`.
   **Done** (2026-10-02): `kernel/steps/step1/mkfile`, beside its Makefile.
   The same `Main.ml`; mini-ml's runtime as it is, compiled with the
   board's sizes (`-DMAXHEAP -DSTACK`: two halves of 32 MB, a value
   stack of 1 MB; its default is 1 GB of bss, which the start would
   clear); step 0's `l.s` and `shim.c`; the whole stdlib, every unit
   initialized (`Unix`, `Sys`... on a board without a system: one
   change, `Sys.executable_name` when there is no argument at all).
   Under mini-qemu and QEMU the four lines are the Makefile's, but the
   sum: 4999950000, which the Pi 1's 31 bits wrap to 704982704
   (`expected-pi4`). The image: 726 KB (the stdlib whole), the Pi 1's
   by ocaml-light 106 KB.
4. **The runtime for a kernel** (decision 7): callbacks, the value
   stacks and their switch, the interface's header (decision 5); tried
   with `kernel/steps/step2` and `step3`'s programs moved to the Pi 4 (a
   trap handled in OCaml, two processes on their own stacks with the
   collector running).
   **Done** (2026-10-02): `kernel/steps/step2/mkfile` and `step3/mkfile`,
   each beside its Makefile, with the Pi 4's machine in `pi4/`. Their
   lines are the Makefiles' `expected`, the same files, under mini-qemu
   and QEMU.
   - **C calls ML**: `callback`, `callback2`, `caml_named_value` in the
     runtime. ML's arguments are in registers and the value stack's top
     in one (R26), so "pushing the arguments from C" (decision 7,
     plan_ml.md) was not it: the start object gains `ml_callback`, six
     instructions written by Gen as `ml_try` and `ml_raise` are; still
     no assembly file. `tests/runtime/callbacks.ml`: collections and an
     exception inside, on arm64 and arm. Not with gcc's C (`-gas`):
     it keeps values in the registers the stack machine uses.
   - **The value stacks**: `ml_stack(i, base)`, `ml_stack_switch(i)`;
     the collector scans each. The kernel's `swtch` keeps three words
     for a context: the stack pointer, the link, R26. For ocaml-light
     (`step3/machine.c`): five globals saved and restored at each
     switch, a hook, and a walk of each stack's frames.
   - In the runtime for every program, not under a switch as decision
     7 said: 80 lines, and nothing a program pays for.
   - **The interface**: `languages/ml/runtime/mlvalues.h` and
     `callback.h`, ocaml-light's names over mini-ml's runtime: the C
     says `#include <mlvalues.h>` for both builds, the `-I` says which.
     Beside the runtime and not in `kernel/lib_machine`: for any C linked with
     mini-ml's code, a kernel's or not.
     `runtime.c` includes it too: a value's layout is said once.
   - **The same `Main.ml`** for the two boards and the two compilers.
     It reads the user's registers as xv6 arm-pi1 lays them out (17
     words of 32 bits); the Pi 4's `machine.c` gives it that view of
     the real frame, and `user.s` keeps that convention.
   - **`l.s`**: the vectors (16 entries of 128 bytes, at a multiple of
     2048) are the image's first bytes, the assembler having no
     alignment; the first entry, never taken, is the branch to the
     start. A system register (`TPIDR_EL1`) holds the user's first
     register while the frame's address is loaded. mini-asm's
     `#include` now includes (it kept only the `#define`s), and a
     `#define` may name others: step 3's `l.s` is step 2's and `swtch`,
     step 2's is the vectors, step 0's start, and the trap.
   - In `mkfiles/check.sh`: each step booted.
5. **The kernel's C for both compilers** (decision 5), `l.s` for the
   Pi 4 (decision 6), the disk image in the kernel (open question 2):
   the Makefile's check still passing.
   **Done** (2026-10-02).
   - **The C, one source**: `lib/runtime.c`, `lib/usb.c` and
     `lib/pi4/machine.c` compile by gcc over ocaml-light's runtime and
     by mini-cc over mini-ml's. What changed in them: a word is a
     `uintptr` (Plan 9's names, `board.h` gives them to gcc); no
     `__attribute__` (an aligned buffer is the aligned address inside a
     longer one, a kernel stack's top is rounded); no `__asm__` (seven
     functions in the board's assembly: `set_ttbr0`, `timer_set`,
     `wait_for_interrupt`...); no `sprintf` (16 hex digits by hand);
     `empty_table()` and `fs_image_size` for two symbols a linker
     without alignment cannot place. In `runtime.c` the collector's
     view of the stacks is the one part with two sides (`MINI_ML`): 25
     lines for ocaml-light (five globals a context, a hook), 8 for
     mini-ml (`ml_stack`, `ml_stack_switch`).
   - **The runtime's interface** gains `memory.h` (`CAMLparam`,
     `CAMLlocal`, `CAMLreturn`: a C function's own values, a chain per
     value stack that the collector follows) and `alloc.h`
     (`alloc_string`, `copy_string`, `alloc_tuple`...).
   - **`lib/pi4/l.s`**, 401 lines for `start.s`'s 353: linked at
     KERNBASE + 0x80000 and loaded at 0x80000, the boot takes KERNBASE
     off each address (the assembler has no address relative to the
     pc); the vectors first; the three tables at fixed addresses below
     the image (no alignment). The context is `runtime.c`'s, of which
     `swtch` keeps three words.
   - **The disk image** (open question 1): data, 192,000 `DATA` lines
     written by `od` and `awk` in the recipe; mini-asm takes 2 seconds,
     mini-ld a quarter. No new feature.
   - `lib/shim.c` (step 0's, the UART where the kernel maps it),
     `lib/mkkernel` (kernel.mk's counterpart).
   - The guard: after the changes, by the Makefiles, mini-xv6's check
     passes on the Pi 4 and on the Pi 1, and mini-9pi builds on both.
6. **mini-xv6 on the Pi 4 by its mkfile**: boots to `sh`; its session
   as `expected-pi4`, under mini-qemu and QEMU; `usertests`. In
   `mkfiles/check.sh`.
   **Done** (2026-10-02): `kernel/xv6/mkfile`. The image booted to
   `sh` the first time it linked. `mini-mk check` is the Makefile's
   check with this image, the six of them: the session under mini-qemu
   and under QEMU as xv6's C kernel's (`expected-pi4`, the same file),
   the screen the same under both, the session typed on a USB keyboard
   with the mouse moved, `usertests` under QEMU. mini-xv6 is built
   without ocaml-light, gcc, GNU's as or ld.
7. **The numbers**, both builds: size, boot, collections.
   First ones (2026-10-02), mini-xv6 on the Pi 4:

   | | by ocaml-light and gcc | by ix's tools |
   |---|---:|---:|
   | the image without the disk's 1.5 MB | 248 KB | 922 KB (the stdlib whole) |
   | the bss | 1.1 MB | about 75 MB (the heap's two halves, the value stacks) |
   | to `sh`'s prompt and an `ls`, under mini-qemu | 2.8 s | 8.1 s (of which the bss cleared) |
   | the six checks | 1 min 54 | 4 min 22 |
   | the kernel built (the stdlib and the C library made before) | | 9 s |

   The collector's work, and where the time goes: with the
   optimization phase (plan_mkfiles.md, step 5).
8. **mini-9pi on the Pi 4** by its mkfile: its sessions (`tests/`).
   **Done** (2026-10-02): `kernel/9pi/mkfile`. 52 modules of its own
   in 22 directories (`mkkernel` takes their paths, their names and
   their `-I`), the pixels in OCaml, the two files the Makefile
   generates (principia's pixel tables, the boot's directory) by the
   same two scripts, `-DTF_USER_PSR=0x10` for the C (the processes are
   principia's arm programs, AArch32 at EL0). Nothing else: the kernel's
   C and `l.s` are mini-xv6's. It booted principia's SD card to `rc`'s
   prompt at its first link.
   `mini-mk check` is the Makefile's check itself: the Makefile run for
   its `check` only, told not to make the images (`make check IMAGE=...
   -o ...`), so the commands, the sessions and the screens expected are
   the Makefile's and the mkfile repeats nothing. The 13 pass: stage
   B's, C's and D1's sessions, a session typed on the USB keyboard, the
   screen and the mouse's cursor as the C 9pi draws them, rio (its
   menu, a window swept out, a command in it: every screen), the
   network (ipconfig, ping, hget), each under mini-qemu and QEMU. 25
   minutes: not in `mkfiles/check.sh`.
   The image: 2,566,384 bytes with the boot's directory (780 KB); the
   Makefile's ELF 1,715,728.
9. **The Pi 1** (arm), after plan_mkfiles.md's step 4. (2026-10-02:
   its floats are done: mini-ld's are VFP's, the Pi 1's.)
   **Done** (2026-10-03): `mini-mk O=5` in each kernel's directory.
   `kernel/lib_machine/mkboard` gives the board from the machine (O=5 the Pi
   1, O=7 the Pi 4), so a step, mini-xv6 and mini-9pi have one mkfile
   each for both. The steps 0 to 3 boot as expected under mini-qemu
   and QEMU (`mkfiles/check_arm.sh`); mini-xv6 passes its Makefile's 7
   checks and mini-9pi its 13 (`tests/kernels_ix.sh`). What it took:
   - the Pi 1's assembly for mini-asm (`kernel/step*/pi1/`,
     `kernel/lib_machine/pi1/l.s`): as the Pi 4's, the tables below the image
     at fixed addresses (no alignment), the boot naming no data until
     the MMU is on. A trap's entry saves R11 with the user's
     registers before it names a variable: the linker's own register,
     for a constant or an offset too large for an instruction (init
     died at its first printf);
   - mini-ld: `MOVW CPSR, R` and back (5l's cases 35 and 36); mini-asm:
     `MRC` and `MCR`, words as 5a makes them. The VFP's `vmsr` and
     `wfi` stay words;
   - `kernel/lib_machine/pi1/machine.c` for gcc and mini-cc: its inline
     assembly in the board's `start.s` and `l.s`, as the Pi 4's;
   - mini-ml passes 7 parameters at most on arm: six functions of
     mini-9pi's `Memshape` had up to 11, regrouped (an ink: a source,
     its point, the operator).
   The images: mini-xv6 1,545,152 bytes, mini-9pi 2,446,816.

## Decided since

1. **mini-ld's image is raw**, as Plan 9's kernels are linked (5l's
   `-H6 -T -R` there), at the address the board loads it (0x80000 on
   the Pi 4): what the real board takes (`kernel8.img`), and QEMU's
   `-kernel` when the file is not an ELF.
2. **A mkfile in each step's directory** (`kernel/steps/step1/mkfile`...),
   with the Pi 4's `l.s`: each step has its two builds, the Makefile's
   for the Pi 1 by ocaml-light and the mkfile's for the Pi 4 by ix.
3. **No `mini-ml -gas`**: it was plan_ml.md's detour (mini-ml's code in
   the kernel with gcc's build around it); arm only, and a third build.

## Open questions

1. **The size of a process's value stack**, and of its kernel stack: a
   call of mini-ml's takes 32 bytes of the C stack, ocamlopt's 16
   (bugs/ix.md). Today 16,384 words and 16 KB (the Makefile's): enough
   for mini-xv6's session and `usertests`; nothing says when one
   overflows.
2. **On the real Pi 4**: the image is the raw `kernel8.img` the
   firmware loads, but only the emulators have run it.

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
