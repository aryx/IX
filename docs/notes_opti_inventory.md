# The frame-time optimizations of a month, and what each one is worth

The author, 2026-10-22, after Redraw was made to compare inside groups:
"we did lots of optimizations in lib_graphics and lib_playground and
also kernel/.../lib_graphics to reduce those fps; would be good to have
a good summary and what each opti brings and whether they are worth it
and whether some cancel each other" (in the last month), then "let's
add a notes_opti_inventory.md document".

Scope: 2026-09-22 to 2026-10-22. lib_graphics/, lib_playground/
(Redraw, Shape_render_software, the sdl, software, draw and ppm
platforms, Plan9_loop), mini-9pi's drawing code
(kernels/9pi/lib_graphics/lib_memdraw, lib_memlayer, devices/screen)
and the C it calls (kernels/lib_machine/libc.c, runtime.c). The
mini-ml, emulator and audio changes that moved the same numbers are in
"Adjacent", at the end.

Sources: `git log --since=2026-09-22`, the commit messages, the code's
OPTIMIZATION, opti: and old: comments, plans/plan_playground_speed.md,
plans/plan_playground_framebuffer.md, [notes_performance.md](notes_performance.md)
(section 1), [notes_font.md](notes_font.md) (section 5),
plans/bugs/ix.md, and the Playground's
`~/playground/docs/claude_notes/dev/notes_opti_ocaml.md`. Every number
is copied from them with the setting they give, except O30's, measured
for this note (`kernels/9pi/tests/perf/redraw.sh`). "QEMU" is mini-9pi
under qemu-system-arm (raspi1ap) on the author's host; a real board's
number says **Pi1**. Line numbers are those of 2026-10-22.

How to switch each one off at run time, where it can be: the flags are
gathered in [manuals/m-ix.md](manuals/m-ix.md).

## Worth it?

Kept, the gain large and measured:
- The kernel's fast paths (O1, O2, O5, O6, O8-O10): mini-9pi's pixels
  went from 19 times slower than principia's C to faster than it for
  the games (30-33 fps against 10).
- Redraw (O16) and its draw-platform side (O30): a program that
  changes a little of its picture pays for that little. Tetris 2 fps to
  51 (software platform); mini-netscape's hover and mini-office's
  typing about three times faster (draw platform).
- Letters as one shape, a mask a letter, loaded once into the kernel
  (O27-O29): the text of a page went from strokes to copies.
- Messages written in place, `Display.load_sub` (O14, O15), the late
  frame not slept (O18): small code, the gain on every frame.
- The Pi1's caches (O11): the only measure on a board, 5 fps to about
  20.

Kept, but to measure again:
- mini-office's caches (O21, O22's kept group): made when a page was
  7,941 rectangles; since Letters a page is far fewer shapes, and the
  plan asks for each to be measured without.
- The collector's setting (O19): `heap=modest` turns it off in the
  programs that are slowest now (office, page, netscape, doom), its
  cost there not measured.
- The white skipped under a game's background (O20): measured once,
  beside another emulator; it applies to whole frames only, and O30
  sends cameltry's turning maze there anyway.

Doubtful:
- The images outside the heap with the lock released (O7, +423 lines):
  no gain ever shown, and it brought the byte-a-turn memcpy into the
  fills for eight days (Interactions, 6).
- The copied fast paths of the Playground (O13): no ix measure, and
  `Opti.enabled` has no switch outside the tests.

What cancels what (details in "Interactions"): O7 against O2 and O5's
memmove, until O9; the red late frame against O22, until O26;
`heap=modest` against O19; O30's boxes against O20. And two layers do
the same work: the draw platform's still-frame test and Redraw's.

## Summary table

| # | Name | Where (module, commit) | Gain recorded | LOC (git show) | Switch |
|---|---|---|---|---|---|
| O1 | Memdraw fast section (fills, copies, characters) | lib_memdraw/Memdraw `faster`, 7d27fd40 | boot to rc prompt under mini-qemu 323 s to 17.6 s (C: 17.2) | part of stage F's +1,203 | `Memdraw.fast` (ref, edited in source) |
| O2 | No divisions on the Pi1, word memmove | Memimage, Memdraw, libc.c memmove; 62881273 | `ls -l /bin` on the console: 61 s to 28.6 s (17.9 s on a quiet host; C 10 s) | +136 -30 | none (old: comments); `mini-pi -p c\|ocaml` switches the whole pixel library |
| O3 | Memdraw path from 32 bits to the screen's 16 | Memdraw, fd61f0c7 | 2.1 s of a 2.9 s Tetris frame (software platform) | ~31 lines | `Memdraw.fast` |
| O4 | `Memimage.load` one blit a row | Memimage `fast_load`, eedc5644 | load 0.22 s to 0.06 s (with O14); whole 480x480 frame 0.8 s to 0.42 s | Memimage +13 | `Memimage.fast_load` |
| O5 | Kernel fills and polygons: `solid`, `fillclip`, colour read once, pattern computed, `mem_rows`, unrolled narrow fill, Memshape edges kept, memmove 8 words | Memdraw, Memimage, Memshape, runtime.c, libc.c; 8779dd3d | TinyWolfenstein device 51-55 ms to 25, then 15; TinyCameltry device 19 to 12 ms (QEMU) | Memdraw +154 -9, Memshape +65 -21, Memimage +25, runtime.c +37, libc +13 | `fast`, `fast_pattern`, `fast_read`, `fast_rows` (refs) |
| O6 | Cursor: 1-bit image through a 1-bit mask | Memdraw `fast_bits`, a3fa43e0 | 370,000 instructions a move; 22M to 7M instr/s (bare console), 25M to 11M (rio), mini-qemu | +43 | `Memdraw.fast_bits` |
| O7 | Images outside the OCaml heap, copies in C with the lock released | runtime.c imag_*, Memimage, Kdraw, Memlayer; 571a997e | **not shown**: cameltry 22-24 fps (lock held) vs 23-24 (released); two cameltry 26-34 vs 27-42, QEMU 4 cores | +423 -18 | `/dev/swap` write "draw N" (`imag_unlock`, 0 = all locked) |
| O8 | Smoothed letters: byte-a-pixel mask fast path, blends kept | Memdraw `fast_grey`, 06d5e605 | general loop ~1,400 instr/pixel avoided; device k1 78/75 ms vs k8 82/82 ms; blends kept save 22-30 ms a frame | Memdraw +71, draw platform +34 -12 | `fast_grey`; `letters=bits` |
| O9 | `memcpy` is `memmove` (words) | libc.c, b11ab2e9 | netscape hover, device 93-100 ms to 78-84 (QEMU) | +14 -4 (with O24) | none (old: comment) |
| O10 | Fully covered 16-bit pixel: two byte stores, not a blit | Memdraw, 2753afbd | shapes 34-36 to 31 ms; device 53-55; a frame shown 66-72 (was 112 that morning) | +15 -1 | under `fast_grey` |
| O11 | Pi1 caches on (and 800 MHz) | lib_machine/pi1 start.s, machine.c (8779dd3d, run on the board in ec922dd1, 1d9dbcf1); a9396fc9 | **Pi1**: TinyCameltry 22 fps, TinyWolfenstein 19 moving; 5 for both with caches off. 800 MHz: "slightly faster", not measured | ~200 in lib_machine | `Main.caches`, `Main.careful`; config.txt |
| O12 | `Framebuffer.clear` of a grey by `Bytes.fill` | lib_graphics/core/Framebuffer, 9f7cd59a | 1M pixels 0.56 s to under 0.06 s; Tetris frame 1.36 s to 0.86 s (mini-ml, arm64) | ~5 | `Opti.enabled` |
| O13 | Playground's copied fast paths: `Fill.polygons_aa_sparse`, `Blit.draw_fast`, `Color.color_clamp` | lib_graphics/software/Fill, core/Blit, lib_playground/core/Color; 9f7cd59a, 78df4ad3 | `draw_fast`: see O31; the others not measured in ix | (copied) | `Opti.enabled` (Fill, Blit); none (Color) |
| O14 | `Display.load_sub`: one copy, one write a picture | lib_graphics/Display, eedc5644 | with O4: load 0.22 s to 0.06 s (four copies and 16 writes removed) | Display +20 -? | none |
| O15 | `Display` writes messages in its own bytes | lib_graphics/Display `long`, `message`; 8779dd3d | rectangle message 12,000 to ~1,000 instructions; Wolfenstein messages 39 to 19 ms (with O17) | +65 -24 | none (old: comment) |
| O16 | `Redraw`: only what changed between two frames | lib_playground/platforms/Redraw, fd61f0c7 | Tetris 51-52 fps vs 2 drawn whole (QEMU, software platform); 353,371 vs 143.9M instructions a frame | Redraw.ml +85 | `redraw=all` (`Redraw.enabled`); ix's own `redraw=each` for tests |
| O17 | Draw platform's short paths | draw/Playground_platform `fast`, 8779dd3d | Wolfenstein 82 to 65 ms a frame (with O15), Cameltry to 57 | +97 -14 | `fast` (ref, source) |
| O18 | Plan9_loop: no sleep when the frame is late | Plan9_loop, 8779dd3d | 5 ms a frame (plan) / 10 ms (bugs/ix.md row 133); with words kept: 65 to 55 ms | (part of +89 -24) | none |
| O19 | Collector for games: `space_overhead = 700` | Plan9_loop, lib_core/Gc, 8779dd3d | `ML_HEAP=4194304` alone: messages 14 to 7 ms; collector 18% to 10% of the program's instructions | Gc +15, Plan9_loop | `heap=modest` (0aca4a6e) turns it off: office, page, netscape (2fe7e116), mini-doom |
| O20 | The white not made under leading opaque rectangles | draw platform `show`, 3869d50c | Wolfenstein showing ~30 to 26-27 ms (QEMU, "measured once") | +68 -30 | `fast` |
| O21 | Office: layout and page letters kept; `Redraw.middle` | apps/office Office_page, Office_view; Redraw; 4b81bbed | Linux still page 25 ms to 1.5 (OCaml); update+view 5.4 to 1.0; mini-ml 17 to 1.4 | +91 -8 | `Opti.enabled` |
| O22 | `x == y` before `x = y` (still frame); page letters one kept group | draw platform show, Redraw, Office_view; 1c4d2bc6 | office on QEMU, still page: 43 ms to 10 a frame (view 11-13 to 1-3, showing 30 to 7) | +55 -6 | none for `==` (it costs nothing); glyphs group by `Opti.enabled` |
| O23 | Thin rectangle drawn as a line | draw platform, 0f8a2e3b | office sheet drag, showing 556 to 415 ms (messages 307 to 255, device 235 to 144); also renders better | +26 | none (old: kept) |
| O24 | Plan 9's bitmap font for a `Words` of 11-16 px | draw platform `bitmap`, 4f535b3a | TinyDrScheme changing frame 125 to 72 ms (QEMU) | +34 | `font=hershey` |
| O25 | A late game runs at most 8 ticks before a frame (was 30) | Plan9_loop `most`, 342743bf | cameltry under mini-qemu (-ips 12): 40 frames in 37.1 s to 26.6 s | +12 -2 | `late=N` (`late=30` = before) |
| O26 | Red late frame only on a changed picture (fixes a regression from 0386e770) | Plan9_loop, 068f2500 | mini-netscape at rest, about:home: 4 fps (show 250 ms every frame) to 45 fps, one frame drawn a second | +12 -1 | none |
| O27 | Text as a shape (`Letters`), a cached mask per letter on Linux | Shape_render_software, Letter_strokes, Playground; 29ef2439, 021f53db | Hacker News, a frame scrolled: OCaml 12 to 1.7 ms (100%), 29 to 4.3 (250%); mini-ml 107 to 9; with quarter-pixel masks 2.1 and 13 | +473 -5, then +22 -9 | none in ix for the Linux masks (old: comment) |
| O28 | A letter loaded once into a kernel image, then one draw message | draw platform, 2cb918e6 | about:home hover, QEMU: messages 220 to 20 ms, device 113 to 90 | +79 -2 | `letters=strokes` |
| O29 | Mask cut to the pixels the letter covers | Shape_render_software `mask_of`, b11ab2e9 | with O9: device 78-84 to 62-66 ms; shapes 51-58 to 31-35; frame shown 112 to 78 ms | ~24 | none (old: kept) |
| O30 | Stage B: the draw platform redraws `Redraw`'s boxes only; `Redraw` compares inside groups | Redraw, draw platform, Display `clip` (this note's commit) | mini-netscape hover 66 to 20-24 ms; mini-office typing 87 to 35-39; DrScheme 80 to 25-29; Tetris 39 to 17-20; cameltry 28 to 29-31 (QEMU) | +248 -49 | `redraw=all`, `redraw=top` |
| O31 | `Blit.draw_copy` (unscaled, whole-pixel blit) | lib_graphics/core/Blit (not committed on 2026-10-22) | mini-doom's 640x400 picture 21 ms by `draw_fast` to 1.7 (the Playground's notes_opti_ocaml.md) | +43 | `Opti.enabled` |

Correctness fix in the same area, no speed number: 29caa303 (Redraw's boxes
render the same pixels as the whole frame; `Framebuffer.part`;
`render_region` removed; "Not timed"; +77 -53).

## Details

### Kernel (mini-9pi's OCaml pixels)

**O1. Memdraw's fast section.** 7d27fd40 (2026-09-26, stage F, the pixels
in OCaml). One general loop with memdraw's arithmetic, and a separate
switchable `Memdraw.fast` for fills, copies and characters. The commit
message says: "the boot 323 s to rc's prompt under mini-qemu without it,
17.6 with, the C 17.2". Evidence: kernels/9pi/lib_graphics/lib_memdraw/Memdraw.ml:70-76
(comment: "19 times slower than 9pi's C to boot"), `faster` at :104. The
stage is 923 lines of OCaml for about 8,000 of C; the fast section's own
size is not given separately.

**O2. No divisions on the Pi1.** 62881273 (2026-09-27), and
docs/notes_performance.md section 1. A profile had `__aeabi_idivmod` at 38%
(ARMv6 has no divide instruction). The fixes:
- divisions by 8 and 32 made shifts (`Memimage.bytex`, `fshr`, `cshr`,
  `units`; Memimage.ml:32), 61 s to 45 s;
- the character path's addresses computed once a row (`Memdraw.faster`,
  Memdraw.ml:126), 45 s to 32 s;
- `repeat`: a pattern built by doubling blits (Memimage.ml:224, 244);
- the flush without `String.sub` (`Machine.Phys.write_sub`, Memimage.ml:118);
- int `max` and `min` (Memimage.ml:17);
- `memmove` copies words whenever both ends share an alignment (libc.c).

The last four together brought it to 28.6 s. On a quieter host it was
17.9 s; the C pixels took 14 s under the profiler and 10 s without. rio
became "slow, but usable". The old code is kept in comments. Switch:
`mini-pi -p c|ocaml` (the whole pixel library); no flag for each change.

**O3. 32 to 16 bits.** fd61f0c7 (2026-10-07). A Memdraw path from a
program's 32-bit pixels to the 16-bit screen took "2.1 s of a frame's 2.9"
(the software platform, Tetris). The plan's survey gives it as 0.02 s after
the path, against 2.1 s before.

**O4. `fast_load`.** eedc5644 (2026-10-07). `Memimage.load` copies a row of
whole bytes with one blit, where it went a byte at a time through two
index-checking functions (Memimage.ml:257, 273). Together with O14, under
QEMU: the load 0.22 s to 0.06 s, a whole 480x480 frame 0.8 s to 0.42 s.
K2 (`Devdraw`'s `String.sub`, 0.013 s) and K3 were not done.

**O5. The kernel's part of "three times faster".** 8779dd3d (2026-10-08).
The changes:
- `Memdraw.solid` (Memdraw.ml:367): a polygon's and a line's runs written
  directly;
- a fill's rows by adding;
- the screen's pattern computed (`fast_pattern`, Memimage.ml:202);
- the colour read once and by its bytes (`fast_read`, Memimage.ml:138);
- `fillclip`;
- a narrow fill unrolled, and its rows by C (`mem_rows`, runtime.c:798,
  `fast_rows`);
- `Memshape.fillpoly`: the edges kept from row to row and sorted by
  integers (Memshape.ml:43);
- memmove forward, eight words a turn.

Numbers from the plan_playground_speed.md table (QEMU, 480x480, the right
arrow held):
- TinyWolfenstein: device 51-55 ms to 25 (first row), then 15 after fillclip.
- TinyCameltry: device 19 to 12 ms after the edges kept.
- The commit as a whole (with O15-O19 and mini-ml's work): Wolfenstein 100
  to 30 ms a frame (33 fps), Cameltry 100 to 26 (38 fps).
- In instructions: 9.9 million a Wolfenstein frame, the device's part 5.9M
  to 4.8M.
- Principia's C 9pi with the same programs: 10 fps (device 44-71 ms).

**O6. Cursor fast path.** a3fa43e0 (2026-10-11), bugs/ix.md row 170.
Swcursor's `img1` through `mask1` went through the general loop: 370,000
instructions a move. With `fast_bits` (Memdraw.ml:95, 332), mini-qemu's
board spends 7M instructions a second where it spent 22M (bare console),
and 11M where it spent 25M (rio). The same commit made a change in the
emulator (raspberry/Sdl_display: only the changed rows given to the
texture). For that one it says "no gain seen by the measure".

**O7. imagmem.** 571a997e (2026-10-13).
- An arena outside OCaml's heap (`imag_alloc`), and `imag_copy`, `imag_rows`
  and `imag_flush` done in C with the kernel's lock released for 16 KB or
  more (runtime.c:700-790).
- Correctness costs: `imag_covers`, `Kdraw.busy` (the cursor's clock waits
  for the copy) and `imag_quiet`.
- The gain is explicitly "not shown": under QEMU, one run each, cameltry
  beside two others 22-24 fps with the lock held and 23-24 without; two
  cameltry 26-34 and 27-42. It was not run on a board.
- Switch: write "draw N" to /dev/swap (Devcons.ml:262).

**O8. `fast_grey`.** 06d5e605 (2026-10-21), notes_font.md section 5.
- An opaque colour through a k8 mask, with the general loop's arithmetic
  and its terms known. The blend of a coverage is kept for the next letter
  of the same colour (Memdraw.ml:258, 276).
- Device time for a frame (QEMU, the mouse on and off a link of about:home,
  40 frames, two runs): k1 78 and 75 ms, k8 82 and 82. "Without the blends
  kept, 22 to 30 ms more a frame."
- So smoothing costs a few ms over k1. The fast path is what keeps that
  cost small, against a general loop of ~1,400 instructions a pixel.
- Verified by tests/memdraw/run.sh (the same bytes as the general loop).

**O9. memcpy as memmove.** b11ab2e9 (2026-10-21), libc.c:95-109.
mini-qemu's samples put 27% of a hover frame in a byte-at-a-time `memcpy`
called by `imag_rows` (the frame's white, 1.2 MB). Device time went from
93-100 ms to 78-84 ms (QEMU, tests/perf/hover.sh).

**O10. Two bytes stored.** 2753afbd (2026-10-21), Memdraw.ml:292. A fully
covered 16-bit pixel is two byte stores, not a call of C
(`Bytes.blit_string`), which had been a third of a letter's pixels. Shapes
34-36 ms to 31; device 53-55 (white 9, copy 15); a frame shown 66-72 ms.
After this change the samples are flat: memmove 11%, Memdraw's loop 7%,
message handling about 10% spread over a dozen functions.

**O11. Caches on the Pi1.** Written in 8779dd3d from the manual. On the
board, 1d9dbcf1 fixed instruction-cache maintenance and ec922dd1 recorded:
"TinyCameltry 22 frames a second, TinyWolfenstein 19 when moving; with the
caches off both are at 5". a9396fc9 set 800 MHz in config.txt: "looks good,
slightly faster indeed", no number. This is the largest recorded real-board
gain. It is not drawing code, but every frame number on the Pi1 depends on
it.

### lib_graphics

**O12. Grey clear.** 9f7cd59a (2026-10-07, ix's own, labelled "ix:
optimization"). Framebuffer.ml:68-77: a million pixels by mini-ml on arm64
took 0.56 s set one by one and under 0.06 s filled. Tetris's frame went from
1.36 s to 0.86 s.

**O13. Copied from the playground.**
- `Fill.polygons_aa_sparse` (Fill.ml:184, 274) and `Color.color_clamp`
  (Color.ml:6) came in 9f7cd59a.
- `Blit.draw_fast` (Blit.ml:90) came in 78df4ad3.
- Opti.mli says their numbers are in the Playground's
  notes_opti_ocaml.md, which has `Color.color_clamp` (a polymorphic
  compare called per pixel) and `draw_fast`'s cost at 1:1 (O31); no
  number for `polygons_aa_sparse`. No ix measurement was found.
- Opti.mli's mention of an "o" key that switches them at run time is the
  playground's. In ix, `Opti.enabled` is set only by unit tests
  (lib_graphics/images/tests/Unit_blit.ml:88). No command-line flag was
  found.

**O14. `Display.load_sub`.** eedc5644, Display.ml:199. The pixels are copied
once into one message and written in one write: 921 KB, which the kernel
takes. Before, it was four copies and sixteen writes of 60 KB. The gain is
the shared one given under O4.

**O15. Messages in place.** 8779dd3d, Display.ml:9-12 (old: comment), 39,
75. A number used to be four `Buffer.add_char` calls, and each message had
a Buffer of its own: 12,000 instructions for a rectangle's 45 bytes. Now
"about 1,000". Together with O17, Wolfenstein's messages went from 39 ms to
19 ms (the frame 82 to 65 ms). `Display.long` is still 10% of a frame (160
instructions a number).

### lib_playground

**O16. Redraw.** fd61f0c7 (2026-10-07).
- Only the shapes that differ are rendered, in the boxes that changed, with
  the same pixels. It is used by the SDL, ppm and software platforms, not by
  the draw platform (until O30).
- Gain: Tetris 51-52 fps under QEMU against 2 fps drawn whole. A frame's
  change is 353,371 instructions against 143.9M for the whole frame.
- After M1 (eedc5644), the change frame rose to 487,427 instructions, "not
  explained".
- Switch: `redraw=all` (Redraw.ml `choose`; `Redraw.enabled`).

**O17. The draw platform's `fast`.** 8779dd3d,
draw/Playground_platform.ml:138:
- an ink cache of 256 slots (:162-185);
- a shape that is not turned placed by 8 products (:232, :351);
- a colour's name not parsed through a string (:153);
- a word's strokes kept (`written`, :331, emptied past 64);
- whole numbers compared where `Float.min` was called (350 instructions).

Combined with O15: 82 ms to 65 ms (Wolfenstein), 57 ms (Cameltry). With
O18: 55 and 50 ms.

**O18. No sleep when late.** 8779dd3d, Plan9_loop.ml:315-319, and bugs/ix.md
row 133. When the next tick was already due, the shortest sleep waited for
the kernel's next tick. The cost is given as "5 ms of each frame for
nothing" (plan) and as "10 ms a frame" (bugs row). A sleep of 0 (a yield)
replaced it. 1d9dbcf1 also keeps `/dev/bintime` open for
`Unix.gettimeofday`, where each call was an open, a read and a close,
several a frame. Not measured.

**O19. Collector setting.** 8779dd3d, Plan9_loop.ml:151-152. Before the
mini-ml float work, `ML_HEAP=4194304` alone took the messages from 14 ms to
7 ms. With the floats in place the collector was still 18% of the program's
instructions; with `space_overhead = 700` it is 10%. 0aca4a6e turned it off
by `heap=modest` for page and office ("NOT MEASURED: its effect on
mini-9pi"). Netscape (2fe7e116) and mini-doom also pass `heap=modest`.

**O20. White skipped under the background.** 3869d50c (2026-10-08),
draw platform :618. This is the first of a frame's four copies. Under QEMU
a Wolfenstein frame's showing is "26 to 27 ms where it was about 30,
measured once and beside another emulator".

**O21. Office caches and `Redraw.middle`.** 4b81bbed (2026-10-09).
- `Office_page.kept` (Office_page.ml:96, 111) keeps the layout while the
  document is the same value.
- `Office_view.glyphs_at` (Office_view.ml:51-72) keeps a page's letters as
  shapes.
- `Redraw.middle` (Redraw.ml:42) skips the shapes two frames share at both
  ends.
- Linux, a still page: 25 ms to 1.5 by OCaml's code; update and view 5.4 to
  1.0 ms; by mini-ml 17 to 1.4.
- "Not gained: a sheet dragged."

**O22. `x == y` first.** 1c4d2bc6 (2026-10-09), draw platform :575 and :603,
Redraw.ml:52. The draw platform's still-frame test was a structural `=` over
8,000 shapes. Now the letters are one kept group and physical equality is
tested first. QEMU, the mouse over a still page: view 11-13 ms to 1-3,
showing 30 to 7, the frame 43 ms to 10. "What the 7 are was not looked at."

**O23. Thin rectangle as a line.** 0f8a2e3b (2026-10-09), draw platform
:243-264. A rotated rectangle thinner than 1.5 px becomes the device's line.
The office sheet drag's showing went from 556 ms to 415 ms. The letters were
also drawn whole for the first time. As a result, recorded screens of
drscheme (138 pixels) and wolf (291 pixels) changed.

**O24. Plan 9 bitmap font for words.** 4f535b3a (2026-10-09), draw platform
:288-313. An upright `Words` of 11 to 16 px is drawn as one message a letter
with the default font. TinyDrScheme's changing frame went from 125 ms to
72 ms under QEMU. Switch: `font=hershey`.

**O25. Late ticks capped at 8.** 342743bf (2026-10-11), Plan9_loop.ml:62-63,
370. Under mini-qemu (-ips 12, the bare screen), cameltry's 40 frames took
26.6 s where they took 37.1 s; the game then runs slower than the clock. It
has "no effect where a frame takes under 133 ms". Switch: `late=N`.

**O26. Red frame regression fixed.** 0386e770 (2026-10-11) added a red frame
around a late game's picture. Because the frame was another picture, it
defeated the still-frame test. 068f2500 (2026-10-20): mini-netscape at rest
showed every frame (250 ms, 4 fps); now it runs at 45 fps with one frame
drawn a second (Plan9_loop.ml:447-450). bugs/ix.md row 219.

**O27. Letters and masks on Linux.** 29ef2439 and 021f53db (2026-10-20),
Shape_render_software.ml:284-360, notes_font.md section 5.
- A `Letters` shape for a run of text. On Linux it is drawn through a mask
  kept for each letter, size, look and scale (the table is emptied past
  4,096).
- Hacker News, a frame scrolled:

  | | strokes | masks, whole pixels | masks, quarter pixels |
  |---|---|---|---|
  | OCaml's code, 100% | 12 ms | 1.7 ms | 2.1 ms |
  | OCaml's code, 250% | 29 ms | 4.3 ms | |
  | mini-ml's code | 107 ms | 9 ms | 13 ms |

- Quarter-pixel positioning (16 masks a letter) was chosen over whole
  pixels for fidelity, at that cost.

**O28. A letter loaded once into the kernel.** 2cb918e6 (2026-10-20).
`mask_of`'s mask goes into a k1 image the first time a letter is used;
after that a letter is one draw message (the table is emptied past 2,048).
QEMU, about:home hover: messages 220 ms to 20, device 113 ms to 90. Switch:
`letters=strokes`.

**O29. Mask cut to the letter.** b11ab2e9, Shape_render_software.ml:320-327.
The mask's box had room for any letter: about 800 pixels a letter, where a
letter covers about 100. Together with O9, under QEMU:

| | before | memcpy | + masks cut |
|---|---|---|---|
| device | 93-100 | 78-84 | 62-66 |
| white | 24-25 | 11-13 | 12-13 |
| shapes (450 letters) | 51-58 | 47-56 | 31-35 |
| copy to the window | 17-18 | 16-18 | 18-19 |
| a frame shown | 112-113 | 97-98 | 78-79 |

On Linux the letters cover fewer pixels too; that was not measured.

**O30. Stage B: Redraw on the draw platform, inside groups.** 2026-10-22.
- The draw platform asks `Redraw.changed` for the boxes that changed
  (Redraw.ml `changed`); each box is made white, the device's clip set
  on it (`Display.clip`, Plan 9's `c` message), every shape asked again
  but those outside the box not sent (`shown`, eight places), then only
  the boxes copied to the window (draw platform `show_boxes`). A word's
  box is its strokes' and its Plan 9 font's (`font_boxes`).
- First version, top-level shapes compared only, as Redraw had always
  done: no gain. mini-netscape draws its page as one group, so a lit
  link changed that group, the 452 letters sent again and the diff paid
  besides: 79-88 ms against 66 whole. mini-office: 143-146 against 87.
- `Redraw.differ`: two groups at the same place compared by their
  members, as the lists at the top are; a changed member put back in
  its groups (`inside`) to ask its box.
- Then two traps, found by printing each frame's changes:
  - mini-office's page gains a member when a word is typed: groups of
    different sizes are compared by their members too.
  - A word typed that reflows a paragraph moves 1,500 words: their
    comparing took 3.6 s on mini-9pi, their bounds a second more, where
    a whole frame is 90 ms. Past 64 shapes left to compare, the whole
    picture (`many`).
- QEMU, ms a frame shown (tests/perf/redraw.sh; frames.sh for the
  games):

  | program, action | whole (`redraw=all`) | top only (`redraw=top`) | inside groups |
  |---|---|---|---|
  | mini-netscape, a link hovered | 66 | 79-88 | 20-24 |
  | mini-office, a line typed | 86-88 | 143-146 | 35-39 |
  | DrScheme, a line typed | 78-82 | 27-28 | 25-29 |
  | Tetris, a piece falling | 39 | 20 | 17-20 |
  | cameltry, the maze turning | 27-28 | 31-32 | 29-31 |

- Not helped: a game whose picture all moves (cameltry, Wolfenstein):
  the diff is paid, then the whole frame drawn, 2 ms more. mini-emacs
  does not go through the playground (lib_terminal's screen).
- Not measured: SDL on Linux, which takes the same `Redraw.differ`.
- The draw platform alone grew by 140 lines, a check in each primitive;
  a dangling `else` in one of them left cameltry's turned walls
  undrawn for a build (bugs/ix.md).

**O31. `Blit.draw_copy`.** Not committed on 2026-10-22,
Blit.ml:147-186. Used when a picture is drawn unscaled at whole pixels. The
Playground's notes_opti_ocaml.md: mini-doom's 640x400 picture 21 ms by
`draw_fast` (80 ns a pixel, each mapped back in floats), 1.7 ms by
`draw_copy`, the same pixels.

### Tried, reverted, or found worse

- **Two caches for mini-office's caret** (a text's layout kept whatever the
  caret; a kept group drawn once into an image of the draw platform's) were
  "taken out, not committed, not measured" (e7d1e470). The author said:
  "let's not add hacks around to optimize things".
- **0386e770's red frame** made a program at rest redraw every frame
  (4 fps); fixed in O26.
- **PIXEL=c** (principia's C memdraw) brought no gain for the games:
  Tetris 42-43 fps with Redraw, 2 whole (plan, "The rest"); b180cd1d says
  "principia's C pixels no faster". Principia's own C kernel ran the same
  games at 10 fps where mini-9pi reached 30-33.
- **The software platform** on mini-9pi for a game that redraws everything:
  Wolfenstein under 1 fps, Cameltry 2-3 (2026-10-07). mini-doom: under 1 fps
  (plan_playground_framebuffer.md).
- **Smoothed letters (k8)** are a little slower than k1 (82 against 75-78
  ms); this was accepted for readability. **Quarter-pixel masks** are
  slower than whole-pixel ones (1.7 to 2.1 ms, 9 to 13 ms); accepted for
  fidelity.
- **raspberry/Sdl_display**, the changed rows only: "no gain seen"
  (a3fa43e0). mini-qemu's `-hosted` was "begun and taken out".
- **The imagmem lock release** (O7): a gain was never shown.
- **A program's hint `changes=all`** (2026-10-22, not committed): a
  picture that moves whole each frame drawn whole, Redraw's comparing
  skipped. Cameltry 27 ms a frame with it, 29-31 without. mini-doom's
  27 either way is void: it showed its first two frames again and again
  then (fbfc0317), nothing new to send. The author: "does not seem
  worth it".
- **Postponed or not tried**: K5 (a 32-bit screen; accepted, not done), K8
  and F1 (a framebuffer in the program's memory, or /dev/framebuffer;
  proposed 2026-10-22, nothing begun), K2, K3, K6, K9, K10, M2, M3, M6.

## Interactions

1. **Two dirty-rectangle layers, and two still-frame tests.**
   - Redraw (user side) keeps `t.last` and returns no boxes when
     `old == shapes`. The draw platform has its own `win.last` with
     `x == y` before `x = y` (O22).
   - With O30 the draw platform calls `Redraw.changed`, so a frame is
     compared twice: by the platform's `win.last` (all of it, a still
     frame then not drawn) and by Redraw's `last` (only `==`, then the
     diff). The first could go, Redraw's `Some []` saying the same.
   - Below them the kernel's Memlayer also repaints only changes to the
     screen ("changes repainted", 7d27fd40).
   - The software platform on Plan 9 has had Redraw since fd61f0c7. The
     draw platform did not until O30. That is why Tetris (software, 51
     fps) and the draw-platform games (whole frames) had such different
     numbers.
2. **O20 against O30.** The white skipped under leading opaque rectangles
   applies only on the whole-frame path. `show_boxes` whitens each box
   unconditionally. So for a game where Redraw finds most of the picture
   changed (the "most" rule: over half the area means all of it), O20
   still matters; for partial frames it is bypassed. Cameltry's 2 ms
   lost with O30 are the diff, paid before that rule.
3. **O21 and O22 against O27 and O28.**
   - `Office_page.kept` and `Office_view.glyphs_at` were built when a page
     was 7,941 rectangle shapes.
   - After `Letters` (021f53db), a page is about one shape a letter (plan:
     "about 1,300 a page"). The plan says they are "taken out after, each
     measured without" if a frame is cheap without them.
   - Both are still in the code. Whether they are now redundant was not
     measured.
   - The `x == y` test is to stay, per the plan.
4. **O23 against O27 and O28.** "Thin rectangle as a line" was motivated by
   letter strokes. Since the letters became masks, it serves only
   `letters=strokes` and other thin rectangles (rules, map rays). It stays,
   because it is also what renders correctly.
5. **Two letter paths on mini-9pi.** `Words` use Plan 9's bitmap font (O24).
   `Letters` use the k8 mask images (O28 and O8). O30 needs `font_boxes`
   because a bitmap word's pixels are not its strokes' bounds. On Linux,
   `Words` are still Hershey strokes.
6. **memmove and memcpy, done three times.**
   - 62881273 (words when the alignment is shared), then 8779dd3d (forward,
     8 words a turn), then b11ab2e9 (memcpy is memmove).
   - Separately, mini-ml's runtime got word-at-a-time `blit_string` and
     `fill_string` in 8779dd3d, which libc's memmove "is a byte a turn"
     there.
   - 571a997e (O7) moved the fill's row repetition to C's `imag_rows`,
     which called the byte-at-a-time `memcpy`. Until b11ab2e9 (eight days
     later) that path was slower than memmove's words; it was 27% of a
     hover frame when found. Inference: O7 likely made fills slower in
     between. No measurement brackets it (see Open questions).
7. **O19 is cancelled for the programs that most need speed now.**
   mini-office, mini-page, mini-netscape and mini-doom all pass
   `heap=modest`. For them the collector's 18% to 10% gain does not apply.
   The effect of `heap=modest` on mini-9pi was "NOT MEASURED".
8. **The kernel's fast paths are only in the OCaml memdraw.**
   - `PIXEL=c` (kernels/9pi/lib_graphics/c/draw9.c, principia's C) has none
     of O1-O10. `Kdraw.busy` is false there. 571a997e: "PIXEL=c ... built?
     no".
   - The web build has a third route: `Memdraw.hosted` (Memdraw.ml:449-470)
     runs `Memgeneral` on the emulator's host (c05029d9). It is a "kernel
     built for its host" style path, which the author's rules make a last
     resort; it is limited to WEB=1.
9. **O25 and O26 interplay.** The 8-tick cap (O25) triggers the red frame
   (0386e770); the red frame broke the still-frame test (O26). So O25 and
   0386e770 together cancelled O22 for programs that are late at least
   once, until 068f2500.
10. **O14 and O4 against M6 and F1.** The load path was optimized for a
    whole frame given as pixels. mini-doom now goes through it at 7-10 ms
    unscaled but "ruinous" when scaled (draw platform). F1 (proposed) would
    bypass the draw device and make O4 and O14 irrelevant for such games.
11. **Redraw's cost grew after M1** (353,371 to 487,427 instructions,
    unexplained, suspected collector copies). This is an unexplained
    regression of O16 caused by another optimization.

## Adjacent (outside the scope, but in the same frame numbers)

- **mini-ml code generation** (8779dd3d; switch `mini-ml -calls`):
  - `Gen.alloc_in_place`, `Lower.floats_in_place`, `Lower.calls_whole`.
  - Per-operation costs: a float product 63 to 20 instructions; a tuple 45
    to 17; another unit's 2-argument call 137 to 56.
  - Table rows: Wolfenstein 55 to 47 to 32 ms, Cameltry 50 to 35 to 22-26.
  - `Bytes.unsafe_get/set` as primitives (eedc5644): shapes 0.57 s to 0.36;
    a frame's shapes 144M to 115M instructions; Linux, five whole frames
    1.82 s to 1.28.
  - Runtime blit and fill a word at a time: a Tetris frame by the software
    platform, 103.7M to 80.2M instructions.
- **Audio's share of a frame**:
  - 543bf082: Tetris 3-5 fps until the tune had gone round, then 58, at
    mini-qemu -ips 200; 6.37 to 3.98 thousand million instructions for 840
    frames.
  - d47f0829: a game's frame without its drawing 6.2M to 1.9M instructions.
- **Text editors' screens** (lib_terminal's draw host, not lib_playground):
  - eb5378a5 (mini-turbopascal): 200 keys 1.37 s to 0.06 s; a key on
    mini-9pi 50-60 ms to 0-10 ms; switch `-nocache`.
  - 716bf6c0 (mini-emacs `Frame.cache`): a line down 2.0 to 0.2 ms (OCaml),
    7.0 to 0.5 ms (mini-ml); switch `-nocache`.
- **mini-qemu's pace** (a3fa43e0): the board caught up from 0.5 to 0.9-1.0
  of the host's clock at 30 moves a second.

## Open questions (claims not verified)

1. Whether O7 (imag_rows calling the byte-at-a-time memcpy) made fills
   slower between 571a997e and b11ab2e9. No measurement brackets it; this
   is an inference from the code and b11ab2e9's profile.
2. Whether `Office_page.kept` and `Office_view.glyphs_at` (O21, O22) still
   gain anything since `Letters` (O27, O28). The plan asks for this measure;
   none found.
3. O31 was not committed on 2026-10-22: its number is the
   Playground's notes', not measured in ix.
4. The 5 ms (plan) against 10 ms (bugs/ix.md) for O18's sleep: the sources
   disagree.
5. O13's `polygons_aa_sparse`: no number in the Playground's notes nor
   in ix. In ix, `Opti.enabled` has no run-time switch outside tests,
   despite Opti.mli's "o" key text.
6. The kernel's `fast*` refs (`Memdraw.fast`, `fast_rows`, `fast_bits`,
   `fast_grey`, Memimage's `fast_read`, `fast_pattern`, `fast_load`) have
   no flag found that sets them at run time. Only `imag_unlock` does
   (/dev/swap). The draw platform's `fast` likewise. "Switchable" means by
   editing the source.
7. The O11 and Pi1 numbers are the only board measures. No candidate
   O12-O29 was measured on a board. All the later mini-netscape and office
   numbers are QEMU's.
8. The effect of `heap=modest` (cancelling O19) on mini-9pi frame times is
   recorded as not measured.
9. The Redraw instruction count rising after M1 (O16, Interaction 11) is
   unexplained in the source.
10. The LOC for O14 is mixed into eedc5644's Display.ml +20 lines; the
    other per-item LOC values are per commit and per file, not per
    optimization, where commits bundle several.
