# Plan: the Pi 4's kernels built by OCaml 4.14 (a third compiler)

Companion of [`plan_kernel.md`](plan_kernel.md) (the kernels, by
ocaml-light and gcc) and of
[`plan_kernel_mini_ml.md`](plan_kernel_mini_ml.md) (the same kernels by
ix's own tools). The author (2026-10-08): "right now for the kernel we
rely on ocaml-light to compile the kernel, as well as gcc to link.
Would it be possible to use the regular ocaml instead of ocaml-light?
I have OCaml 4.14 installed in the switch; would it require a more
complicated machine.c and runtime support than what we currently have
under kernel/lib_machine/ ?", and then: "maybe we should consider it as
an optional compiler to use when building for the Pi4 with real arm64
binaries".

**Status: done** (2026-10-08), and this file kept as its record: the
answer (yes, and no: the machine's C does not change), what it took,
the numbers. Left, for a plan of its own if it is wanted: the Pi 1 (an
ocamlopt for arm), the real Pi 4, and the open questions at the end.

## The answer

    cd kernels; ./ocaml.sh                     # once: the runtime's sources
    cd xv6;  make BOARD=pi4 COMPILER=ocaml     # kernel-pi4-ocaml4.elf
    cd 9pi;  make BOARD=pi4 COMPILER=ocaml
    make BOARD=pi4 COMPILER=ocaml check        # run, qemu, check: the same

`COMPILER` is `light` by default: nothing changes for who does not ask.
`COMPILER=ocaml` is refused for `BOARD=pi1`.

| piece | ocaml-light (`COMPILER=light`) | OCaml 4.14 (`COMPILER=ocaml`) |
|---|---|---|
| the compiler | `kernels/ocaml-light.sh`'s, cross-built in `/tmp` (5 minutes) | the switch's `ocamlopt`, as it is |
| its stdlib | ocaml-light's, compiled for the board | the switch's `stdlib.a` |
| the runtime | ocaml-light's `asmrun/` and `byterun/`, 32 files, by gcc, freestanding | 4.14's `runtime/`, 46 files, by gcc, freestanding (`kernels/ocaml.sh`: `opam source`); the headers are the installed ones |
| the kernels' OCaml | as written | as written (their written strings are `Bytes` now: step 7) |
| `machine.c`, `usb.c`, `start.s`, `kernel.ld` | | the same files, not a line changed |
| `runtime.c` | | 15 lines more |
| `libc.c` | | 80 lines more, under `#ifdef OCAML4` |

So no: the machine's side is not more complicated. What the regular
OCaml asks more is a longer C library under its runtime, and strings
that are not written.

## What it took

1. **The strings** (a shim first; gone in step 7). The kernels were written for ocaml-light, whose
   strings are written: `String.create`, `String.set`, `s.[i] <- c`,
   `String.blit` into one (63 places in 13 files, 55 of them
   mini-9pi's). The switch's 4.14 is configured with
   `-force-safe-string`: `-unsafe-string` is refused. Not a kernel's
   line was changed: `lib_machine/ocaml/String.ml` is OCaml's `String`
   with the six functions that write (`create`, `set`, `unsafe_set`,
   `blit`, `unsafe_blit`, `fill`), through `Bytes.unsafe_of_string`. A
   module of that name in the build's directory is the `String` the
   others see, `s.[i] <- c` included. kernel.mk's `COMPAT_ML` compiles
   and links it first.

2. **The runtime's view of the stack** (`runtime.c`). The five things a
   process's context keeps for the collector (`caml_bottom_of_stack`,
   `caml_last_return_address`, `caml_gc_regs`,
   `caml_exception_pointer`, `local_roots`) are the same five in 4.14,
   fields of its domain state (`Caml_state_field`); the hook is
   `caml_scan_roots_hook`, and `do_local_roots` is
   `caml_do_local_roots_nat`, the same five arguments. Seven
   `#define`s. The context's own field `local_roots` is now `roots`:
   4.14's `CAMLparam` has a macro of that name. The other names the
   kernel's C uses (`alloc_string`, `callback`, `copy_string`,
   `modify`) are 4.14's `compatibility.h`'s.

3. **The runtime's sources, and its headers.** The switch's
   `libasmrun.a` is for Linux: a stack protector, `_FORTIFY_SOURCE`'s
   `__memmove_chk`, Advanced SIMD. The runtime's C is compiled again,
   as ocaml-light's is, from 4.14's `runtime/`
   (`NATIVE_C_SOURCES` less `main`, `dynlink`, `dynlink_nat`, `meta`),
   with `-DCAML_NAME_SPACE` (its own files name the domain state's
   fields without the underscore the others see). `m.h` and `s.h` are
   configure's: the installed ones, so nothing is configured here.

4. **The C library** (`libc.c`): what the linker reported undefined, 58
   names. A few do something: `vsnprintf` and `snprintf` (`string_of_int`:
   the runtime tries 128 bytes, then the length it was told),
   `vfprintf` (the fatal errors), `ffs` (the best-fit free list's map
   of its small sizes) and `fmin` (the major collector's slice: the
   kernel booted to its prompt and panicked in `fmin` at its first
   major slice). The system's calls fail, and the runtime goes on:
   `readlink` (its executable's name), `mmap` and `sigaltstack` (a
   stack for the stack overflows), `lseek` (where a channel's
   descriptor is: ocaml-light's never asked, so it was a panic). The
   locale, the terminal and the directories say nothing; the maths
   panic, as before. `sscanf` reads `=%u%c` too (`CAMLRUNPARAM`'s
   `s=256k`).

5. **No Advanced SIMD.** gcc converts the collector's counters to
   doubles with the scalar forms of the vector instructions
   (`ucvtf d2, d2` in `caml_empty_minor_heap`): mini-qemu's arm64 has
   the scalar floating point only, and the kernel died there, an
   unknown instruction, at its first minor collection (QEMU ran it).
   `-fno-tree-vectorize`, enough for ocaml-light's runtime, is not for
   this one: `-march=armv8-a+nosimd` for the 4.14 build's C. ocamlopt's
   own code has none.

6. **The build's directories.** `build/pi4-ocaml4` and
   `kernel-pi4-ocaml4.elf` for xv6. mini-9pi names its directories
   itself (`build/pi4-ocaml` is its OCaml pixels', ocaml-light's; its
   check builds more with `B=` on the command line): its `PIX` has the
   compiler too (`build/pi4-ocaml-ocaml4`, `-b`...). The first try
   wrote 4.14's objects among ocaml-light's there, and the link said
   so (`caml_modify` undefined, 395 times).

7. **The written strings are `Bytes`** (the author, the same day:
   "maybe we can modify mini-ml to use immutable strings too, and use
   Bytes module for mutable one, so we're more aligned with what
   modern ocaml do, and need less shim"; of the two steps proposed,
   the kernels' sources first: "yes, let's start"). OCaml 4.14 without
   the shim was the checker: every place that wrote a string, and
   every type that carried one, an error. 14 files:
   - a buffer made, filled and given away (`Machine.le16`, the Pi 4's
     `Arch.word_bytes`, `Screen.row`, `Emmc.bytes`, `Devcons`'s
     `be64` and `random`, `Devusb`'s hub reply, `Devenv`'s value,
     `Exec`'s stack image, `Swcursor`'s two images, `Memimage`'s
     `pattern` and `repeat`): `Bytes.create`, `Bytes.set`, and
     `Bytes.unsafe_to_string` at the end, no copy;
   - mini-9pi's pixels: `Memimage.data`'s `bytes` is a `Bytes.t`
     (ocaml-light and mini-ml have no type `bytes`), and `Memdraw`
     reads and sets it with `Bytes.unsafe_get`, `unsafe_set`, `blit`,
     `blit_string`; `mem_rows` (the C) takes one. Where a string is
     asked of them without a copy (the framebuffer's write,
     `Memimage.to_screen`): `Bytes.unsafe_to_string`;
   - `Devsd`'s blocks read then written in part:
     `Bytes.unsafe_of_string` of what the card just gave, no one
     else's.

   `lib_machine/ocaml/String.ml` is deleted, with kernel.mk's
   `COMPAT_ML`. Two stdlibs followed: ocaml-light's `Bytes` had no
   `unsafe_set` and its `get` and `set` were functions
   (`kernels/ocaml-light-patches/bytes-primitives.patch`, the cross
   compilers built again; `docs/plans/bugs/ocaml_light.md`, section
   7), and mini-ml's (`lib_core/base/Bytes.ml`) has `get` and `set` as
   the primitives too: `Bytes.get` is where `s.[i]` was. Nothing
   changed in mini-ml itself: for it and for ocaml-light `Bytes.t` is
   `string`, so they accept the sources and do not check them; OCaml
   4.14's build is what says when a string is written again. The
   second step (mini-ml's own `bytes` apart from `string`,
   `String.set` and `s.[i] <- c` refused) is in "Left".

## The checks, the numbers

`make BOARD=pi4 COMPILER=ocaml check`:

- mini-xv6: all of it. The session under mini-qemu and QEMU as xv6's,
  the screen, the USB keyboard and mouse, usertests under QEMU.
- mini-9pi: stages B, C and D1's sessions, the USB keyboard, the
  screens as the C 9pi's, rio (11 lines of ok). The network's two
  `hget` said "Not found on server": a `python3 -m http.server 8123`
  of the day before still had the port and answered 404 to curl too;
  `ipconfig` and `ping` were as expected. To run again with the port
  free.
- ocaml-light's builds (the same `runtime.c`, `libc.c`, `kernel.mk`):
  both boards build, xv6's session under QEMU as before. Their full
  checks were not run again.

After step 7 (the written strings `Bytes`, no shim), the checks again:
mini-xv6's whole under ocaml-light (the Pi 1, the Pi 4), OCaml 4.14
(the Pi 4) and mini-ml (`mini-mk check`, the Pi 4); mini-9pi's under
ocaml-light (the Pi 1) and OCaml 4.14 (the Pi 4), each its 11 lines of
ok and the two `hget` of the stale server. mini-9pi by mini-ml builds
for both boards; its checks were not run.

| the Pi 4's image | ocaml-light | OCaml 4.14 |
|---|---:|---:|
| mini-xv6, bytes | 1,922,912 | 2,748,552 |
| mini-9pi, bytes | 1,715,728 | 2,991,464 |
| mini-xv6: the OCaml and its stdlib, text | 118,252 | 302,548 |
| mini-xv6: the runtime, text | 65,245 | 188,676 |
| mini-xv6: to `ls` under mini-qemu, seconds | 3.0 | 3.0 |
| mini-xv6: the check's session under mini-qemu, seconds | 20.9 | 20.6 |

(`kernels/xv6/numbers.sh light=kernel-pi4.elf ocaml4=kernel-pi4-ocaml4.elf`;
`size` on `build/pi4*/ocaml.o` and `rt_*.o`.) The image is larger by
the stdlib a `Printf` brings and by a runtime three times ocaml-light's;
the time is the same, the session being xv6's programs more than the
kernel.

## Left

- **The Pi 1.** The switch's ocamlopt emits arm64 only, and 4.14 does
  not build a compiler for a 32-bit target on a 64-bit host. An OCaml
  4.14 for armhf built by `arm-linux-gnueabihf-gcc` and run under
  `qemu-arm` (both are installed), with `-farch armv6 -ffpu vfpv2`, is
  the route to try. Not tried.
- **The real Pi 4**: under the emulators only, so far.
- **`malloc` without `free`** (`libc.c`'s bump pointer): 4.14's runtime
  may free more than ocaml-light's (the minor heap resized, a
  compaction's chunks). The checks did not run out; a long session of
  mini-9pi was not measured.
- **`.eh_frame`**, 87 KB of the image: `kernel.ld` could discard it.
- **The collector's parameters**: `CAMLRUNPARAM=s=256k` is read
  (4.14's default minor heap is already 256k words);
  [`plan_9pi_gc.md`](plan_9pi_gc.md)'s measures were not made again.
- **mini-ml's build** (`mkkernel`) is not concerned: its runtime is its
  own.
- **mini-ml checking it**: `bytes` a type of its own in mini-ml and
  `lib_core` (`Bytes.t` abstract, `unsafe_to_string` the identity
  primitive), `String.create`, `String.set`, `s.[i] <- c` gone. The
  stdlib's own `String`, `Buffer` and `Format` write strings still;
  ix's programs, compiled by OCaml 4.14 too, do not, nor the other
  kernels.
