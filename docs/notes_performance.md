# Performance, written up as it gets measured

Notes on how slowness in ix was tracked down and fixed. Each case gives
the symptom, the measure, the profile, the fixes in order with what
each one saved, and the lesson. It is the companion of
[notes_debugging_techniques.md](notes_debugging_techniques.md). The
general OCaml techniques are in the Playground's
`~/playground/docs/claude_notes/dev/notes_opti_ocaml.md`. The code
keeps each optimization's slow version in an `old:` comment next to
the fast one, so that a reader can see what the optimization buys.

The tools (`kernel/9pi/tests/perf/`):
- `timecmd.py CMD -- EMULATOR...` times a command typed at rc's
  prompt, N times.
- mini-qemu's `-prof F` counts every 1024th instruction's PC and
  writes the counts to F at exit
  ([manual](manuals/mini-qemu.md), section 4.5).
- `pcprof.py F kernel.elf` maps those PCs to the kernel's functions.
- mini-qemu's `-status N` (`mini-pi -v`) says every N seconds how idle
  the kernel is and which of its functions run
  ([manual](manuals/mini-qemu.md), section 4.6).

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
| `memmove` copies words whenever both ends share an alignment (before: only when both ends and the length were all aligned, so rows of 16-bit pixels went a byte at a time) | `kernel/lib/libc.c` | 28.6 s (last three together) |

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
   `kernel/lib/`, which mini-xv6 uses too.
