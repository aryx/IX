# Plan: mini-9pi's collector, the boot's time

mini-9pi's boot to rc's prompt (about 8s of the host's under mini-qemu)
spends a third to a half of its time in OCaml's major collector. Not a
bug, and not an optimization of an original (so not in
[variants/opti.md](variants/opti.md), which points here): the kernel's
own runtime, tuned or not.

- **Measured (2026-09-27)**: `mini-pi -v mini-9pi` (mini-qemu's
  `-status 2`, docs/manuals/mini-qemu.md section 4.6), the boot to
  rc's prompt, about 8s of the host's: after the first two seconds
  (`memmove`, `mark_slice`, the console drawn), the major collector
  takes 30 to 50% of the kernel's time (`mark_slice` 30, 45, 50% in
  successive lines, `sweep_slice` 12 to 15% more); the same on the Pi4
  (`mini-9pi4`). At the prompt it is idle (97%): the cost is the
  boot's, and a session's commands'.
- **Why, a guess not yet checked**: the kernel runs with ocaml-light's
  defaults (byterun/config.h; kernel/lib/libc.c's `caml_main` sets
  none): a 32K-word minor heap, the major heap grown by 62K-word
  chunks, 42% of space overhead. A small minor heap promotes much, and
  small increments mean many major cycles, each marking everything
  live (the embedded bootdir's programs among it, if they are OCaml
  strings in the heap).
- **The first steps**: count the collections (minor and major) over a
  boot; then try the parameters (a larger minor heap and increment, a
  higher space overhead, set in `caml_main`'s caller before it runs),
  each a switch as the other optimizations, the default kept; measured
  by the boot's time and `-status`'s share. Only then the allocations
  themselves (who allocates what at boot: `-prof`, pcprof.py).
- **The tests**: 9pi's `make check` (the console byte for byte, the
  screens), unchanged: the collector's parameters do not change what
  the kernel prints.

