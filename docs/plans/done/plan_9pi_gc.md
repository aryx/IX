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
  defaults (byterun/config.h; kernels/lib_machine/libc.c's `caml_main` sets
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

**Status: done** (2026-10-08; the author: "let's do it, let's move to
done/"), and this file kept as its record: the collections counted and
the parameters tried, `s=256k` the kernels' default. Left, for a plan
of their own if they are wanted: the allocations themselves (who
allocates what at boot: `-prof`), and the collector's steady cost at
the prompt (each tick's wakeup makes Proc's list).

## Done (2026-09-28)

- **Counted**: the runtime's own trace (CAMLRUNPARAM=v=1), reachable
  once libc.c's getenv gives CAMLRUNPARAM when the kernel is built
  with one (and a sscanf for its values): 100 minor collections and
  43 whole major cycles over the Pi1's boot, the heap grown by 248 KB
  ten times. The guess was right: the defaults' minor heap (32k words)
  too small for a boot's ~13 MB of short-lived data.
- **The parameters, each a switch** (kernels/9pi/tests/perf/gc_boot.sh,
  the median of 3 boots): `s=256k`, the Pi1's boot 13.5 s to 9.4 (12
  minor, 6 major), the Pi4's 9.7 to 8.1; `o=200` 10.2; the heap's size
  and increment 12.4; all four 9.1; nothing else near `s`'s gain. Its
  default in kernel.mk now (`make CAMLRUNPARAM=` for ocaml-light's),
  1 MB of memory (2 on the Pi4). The numbers, and why: notes_performance.md,
  section 2; the trace: notes_debugging_techniques.md, 13.
- **Found**: idle at the prompt, the collector never stops: each tick's
  wakeup walks Proc's `all ()`, a list made at each call. A steady
  cost, small (97% idle), not the boot's: left.
- **Checked**: each boot of gc_boot.sh reached rc's prompt, Pi1 and
  Pi4, with every parameter tried; mini-9pi's and mini-xv6's make
  check with the new default (the consoles byte for byte): running
  when this was committed.

