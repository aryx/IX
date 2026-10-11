# Plan: several cores: mini-9pi on the Pi 2's four, and mini-qemu's cores on the host's (`kernels/9pi/`, `kernels/lib_machine/`, `raspberry/`)

The author (2026-10-11), after asking whether mini-9pi and mini-qemu
handle several cores: "maybe we can start a multicore plan document;
we definitely want to handle the Pi 2 multiple cores so mini-9pi must
be extended, and care must be taken because of ocaml runtime and
assumptions. For mini-qemu, maybe when we are on ocaml 5 we could use
multiple domains; I think in mini-chrome we managed to find
abstraction (like work pool or something) so that we were using
threads on ocaml 4 and domains on ocaml5".

This is what [`plan_pi2.md`](plan_pi2.md) leaves out by its decision 2
("One core. ... Several cores is a kernel's change (locks, a scheduler
for each), not a board's: not in this plan"). That plan comes first:
there is no Pi 2 kernel yet, and no Pi 2 in mini-qemu.

The short answer, in two parts that do not depend on each other:

- **mini-9pi: one lock around the whole kernel.** A core takes it at
  every trap and interrupt and gives it back on the way to user mode,
  so OCaml's runtime (one heap, one collector, written for one thread)
  is only ever run by one core at a time, and no module of the kernel
  gets a lock of its own. Four programs compute at once; two system
  calls do not. It is what the first multiprocessor Unix kernels did.
- **mini-qemu: a guest core on a host domain, under OCaml 5 only, and
  behind a switch.** The turns in one thread stay what the tests run
  (they are repeatable); mini-chrome's `Worker_spawn` is the piece to
  take, not its pool.

**Nothing here was built or run.** What is said of the tree was read
on 2026-10-11; what is said of the BCM2836's registers, of QEMU and of
OCaml 5's runtime is from memory and is marked so.

## The survey (2026-10-11, read; nothing run)

### mini-9pi and its runtime

- **One processor is an assumption stated twice**:
  `kernels/9pi/init/Main.mli` ("there is one processor and no lock")
  and `kernels/9pi/processes/Proc.mli` ("One core, no preemption inside
  the kernel: no locks"), which also says where it breaks first: sleep
  and wakeup on a `wait_chan` lose a wakeup with two processors, and
  Plan 9 replaced them by a Rendez with a lock. On the Pi 4 the four
  cores arrive at `_start` and `kernels/lib_machine/pi4/l.s` parks all
  but the first.
- **The kernel is built by three compilers, and none of their runtimes
  is for several cores**: ocaml-light (the Makefile's default), OCaml
  4.14 (`COMPILER=ocaml`, the Pi 4 only) and mini-ml (the mkfile: the
  kernel that goes on the card). Each has one heap, one allocation
  pointer and a collector that believes nothing else runs.
  **OCaml 5's runtime is no way out**: it has no native code for
  32-bit ARM (from memory: 5.0 dropped it), the Pi 2's kernel is 32
  bits, and the kernel of the card is mini-ml's.
- **What the runtime keeps per stack is already saved per process**:
  `kernels/lib_machine/runtime.c`'s `k_swtch` saves and restores the
  collector's view of the stack (`caml_bottom_of_stack`,
  `caml_last_return_address`, `caml_gc_regs`,
  `caml_exception_pointer`, `local_roots`; mini-ml: `ml_stack_switch`),
  and `scan_stacks` gives the collector the stacks that do not run.
  With one lock this stays right as it is: the running stack is the
  lock's holder's, every other is a saved one.
- **What is per kernel and must become per core**, all in
  `runtime.c` and the board's files: `current` and `cur_tf` (the
  running slot and its trap frame, globals read by the trap entry in
  assembly); the scheduler's slot (`contexts[NPROC]`, on the boot
  stack: one, where each core needs its own to idle on); the modes'
  stacks set by `start.s` (IRQ, abort, undefined); the user's table
  (`set_ttbr0`) and the TLB, which are a core's.
- **No instruction for a lock yet in ix's toolchain**: `machine/Arm32`
  (the emulator) decodes `ldrex`, `strex` and `clrex`; `assembler/`
  has none of them (grep), and `l.s` is assembled by it. ARMv6's `swp`
  is no substitute: the author's board is a Cortex-A53, which has not
  got it (from memory). principia's port has `tas_raspi2.s` (41 lines)
  and `concurrency_raspi2.c` (32).
- **The user's side needs nothing**: the programs are the Pi 1's, a
  process is one thread of control, and Plan 9's processes that share
  memory (`rfork` with RFMEM) already use the kernel's semaphores
  (`Syssema`), not an instruction of their own (to check: what ix's
  libc does for its locks).

### The Pi 2's cores (from memory, to read at stage 1)

- The firmware starts core 0 in the kernel and leaves the three others
  in a loop of its own, each waiting for an address written to **its
  mailbox 3** of the cores' controller at 0x40000000 (plan_pi2.md has
  the controller; the write is at 0x4000008C + 16 times the core's
  number).
- The same controller has, per core: four mailboxes whose write
  interrupts the core (how one core tells another to reschedule or to
  empty its TLB), the routing of the core's own timer (ARM's generic
  timer, `CNTP_*` in CP15), and where the peripherals' interrupt goes
  (core 0 by default).
- The Pi 1's system timer and interrupt controller, which plan_pi2.md
  keeps, serve core 0 alone. The other cores' clock is their own
  timer: the first new driver.
- QEMU's `raspi2b -smp 4` has the controller, the mailboxes and the
  timers. It starts the other cores itself in a stub like the
  firmware's (to check: whether as the board does).

### mini-qemu

- **The Pi 4's board already has one to four cores**
  (`raspberry/Pi4.ml`, 454 lines; `-smp N`): in one thread, a
  `quantum` of 1,000 instructions each in turn, a sleeping core
  skipping its turns; `raspberry/Gic.ml` (168 lines) has each core's
  private interrupts and the SGIs. What runs on it is xv6-pi4, about 4
  times slower with 4 cores (its idle cores spin).
- **The Pi 1's board is one core by construction**
  (`raspberry/Board.ml`, 591 lines): one `Arm32_isa.state`, and its
  caches of decoded instructions are the module's globals (`used`,
  `kept_words`, `kept_code`, `code_pages`, the `host_*` references).
  A Pi 2 is this board with an array of cores, as `Pi4.ml` is.
- **No domain, no thread in `raspberry/` or `machine/`** (their dune
  files name `unix` and `tsdl` only).
  [`plan_mini_qemu_speed.md`](plan_mini_qemu_speed.md) does not
  propose any.
- **OCaml 5 already builds the tree, in Docker**: the Dockerfile's
  `OCAML_VERSION`, `make build-docker-ocaml5` (5.5.1), and
  `.github/workflows/docker.yml`'s matrix has 5.5.1. No file of ix
  asks which compiler it is (`grep ocaml_version */dune`: none), so
  no program is another under 5. A 5.5.1 switch is on this machine
  beside 4.14.2 (`opam switch list`); `dune build` in it was not
  tried here.
- **mini-chrome's abstraction is two pieces**
  (`~/github/mini-chrome/libs/network`):
  - `Worker_spawn.mli`: `parallel : bool`, `workers : int -> int`,
    `spawn : (unit -> unit) -> unit`; its implementation is one of two
    files of three lines, `spawn/threads.ml.in` (`Thread.create`) and
    `spawn/domains.ml.in` (`Domain.spawn`), copied by two dune rules
    on `%{ocaml_version}`. Mutex and Condition have the same names in
    both.
  - `unix/Worker.ml` (63 lines): the pool, `submit` and `poll`, for
    jobs that block (a name resolved) or compute (a picture decoded).
- **Which piece fits**: a guest core is not a job. It runs for the
  whole session and shares the board's memory with the others. So
  `Worker_spawn` alone, and its `parallel`: under 4.14 a thread a core
  would be the turns of today with the runtime's lock passed around,
  slower and no longer repeatable; there the cores keep taking turns
  in one thread. The pool could serve the emulator elsewhere (the
  network's slow connect, which stops the board 10 s at most: 256dc48):
  not this plan's.

## Decisions (proposed, for the author)

### mini-9pi

1. **One big lock for the kernel, as the start** (the author,
   2026-10-11: "we can start with one kernel big lock, but ultimately
   we would like to imitate principia's more fine grained multi-core
   locks. This is complicated though probably with ocaml runtime and
   heap not being concurrent ready"). What comes after is the section
   "After the big lock" below. Taken in the trap, interrupt and
   fault entries before OCaml is called, released in `user_return`
   and around the idle wait. Inside, the kernel is today's: one core
   in it, no preemption, the old sleep and wakeup right again.
   Why not principia's locks at once: every module of the kernel
   changes, and with these runtimes an allocation is itself not safe
   on two cores, so a lock around each: the big lock again, by
   another name. Not taken at all:
   - *a runtime a core*, the cores speaking by messages (Barrelfish's
     way): Plan 9's kernel shares everything (channels, the name
     space, the mount table), so it would be another kernel.
2. **The lock is taken in C or assembly, never in OCaml**, and a core
   that waits for it spins with its interrupts off. The runtime never
   learns there are several cores: the same `runtime.c` for the three
   compilers, with `current`, `cur_tf` and the scheduler's slot
   indexed by the core's number.
3. **What a core must not do without the lock**: touch the heap, call
   the runtime, read a kernel's global. So an interrupt taken in user
   mode waits for the lock like a system call; an interrupt taken
   while idle takes it before the scheduler goes on.
4. **The peripherals' interrupts stay on core 0**; the other cores
   get their own timer's, for the 100 ms slice only. The clock's work
   (`Main`'s tick: the sleepers, the network, USB) is core 0's.
5. **One run queue**, as today, each core's scheduler taking the
   first process ready. The queue's order is what the console's
   byte-for-byte comparison with principia's kernel rests on: with
   several cores the order of two processes' output is no longer
   one, so **the recorded sessions are run with one core**
   (`ncpu=1`, or the cores not started), and several cores get tests
   whose answers do not depend on the order.
6. **An address space changed under another core**: when a process's
   pages are unmapped or its table freed while a process sharing it
   (RFMEM) runs elsewhere, the other cores are told by their mailbox
   to empty their TLB, and the caller waits for them. The simple first
   form: every core, the whole TLB.
7. **`ldrex`, `strex` and `clrex` in ix's assembler**, for the lock;
   gcc's side has them.
8. **The Pi 4 after the Pi 2**, by the same lock; its start already
   has the cores in hand (`park`), its interrupts are the GIC's.

### mini-qemu

9. **A Pi 2 board with one to four cores, in turns first**, as
   `Pi4.ml`: the cores' controller (mailboxes, the timers' routing),
   the generic timer's registers, the firmware's wait for mailbox 3.
   It is the "hundreds of lines" plan_pi2.md set aside ("the four
   cores started, their controller and their own timer"), wanted now
   because stage 2 below is debugged there first: turns are
   repeatable, and `-status` says where each core is.
10. **OCaml 5 is a compiler of the tree, the third** (the author,
    2026-10-11: "OCaml 5 should become a second compiler; actually it
    could be a third because we have ocaml-light, ocaml 4.14, and we
    could have ocaml 5 then to enable the domain features for some
    programs"). ocaml-light compiles the kernels, 4.14 is what the
    tree is built and tested with each day, and 5 is where a program
    may have more: its domains. The rule for such a program: **one
    source, the same answers under 4.14** (and under mini-ml where it
    is built by it), slower only; what differs is a file chosen by
    dune on `%{ocaml_version}`, as mini-chrome's. Checked by
    `dune build` and the fast tests in the 5.5.1 switch, beside
    Docker's build.
    **mini-qemu is the first such program: asked for
    (`-cores-parallel`, off by default), a guest core a domain.** `Worker_spawn` copied from
    mini-chrome (its `.mli` and the two three-line files, with the
    line that says where they come from). 4.14 and mini-ml: the
    turns, as today, whatever is asked. The tests stay on the turns.
11. **What the domains share, and how**:
    - the guest's RAM, without a lock: two guest cores racing on a
      word is the guest's race, as on the board (OCaml 5 keeps a race
      on bytes memory-safe: from memory, to read in its manual);
    - `strex`, under one mutex of the emulator's, comparing the word
      with what `ldrex` read (QEMU's way; it can succeed where the
      board's would fail, when another core stored the same value in
      between: to say in the code);
    - every device and the interrupt controller, under one mutex (a
      device is touched rarely against an instruction);
    - nothing else: each core's registers, MMU and decode caches are
      its own, so `Board.ml`'s global caches become the core's first
      (step 4).
12. **Time**: today the board's clock is the instructions run. With
    domains each core counts its own, and the devices' clock is core
    0's; a core asleep waits on a condition, not in a loop.

## The stages (each checked before the next)

0. **[`plan_pi2.md`](plan_pi2.md)'s stages 1 and 2**: the Pi 2's
   kernel with one core, under QEMU.
1. **mini-qemu's Pi 2 with several cores, in turns** (decision 9).
   Check: a few lines of assembly that start the three other cores by
   their mailbox and print each one's number, the same on QEMU's
   `raspi2b -smp 4` and on mini-qemu; xv6's arm-pi2 if it starts its
   cores (to look).
2. **The cores started and idle** in mini-9pi: each with its stacks,
   its MMU on, its timer, the lock taken and given back around `WFI`,
   running no process. Check: the Pi 1's sessions unchanged on core 0;
   `-status` shows three cores asleep.
3. **Processes on every core.** The per-core `current`, the
   scheduler a core, the TLB's message (decision 6); a line a core
   where the kernel says its processors (`#c/sysstat` in Plan 9: to
   look whether Devcons has it). Check: four programs that only compute end in about
   the time of one (the board's clock, under QEMU `-smp 4`); a test
   that forks, shares memory and exits in a loop, for hours; the
   collector forced often (`CAMLRUNPARAM`) meanwhile. Then the
   author's Pi 2B.
4. **mini-qemu's cores on domains** (decisions 10 to 12). First what
   stage 1 left global made a core's; then the dune rules and
   `Worker_spawn`; then the mutexes. Check: built by 4.14 and by 5.5.1
   (`dune build`), the sessions the same under both with the switch
   off; with it on, stage 3's four programs in about a quarter of the
   host's time; ThreadSanitizer once if the 5.5.1 switch has it.
5. **Measured, and what it says**: where the lock is waited for (a
   counter a core: the time spent spinning), under rio with a game.
   The numbers choose where "After the big lock" begins (the draw
   device is in the kernel: a game's pixels are system calls).
6. **The Pi 4** (decision 8).

## After the big lock: towards principia's locks

The goal (decision 1): principia's `lock`, `qlock` and `Rendez`, a
structure at a time. What stands in the way is not the kernel's
modules but the runtime under them, on four points:

    what the runtime has one of          what two cores in OCaml need
    -----------------------------------  ------------------------------
    the allocation pointer (a register   an area a core, or a lock an
    or a global), the young heap         allocation
    the table of old-to-young pointers   one a core, or a lock a store
    (caml_modify's)
    the major heap's free list           a lock
    a collection: it believes the        every core in OCaml stopped at
    running stack is the only one        a point where its stack can be
                                         scanned, and scanned

That is a stop-the-world collector for several cores: less than OCaml
5's (no concurrent collection), still a runtime's rewrite. Three
steps, each of use by itself, the first two with the runtimes as they
are:

- **A. The names, under the big lock.** `Lock`, `Qlock` and `Rendez`
  as modules, used where principia uses them (Proc's sleep and wakeup
  become its `sleep(r, f, arg)` and `wakeup(r)`), costing nothing
  while one core is in the kernel. The kernel reads as its twin, the
  structures' owners are written down, and step C has its places
  marked. Its cost is the count of sites: to grep in principia first.
- **B. The lock given back around what does not touch the heap**, as
  OCaml 4.14's own threads give back the runtime's lock around a
  blocking call (`caml_enter_blocking_section`): a page zeroed or
  copied (fork, a fault), a device's wait, a fill or a copy of pixels
  **if the pixels are outside the heap** (an image that is an OCaml
  string may be moved by a collection another core starts: to look at
  what Memdraw's images are, and the framebuffer's). Chosen by stage
  5's numbers; each a few lines of C.
- **C. Two cores in OCaml: mini-ml's runtime only.** It is ours and
  small, and its kernel is the one on the card; ocaml-light's and
  4.14's stay on the big lock (the same kernel source: A's modules
  are no-ops there). The four rows above, in the order they are
  listed; the stop asked by the cores' mailbox interrupt, taken at an
  allocation or a call (where mini-ml's value stack is exact: to
  check). A plan of its own when A and B are done, with
  [`done/plan_9pi_gc.md`](done/plan_9pi_gc.md)'s numbers to say
  whether a stop of every core is bearable.

cs-history: the same road was Unix's and Linux's (a big kernel lock
in 2.0, 1996; the last of it removed in 2.6.39, 2011), and OCaml's
own: one runtime lock from 1995, OC4MC's stop-the-world parallel
collector tried in 2008 to 2010, domains in 5.0 (from memory).

## What several cores will not give

- **A game is one process**: its update and its drawing are on one
  core whatever the board. The three others take what was beside it
  (rio, the file server, the network, a compile in another window).
  [`plan_pi2.md`](plan_pi2.md)'s reason for the board ("four cores
  each faster than the Pi1's one") is, for one game, the "each
  faster", not the four.
- **Two system calls at once**: the lock. A process that mostly
  reads, writes and draws gains nothing from a second core.
- **A collection stops every core** that wants the kernel, for its
  whole length ([`done/plan_9pi_gc.md`](done/plan_9pi_gc.md) has its
  numbers for one core).

## Open questions

- Step C in mini-ml's runtime alone, the two other compilers'
  kernels staying on the big lock: acceptable?
- mini-qemu's Pi 2 with its cores (stage 1) before the kernel's work,
  or QEMU alone for the bring-up and mini-qemu after?
- Which other programs get domains under OCaml 5 after mini-qemu
  (mini-netscape, as mini-chrome's pool; the build's jobs)?
- Does the mkfile's mini-qemu (built by mini-ml where it is) need to
  know of this at all, beyond a third `Worker_spawn` that says
  `parallel = false`?

## Status

2026-10-11: plan written, from reading. Nothing built, nothing run.
Decided by the author the same day: the big lock first, principia's
locks the goal; OCaml 5 a third compiler, for domains.
No Pi 2 kernel and no Pi 2 in mini-qemu yet (plan_pi2.md: written,
not begun).
