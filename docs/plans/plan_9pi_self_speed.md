# Plan: m-IX building itself in mini-9pi in 25 minutes on one core, under 10 on four (`kernels/9pi/`, `kernels/lib_machine/`, `languages/ml/runtime/`)

The author (2026-11-15), after t-IX's self-build went from 50 minutes
to under 10 ([plan_tiny_self_speed.md](../../tiny/docs/plans/done/plan_tiny_self_speed.md)):
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

## 2026-11-18: where four cores stop, and three things found

The author: "make self-mix use 4 cores, but before we need to
significantly improve the ratio". The measure is now all of lib_core
on the card (mk lib_core.dir, mk -p), the committed kernel at both
ends of each series: 42.9 s on one core, 28.8 s on four, 1.5 times.

Where they stop. On four cores each core waits about 10 s of 29 for
the kernel's lock, and works the rest: the work adds to the one core's
40 s, so nothing is lost but the wait. The kernel's part of the build
is about 18 s on one core (card writes 3.9 s, opens 2.8 s, creates 1.7
s, exec 1.3 s, faults 6.3 s), and it is one at a time: the four-wide
part of the build, 20 s, cannot go under it. The cores' idle time is
the two serial steps', .depend and the archive, not the scheduler's.

A count put right: the reads' 4 s to 6 s said before were a process
asleep on a pipe while the core was idle (the time of a call that
sleeps was taken from the core's last entry). By device, the card's
files read are 0.55 s for 25 MB.

mini-qemu -prof, make self-quick on one core, by instructions: the
programs 57.7%, the kernel 42.3%, and in it division in software 8.4%
(libc.c's 32 turns), memmove 4.6%, phys_zero 3.0%, the collector
2.8%. Under QEMU that is not the time: the division made short
changed no measure there, a loop of registers being what a translator
runs best.

Kept (kernels 9pi and lib_machine; all three together, lib_core:
four cores 25.3 s with 4096-byte blocks too, one core 40.1 s):

- Kfs's failing wrote the waiting pieces to the card whenever a call
  failed, and a name that is not there is a call that fails: 3,500
  opens of that build, the compiler looking for a summary in each
  directory and rc for a command along its path, 20 to 118 ms for one,
  the lock held. Now only if the call itself wrote. 27.1 s against
  28.9 s on four cores.
- klock_take read the clock at each failed try, for the watchdog, and
  once at each take: a device's access, which QEMU serves one core at a
  time. Now once in 4,096 tries. 27 s against 29 s, alone.
- libc.c's division: the denominator put under the numerator's highest
  bit first, as lib_core's div.s; checked against the host's on 20
  million cases. Nothing under QEMU, kept for the boards, whose time
  is their instructions'.

Tried and not kept: a table of the names looked for, in Kfs (27.0 s
against 27.1 s once the flush was gone: the lookups were not the
cost); blocks of 4096 bytes on the card, a page and a piece of the
cache (26.4 s against 27.0 s, within the runs' spread, for another
format); the pages of zeros ahead of a fault and /env's variables
written only when changed, again on four cores (28 s and 30 s against
29 s).

So the ratio is 1.6 where it was 1.5, and what is left is the lock
itself: a compile's kernel work cannot overlap another's. Next, the
transfers of the card out of the lock again, now that the waiting
cores no longer read the clock (the first try lost a second and a
half, with them reading it), and a program's data pages kept as its
text is.

### The same day: two more for the kernel, not kept; then a directory's serial steps

The author, on 28.8 s to 25.5 s: "it's still not a big win", and on
t-ix's 50 minutes to 5: its plan's steps were the emulator made faster
twice, the compilers' code (registers, allocation inline), a name's
lookup in its kernel, then the cores for 2 times; one core alone was
4.3 times. make self-quick on mini-9pi was 52 s and is 21 s.

Not kept: the card's transfers out of the kernel's lock, tried again
with the waiters no longer reading the clock (25.8 s, 25.7 s and 26.2
s against 25.5 s, 25.3 s and 25.5 s on four cores; 43.9 s against 41.2
s on one); a program's data pages kept beside its text and copied (the
faults' time by kind, lib_core: 2.9 s for 16,000 pages read from a
file, 1.0 s for 192,000 pages of zeros, 0.85 s for 45,000 copied after
a fork; kept, 24.8 s and 25.4 s against 25.2 s and 25.8 s, 41.4 s
against 42.4 s on one core: a second, for 30 lines).

The programs, by mini-5i -prof: mini-ml compiling Unix.ml is a billion
instructions, its first function 4% (the collector's copy, hashing,
the lexer, the write barrier, comparison, Printf, division 2.2%,
memmove 2.1%): nothing to take in one place.

Kept, a directory's two serial steps, a third of lib_core on four
cores:

- .depend by as many mini-ml as cores (mini-ml -depend -part K/N: the
  lines of the K-th part of the units; depend.rc runs the N side by
  side and puts the parts one after the other: the same file). By
  hand on the card, 1.58 s against 3.31 s. A first version gained
  nothing: for(k in ...) { ... } & is the loop beside, not its turns.
- the archive: mini-ar u was 1.6 billion instructions for lib_core.a's
  5 MB (mini-5i -prof), each object read as a value and written as a
  value again to take its version out, then the file written a byte
  at a time by the runtime. A member is now its object's file's bytes
  (Link's library version 5: the libraries of a tree built before are
  refused, to remove), and caml_output moves a string to the channel's
  buffer by pieces.

lib_core: 23.1 s and 23.0 s against 25.3 s and 25.1 s on four cores
(3.1 s before the first recipe where it was 4.9 s), 38.9 s against
40.2 s on one. 1.7 times.

## 2026-11-18, later: the whole build never ran, and the kernel by ix's own tools

The whole `make self`, run on four cores for the first time, hung four
hours. What it showed, in the order found:

- The Pi 2's kernel, ocaml-light's, raised an exception nobody caught,
  and its panic faulted before saying which: ocaml-light's native
  runtime answers a null pointer for no backtrace. The panic now
  prints the exception first: `Out of memory`. The kernel's malloc
  never takes back, and ocaml-light's heap was at 52, 73, 78 and 90 MB
  of its 96 after 20, 40, 60 and 80 s; on one core the same end,
  later. GitHub's self (mix) had failed every day since 2026-10-30,
  six hours on 2026-11-18.
- The author: "let's build mini-9pi with mini-ml instead of
  ocaml-light, so we have better control on what we can do". The
  Pi 2's kernel by ix's tools (COMPILER=ix: mini-ml's two halves of
  32 MB, no malloc that grows) built 84 of 85 directories in 48
  minutes of mk on one core. But it had one core only: board.h's CORES
  was gcc's, and l2.s parked the other three.
- The 85th, mini-ld linking mini-netscape: 195 MB alive of a half's
  192. A library's member is now let go once taken (40 MB of bytes
  were kept beside the program made of them).
- "25 files not Linux's": Linux's were wrong. The top mkfile of
  2026-11-17 let lib_mime, lib_crypto and lib_compression start beside
  lib_core, and compile before its summaries were there. Each library
  now waits for lib_core (mkfiles/top.rc).

The cores for the kernel by ix's tools: l2.s starts the other cores
(each its stacks, the first core's table), has the kernel's lock
(ldrex and strex as words: the assembler needs nothing) and each
core's trap frame; l.s has four hooks, empty for the Pi 1. The C has
no gcc-only construct left for the cores: the core's number and its
timer's registers are the board's assembly for both builds. mini-ml's
runtime runs one value stack at a time, the lock's holder's: a stack
for each core's scheduler, and kernel_enter says which runs, where
ocaml-light's view of the stack is restored.

| self-quick, mk on the card | one core | four cores |
|---|---|---|
| ocaml-light's kernel | 21 s | about 20 s, then 15 s with the shared changes |
| mini-ml's, before the cores | 26 s | one core |
| mini-ml's, with them | 26 s | 18 s, twice |

The whole build on four cores with it: 1,145 s of mk against 2,881 s
on one, 2.5 times, 3.4 recipes at once, but seven directories killed:
"virtual memory allocation failed". Four mini-ld at once: a program
of mini-ml's holds the half in use, filled to its size before the
next collection, and the one just emptied, about 310 MB for 120
alive, and the Pi 2 has 847. Waiting for a page (Plan 9's newpage)
alone made it worse: all waited for each other. So the runtime gives
the emptied half back when it is 64 MB or more (segfree, which the
kernel now takes for a program's own data, and mini-5i), and a fault
with no page left waits a minute at most.

## 2026-11-19: the whole build passes, four cores, the kernel ix's own

The whole build on four cores with the memory given back, three runs:

| | mk on the card | built | what stopped it |
|---|---|---|---|
| the half given back at 64 MB, a minute's wait | 1,795 s | 83 of 85 | two mini-ld refused after their minute, beside a build of games still going |
| at 16 MB, the wait going on while others give pages back | 1,283 s | 84 of 85 | one mini-ld in games: every large link waited for the others |
| and mini-ld sharing its operands | 1,620 s | 85 of 85 | nothing |

The last: 5 ok, the 2,919 files made on the card Linux's byte for
byte, both hello programs. 27 minutes against 48 on one core, 1.8
times; the first pass of this build since 2026-10-29.

mini-ld's share of it: the program it links was a block for each
operand of each instruction. mini-netscape: 1.08 million instructions,
2.03 million operands, 38.6 million words (64 bits), of which 18.1 the
operands and their lists (half are registers, 2 words each; an
x+8(SB) is 13) and 3 a pair of file and line for each instruction.
One copy of each operand written the same, and one pair a line: 23.8
million words, 193 MB alive after the load where it was 305. The same
file; the ARM mini-ld under mini-5i 10% sooner.

What the build still shows: the directories' times add to 5,525 s
where they add to 2,870 s on one core. Some wait for memory:
languages/smalltalk/hosts/draw 586 s for 17 alone, lib_playground/apis
304 for 12. games, twice (each platform), is 912 s of the 1,152 s
critical path. So the Pi 2's 847 MB bound the four cores more than the
kernel's lock does, and a link's memory is the next thing to cut: 22
words an instruction now, 11 of them the instruction's record, three
of whose fields are a TEXT's alone.

The Pi 2's kernel is ix's tools' by default (kernels/9pi/Makefile's
COMPILER), and make self and self-quick run on four cores
(SELF_CORES=1: one).

Open: the mini-ml kernel's 26 s on one core where ocaml-light's is 21;
QEMU's settings, none given today; the cores of this kernel on a
board, not run.

## 2026-11-20: where a third of the build went: mk's own walks

The whole build on one core with each tool timed (SELF_TIMES=1): 3,687 s
of mk on the card, of which mini-ml 1,222 s (1,370 runs), mini-ld
1,131 s (122 links, 9.3 s each), mini-ar 279 s, and 1,050 s in no tool.

- mini-ar: 388 of its 413 runs listed a library's members for a
  program's -start (mkfiles/units.rc), the library read whole each
  time, 250 s. The list is written once with the library (lib.a.units).
- The 1,050 s. editors/emacs/draw had 261 of them: 74 recipes of 268 s
  by mk's clock for 104 s of tools, the first recipes 12 s for a tool
  of 0.4. Ruled out by a run each: mk's own work in a dry run, the
  generators, the environment's size, a shell's start, a target made
  again in the built directory. What found it: the kernel counting the
  time each process runs, in its own code and in the kernel
  (Proc.charge; time's u and s, /dev/cputime, /proc/n/status, which
  said 0), and mk -p saying its walks. mk's own time was 37 s after 40
  of the build, 77 after 80, 117 after 120: it computed all the while
  its recipe ran, on the same core. 108 walks of the graph, 46 million
  arcs: a node not ready was walked again through every path to it, a
  directory's units naming each other and all waiting for the generated
  ones. Natively, recipes that do nothing: 8,177 arcs. A node looked at
  in a walk and left not made is now left alone for the rest of it:
  954,000 arcs, and the directory 78 s where it was 275.

| the whole build, mk on the card | one core | four cores |
|---|---|---|
| 2026-11-19 (85 directories) | 2,881 s | 1,620 s |
| 2026-11-20, each tool timed (86) | 3,687 s | |
| with the units' list and mk's walk | 2,521 s | 1,547 s |

Both of the last line 5 ok, 86 directories, the 3,803 files Linux's.
On four cores the recipes add to 5,142 s where they add to 2,520 s on
one: each is twice as long beside the others (games.dir 457 s for 312).
That, the memory and the kernel's lock, is what is left between 1.6
times and more.

### 2026-11-23: what holds the kernel's lock

/dev/waits (ecd81d51) said each core spends 46% of the four-core build
spinning for the kernel's lock. /dev/lockstat now says what the lock
is held for: the kernel's time of each system call by its name, of
each page fault by its kind, of interrupts, kernel processes and the
schedulers, and the kernel's collections (self.sh prints both files
after the build). The whole make self on four cores at 8708184c, 5 ok,
86 directories, no page refused: mk 1,735 s on the card, each core
about 830 s spinning, and with the lock held:

| account | times | seconds |
|---|---|---|
| Pread | 1,701,657 | 555 |
| Pwrite | 955,998 | 260 |
| fault-zero (a page zeroed) | 10,798,386 | 232 |
| kproc | | 98 |
| Open | 474,822 | 68 |
| Rfork | 12,874 | 47 |
| fault-read (a page of a program's file) | 242,535 | 37 |
| Create | 803,995 | 37 |
| fault-copy (copy on write) | 715,916 | 27 |
| Exec | 13,268 | 20 |
| Stat | 54,570 | 19 |
| the rest | | about 50 |

About 1,450 s of the 1,735: the lock is 84% full. The kernel's
collections are 41 s of it (87,012). Reads and writes are more than
half, 0.3 ms a call: next, what in them (the card, the file system,
pipes). Then the zeroed pages: 42 GB of them, 830 pages for each of
the 13,000 programs run, 21 µs each.

The number to bring down, whatever the change (the kernel, the
toolchain, the mkfiles; the author: "We should track this number and
work towards lower it as we improve things in the kernel or toolchain
or mkfile or other", "in this self.yml job"): tests/self.sh's lines
"self: the kernel's lock held N s of mk's M (P%), each core waited W
s" and "self: what held it most: ...", which self.yml copies to each
run's page (its summary). Each whole four-core run measured goes here:

| run | mk on the card | lock held | each core waited | most held by |
|---|---|---|---|---|
| 2026-11-23, 8708184c | 1,735 s | about 1,450 s (84%) | 833 s | Pread 555, Pwrite 260, fault-zero 232 |
| c870037a, the card's reads and writes counted | 1,727 s | 1,444 s (83%) | 830 s | Pread x 499, Pwrite x 255, fault-zero 225 |
| Kfs's cache a clock, 128 MB | 1,387 s | 1,085 s (78%) | 592 s | Pwrite x 257, fault-zero 228, Pread x 164 |
| + writes clustered, reads ahead (the Mac busy) | 1,524 s | 1,198 s (78%) | 690 s | fault-zero 254, Pwrite x 247, Pread x 180 |
| + names and inodes kept (the Mac busy, load 20) | 1,510 s | 1,171 s (77%) | 670 s | fault-zero 260, Pwrite x 252, Pread x 204 |
| + the card's transfers out of the lock | 1,456 s | 806 s (55%) | 590 s | Pwrite x 269, fault-zero 249, Pread x 187 |
| + a fault's registers as integers, no breakpoint look on a data abort (the Mac quieter, load 5) | 1,106 s | 617 s (56%) | 400 s | Pwrite x 244, Pread x 178, fault-zero 150 |
| the same, again (a quiet Mac; games' directories mk's targets, d457ad30) | 1,118 s | 610 s (54%) | 371 s | Pwrite x 244, Pread x 170, fault-zero 150 |
| + the self build's games for the draw platform alone | 976 s | 529 s (54%) | 352 s | Pwrite x 225, Pread x 155, fault-zero 130 |
| a fault's page zeroed out of the lock (tried, not kept; the Mac at load 5) | 1,004 s | 524 s (52%) | 396 s | fault-zero 607 (545 of it out of the lock), Pwrite x 225, Pread x 183 |

The reads and writes were the card's (x, the card's file system;
c870037a's run): its commands, polled with the lock held, 740 s of the
1,444, 472,066 reads of 4 KB and 144,709 writes. Kfs's cache of 32 MB
was forgotten whole when full, 57 times in the build: what a build
reads again and again went with the rest. A clock (one piece given
back at a time, a used one let off once) and up to 128 MB while the
machine has 64 MB free: 174,498 reads, 206 s where they were 563, mk
20% faster, the files Linux's. What is left of the card is mostly its
writes (167 s), each changed piece written by itself.

Then classic file system work (the author: "are there general, classic
OS opti relevant here?", "that ideally also are simple to implement
with few LOC"). Kfs writes each run of neighbouring changed pieces in
one command (BSD's cluster_write) and reads up to 8 pieces ahead when
the one before is kept (readahead): the card's commands 174,498 reads
to 26,290 and 143,797 writes to 11,181, and its time the same, 206 s
and 167 s. Under QEMU the card costs by the byte, about 3.5 MB/s
(its DMA and SD emulated), not by the command; on a board, where a
command waits for the card, the commands are what count. Xv6fs keeps
the blocks its numbers are read from (inodes, blocks of numbers, the
bitmap; written through) and the names looked for, found or not
(Linux's dentries, negative ones too). Both runs were on a Mac busy
with other work, every account slower, fault-zero too, which none of
this touches (228 s, then 254 and 260): against it, Open 40% less,
Stat 45%, Pwrite x 14%, the lock held about 5%. Create is rc's /env
(804,119, with Pwrite e's 798,211), not the card's. What is left of
the card's file system is the card: about 390 s of transfers, polled
with the lock held. A run's time moves with the Mac's load: compare
accounts against one a change does not touch.

Then the card's transfers without the kernel's lock (the classic
remedy: a driver that does not hold the big lock while its device
works; FreeBSD's drivers out of Giant, Linux's out of the BKL).
runtime.c's io_run starts the card's DMA and waits for its end with
the lock given back, as the screen's copies are (Emmc's dma_move).
What is left must not be entered half way: a sleeping lock, Proc's
qlock (Plan 9's QLock, taken again by its holder, a note not ending
the wait), and one of them, Emmc.storage, held by every call that
reaches the card, Devsd's own and the file systems' on it (Kdos, Kfs:
Devsd.serialized wraps each of a device's calls) and Kfs's writer.
386 s of transfers out of the lock ("in unlocked card", not counted
held by self.sh): the lock held 806 s (55%) where it was 1,171, mk
1,456 s (the Mac's load lower; fault-zero 249). mk only a little
faster: the card is still one at a time, the processes that want it
now asleep instead of spinning. What it gives is the lock's room:
the other cores' faults, forks, pipes and /env no longer wait behind
the card, which counts once those are cheaper. Also seen: a
directory's recipe said after another job's line not yet ended,
counted out (85 of 86 directories); self.sh counts each directory
once, anywhere in a line.

Then the page faults: 10.8 million in the build, 22 µs each, most of
it not the page's zeroing. runtime.c's user_fault gives mini-9pi the
fault's registers as integers ("fault_ints"; xv6, whose sessions print
them whole, the strings still), where they were three strings of 18
characters read back by Main's hex; and a data abort, which a
breakpoint is not, no longer walks the tables twice looking for one.
Fault's make counts the time to get a zeroed page ("in zeroing"). The
whole build: fault-zero 150 s where it was 249, of it 62 s getting
the 10.9 million zeroed pages (6 µs each); mk 1,106 s, the lock held
617 s, each core waiting 400 s, on a quieter Mac (what this does not
touch, Exec and fault-read, 10 to 15% less too; fault-zero 40%).
That run also showed a lost line of the build's log: two writes on
one channel (mk and its recipes into one file) at one offset, a write
now able to sleep under the storage qlock before moving it. Sysfile's
write takes its bytes' place first, as Plan 9's sysfile.c.

Then the critical path, 735 to 753 s of mk's 1,112 to 1,118: games
(326 s) then the top mkfile's games-software (191 s), the same games
again for the software platform. games/mkfile's directories and
platforms became its mk's targets (506930c8; the critical path's games
459 s); then the self build (tests/self.sh, the card's and Linux's)
builds them for the draw platform alone (SOFTWARE=0: the author, "for
the self jobs it's fine to skip all the soft variant, and keep just
the draw one"). mk 976 s, the critical path 545 s, games 256 s of it,
the 3,619 files Linux's. The critical path is now well under mk's
time: 3,457 s of recipes, 3.5 at once on four cores; what is left is
the work itself (the tools under QEMU, the kernel's lock).

The card (d457ad30, self.sh's line of it): 704 MB read in 194 s, 558
written in 148 s, for a build of 515 MB; the writes are what stays
(a longer write-back would save 11 s), the reads what memory's
pressure gave back of the cache. And GitHub's runner runs QEMU 2.6
times slower than this Mac: self.yml at 8aeb061c, mk 2,904 s on the
card where this Mac's was 1,118; its mix job 67 minutes, 48 of them
the card's build, 10 the image's setup, 5 the rest of make self-mix,
3 the image's export.

### 2026-11-24: a fault's page zeroed out of the lock, not kept

self.yml at 1f9ffcf3 (mini-ml's lexer, its kept interface trees, the
runtime's MD5): mk 1,507 s on the card where 6a9ff915's was 1,741, the
mix job 37.5 minutes where it was 43; but the tix job, the runner's
speed, went from 35 to 23 minutes, so one run does not say how much
of it is ix's. The lock held 940 s (62%), each core waiting 572 s;
most held by Pread x 275 s, Pwrite x 247, fault-zero 221.

So fault-zero, the third (the author: "let's do 1"), by the classic
remedy: Linux's and the BSDs' faults zero a new page with no lock
held. Mmu.kalloc_dirty, a page not zeroed; runtime.c's phys_zero_out,
the zeroing between imag_out and imag_back as io_run's wait; Fault's
make zeroing its page so, timed as "in unlocked zeroing". The whole
build passed, its files Linux's, but gave nothing: mk 1,004 s where
it was 976, the lock held 524 s where it was 529, each core waiting
396 s where it was 352. The 9.8 million pages were 545 s out of the
lock, 55 µs each, where zeroing one takes a few: the rest was taking
the busy lock back, a fault now taking it twice. runtime.c's
IMAG_WORTH says the same of the screen's copies: below 16 KB, a page
is 4, giving the lock back costs more than it frees. Zeroing pages
ahead while a core is idle (FreeBSD's old vm_page_zero_idle, Windows'
zero page thread) does not fit either: the cores here are seldom idle,
they wait for the lock. Most of fault-zero is the fault itself (22 µs,
of it 6 the page): what is left is a cheaper fault, or fewer of them
(several neighbouring pages mapped at a fault, Linux's fault-around).

### 2026-11-27: the accounts without the card's waits, and who faults

On the Linux box (an Ampere Altra, about 3.5 times slower a core than
the Mac under QEMU), quiet, at fcea9212: mk 3,317 s on the card, the
lock held 2,094 s (63%), each core waiting 1,384 s; most held by Pread
x 590 s, fault-zero 515, Pwrite x 405, kproc kfs 296. Three things
found, each by a kernel of the day's with counters of its own:

1. **The guest's profile favours a device's access.** qemupcs.py's
   samples, every core's, put 35% of the kernel's time (not spinning,
   not idle) in timer_now, the board's clock read at each entry, by
   Fault's make and by charge_entry. The Pi 2's timer_now made a read
   of the core's own generic timer (CNTVCT, a coprocessor's register,
   no device): self-quick 74 s of mk where it was 72, the lock 52 s
   where it was 51. Nothing: QEMU stops a core where it is between
   two translated blocks, and a device's access ends one, so the
   samples land there. Not kept; the profile's devices (the step 0
   table's io_read_fifo, io_write_fifo) are suspect the same way.
2. **The accounts counted the card's waits.** An account's time is its
   processes' kernel time, the card's transfers included, which give
   the lock back (dma_move); self.sh took "in unlocked card" from the
   total only. Proc.add_out now counts each account's time out of the
   lock (/dev/lockstat's "out" lines), and self.sh takes it from the
   account. The whole build with it (61 minutes, all 98 directories,
   the 4,611 files Linux's; a counter of the day's in each fault, not
   kept, cost fault-zero 2 minutes):

   | account | held | with the card's waits | per call |
   |---|---|---|---|
   | fault-zero | 658 s (524 without the counter) | 658 | 56 µs |
   | Pread x | 483 | 617 | 545 µs |
   | Open | 220 | 222 | 486 µs |
   | Create | 152 | 154 | 218 µs |
   | Rfork | 133 | 133 | 13 ms |
   | Pwrite x | 126 | 430 | 1.1 ms |
   | the kernel's collections | 101 | | |
   | kproc kfs | 26 | 337 | |

   Kfs's writer is the card, nothing more; Pread x is the lock's,
   with 99% of its pieces found in the cache: 80 µs a piece of 4 KB.
3. **Half of the zero-filled pages are mini-ld's.** The pages zeroed
   at a fault counted by program (the exec's name) and segment, and
   each program's execs:

   | program | pages | share | execs | pages an exec |
   |---|---|---|---|---|
   | ld | 4.88 million | 52% | 121 | 40,348 (157 MB) |
   | ml | 2.40 million | 26% | 1,463 | 1,640 |
   | rc | 1.15 million | 12% | 2,473 | 466 |
   | ar | 0.56 million | 6% | 171 | 3,292 |

   All in bss, the heap. A link's halves are 16 MB and more, and
   gc.c gives the half just emptied back at each collection (GIVEBACK,
   2026-11-18: four links at once fit in 847 MB): the next collection
   faults it in again, a page at a time.

Also: two of the day's four whole builds failed, rc or ld refused a
page after its minute (languages/smalltalk, apps/music/rebirth, games),
each after 469 s waiting for pages (bugs/ix.md).

Next: fault-around for a zero-filled page, of a heap and a stack
(37 µs of a fault's 56 are the fault, and mini-ml's halves are filled
in order): about 300 s of the lock, every program, no more memory;
then what Pread x does with the lock for 545 µs.

### 2026-11-28: fault-around for the heap

Fault's fill_around: a zero fault of the bss whose page below is the
segment's already (a program walking up its heap) makes the 15 pages
after it too, from the free list alone while more than 2,048 pages
are left, so that it never waits for a page nor gives the kept texts
back. The stack is left out, and so is a fault with nothing below it:
a page made and never touched costs a fork its copy, and rc forks the
most. around = 1 turns it off.

| | before (full-prof) | fault-around |
|---|---|---|
| zero faults | 9.32 million | 1.94 million (79% fewer) |
| fault-zero, the lock | 658 s | 298 s (55% less) |
| fault-copy | 49 s | 63 s |
| Rfork | 133 s | 146 s |
| the lock held, in all | 2,364 s | 2,133 s (10% less) |
| mk on the card | 3,653 s | 3,350 s (8% less) |
| the build, minutes | 61 | 56 |

The whole build passed, the 4,611 files Linux's, no page waited for
(page 0). Self-quick the same way: zero faults 111,359 to 15,263, 8.1 s
to 3.5, mk 72 s to 67. What fault-around adds: pages made ahead and
shared at a fork, copied when written (fault-copy, 23% more faults),
and Rfork's dup holding more pages. The other accounts moved by as
much as 10% from one run to the next (Pread x 483 s, then 538; the
card's reads 485 s, then 525): the host's speed.

Next: Pread x, now the first, 538 s.

### 2026-11-28, later: Pread x is directories

A kernel of the day's (not kept) timed Pread x's parts on Kfs (#x),
by /dev/lockstat's "in" lines: a directory's read (Kchan.dirs, then
Dev.dirread), a file's (Xv6fs.read, under the storage qlock), the
copy to the user. The whole build: Pread x 885,576 calls, 722 s, 568
of them the lock's; 95,797 of the calls are directories, 503 s of it
(the qlock's waits in it too), for 47,405 directories, each read twice
(its entries, then the read that finds the end), 27 entries a listing.
Each listing at each read; each entry's kind, size and time 14 lookups
of Xv6fs's kept blocks, one a byte; and Dev.encode some forty strings
of a byte or two joined, 83 µs an entry. Three changes:

1. Sysfile: Kfs's entries kept from the first read to the end, as
   #p's already were (not a union: a mounted server's are asked at
   each read, as before).
2. Xv6fs's get16 and get32 look for their block once, not once a
   byte (a file's read gains too: each block's number is a get32).
3. Dev.encode writes into one buffer, the same bytes (checked against
   the old on 200,000 random entries).

| the whole build | before | after |
|---|---|---|
| directories' reads | 503 s | 145 s (71% less) |
| of it, the listings | 397 s | 113 s |
| of it, the encoding | 106 s | 32 s |
| files' reads (Xv6fs.read) | 316 s | 258 s (18% less) |
| Pread x, the lock | 568 s | 317 s (44% less) |
| the lock held, in all | 2,286 s | 1,718 s |
| the build, minutes | 59 | 48 |

Self-quick: directories' reads 1.31 s to 0.40, Pread x's lock 3.8 s
to 2.7. The host was faster in the second whole build: Pread e, which
none of this touches, 63.5 s then 41, so the last three lines say more
than the changes did; the parts above are their own.

What held the lock most, after: Pread x 317 s, fault-zero 274, Open
193, Create 151, Rfork 135, Pwrite x 119.

## The gate

- make self-quick's files Linux's, each step; make self-mix's at the
  end, in CI's image;
- make test, and kernels/9pi's checks (make check), unchanged;
- the time measured each step, the same way, written here.
