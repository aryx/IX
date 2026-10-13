# Plan: mini-qemu fast enough natively: the mouse, rio and a game in its window as they are under QEMU (`raspberry/`, `machine/`, `kernels/9pi/`, `windows/`)

The author (2026-10-11), of `./mini-pi -g mini-9pi`: "we recently
optimize mini-pi for the web, including special code for the mouse
that was taking lots of time when processed by the usb stack. Could we
do the same for mini-qemu in native? Moving the cursor right now feels
sluggish and the cursor lags behind. Is there a way to optimize this
while not denaturating the code"; "note that qemu itself is fast and is
great at running mini-9pi kernel, as is"; "maybe, like we did for the
web, we could also have a special kernel build for mini-qemu, that
might help a bit, without cheating too much"; "same for the graphics,
which are currently very slow under mini-qemu but reasonably fast under
qemu (cameltry is pretty good under qemu, and on the real pi1)"; "maybe
this could be the start of a plan document to optimize the speed of
mini-qemu (native), which can relate to plan_web.md"; "maybe improving
mini-qemu in native can also help it when run on the web"; "ideally we
would not need those "cheats" but instead optimize globally things so
we don't need them"; "I'm mentioning the Cursor being an issue under
mini-qemu, but really the speed of many things is an issue (rio, games,
etc.)"; "ideally we do optimizations that benefit across all targets".

So, in this order of preference:

1. **What is slow for every machine** (the kernel's and the programs'
   own instructions): fixed there, it is faster on the Pi, under QEMU,
   under mini-qemu and in the page.
2. **What is slow in mini-qemu** (its interpreter, its loop, its
   window): fixed there, for every kernel it runs; what is the board's
   or the processor's helps the page too ([`plan_web.md`](plan_web.md)).
3. **What a kernel built for its host skips** (the page's kernel:
   `make ix-web`, `Kweb`, `Hostdraw`): the "cheats". Not taken here;
   what they would buy is measured below, to know what 1 and 2 are
   worth against them.

Its numbers: `raspberry/tests/Boot_bench` (the board alone: a guest's
instructions, which no host changes, and its profile by
`guest_profile.py`) and `raspberry/tests/window_lag.py` (new:
mini-qemu's own loop with its window, SDL's dummy driver, the mouse
over QMP: the board's time against ours). Seconds are this machine's
(64 cores, others busy on it), the emulator built by
`dune build --profile release`. **No number here is QEMU's or a real
board's: those are still to take.**

## What was measured (2026-10-11)

### The emulator's own speed

| what runs | million instructions a second of the host's |
|---|---|
| mini-9pi's boot to rc's prompt (389 million), release | 20.6 |
| the same, dune's default profile (bounds checked) | 13.0 |
| rio and a mouse that moves, release | 12 to 15 |
| under node, the interpreter (plan_web.md) | 7 |
| under node, the blocks translated to JavaScript | 28 |

The board says a microsecond is 30 instructions (`-ips 30`): **a
kernel that is busy asks 30 million a second of an interpreter that
gives 12 to 20.** Whatever is busy more than half of the time is late.
node with its translator runs the board's blocks faster than the
native interpreter does.

### The mouse (`Boot_bench kernel-pi1-ixu.img card.img -usb -idle 20 -move`)

Instructions for a second of the board's, the USB mouse moved 60 times
in it:

| | bare console | under rio |
|---|---|---|
| nothing moving | 1.9 | 2.0 |
| the mouse moving, before | 22.1 | 25.1 |
| the mouse moving, the cursor by its own loop (below) | 6.7 to 7.1 | 11.1 |
| the page's kernel (`kernel-pi1-web.img`: no USB, no cursor drawn) | | 5.2 to 5.7 |

Before, by `guest_profile.py`: Memimage 47%, Memgeneral 17%, Memchan
11%, the programs 5%: **three quarters were the cursor, drawn through
memdraw's general loop, 370,000 instructions a move** (256 pixels, each
read from three images, composed and written through tuples and
lists). The USB (the controller's registers, usbd's processes) was a
twentieth, not the cost plan_web.md's entry of the night gave it: the
page's kernel is fast for the cursor it does not draw.

The measure itself was wrong before today: `-move` sent the mouse one
way only, the cursor was at the screen's corner after six seconds and
no longer drawn, and the seconds after the tenth said 8.7 million
(docs/plans/bugs/ix.md). It goes there and back now.

### The window's loop (`window_lag.py`, rio, 30 moves a second: what the window gives, a sync a frame)

| | the board's time for a second of ours | idle |
|---|---|---|
| before | 0.5 s | 13% |
| the cursor's loop | 0.7 s | 70% |
| and SDL given the rows that changed | 0.7 s | 70% |
| and 30 ms of lateness caught up | 0.9 to 1.0 s | 75% |
| 60 moves a second (more than the window gives) | 0.6 s | 40% |

A board idle 70% of its time and still late: its bursts ran at the
host's speed, under the board's, and `Main.loop` gave up each
millisecond lost at once.

## Done (2026-10-11)

1. **For every machine: the cursor's draw**
   (`kernels/9pi/lib_graphics/lib_memdraw/Memdraw.ml`, `faster`): an
   image of one bit a pixel through a mask of one (Swcursor's `img1`
   and `mask1`) has a loop of its own, beside the character's: where
   the mask's bit is set, white or black by the source's. Its switch:
   `Memdraw.fast_bits`. The settled screen after 300 moves under rio is
   the same bytes with the kernel of before and this one.
2. **mini-qemu's window** (`raspberry/video/Sdl_display.ml`): the frame's
   first to last changed rows copied and given to the texture, where
   the whole frame was, a byte at a time through a closure. No change
   by `window_lag.py`, whose SDL draws nowhere; not measured on a
   screen.
3. **mini-qemu's pace** (`raspberry/Main.ml`, `late`): behind by under
   30 ms, the board catches up while its kernel waits; beyond, the
   time is lost as before. (Under a key's repeat, 160 ms: a key held
   100 ms of ours is at most 130 of the board's.)

Not rebuilt: the other images of mini-9pi (`kernel-pi1-web.img`, the
Pi 4's); the page's kernel draws no cursor and gains nothing from 1
unless `?input=usb`.

## To do, by what was measured

Global first; each to be measured before it is begun.

1. **A move's 110,000 instructions without rio, 180,000 with it**
   (what is left of 6.7 and 11.1 million). Bare: the programs (usbd)
   21%, `Memdraw.faster` 21% (the cursor's three draws: its place saved
   as 32 by 32 where it is 16 by 16, each draw's clip and its tests of
   what kind it is), memmove 8% (the rows to the framebuffer),
   `Array.iter` 5%, divisions 5%, `List.find`. Under rio a third is
   rio's own (plan_web.md: 60,000 a move, "not looked at"): what rio
   does at each move with no button down.
2. **An idle rio is 2 million instructions a second**, a quarter the
   programs', `Array.iter` 13%, divisions 10%: usbd asking the
   keyboard and the mouse. The page's kernel waits at 0.5.
3. **The boot: 389 million instructions**, where the page's kernel
   takes 122 by having the host move and fill bytes. The GC was a
   third of a profile that had rio's start in it (`mark_slice` 23%,
   `sweep_slice` 8%), memmove a tenth. What a faster memmove in the
   kernel's C and the GC's settings (`WEB_GC = s=2M,o=400`, the page's
   only) give on the Pi's kernel is not known.
4. **The interpreter: 20 million instructions a second.** No profile
   of the host yet (no `perf` on this machine): where an instruction's
   50 nanoseconds go (the decode cache's lookup, the MMU, the
   interrupt's test before each instruction, the closures) is the
   first thing to learn. A mouse that moves runs slower than a boot
   (12 to 15): switches of process, the TLB and the decoded
   instructions emptied each time. The translator of the page
   (`raspberry/web/jit`) makes JavaScript; natively its like would be
   blocks of closures, or of host code.
5. **The board's clock.** `-ips 30` is a machine the host cannot be;
   the page measures what it runs and sets the board's pace by it
   (`paced`, `Board.set_ips`). The same natively would keep the clock
   ours when a game is busy all the time, at the price of a run not
   being the same twice (as in the page), so with a window only.
6. **The frame.** `Board.frame` copies the framebuffer (1.5 MB) 30
   times a second and the window compares it with the last; the
   board could say which rows were written (`Board.host_rows` knows
   for the page's kernel only: it sees the kernel's moves, not its
   stores).
7. **The games** (cameltry: "pretty good under qemu, and on the real
   pi1"). Not measured natively. `raspberry/tests/game_profile.sh` is
   the page's way; plan_web.md's five things for cameltry (the
   physics' tick, the shapes outside the picture, `Memshape.fillpoly`'s
   division) are all of the first kind and are this plan's too.
8. **QEMU's and the Pi 1's numbers for the same sessions**, to know
   how far this is: the same `window_lag.py` under
   `qemu-system-arm`, a game's frames a second on the three.

## Not taken: the kernel built for its host

The page's kernel runs under the native mini-qemu already
(`Boot_bench` does it): with a `-hosted` of mini-qemu (the window's
keys and pointer by `Board.host_key` and `host_pointer`, the pointer's
shape an SDL cursor from `Board.host_shape`, `Hostdraw.install`) and an
option of mini-pi it would be the window's kernel: about 60 lines.
Measured: rio and 60 moves a second, 5.2 to 5.7 million instructions
where the Pi's kernel is now at 11.1; a boot of 122 million where 389;
and a cursor that is the host's never lags, whatever the board does.
Begun this morning and taken out when the author said what he would
rather have: it is the third kind, and after today's three changes the
mouse no longer needs it. It stays the fallback if 1 to 5 above do not
make rio and a game comfortable.

## Status

2026-10-11: the plan; the three changes of "Done"; `Boot_bench -move`
there and back; `window_lag.py`. Checked: `window_lag.py` at 30 moves
a second, the board at 0.9 to 1.0 of our clock where 0.5; the same
settled screen (rio, the cursor after 300 moves) by the kernel of
before and by this one; mini-ml compiles raspberry's 19 files and
kernels' 146; `dune build ./raspberry ./tiny`. Not run: a window on a
screen, by a hand (the author's to try: `./mini-pi -g mini-9pi`);
QEMU; the Pi 1; the graphical sessions (`make -C kernels/9pi
check-windows`: minutes, and its first screens are known to be older
than the boot line); `make test-lite`; the page.
