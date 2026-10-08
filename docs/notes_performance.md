# Performance, written up as it gets measured

Notes on how slowness in ix was tracked down and fixed. Each case gives
the symptom, the measure, the profile, the fixes in order with what
each one saved, and the lesson. It is the companion of
[notes_debugging_techniques.md](notes_debugging_techniques.md). The
general OCaml techniques are in the Playground's
`~/playground/docs/claude_notes/dev/notes_opti_ocaml.md`. The code
keeps each optimization's slow version in an `old:` comment next to
the fast one, so that a reader can see what the optimization buys.

The tools (`kernels/9pi/tests/perf/`):
- `timecmd.py CMD -- EMULATOR...` times a command typed at rc's
  prompt, N times.
- mini-qemu's `-prof F` counts every 1024th instruction's PC and
  writes the counts to F at exit
  ([manual](manuals/mini-qemu.md), section 4.5).
- `pcprof.py F kernel.elf` maps those PCs to the kernel's functions.
- mini-qemu's `-status N` (`mini-pi -v`) says every N seconds how idle
  the kernel is and which of its functions run
  ([manual](manuals/mini-qemu.md), section 4.6).
- `gc_boot.sh [PARAMS [RUNS [BOARD]]]` times mini-9pi's boot to rc's
  prompt for the collector's parameters (CAMLRUNPARAM's), and counts
  its collections from the runtime's own trace (v=1).

Wall times depend on the host's load: compare runs made back to back,
and check the boot's time, which should not change.

## 1. mini-9pi's OCaml pixels: division is a function call (2026-09-27)

**Symptom.** `mini-pi -g mini-9pi` with the OCaml pixels
(`lib_graphics/ocaml/`, stage F) felt "very sluggish", and rio "almost
unusable". With `-p c` (principia's C memdraw) it was fine.

**Measure.** `ls -l /bin` on the drawn console (without a window: the
console is still drawn in the framebuffer):

| pixels | time |
|---|---|
| C | 10 s |
| OCaml | 61 s |

The OCaml version was steadily 6 times slower. Nothing got worse over
time; the drawing was just slow everywhere.

**First guess, wrong.** An earlier histogram of the draws that fall
into the general loop showed only about 11,000 pixels in a whole rio
session, so the guess was the GC: `flush`'s per-row `String.sub`,
allocated in the major heap. That turned out to be part of the cost,
but not most of it. Measuring first would have saved the guess.

**Profile** (every 1024th PC, mapped to the kernel's symbols):

| function | share |
|---|---|
| `__aeabi_idivmod` | 38% |
| `memmove` | 18% |
| `mark_slice` + `sweep_slice` (the major GC) | 14% |
| `Memdraw.faster`, `Memimage.layout`, `byteaddr` | 11% |

`__aeabi_idivmod` is not in our code: it is libgcc's division, a loop
of tens of instructions. The Pi1's ARMv6 has no divide instruction, so
every OCaml `/` and `mod` compiles to a call to it. The divisions were
here:
- `Memimage.byteaddr` computed `fdiv (x * depth) 8`. It runs for every
  row of every draw, and in the character path for every pixel, with
  a `layout` and a second `byteaddr` besides.
- `Memdraw.row` built a row's bytes with `pat.[i mod n]`, one division
  a byte.
- `Memimage.fill` used two `mod`s a byte, 1.2 million divisions for
  a 640x480 screen at 16 bits.

**Fixes**, in order, measured the same way:

| fix | where | time |
|---|---|---|
| before | | 61 s |
| divisions by 8 and 32 become shifts (`a asr 3`); `asr` floors, as `fdiv` did, negative x included | `Memimage.bytex`, `fshr`, `cshr`, `units` | 45 s |
| the character path computes each row's mask and destination addresses once; a pixel is then an offset | `Memdraw.faster` | 32 s |
| a pattern's row built by doubling blits, log2 of the repetitions, and no `mod` | `Memimage.repeat` (`fill`, `Memdraw.row`) | |
| the flush writes a row from where it is in the image: `Machine.Phys.write_sub`, no `String.sub` (no 1280-byte string to the major heap per row) | `Memimage.flush` | |
| `max` and `min` on ints: the Stdlib's are polymorphic, each a call to `compare_val` | `Memimage` | |
| `memmove` copies words whenever both ends share an alignment (before: only when both ends and the length were all aligned, so rows of 16-bit pixels went a byte at a time) | `kernels/lib_machine/libc.c` | 28.6 s (last three together) |

Afterwards, on a quieter host, the same command took 17.9 s. The C
pixels took 14 s under the profiler (10 s without). So the OCaml
pixels went from 6 times slower than the C to under 2 times. rio is
"slow, but usable". Every check still passes: all of rio's screens are
byte for byte the C 9pi's, and mini-xv6 (which shares `memmove`)
passes too.

**What is left**, from the profile after the fixes:
- `memmove`, 20%. The OCaml screen is a copy that each draw flushes
  to the framebuffer; the C memdraw draws straight into it. A scroll
  copies the screen twice.
- The major GC, about 13%. The C 9pi has it too (23% of its profile):
  it comes from the kernel, not from the pixels.
- The cursor goes through the general loop: a GREY1 source through a
  GREY1 mask onto RGB16, about 256 pixels read, composed and written
  per move.

**Lessons.**
1. **Look at the target's instruction set.** On a CPU without a
   divider, a division in a per-pixel or per-row helper costs more
   than the pixel operation itself. Divisors that are powers of 2 are
   shifts. A `mod` inside a byte loop is a division per byte.
2. **Profile before guessing.** The guess (the GC) was plausible and
   partly true, but the profile named the real cost in one run, and
   the cost was in a function we did not write.
3. **Hoist what does not change out of the inner loop.** An address
   recomputed per pixel (tuples, a division) became a base per row
   plus an offset.
4. **Do not allocate per row.** A `String.sub` bigger than the minor
   heap's limit (256 words) goes to the major heap and is marked and
   swept later. A primitive that takes an offset and a length avoids
   the copy.
5. **Shared code gets faster for everyone.** The `memmove` fix is in
   `kernels/lib_machine/`, which mini-xv6 uses too.

## 2. mini-9pi's boot: the collector's minor heap (2026-09-28)

**Symptom.** mini-9pi boots to rc's prompt under mini-qemu in 13.5 s
on the Pi1, and `-status` put 30 to 50% of it in the major collector
(`mark_slice`, `sweep_slice`), in no function of the kernel's
(plan_9pi_gc.md).

**The measure.** The runtime's own trace first, before any profile:
ocaml-light's CAMLRUNPARAM=v=1 prints `<` `>` around a minor
collection and `$` at a major cycle's end
([debugging techniques](notes_debugging_techniques.md), 13). A kernel
has no environment: libc.c's getenv now gives CAMLRUNPARAM when the
kernel is built with one, and a small sscanf parses its values. The
boot made 100 minor collections and 43 whole major cycles: the
defaults' 32k-word minor heap (128 KB on the Pi1), too small for a
boot's ~13 MB of mostly short-lived data, promoted it, and the major
collector marked and swept the whole heap over and over.

**The fix, a parameter** (`gc_boot.sh`, the median of 3 boots):

| board | CAMLRUNPARAM | boot | minor | major |
|---|---|---|---|---|
| Pi1 | (ocaml-light's defaults) | 13.5 s | 100 | 43 |
| Pi1 | `s=256k` (the minor heap, 8 times) | 9.4 s | 12 | 6 |
| Pi1 | `o=200` (the space overhead) | 10.2 s | 100 | 48 |
| Pi1 | `h=1M,i=1M` (the heap, its increment) | 12.4 s | 102 | 55 |
| Pi1 | all four | 9.1 s | 13 | 7 |
| Pi1 | `s=1M,o=200,h=4M,i=1M` | 8.6 s | 4 | 2 |
| Pi4 | (ocaml-light's defaults) | 9.7 s | 61 | 42 |
| Pi4 | `s=256k` | 8.1 s | 7 | 4 |

`s=256k` is the kernels' default now (kernel.mk; `make CAMLRUNPARAM=`
for ocaml-light's): 30% of the Pi1's boot, 17% of the Pi4's (whose
default minor heap is already twice as big in bytes), for 1 MB of
memory (2 on the Pi4). The other parameters add little against the
noise; a floor near 8 s is the boot's own work.

**What is left.** After the prompt, idle, the trace goes on without
end, `<>$<>$...`: each interrupt runs the idle loop and the clock's
wakeup, which walks Proc's `all ()`, a list of the processes made anew
at each call; a few hundred ticks fill the minor heap, and with a live
heap that small each minor collection's major slice ends a whole
cycle. Cheap (the kernel is idle 97% of the time), but a real Pi's
steady cost.

**Lessons.**
1. **Count the collections before profiling the code.** The runtime
   knows how often it collects; the profile only shows where the time
   went, not why so often.
2. **Try the minor heap first.** A program that allocates much and
   keeps little (a boot, a compiler's pass) wants a nursery big enough
   for its short-lived data: one parameter, no code.
3. **Give a freestanding program its environment.** The runtime's
   switches (OCAMLRUNPARAM) are there; a kernel only lacked the
   getenv to reach them.

## 3. mini-9pi's checks: a second of quiet a line, and a card with no cache (2026-10-07)

**The symptom.** `make check-all` in kernels/9pi took 14 minutes on
2026-10-06 and 20 minutes 40 the day after, when the card's session
had 30 programs of utilities/ more. By the times of the consoles'
files: `check` 1 minute 40 (its sessions at once), `check-ix` 2
minutes 10, `check-card` 8 minutes 30 (the card's session of ix's
programs: 4 minutes 09 under mini-qemu, 2 minutes 17 under QEMU).

**The measures** (QEMU, the image of `make ix` with the card; the
boot alone 4.5 s):

| five commands after the boot | seconds | a command |
|---|---:|---:|
| five programs from the card (wc, date, mtime, basename, cmp) | 13.3 | 1.76 |
| the same, with `Kfs`'s cache | 11.3 | 1.35 |
| one program from the card five times, with the cache | 9.7 | 1.04 |
| `cat` from the kernel's image (/boot) five times | 9.0 | 0.90 |

So a second a command was there whatever the kernel did: not the
card's, the driver's.

**Three causes, three changes.**
1. `kernels/lib_machine/session.py` types a line after a prompt *and a second
   with no output* (a file's text may hold a prompt). For ix's
   sessions, of 60 and 120 lines whose output has none: `--quiet 0.3`
   (the Makefile's `IXQUIET`). The principia sessions keep the second.
2. The sessions of `check-ix` and of `check-card` ran one after the
   other: now all at once, each its own emulator (the card is a
   snapshot for each), then their consoles compared.
3. `Xv6fs` has no cache of blocks, by its design: a file's block is a
   read of the device for its number and one for its bytes, each a
   command to the SD card. `Kfs` now reads the device by pieces of 4
   KB and keeps them (512, then all forgotten; a write forgets the
   pieces it touches): `Kfs.cached`, false for the device read each
   time as before. A program's first start from the card: 1.76 s to
   1.35; started again, as from the kernel's image.

**What it bought.** `check-ix` 39 s (130), `check-card` 3 minutes 12
(8 minutes 30): what is left there is the card's session under
mini-qemu, 3 minutes, the emulator's own speed on 30 programs of 650
KB.

**Then the card's session cut in five** (the same day): one session of
73 lines was 3 minutes under mini-qemu whatever ran beside it; five
short ones at once (`CARDS_IX`), `check-card` 68 s. A long session is
the sum of its lines; short ones are the longest of them.

