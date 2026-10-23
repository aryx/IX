# Plan: several cores in t-IX: tiny-machine's cores, tiny-kernel on them, tiny-build using them

The author (2026-10-20), while t-IX was building itself on tiny-kernel
(plan_tiny_self_hosting.md, step 8), a build of most of an hour on one
core: "I wonder if we could do like for mini-qemu and leverage ocaml
domains when we can and so propose to have multiple cores in tiny-cpu
that tiny-build could then leverage and so we could speedup things
there too. Tiny-machine is a simplified machine, and having 1 core
definitely simplifies things, but nowaday and I think for a long time
we will have machines with multiple cores, so maybe it is more
didactic to also have a tiny machine with multiple cores, and not wait
for m-ix to see and leverage those multiple cores"; then "maybe we
could have a plan_tiny_multicore.md".

m-IX's side is [plan_multicore.md](plan_multicore.md) (mini-9pi on the
Pi 2's four cores, mini-qemu's cores on the host's domains). This plan
takes its two rules for the emulator (turns by default, domains under
OCaml 5 behind a switch) and makes the other choice for the kernel:
mini-9pi gets one lock around its whole kernel; tiny-kernel keeps its
kernel on one core.

Stages 1 to 4 built on 2026-10-23 (the author: "let's start the tiny
multicore plan and leverage domains on ocaml 5 so can build t-ix under
t-ix using multiple cores"): Status, at the end, says what was found
and decided on the way.

## The short answer

```
   tiny-machine -cores 4                      tiny-kernel
   ┌────────┬────────┬────────┬────────┐      core 0: the kernel (ML, one heap,
   │ core 0 │ core 1 │ core 2 │ core 3 │      one collector) and its scheduler;
   │ regs   │ regs   │ regs   │ regs   │      a process on it too, between traps
   │ pc,csr │ pc,csr │ pc,csr │ pc,csr │      cores 1-3: entry.tm's loop only: run
   └───┬────┴───┬────┴───┬────┴───┬────┘      the process given, until its trap,
       └────────┴── memory ┴────────┘          hand the trap to core 0
         devices, one clock, IPIs              tiny-build -j 4: four compilers
```

- **tiny-machine: cores.** `-cores n` (1 by default, as today): each
  core its registers, pc and registers of control (`core` is one
  already, read only, always 0), memory and devices shared. In turns,
  in one thread, a slice each: repeatable, what the tests run, what the
  web page runs. Under OCaml 5 only, and asked for
  (`-cores-parallel`), each core on a domain: plan_multicore.md's decisions
  10 and 11, mini-chrome's `Worker_spawn`.
- **tiny-kernel: master and slaves.** The kernel is an ML program: one
  heap, one collector (TinyMLRuntime/core.c), written for one thread.
  So it stays on core 0, whole; the other cores run only processes.
  A trap on core k (a system call, a fault, its timer) stops it and
  goes to core 0 as a message; core 0 handles it as today and gives
  core k a process again. No lock in the kernel, no change to its
  data structures: the scheduler's "run this process until its next
  trap" (`k_run`, a hypervisor's KVM_RUN) becomes "start it on a free
  core" and "the next trap of any core".
- **tiny-build: nothing new.** `-j N` already runs N recipes, waiting
  with `wait_any`; its open bug (bugs/ix.md: `-j 3` hangs when the 8
  process slots run out under pipelines) gets fixed first.

## Why master and slaves, not one big lock

mini-9pi's kernel gets a lock taken at every trap (plan_multicore.md):
any core runs the kernel, one at a time. That works there because
each process has its own kernel stack, which OCaml's runtime is told
about at each switch (`k_swtch`). tiny-kernel has no kernel stack per
process (TinyKernel.mli: "no kernel stack per process") and its
collector's roots are one value stack (runtime.c's VSTACK): two cores
in the kernel, even in turns under a lock, would need a value stack
each and the collector to scan both. Keeping the kernel on core 0
needs neither.

It is also the older way, and the simpler to read: the first
multiprocessor Unix kernels (Purdue's dual VAX, Goble and Marsh,
1982; from memory) ran the kernel on one processor and only user code
on the other. Its limit is the same as the big lock's, and plainer:
system calls are not parallel. A compiler makes few (a read of its
files, a write of its output); its time is in user mode, which is
what scales.

```
   core k (k > 0)                         core 0
   running process P ── trap ──>  writes P's frame, its cause in its
                                  mailbox; an IPI to core 0; waits (wfi)
                                          kernel: the next trap of any
                                          core (its own or a mailbox's),
                                          handled as today (TinyKernel.ml),
                                          the scheduler picks Q for core k:
   <── IPI ── frame of Q in k's mailbox, its window (base, bound)
   runs Q until its trap
```

A mailbox has one writer at a time (core k until it posts, core 0
until it answers), so no atomic instruction is needed: the ISA stays
as it is.

## The survey (2026-10-20, read)

- **TinyMachine/TinyMachineDevices.ml**: one `machine` (a CPU, its
  CSRs, the devices); `ticks` runs a core's instructions between two
  looks at the devices (the batching that makes it 22 million
  instructions a second on the author's M3). The clock is the
  instructions run (`time`), which the recorded sessions depend on.
- **TinyKernel/entry.tm**: `k_run` saves the kernel's sp and link,
  loads the process's frame and erets; its next trap returns from
  `k_run`. `k_idle` waits for an interrupt with nothing to run.
- **TinyKernel.ml**: round robin over 8 slots (`nslots`), a frame
  each (68 bytes at 0xb40000); the partitions from 32 MB, 95 MB in
  all. The scheduler's loop calls `k_run` on the next ready process.
- **Memory is the first limit**: `ml` asks for 32 MB (TinyML.ml's
  compile), so two compilers at once already take two thirds of the
  partitions. Several cores for the build want the machine's memory
  larger (128 MB today: `TinyMachineDevices.memsize`), or `ml`
  smaller.
- **OCaml 5**: the tree is built by 4.14 each day; 5 is a third
  compiler for domains only (plan_multicore.md, decision 10), so the
  host's speed gain needs the 5.5.1 switch, and under 4.14 several
  cores are repeatable turns: a model to read and test, not faster.

## Decisions (proposed, for the author)

1. **`-cores n`, turns by default.** A slice of instructions per core
   in turn (a slice as `ticks`'s, its length a constant), so a run is
   the same each time; one core is today's machine, exactly (the
   recorded screens and sums unchanged).
2. **Domains under OCaml 5, asked for**: `-cores-parallel`, a core a
   domain, the devices and the IPIs under one mutex, memory without
   lock (a race between cores is the program's, as on hardware); each
   core counts its own time, the devices' clock is core 0's.
3. **The kernel on core 0, the others slaves** (above): their loop in
   entry.tm (a few lines: wait, load the frame, eret, save it, post,
   IPI); `k_run` split in `k_start core frame` and `k_next`; the
   scheduler gives a ready process to a free core. A process is on one
   core at a time; which one it is on is not its business.
4. **An interrupt between cores**: a device word, core k's IPI bit set
   by another core's store; nothing else new in the machine.
5. **Memory**: the machine's 128 MB to 256 MB (the kernel's map moves
   nothing below 32 MB: the partitions get the rest), so four `ml`
   fit.
6. **tiny-build**: its `-j` bug fixed; `-j` given the number of
   cores (a call, or the kernel's line at boot, read by the user).

## The stages (each checked before the next)

1. tiny-machine's cores in turns, a test of its own (two cores running
   two loops, each its counter); `-cores 1` is today's (make check's
   sums unchanged).
2. tiny-kernel on them: slaves running processes, every trap on core
   0; make check unchanged with one core; with four, two `spin`s at
   once in twice less time (in instructions of core 0's clock).
3. tiny-build's `-j` fixed; the self-build (make self) with `-j 4`
   on four cores in turns: the same image, byte for byte, the build's
   time in instructions per core.
4. Domains under OCaml 5 (`-cores-parallel`): the same image again;
   the host's time measured against one core.

## What it costs, roughly

TinyMachine: the cores, their slices, the IPI, about 150 lines; the
domains, a file chosen by dune for OCaml 5 and its twin for 4.14, 40.
entry.tm, the slaves' loop: 30. TinyKernel.ml, start and next, the
free cores: about 100. tiny-build's fix: tens. About 350 lines of the
4,459 left in t-IX's budget (README).

## What several cores will not give

- System calls in parallel: the kernel is one core's.
- A faster build under OCaml 4.14 or in the web page: the cores take
  turns in one thread there.
- Anything for a program that does not fork: one compiler of one big
  unit (TinyML.ml, 168 s) is as slow as before; only the build's
  units in parallel gain.

## Open questions

- A core's timer: one for all (core 0's, which preempts), or each its
  own (a slave preempted without asking core 0)?
- Should the slaves' loop be in ML after all (a second, tiny runtime
  without collector)? Assembly keeps the kernel's one runtime.
- The partitions' first-fit with several running at once: does it
  fragment the 256 MB under the build's mix (32 MB compilers, 1 MB
  shells)?

## Status

2026-10-20: plan written, from reading. Nothing built, nothing run.

2026-10-23: stages 1 to 4 built, the decisions taken as proposed but
where said.

- **tiny-machine's cores** (TinyMachineDevices, TinyMachine.ml):
  `-cores n` (1 to 16) and `-cores-parallel`. A core is a `machine`
  record of its own made by `core mc k` (`{ mc with ... }`: its CPU
  registers and pc, its registers of control, the memory's bytes and
  the devices' records shared), so nothing of the one-core code path
  changed. Core 0's loop in TinyMachine.ml runs the others' slices
  after its own, the same length; with domains each other core loops
  on its domain (`Parallel.spawn`, lib_core/parallel's, as mini-qemu),
  a failure or the halt said to all by an Atomic. **Every core starts
  at 0** (RISC-V's way, not the plan's "slaves started by core 0"):
  entry.tm parks the others by their number, two instructions. **The devices
  are wired to core 0**: another core that reaches one faults (so no
  lock around them, and the host's thread, core 0's, is the only one
  that touches them). New: `cores`, a register of control (15, read
  only), the count; **-64(r0), the interrupt between cores**, source
  32: a store of k raises core k's, a load gives the senders, a bit
  each, and clears them (an `Atomic.exchange`, which orders the
  mailbox's words between domains: the receiver reads only what a
  sender it was told of wrote before telling). Memory **256 MB**
  (`1 lsl 28`). amoswap is not atomic between domains (said in the
  code; tiny-kernel does not use it). Built by mini-ml too: tiny/mkfile
  compiles lib_core/parallel's 4.14 file as Parallel.
  Check: `TinyMachine_tests/cores.tm`, three cores (the count, the
  interrupt and its senders, the device's fault), in turns and on
  domains (5.5.1); TinyMachine_test.sh whole (paging.tm's page of the
  devices moved to 256 MB's top).
- **tiny-kernel: master and slaves** as planned. entry.tm: `slave`,
  `slave_take`, `slave_post` (about 50 lines; `k_enter` shared with
  k_run's register load, trapvec shared, the core's number tested after the save).
  TinyKernel.ml: a process's `core` (-1 none, 0 core 0's, k) and
  `doomed`; `give`, `dispatch`, `back`, `runnable ok`; the cores'
  interrupt read in `interrupts`. **A kill of a process on another core
  waits for its next trap**, which the interrupt makes now (its
  partition is not another's before); **a trace(pid) of one waits for
  it to come back**, and a traced process stays on core 0. 16 slots,
  partitions to 0xfff0000 (223 MB).
- **tiny-ml: a record of more than 11 fields** (the process's record,
  12, was "an expression too deep"): built in a block allocated first,
  kept in a slot, each field stored as computed (`fields_block`);
  `languages/ml/tests/tiny/records_wide.ml`, OCaml's output recorded.
- **tiny-build's -j hang** (bugs/ix.md, fixed): a fork that failed
  was kept as a recipe running, pid -1, waited for ever.
- **make check (one core)**: the screens the same; `tetris.wav`'s sum
  and three of check.expected's interleavings recorded again (the
  kernel's few instructions more per trap: the time moved); the
  pipeline that tested the slots running out has 13 cats (16 slots);
  the background loop that debug attaches to lasts four seconds, not
  three (debug takes three to start: on the edge, 2.9 s before, 3.1
  now). `make self-cores` added.
- **"core", not "hart"** (the author: "tiny-machine spirit is to be a
  simple (but still modern, hence the multi cores) machine, so maybe
  we should remove this hart terminology and use core", then "IX's
  goal is teaching and simplifying things when possible"). RISC-V's
  hart, a hardware thread, differs from a core only where a core runs
  several (SMT), which tiny-machine will not model: the registers of
  control `hartid` and `harts` are `core` and `cores`, tiny-kernel's
  `k_cores` and a process's `core`, the test `cores.tm`; the plan's
  text renamed too.
- **Each core's instructions, at the halt** (the author: "yes add the
  per-core busy/idle counts. I also like the -j 6 and measuring plan
  to possibly reorganize the Buildfile and maybe even code
  sometimes"): with several cores, a line each on the standard error,
  its instructions and how many were a program's, the kernel's, idle
  (the kernel's jump to itself). Counted a batch of `ticks` at a time,
  by its first instruction: exact, as a trap, an eret and the write of
  status before the loop of idle each end a batch. cores.expected has
  the three lines (in turns the same at each run).
- **The first measures, and what they found** (2026-10-23):
  - `build -j 4` on four domains: 115 minutes, then `bin/ml`'s link
    failed (`trap 2`, an illegal instruction): **tiny-kernel's ld out
    of its 32 MB**, which today's 1.7 KB more of bin/ml crossed; the
    same with the kernel, the machine and the ld of before that day,
    so not the cores'. MEM_ld 48 (bin/ml then the host's byte for
    byte); bugs/ix.md has the row (a limit reached without a word).
    The one-core build would have failed there too; stopped.
  - `build -t -j 6` on four domains: failed after 15 minutes, `as: not
    found`: six recipes at once (two ml, two as, ld, cc) took 176 MB,
    the seventh found no partition and exec failed. Now **an exec or a
    fork that finds no slot or no partition waits** for a process to
    end (`with_room`), as long as another can run; retried when one
    has ended (`since`, a wait's), not at each round: retried at each
    round, its walk of the slots made a round longer than a tick, every
    process entered with its time already up, and none ran an
    instruction (found with the -j 8 test of bugs/ix.md's -j row,
    which now builds its eight targets).
  - The counts of those 15 minutes, mostly the library's one recipe:
    core 0 programs 0%, kernel 56%, idle 43%; core 1 41% programs;
    cores 2 and 3 about 8%: one program at a time then, and core 0's
    kernel as busy as all the programs. Part of it: **each recipe a
    fork of build, its 16 MB copied** (k_copy, 18 million
    instructions, over 2 s of the machine's time, on core 0). To
    measure on the whole build, then a spawn (fork and exec in one) or
    a smaller build.
  - tiny-build -t with -j: the recipes' sum and how many ran at once
    (it said a negative "not a recipe's").
- **A first four-core run lost** (`-j 6`, four domains, 109 minutes):
  bin/ml's link died as before, the image's ld still of 32 MB (the
  Makefile does not relink a program when its `MEM_` changes:
  bugs/ix.md). Its counts still say where the time went: core 0 2%
  programs, 73% kernel, 24% idle; cores 1-3 38%, 22%, 19% programs,
  the rest idle. The kernel on core 0 is the bottleneck: fork's copy
  of build's 16 MB at each recipe, among others; hence spawn
  (plan_tiny_memory.md, stage 1).
- **The first whole self-build on four cores** (fork, `build -t -j
  6`, four domains, ld of 48 MB; 2026-10-23, 11:56 to 14:11): 135
  minutes, the image built the host's byte for byte. The first build's
  recipes took 33,000 s of machine time in 7,900: 4.1 at once. Where:
  the links (bin/*, 31 of them) 10,250 s, the assemblies (ml/*.o, 43)
  8,300 s, the compiles (ml/*.tm, 43) 4,660 s. Each core's counts:
  core 0 71% kernel, 28% idle; cores 1-3 36%, 15%, 14% programs, the
  rest idle.
- **Measuring, running**: the self-build with `build -t` on one core
  (fork), and four domains with spawn.
