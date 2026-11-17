# Plan: m-IX building itself in mini-9pi in 25 minutes on one core, under 10 on four (`kernels/9pi/`, `kernels/lib_machine/`, `languages/ml/runtime/`)

The author (2026-11-15), after t-IX's self-build went from 50 minutes
to under 10 ([plan_tiny_self_speed.md](done/plan_tiny_self_speed.md)):
"we've managed to optimize significantly the self build of t-ix under
t-ix and get under 10min, with a tiny-machine interpreter with a simple
implementation ... So there is no reason we can't reach under 10min
also for m-ix under mini-9pi when using QEMU; QEMU is significantly
faster than an interpreter like tiny-machine written in ocaml". And
about the way to get there: "if we have to wait 50min each time to
learn something and change something, it will be a slow iterative
development loop".

**Status: started** (2026-11-15). Step 0's profile of make self-quick
is done; the steps are proposed, none done. One change is in: each
command's `time` off on the card (tests/self.sh, SELF_TIMES), 7%.

## The problem

make self-mix (kernels/9pi's make self, tests/self.sh): m-IX's
libraries and 70 programs built by m-IX's tools (mini-mk, mini-ml,
mini-ld...) inside mini-9pi, on a Pi 2 emulated by QEMU, then each file
compared with the same build's on Linux. CI's nightly mix job
(.github/workflows/self.yml) takes about 93 minutes, most of it this
build, and fails each night (2026-11-11 to 15) without saying why:
BuildKit kept only the first 2 MB of the step's log (fixed: the
Dockerfile now prints the end of make self's output). The cause, found
by running tests/self.rc on Linux: its list of libraries lacked
lib_mime and lib_executable, so apps/media/play, browsers/netscape and
linker/tools failed, on Linux and on the card alike (fixed: the top
mkfile's LIBS, in its order; 81 directories, none failed).

The same build on Linux (tests/self.rc, the tools compiled by OCaml,
CI's image on this Mac) takes 90 s with one job and 62 s with four
(tests/self.sh's comment said about 2 minutes). On the card it is 40 to
60 times longer on one core. QEMU translates the guest's ARM code to
the host's and should cost a few times, not 40: most of the time is
elsewhere, in mini-9pi's kernel and in the programs' own code (the
floor, the same build by m-IX's ARM programs under qemu-arm with
Linux's kernel, is step 0's last measure).

**The floor** (2026-11-15, CI's image on this Mac): the same build,
tests/self.rc, by m-IX's own ARM programs (mini-mk O=5's: mini-ml
compiled by mini-ml...) under qemu-arm, with Linux's kernel, one job:
1,155 s, about 19 minutes (79 directories, before self.rc's list was
fixed; about 20 for its 81). So on one host's core:

| the same build | one job | |
|---|---|---|
| on Linux, the tools compiled by OCaml | 90 s | 1 |
| the floor: m-IX's ARM programs under qemu-arm | about 20 min | 13 |
| on the card: the same programs in mini-9pi, QEMU's whole machine | 55 to 60 min here, about 85 in CI | 40 |

mini-9pi and the machine QEMU emulates (its MMU, the SD card) cost
about three times the floor: that is what this plan can take away. The
floor itself is QEMU's translation times mini-ml's code against
OCaml's (and ints of 31 bits): faster only by mini-ml's code generator,
another plan.

**So the goals:** make self-mix's build in about 25 minutes on one core
(the floor and a kernel's small share, from about 60), and **in under 10
minutes on the Pi 2's four cores** (the floor divides by the cores, as
make test-ix-fixpoint-arm's runs show; mini-9pi's SMP first, step 6).
Then CI's whole mix job in about 15.

## How to measure, in minutes, not an hour

The loop is make self-quick (lib_core's C library, its runtime and
three units, then two programs, 1 minute of mk on the card, 3 in all
with the card's build), in CI's own image, the committed tree:

    git archive HEAD | tar -x -C ctx    # what CI checks out; a docker
                                        # build of the working tree takes
                                        # _cross/ and its macOS tools too
    (in ctx) head -n $(grep -n '^ARG TESTS' Dockerfile | cut -d: -f1) Dockerfile > Dockerfile.base
    docker build -f Dockerfile.base --build-arg SELF=mix -t ix-mix-base .
    docker run --rm -v $OUT:/out ix-mix-base bash -c '... make self-quick ...'

and inside it, the files changed copied in, then:

- **the guest's profile**: scripts/qemupcs.py samples
  each core's PC and mode through QEMU's monitor, 50 times a second
  (`make self-quick QEMU="qemu-system-arm -qmp unix:SOCK,server=on,wait=off"`),
  and scripts/pcprof.py names them by kernel.elf's symbols: the
  kernel's functions, and the user programs' share;
- **the build's own log**: the card's /tmp/self.log, each command's
  time with SELF_TIMES=1, readable while the build runs from a copy of
  the card (its second partition, by Xv6test's cat), so a full run
  can be read halfway;
- **the result**: self.sh's lines (the files made on the card Linux's,
  byte for byte), the gate of every step.

The disk: an image is 6 GB, a card 1 GB, and Docker's disk only grows
(2026-11-15: the Mac's disk filled, docker system prune -a gave back 20
GB). One container at a time, and the images removed after.

## Where the time goes (step 0)

Measured 2026-11-15, one core (the everyday kernel):

The full build's log, halfway (54 of about 85 directories, 24 minutes of
mk on the card): ml 52% (717 compiles, 1.1 s each), ld 20% (70 links,
4.2 s each), mk itself and its shells 20% (0.24 s a command, 1.5 s a
directory; part of it each command's `time`, now off), ar, cc and asm
8%. No directory dominates (lib_core, lib_graphics, troff and the
JavaScript engine about 1.5 minutes each).

make self-quick under qemupcs.py, core 0:

| | share of core 0's time |
|---|---|
| the kernel (svc32) | 65% |
| `phys_zero`: a page zeroed | 19 to 21% |
| `wait_for_interrupt`: the core idle, waiting for the SD card | 11 to 12% |
| `io_read_fifo`, `io_write_fifo`: the SD card's data, a word at a time | 12 to 15% |
| `kmain`, `memmove`, the timer, the collector | the rest |
| the user programs (usr32) | 30 to 33% |

So the kernel takes two thirds, and two causes are half of it:

1. **Zeroing.** Pages are given on demand, at a fault, zeroed. A
   program compiled by mini-ml starts with a heap of 4 MB a half
   (languages/ml/runtime/gc.c's HEAPSTART on plan9) and Cheney's
   collector writes both halves: each ml writes about 8 MB, 2,000
   pages zeroed, for each of the 717 compiles. Under QEMU a page is
   1,024 stores emulated, each through the emulated TLB.
2. **The SD card.** QEMU's SDHCI moves its data a word at a time
   through the FIFO, each word a call of the device's emulation; and
   while a read waits, the core idles.

Tried and not kept (no gain measured): `phys_zero` unrolled to eight
words a turn (the stores' count is the cost, not the loop's); a page
not zeroed where a fork copies it whole (Fault.ml's two copies: the
zeroing is not there). The four cores (SMP=1): 1.1 times, each command
2.4 times slower when they run together (plan_multicore.md, the
self-build on four cores).

## The steps

Each one measured with self-quick and the profile, against the one
before, with the files Linux's. The gains are guesses from the profile.

| # | step | where | guess |
|---|---|---|---|
| 0 | the baseline: self-quick profiled (done); the full build timed and profiled on one core | scripts/qemupcs.py | |
| 1 | pages zeroed while the core is idle: a list of zeroed pages, kalloc's first choice | lib_machine's Mmu.ml, the idle loop | up to 1.1 to 1.2 |
| 2 | a smaller heap to start, on mini-9pi: 1 or 2 MB a half instead of 4 (fewer pages zeroed, more collections) | languages/ml/runtime/gc.c | 1.05 to 1.15 |
| 3 | the SD card: fewer reads (Kfs's cache large enough for a build that reads the same libraries again), larger reads, then the controller's DMA | 9pi's Kfs, the SD driver | 1.1 to 1.3 |
| 4 | each command's `time` off on the card (done) | tests/self.sh | 1.07 |
| 5 | the programs: ml's and ld's own time, profiled with their maps (mini-ld -map) as the kernel is with its symbols; ld 20%, perhaps libraries linked whole | languages/ml, linker | not known |
| 6 | the four cores again, once the kernel costs less: the big lock's waits counted, then the fix they point to (plan_multicore.md) | the SMP kernel | 2 to 3, later |

The order: 2 is one line to measure, so first; then 1, the larger cause
in the kernel; then 3; then the full build timed again (step 0's full
run) before 5 and 6.

(A step 7 was here, CI keeping Docker's layers between nights: taken
out, the author's rule being that the time is taken from ix itself,
its kernel and its compiler, not from CI's caches.)

## 2026-11-17: the kernel's time by its own clock, and a program's text kept

The author: "let's do it" (the kernel's steps), then "maybe we should
reset the change and focus on the multicore", "it's 1.1x we should
hope to get closer to 2x", and on the text kept, "sounds very adhoc and
specialized ... is it something mainstream kernels (bsds, linux) do?",
"I usually prefer general mechanisms and opti, but it also depends on
the LOC it requires and how it complicates things".

**A method's mistake first.** Three comparisons of this day said "no
gain" and had compared a kernel with itself: the changed files were
copied over the tree with their own times (cp -a), older than the
objects of the run before, so nothing was built again. The author:
"that's a big mistake; what we could have done to detect more easily
we were not running the right modified kernel?", "maybe a stamp or
version displayed". So the kernel now has a stamp, the checksum of the
objects it is linked from, in `/dev/osversion`, and tests/self.sh says
it with the time: "31 s of mk on the card, kernel 34260254". Two runs
compared must show two stamps. What those comparisons had said is not
known: pages zeroed while the core is idle (its counters, a kernel
that was built, do hold: 5,480 pages given zeroed ahead, 179,081
zeroed at the fault: one core is never idle in a build, the SD driver
polls, so step 1 waits for other cores); a page not zeroed when it is
written whole (to do again).

**Where the kernel's time goes**, by the board's clock read at each
entry from user mode and each way back (a scratch kernel; self-quick,
57 s of build on the card's clock, one core):

| | time | count | each |
|---|---|---|---|
| page faults | 20.5 s | 183,000 | 112 microseconds |
| system calls | 11.8 s | 156,000 | 76 |
| interrupts | 0.3 s | 4,000 | |
| idle | 1.9 s | | |

The kernel 57% of the build, as step 0's samples said, the faults
alone 36%. Inside a fault: the page's allocation 12.4 s (170,000
pages, 73 microseconds each: its zeros), the image read from Kfs's
cache 6.4 s (66,000 pages, 98 each), the copy into the page 0.1 s (2
each, the page then written a second time), the rest under a second
(the mapping, the breakpoint's test, the way back). So the first
write of a page given again is what costs under QEMU, and a third of
the pages are a program's text, read again at each exec.

On four cores (SMP=1; 50 s where one core took 57): each core waits
17 s of the 50 for the kernel's lock and is idle 13 to 23; of the 68
seconds waited, the holder was in a page fault for 44 (65%), then Open
5.6, Create 3.8, Pwrite 3.1, an interrupt 3.0, Close 2.1, Pread 1.9.
The cores wait for each other's faults: fewer and cheaper faults
before finer locks.

**A program's text kept** (Fault.text; Plan 9's cached images,
principia's attachimage and imagereclaim): the text segment stays
after its last process, by one more reference, and the next exec of
the same file gets it, all its pages mapped at once. By the file's
device, qid path and version, and the text's length; Kfs's files
only, whose version now counts a file's changes since the boot (it
was 0). Mapped to be read only; a write (the program's, a debugger's
breakpoint, the kernel's copy into it) takes the text out of the kept
ones first. All let go past 64 MB of them, and when no page is left.
Linux's and the BSDs' way, one cache of files' pages mapped and not
copied, is the general one, and not possible here without a second
cache: the card's file system has blocks of 512 or 1,024 bytes, so a
file's page is four or eight blocks of Kfs's cache, never one of its
pages.

| self-quick, one core, mk on the card | |
|---|---|
| before, two runs | 52 s, 51 s |
| a program's text kept, two runs | 32 s, 32 s |

1.6 times, more than the text pages' own cost (11 s by the clock
above): QEMU translated each program's code again at each run, and
the pages that had held code were the slow ones to write. The 89
files Linux's byte for byte each time. Not measured yet: the whole
build, and the four cores with it.

Next: the page not zeroed when written whole, compared again; the four
cores measured again (the faults were two thirds of the lock's waits);
the data segment's pages, read at each exec as the text was.

The same day, after the kept text (kernel 34260254 on one core,
f3664f4b built with SMP=1), each comparison's two stamps looked at:

- the zeroing of a page with its count computed once and eight words a
  turn (kernel 3d283f21): 31 s and 32 s, against 32 s and 32 s. Nothing.
  The 12 s measured in the allocation were not the loop's, and were not
  looked for further;
- four cores: 28 s and 29 s, against 31 s and 32 s on one, 1.1 times as
  before the kept text. mk -u on the card says four jobs ran at once for
  15 of lib_core's 26 s, so the build asks for the four cores and does
  not get them: the faults were not what kept them waiting;
- two traps met again, both seen by the stamp: SMP=1 given to the top
  Makefile is not passed on, and given to kernels/9pi's it compiles
  nothing when the kernel is already built (make does not see a flag
  change; touch lib_machine/runtime.c).

Then the kernel's time measured again, one core, 31 s: system calls
11.4 s, faults 8.8 s (146,000), idle 1.9 s; the programs themselves
about 9 s.

- 21,900 of the faults still read a text's page from its file: 19,000
  of them rc's, echo's and bind's, which are the kernel's own in /boot
  and were not kept (Kfs's files only). Kept too, one line of Fault.ml:
  26 s, 25 s and 26 s against 32 s (kernels 9f9a2825 and 34260254).
- 105,000 faults are a zeroed page of bss or stack, 3 s of them the
  allocation. Not cleaning the cache after the zeros (tried for the
  measure only: the tables need it) gives nothing.
- rc writes its 80 variables to /env before each command: 24,000 of
  the build's 31,700 creates, with as many writes and closes. Written
  only when changed (the Plan 9 Unix library, 25 lines, by each
  variable's qid version), the system calls go from 158,000 to 79,000,
  and the time does not move: 26 s and 26 s both ways on a quiet
  machine. Those calls were the cheap ones. Not kept.
- the system calls that cost are the card's: a create by cc is 12 ms,
  by mkdir 25 ms.
- four cores with /boot's texts kept: 24 s and 25 s, against 26 s on
  one. Four shells that only compute take 0.26 s at once on four cores
  and 0.61 s on one (0.19 s for one alone), so the emulator and the
  scheduler do give the cores: it is the kernel's two thirds of the
  build, under the one lock, that they wait for. Each core waited 10.6
  s of 29 for the lock, half of it behind a fault.

Then the fault's stages timed, with counters in an array (a timer read
is 0.27 microseconds; the table of names used before cost more than
what it timed, and made the zeroed pages look dear: a page allocated
is 4.5 microseconds, and the 26 said above was the measure's own). Of
the faults' 6.1 s, 3.6 s read 9,600 pages from a program's file, and
most of that is the first read of a text from the card: 1.6 ms a
page. The driver timed (Devsd's calls of Emmc.bio), make self-quick,
one core, 26 s:

    card reads    5.3 s   3,781 reads, 30,000 sectors (15 MB)
    card writes   1.8 s   1,228 writes, 9,800 sectors (5 MB)

7 s of the 26, the kernel's lock held, 1.4 ms for 4 KB either way. A
sector is 128 words taken one at a time from the controller's data
register (Machine.io_read_fifo), each a register's access that QEMU
emulates. 9pi's emmc.c moves a transfer's bytes by the DMA controller
instead, one request for all its sectors.

That, written in Emmc.bio (60 lines, and Machine.dma_pages: two pages
never cached; the audio driver already uses the controller, and ix's
own emulator has it): 23 s and 23 s against 25 s and 26 s (kernels
286f2785 and 9f9a2825), the 89 files Linux's. The driver's time goes
from 7.05 s to 5.25 s only: a transfer of 4 KB is still 0.9 ms, all of
it inside the write that starts the controller, which QEMU serves at
once: its own reading of the card's 8 sectors. So about 100
microseconds a sector is the emulator's, whatever the driver does, 4 s
of this build. Not tried on a board, where the words one by one are
known to work; a move that fails falls back to them.

For the cores, what this says: the 5 s of a card's transfers are spent
in C, the kernel's lock held, and could give it back as a copy of
pixels does (runtime.c's imag_out); the file system would then need a
lock of its own, since another process could enter it meanwhile.

That tried, and not kept. Four cores with the DMA's moves, make
self-quick: 20 s, 20 s, 19 s and 20 s (kernel a83d9bb6), against 23 s
on one core. With the kernel's lock given back while a move runs (a
function in C around the controller's start and its wait, as
imag_out), and a lock that sleeps around each transfer and each call
of Kfs and Kdos, taken again by its holder (60 lines over 9 files): 21
s, 22 s, 21 s and 21 s (kernel 04a26262), the pairs in turn, the 89
files Linux's each time. A second and a half slower. Why was not
looked into. Two guesses, neither measured: each transfer now pays
the lock's two exchanges and wakes the processes that slept on the
card; and QEMU serves a move inside the write that starts it, holding
its own lock, which the other cores need for their timer and their
interrupts. On a board, where a move takes the card's time, it could
be otherwise.

A measure that was noise, said so: the same kernel gave 26 s and 40 s
(and another 54 s then 27 s) while the host was busy. The host's load
is now printed beside each time.

## 2026-11-17, evening: the four cores, and mk's profile

Four cores gave 1.15 times one on make self-quick (20 s against 23 s),
and the author: "far too little", "there must be low hanging fruit
here", then "maybe mini-mk itself can help with his profile mode
(tiny-build had such a flag)".

mk -u, each way: on one core the card runs one recipe at a time (NPROC
is the cores'), 26 s inside recipes and 7 s outside; on four, 14 s
inside and 5.5 s outside. The 5 s outside are lib_core's .depend, one
mini-ml -depend over its 110 units before any recipe (mk -n there: 5.7
s the first time, 0.5 s the second), to compile 3 of them: a quarter
of make self-quick, and why it shows the cores so little.

mini-mk -p, new (Build.profile, as tiny-build's -t): the time before
the first recipe, the recipes' number and sum, how many ran at once,
and the critical path. All of lib_core on the card (mk lib_core.dir):
46 s on one core, 31 s on four, 1.5 times, and on four:

    mk: 31.3 s: 5.0 s before the first recipe, then 127 recipes of 89.7 s in all in 26.3 s, 3.4 at once
    mk: the critical path, 14.3 s of them:
         1.5  Pervasives.5   0.5  Seq.5   1.3  List.5   1.1  String.5   0.7  Bytes.5   0.8  Buffer.5
         2.3  Unix.5   1.1  Sys_plan9.5   0.6  Exit.5   0.4  Arg_.5   3.9  lib_core.a

So the mkfile is wide already, 3.4 at once, and its two serial steps
(.depend, the archive) are once in a whole build, where the other
directories run beside them. What is lost: the same recipes add to 41
s on one core and to 89.7 s on four. Each takes twice the time when
four run, which is the kernel's lock: half of a compile is the
kernel's, and that half is one at a time. (Four shells that only
compute lose little: 0.26 s at once, 0.19 s for one.)

Tried for the cores in the kernel, and not kept: the lock given back
during a card's transfer (above: slower); the pages of zeros after
the one a fault asks, 7 more of its segment (20 s, 20 s and 21 s
against 20 s, 20 s and 20 s on four cores; 24 s and 23 s against 26 s
and 24 s on one).

Kept, to shorten the kernel's half, lib_xv6fs's Xv6fs.ml: a file made
looked for a free inode from the first one, a read for each of the
card's 5,000 (the 12 ms of a create by cc), and now from where the
last was found; a name looked for in a directory made a list of all
its entries, two strings each, twice for a file made, and now reads
the directory's bytes; a file emptied sent the search for a free block
back to the device's first. make self-quick on one core: 22 s and 22 s
against 24 s and 24 s (kernels 06dde492 and 286f2785).

On four cores: 19 s, 19 s and 21 s against 20 s, 21 s and 20 s (kernels
f7ffc52c and a83d9bb6): a second at most, within the runs' spread.

Also: make run and make run-window at the top, mini-9pi by hand on the
card make self builds on (kernels/9pi's run-self); and SMP=1 now makes
runtime.o again when it is given or no longer is (kernel.mk), where it
kept the kernel there was, on one core, twice taken for four today.

Next: the kernel's half of a compile, measured call by call (an open,
a read, an exec), the largest first; whether make self-mix runs on
four cores, as t-ix's self does; and the whole make self-mix once.

## The gate

- make self-quick's files Linux's, each step; make self-mix's at the
  end, in CI's image;
- make test, and kernels/9pi's checks (make check), unchanged;
- the time measured each step, the same way, written here.
