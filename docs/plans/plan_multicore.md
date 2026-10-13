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

2026-10-12: stage 0 is done (plan_pi2.md: the Pi 2's kernel with one
core on the author's board, and a Pi 2 in mini-qemu, one core). The
author the same day: "what about trying to add multi core to
mini-9pi! so that I can run 2 games in different windows and getting
both games fast."

**Measured first, what a game's time is** (mini-qemu's `-status` and
`-prof`, the Pi 2's kernel, cameltry started from the console, no
rio): a quarter of the instructions in user mode, three quarters in
the kernel, and of the kernel's nearly all in `memmove` (the pixels:
the game's image loaded, the screen flushed). So with the big lock
alone two games on two cores each run at about two thirds of one
game's speed alone (the kernel's three quarters taken in turn), where
one core gives a half: a third more, not twice. What gives the rest
is step B of "After the big lock", wanted with the lock and not
after: the lock given back around a large `memmove`, if its bytes
are outside the heap or cannot be moved (to look: what Memdraw's
images are for each of the three runtimes). The numbers are the
emulator's instructions, not the board's time (its caches, its
memory's speed); under rio, not measured.

**Stage 2, its first half: the Pi 2's three other cores started, and
idle**, not committed. The open question's answer taken: QEMU alone
for the bring-up (its `raspi2b` has the four cores, each a host's
thread), mini-qemu's cores after (stage 1 becomes a later one).
`pi1/start.s`, under PI2: every core leaves the hypervisor's mode;
the others then wait (`wfe`) until the first names them (`core_go`),
take the kernel's table, turn their MMU on, get their own stacks
(`core_stacks`, 128 KB a core) and call `core_main`; the cores'
controller mapped at 0xFF000000; `dcache_all` may empty the first
level only (a core that starts must not empty the second, which is
every core's: Linux's `v7_invalidate_l1`), `caches_enable_core`.
`pi1/machine.c`: `cores_start` (the address of the start written to
each core's mailbox 3, for the board, whose firmware holds them;
`core_go`; a tenth of a second waited for `core_up`), `core_main`
(its caches on, then `wfi` for ever, interrupts masked: no OCaml, no
interrupt, no timer yet). `Main.ml`: "cpu0: ... (4 cores)", on the
one line (a line a core, 9pi's way, moved the console down and the
recorded screens with it). By gcc's start only: the kernel by ix's
tools (`l2.s`) still keeps its other cores and says one.
Checked: under QEMU the line says 4 cores, under mini-qemu (one
core) nothing more and a tenth of a second at the boot; `make
check-ix` for both boards and `make check-draw BOARD=pi2`, as
before; the Pi 2's kernel by ix's tools links and boots. Not
checked: the board, where the cores come from the firmware's loop
by their mailbox and in the hypervisor's mode, neither of which an
emulator here does; that a started core's caches are right (an idle
core touches nothing). Next: each core's own `current`, trap frame
and scheduler's stack in `runtime.c`, its timer, the lock (`ldrex`,
`strex`) taken at each entry of the kernel and given back on the way
out and around the large `memmove`s.

2026-10-12, on the board (the author: "it didn't detect the 4 cores (18:10
card img)"). The cause supposed, not yet confirmed there: a core that
starts has its caches off and reads `core_go` (and `caches_are_on`, the
tables) from memory, where the first core's write was not yet: it was in
the first core's cache. QEMU has no caches and showed nothing.
`cores_start` now writes `core_go` and empties the caches
(`cache_flush_all`) before the mailbox is written. And each core marks
how far its start came (`core_stage`, a line of its own, read by the
first without the cache): a core that does not come up is said on
cpu0's line, "(core 1 stopped at N)", N being 1 waiting for `core_go`,
2 before its MMU, 3 after; nothing is said when it never left the
firmware (an emulator's one core too). Checked: `make check-ix
BOARD=pi2` as before, "(4 cores)" under QEMU, nothing more under
mini-qemu. On the board, with the card built at 20:53, the author: "it worked!":
the four cores are up, so the cause was that one.

2026-10-12, stage 3, the processes on every core (the author: "ok let's
continue with the next step"). Under QEMU's four cores only; the board
not yet (a card built at 21:44).

What was done, the kernel by gcc (`start.s`):
- **The lock** (`klock`, `ldrex` and `strex`), taken by `kernel_enter`
  after each trap entry has saved the user, given back by
  `kernel_leave` at `user_return`, and both around the wait of a core
  with nothing to run (`wait_interrupt`). The runtime's view of the
  stack goes with it: saved in the running slot's context when the
  lock is given, taken back with it. So a process in user mode on
  another core is, for the collector, a stack that does not run.
- **A core's own**: `current` and `cur_tf` (`currents`, `cur_tfs`, by
  MPIDR), a scheduler's slot (NPROC + the core; OCaml sees NPROC), the
  modes' stacks (the abort entries no longer set sp from a global),
  and in `Proc` the readied process and the slice.
- **The other cores' tick**: ARMv7's virtual timer, 10 ms, through the
  cores' controller, on only while the core runs a process. The
  devices and the clock stay the first core's (decision 4).
- **A core that waits is told** by its first mailbox when a process is
  made ready (`Proc.ready`, `cores_wake`: one core that waits).
- **Shared memory said so**: S in the kernel's sections and in the
  user's pages on the Pi 2 (the lock's pair of instructions sees
  another core's write only there, by the architecture); the
  instruction cache emptied on every core when code is written
  (ICIALLUIS).
- **When the cores run processes**: on a board; under an emulator only
  in a kernel built with SMP=1, the recorded sessions being one core's
  (decision 5).

Checked: `make check-cores BOARD=pi2` (new: four shells that compute
and four that start 150 processes each, at once, then threads and
hello, under QEMU); by hand the same with 2,700 pipes of three a shell
(some ten thousand processes), no fault; four shells that compute end
in 13.3 s where one core takes 30.7 (one alone: 7.6 s; the host has 64
threads, so why not four times is the kernel's, not looked into: stage
5); session-ix and session-ix-b on four cores, the recorded consoles
but the two lines known before. With one core, as before: `make
check-ix` and `make check-draw` for both boards; the probe of a device
that is not there (`echo x > /dev/audio` under QEMU's Pi 1: the abort
entries were rewritten for both boards); the kernels by ix's tools
link (not run).

Not checked: the board, all of it. What no emulator shows: the lock
between real cores, the virtual timer after the hypervisor's mode,
the caches of a process that changes core. Not done: the TLB's
message (decision 6: no process shares a table here; rfork's RFMEM
shares segments, each process its own table, so a page taken from one
is still in the other's until it faults, as with one core); the lock
given back around the large `memmove`s, which is what two games need
(three quarters of a game's time is in the kernel, so with this alone
two games should run at about two thirds of one's speed each); `ldrex`
in ix's assembler and `l2.s`; mini-qemu's cores; a line a core in the
console.

2026-10-12, stage 3 on the board (the author, the card of 21:44: "it
works pretty good; I was able to run many cameltry in different
windows and the fps each time go down, but it's still playable"). So
on real cores: the lock, the other cores' timer and a process that
changes core hold, for games in windows; no number taken. The fps
going down with each game is what was expected of one lock (the
pixels are copied under it).

For the step after, read (nothing run): the pixels are not copied by a
few large `memmove`s but a row at a time (`Memdraw`'s `Bytes.blit`
between two images, `Memimage.to_screen`'s `Phys.write_sub` to the
framebuffer), and an image's bytes are in OCaml's heap. So "the lock
given back around the large copies" is one of:
- the lock given back for a whole draw of rows, in C, the images'
  bytes being where the collector does not move them: true of
  ocaml-light's large blocks if its compaction is off, false of
  mini-ml's collector, which copies all (the kernel by ix's tools);
- or the images' bytes outside the heap (pages of their own, as the
  framebuffer), which is right for the three compilers and is the
  larger change (Memimage's data is a Bytes everywhere).
Either way the external must not be a "noalloc" one: the runtime's
view of the stack has to be the caller's when the lock goes.

2026-10-13: what each core does can be seen (the author: "an
application to display the cpu activity, a bit like xosview on
linux", "so we can see the 4 cores activity, whether they are idle or
not"). The runtime counts the microseconds each core waits with
nothing to run (`idle_wait`: the board's clock before the wait and as
soon as it ends, so a core waiting for the kernel's lock is busy, not
idle); the kernel has `/dev/sysstat`, a line a core in 9pi's ten
numbers (the processes switched to and the percent idle are counted,
the others 0; the percent is of the last fifth of a second), and
`apps/misc`'s mini-stats (`stats` on the card) draws a strip a core,
five samples a second. Checked under QEMU's four cores (SMP=1): idle
cores read 100, two shells that compute take two cores to 0, the four
strips on the bare screen. Not checked: on the board; in a window of
mini-rio's. What it costs is not nothing: alone on QEMU's screen
(1024 by 768, four strips moved five times a second) the cores read
some 10 to 20% busy; not measured on the board. It is the tool for
stage 5's measurement, and for the lock's cost: two games that draw
show two cores busy where one mostly waits for the other.

2026-10-13: mini-qemu's Pi 2 has its four cores, in turns: decision
9 (the author: "what about trying to get multiple cores used also for
mini-qemu? so mini-qemu could also emulate 4 cores of the Pi 2?").
`raspberry/Board.ml`: a core's own state (registers, MMU, CP15,
decode cache, whether it waits) in a record, the running core's put
in the board's fields when its turn comes (`select`), so the
interpreter's loop and the coprocessor's code are as they were; a
batch each in turn in one thread, the time that passes the longest
turn's; a WFI'd core skips its turns until its own interrupt is
pending, a WFE gives the turn up; `ldrex`'s reservation ends with the
turn (another core may have written the word: the `strex` is refused
and tried again). The cores' controller at 0x40000000 (mailboxes,
which timers and mailboxes interrupt a core, what is pending) and the
virtual timer (CNTFRQ, CNTV_TVAL, CNTV_CTL: a count a microsecond).
MPIDR says the core; ICIALLUIS and the TLB's c8 c3 are every core's.
`Main.ml`: `-device loader,addr=,cpu-num=n` starts core n there (it
was ignored), `-device loader,addr=,data=,data-len=4` writes a word.
The kernel needed nothing. `./mini-pi mini-9pi2` asks for the four
under mini-qemu too.
Checked, the Pi 2's kernel under mini-qemu: "(4 cores)"; without the
word the three others wait and `/dev/sysstat` has one line; with it
four lines, and four shells that compute, four that start 9 processes
each through pipes, the 200 threads, hello, no fault. `make check-ix`
for both boards: mini-qemu's console the same as QEMU's byte for byte
but QEMU's own warning (and both the recorded one but the line known
before, 28 for 24). What it costs: nothing while the others wait;
busy, the host's time is the cores' sum (the four shells of
`session-cores.cmds` that compute: ten minutes, where QEMU's four
host threads take seconds; its four that start 150 processes each
were not finished in that time). Not checked: games in windows there
(minutes a screen); the recorded graphical sessions for the Pi 2
(they fail at the first screen since before: the Pi 1's banner). Not
done: the domains (decisions 10 to 12, `-cores-parallel`), which is
what would make four busy cores as fast as one; `make check-cores`
still runs under QEMU alone.

2026-10-13, on the board (the author, the Pi 2 with the card built
at 11:44): "it works well, no more exn this time. cameltry alone is
50fps and when running 2 around 31 fps, and stats clearly show the 4
cores are used pretty well". The first numbers from the board: two
games each at 62% of one's speed, where the plan's measurement under
mini-qemu said about two thirds each with one lock and nothing more
(three quarters of a game's instructions are the kernel's, nearly all
the pixels' copies, and one core at a time is in the kernel). So the
lock is what is left: the next step, the lock given back around the
copies, is what would take two games towards 50 each. Not known from
this: one game's frames a second with one core (the same kernel
cannot be asked for one on a board yet), and what `stats` itself
takes. The exception of the morning was not seen: not found, and not
explained by anything changed since but the first mouse state.

2026-10-13: the images outside OCaml's heap, and their copies without
the kernel's lock (the author: "I think having the images outside the
ML heap makes sense, a bit like we just move the Pages also outside
the heap no?"; "this is a bit similar to principia's kernel that have
a special allocator for image (imagalloc) separate from the rest";
"it's also ok to have some part of the graphics stack in C if that
helps", "(or even assembly)"). Not committed yet; the board has not
run it.
- **The arena** (`runtime.c`, `Machine.Imag`: principia's imagmem):
  48 MB of the machine's pages in one piece, taken at the boot
  (`Mmu.kalloc_run`), first fit, free extents joined. A block is
  still a string for OCaml (a header before its bytes), so Memdraw
  reads and writes it as before, and neither collector, ocaml-light's
  nor mini-ml's, looks at a pointer outside its heap. In it: the
  screen's copy, each window, each image a program asks for
  (`Memimage.alloc_out`); freed where the draw device's counts say
  (`Kdraw.free`, `lfree`: they did nothing before). What the kernel
  makes for itself (a colour, a font, the cursor) stays in the heap.
  `/dev/swap`'s "kernel draw" says it: 1575648/50331648 at the boot.
- **Three copies by the machine's C, in one call each**, where OCaml
  looped over rows: an image to another (`Imag.copy`), a fill's first
  row to the others (`Imag.rows`), an image to the framebuffer
  (`Imag.flush`). When what is read and written is the arena's and it
  is 16 KB or more, with the kernel's lock given back.
- **What such a copy must not meet**, found by the first run: a fill
  of the screen copying its first row down while the clock, on another
  core, drew the cursor into that row: a black strip down the screen.
  principia's draw device has one lock for all of it; here a copy
  says which rows of the screen it writes and the cursor's clock
  leaves them (`imag_covers`, `Kdraw.busy`), and an image freed or a
  window made, moved, restacked or deleted first waits until no copy
  is under way (`Imag.quiet`).
- **A switch**: `echo draw 0 > /dev/swap`, every copy with the lock
  held; `draw 7`, the start's.
Checked: `make check-draw` for both boards, hellodraw's screen the
same pixels under both emulators; under QEMU's four cores stats,
breakout and cameltry in three windows for 100 s, no fault, the strip
gone. What it gives is not shown: under QEMU, cameltry beside the
two others 22 to 24 frames a second with the lock held and 23 to 24
without, two cameltry 26 to 34 with and 27 to 42 without, in one run
each, and QEMU's four host threads are not the board's cores. To be
measured on the board, with the switch. `make check-quick` stops at
the boot's screen, as it must have since 2026-10-10 (the memory's
line changed after the screens were recorded on the 9th). Not
checked: a window deleted or moved while a game draws (the wait);
the arena full; the Pi 4's kernel and the one by ix's tools (the
same C, not built); mini-qemu's four cores with it.

2026-10-13: mini-qemu's cores on the host's cores: stage 4, decisions
10 to 12 (the author: "what would it take to make mini-qemu use
multiple domains when emulating a pi2? We could do like in
~/github/mini-chrome/ maybe and have an intermediate lib that is
working both for ocaml 4 (using threads) and ocaml 5 (leveraging
domains for true parallelism)"; then "let's start"). Not committed.
- **Measured first**: mini-qemu built by OCaml 5.5.1 is as fast as
  4.14's with one core (the Pi 2's session-ix: 32.1 s against 31.2,
  the same console byte for byte).
- **A core's own, its own** (`raspberry/Board.ml`, no behaviour
  changed): the running core's registers, MMU, CP15 and decode cache
  were copied into the board when its turn came (`select`); each
  function now takes its core. With them what was a module's and two
  cores would have spoiled: the table of words decoded (a core's),
  and in `machine/` the shifter's carry out (`Arm32.carry_out`) and
  the words of a block load (`Arm32_fast.loaded`), now the state's.
- **`lib_core/parallel/` (new), `Parallel`**: `available`, `spawn`, a lock,
  something to wait for; `host/domains.ml.in` under OCaml 5 (Domain,
  Mutex, Condition), `host/single.ml.in` under 4.14 (no worker, a lock
  nobody waits for), chosen by dune on `%{ocaml_version}` as
  mini-chrome's Worker_spawn. **Not mini-chrome's files, and no
  threads under 4.14**, which is not what decision 10 said: 4.14's
  Mutex is the threads library's, and a program by js_of_ocaml that
  links it stops at its start (`caml_thread_initialize is not a
  function`, tried), and the board is also a page's
  (`raspberry/web/`). Threads would have given nothing here anyway
  (the survey's "Which piece fits"). To decide: whether that is right,
  or the page should get stubs and the library be mini-chrome's.
- **`-cores-parallel`** (`Board.cores_parallel`, a switch read by
  create; off by default; under 4.14 said and the turns): each started
  core on a domain, the main domain keeping the terminal, the window
  and QMP. The devices and the time behind one lock (each device
  wrapped where it is mapped; the devices themselves reach the memory
  by a view of it that is not, Dma copying from another device's
  register); the memory behind none; `strex` behind its own, and only
  if the word is still what `ldrex` read (`Arm32.strex`, a hook);
  another core's caches emptied by asking it (a flag, and its batch
  ended). A core in WFI waits on a condition. **The time** (decision
  12, changed): the instructions of the lowest core that does not
  wait, and not the first core's, which may wait while another
  computes; every core waiting, the time to the next event is
  skipped by the main domain, as in turns. Board.ml's section "Faster:
  a core a domain" has it. `./mini-pi -P mini-9pi2` builds OCaml 5's
  mini-qemu in `_build5` and asks for it; docs/manuals/mini-qemu.md.
- **What it gives** (release builds, a kernel with SMP=1 of today,
  the host's 64 threads; the boot and the two lines typed first are
  11 to 12 s of each): one shell of `session-cores.cmds` that
  computes, 31.3 s in turns and 30.7 with a core a domain; four at
  once, 92.8 s in turns (96.2 by 4.14) and 32.3: four busy cores take
  one's time and a tenth more, where they took four times. The whole
  of `session-cores.cmds` (the dune's default build): 1217 s in
  turns, 472 with a core a domain, each line `check-cores` counts
  there (most of it the four shells that start 150 processes each:
  the kernel's lock, three cores spinning for it; QEMU was not run
  beside it today).
Checked: in turns, by 4.14 and by 5.5.1, session-ix and session-ix-b
on the Pi 2 and session-ix on the Pi 1 the same bytes as before any
of this; with a core a domain, the same two sessions the same bytes
too (the kernel of one core: the others wait); `session-cores.cmds`
seven times (four with the SMP kernel of the 12th, three with
today's), no fault, every line; rio and Tetris in a window by QMP
(`tests/tetris-win.steps`, a USB keyboard and mouse, the card), the
fourteen screens the same as in turns' without the cores' word, and
with it all but the last (a piece elsewhere: the game's time);
`machine/` compiled by mini-ml in a copy (not linked there). The 5.5.1
switch had no menhir, which `machine/`'s preprocessing needs: installed
(the Dockerfile's list).
Not checked: a window on the screen (SDL, the sound from another
domain), games in it by hand: the author's to try, `./mini-pi -P -g
mini-9pi2`; the page (`raspberry/web/` does not build today, another
session's Hostdraw); ThreadSanitizer; `make test`, tests/lite.sh.
Found on the way: `session.py` with `-status` stops typing when a
status line lands after a prompt (the text no longer ends with it):
timings are taken without `-status`. The four shells' order in a
session typed by `session.py` is not the same from run to run in
turns either (when a line is typed is the host's).
Not done: the Pi 4's cores (`Pi4.ml`, the same work); `make
check-cores` under mini-qemu (eight minutes); `Per_domain` moved
beside `Parallel` (it is the browser's, built by mini-ml).
