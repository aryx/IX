# Plan: m-IX building itself in mini-9pi in under 10 minutes (`kernels/9pi/`, `kernels/lib_machine/`, `languages/ml/runtime/`)

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

**The goal is make self-mix's build in under 10 minutes**, on one
core first; then CI's whole mix job in about 15.

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

- **the guest's profile**: kernels/9pi/tests/perf/qemupcs.py samples
  each core's PC and mode through QEMU's monitor, 50 times a second
  (`make self-quick QEMU="qemu-system-arm -qmp unix:SOCK,server=on,wait=off"`),
  and tests/perf/pcprof.py names them by kernel.elf's symbols: the
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
| 0 | the baseline: self-quick profiled (done); the full build timed and profiled on one core | tests/perf/qemupcs.py | |
| 1 | pages zeroed while the core is idle: a list of zeroed pages, kalloc's first choice | lib_machine's Mmu.ml, the idle loop | up to 1.1 to 1.2 |
| 2 | a smaller heap to start, on mini-9pi: 1 or 2 MB a half instead of 4 (fewer pages zeroed, more collections) | languages/ml/runtime/gc.c | 1.05 to 1.15 |
| 3 | the SD card: fewer reads (Kfs's cache large enough for a build that reads the same libraries again), larger reads, then the controller's DMA | 9pi's Kfs, the SD driver | 1.1 to 1.3 |
| 4 | each command's `time` off on the card (done) | tests/self.sh | 1.07 |
| 5 | the programs: ml's and ld's own time, profiled with their maps (mini-ld -map) as the kernel is with its symbols; ld 20%, perhaps libraries linked whole | languages/ml, linker | not known |
| 6 | the four cores again, once the kernel costs less: the big lock's waits counted, then the fix they point to (plan_multicore.md) | the SMP kernel | 2 to 3, later |
| 7 | CI: Docker's layers kept between nights, OCaml not built again each time | .github/workflows/self.yml | 5 to 8 minutes a night |

The order: 2 is one line to measure, so first; then 1, the larger cause
in the kernel; then 3; then the full build timed again (step 0's full
run) before 5 and 6.

## The gate

- make self-quick's files Linux's, each step; make self-mix's at the
  end, in CI's image;
- make test, and kernels/9pi's checks (make check), unchanged;
- the time measured each step, the same way, written here.
