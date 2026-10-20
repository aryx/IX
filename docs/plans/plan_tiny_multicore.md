# Plan: several cores in t-IX: tiny-machine's harts, tiny-kernel on them, tiny-build using them

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

**Nothing here was built or run.** What is said of the tree was read
on 2026-10-20.

## The short answer

```
   tiny-machine -cores 4                      tiny-kernel
   ┌────────┬────────┬────────┬────────┐      hart 0: the kernel (ML, one heap,
   │ hart 0 │ hart 1 │ hart 2 │ hart 3 │      one collector) and its scheduler;
   │ regs   │ regs   │ regs   │ regs   │      a process on it too, between traps
   │ pc,csr │ pc,csr │ pc,csr │ pc,csr │      harts 1-3: entry.tm's loop only: run
   └───┬────┴───┬────┴───┬────┴───┬────┘      the process given, until its trap,
       └────────┴── memory ┴────────┘          hand the trap to hart 0
         devices, one clock, IPIs              tiny-build -j 4: four compilers
```

- **tiny-machine: harts.** `-cores n` (1 by default, as today): each
  hart its registers, pc and registers of control (`hartid` is one
  already, read only, always 0), memory and devices shared. In turns,
  in one thread, a slice each: repeatable, what the tests run, what the
  web page runs. Under OCaml 5 only, and asked for
  (`-cores-parallel`), a hart a domain: plan_multicore.md's decisions
  10 and 11, mini-chrome's `Worker_spawn`.
- **tiny-kernel: master and slaves.** The kernel is an ML program: one
  heap, one collector (TinyMLRuntime/core.c), written for one thread.
  So it stays on hart 0, whole; the other harts run only processes.
  A trap on hart k (a system call, a fault, its timer) stops it and
  goes to hart 0 as a message; hart 0 handles it as today and gives
  hart k a process again. No lock in the kernel, no change to its
  data structures: the scheduler's "run this process until its next
  trap" (`k_run`, a hypervisor's KVM_RUN) becomes "start it on a free
  hart" and "the next trap of any hart".
- **tiny-build: nothing new.** `-j N` already runs N recipes, waiting
  with `wait_any`; its open bug (bugs/ix.md: `-j 3` hangs when the 8
  process slots run out under pipelines) gets fixed first.

## Why master and slaves, not one big lock

mini-9pi's kernel gets a lock taken at every trap (plan_multicore.md):
any core runs the kernel, one at a time. That works there because
each process has its own kernel stack, which OCaml's runtime is told
about at each switch (`k_swtch`). tiny-kernel has no kernel stack per
process (TinyKernel.mli: "no kernel stack per process") and its
collector's roots are one value stack (runtime.c's VSTACK): two harts
in the kernel, even in turns under a lock, would need a value stack
each and the collector to scan both. Keeping the kernel on hart 0
needs neither.

It is also the older way, and the simpler to read: the first
multiprocessor Unix kernels (Purdue's dual VAX, Goble and Marsh,
1982; from memory) ran the kernel on one processor and only user code
on the other. Its limit is the same as the big lock's, and plainer:
system calls are not parallel. A compiler makes few (a read of its
files, a write of its output); its time is in user mode, which is
what scales.

```
   hart k (k > 0)                         hart 0
   running process P ── trap ──>  writes P's frame, its cause in its
                                  mailbox; an IPI to hart 0; waits (wfi)
                                          kernel: the next trap of any
                                          hart (its own or a mailbox's),
                                          handled as today (TinyKernel.ml),
                                          the scheduler picks Q for hart k:
   <── IPI ── frame of Q in k's mailbox, its window (base, bound)
   runs Q until its trap
```

A mailbox has one writer at a time (hart k until it posts, hart 0
until it answers), so no atomic instruction is needed: the ISA stays
as it is.

## The survey (2026-10-20, read)

- **TinyMachine/TinyMachineDevices.ml**: one `machine` (a CPU, its
  CSRs, the devices); `ticks` runs a hart's instructions between two
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
  harts are repeatable turns: a model to read and test, not faster.

## Decisions (proposed, for the author)

1. **`-cores n`, turns by default.** A slice of instructions per hart
   in turn (a slice as `ticks`'s, its length a constant), so a run is
   the same each time; one hart is today's machine, exactly (the
   recorded screens and sums unchanged).
2. **Domains under OCaml 5, asked for**: `-cores-parallel`, a hart a
   domain, the devices and the IPIs under one mutex, memory without
   lock (a race between harts is the program's, as on hardware); each
   hart counts its own time, the devices' clock is hart 0's.
3. **The kernel on hart 0, the others slaves** (above): their loop in
   entry.tm (a few lines: wait, load the frame, eret, save it, post,
   IPI); `k_run` split in `k_start hart frame` and `k_next`; the
   scheduler gives a ready process to a free hart. A process is on one
   hart at a time; which one it is on is not its business.
4. **An interrupt between harts**: a device word, hart k's IPI bit set
   by another hart's store; nothing else new in the machine.
5. **Memory**: the machine's 128 MB to 256 MB (the kernel's map moves
   nothing below 32 MB: the partitions get the rest), so four `ml`
   fit.
6. **tiny-build**: its `-j` bug fixed; `-j` given the number of
   harts (a call, or the kernel's line at boot, read by the user).

## The stages (each checked before the next)

1. tiny-machine's harts in turns, a test of its own (two harts running
   two loops, each its counter); `-cores 1` is today's (make check's
   sums unchanged).
2. tiny-kernel on them: slaves running processes, every trap on hart
   0; make check unchanged with one core; with four, two `spin`s at
   once in twice less time (in instructions of hart 0's clock).
3. tiny-build's `-j` fixed; the self-build (make self) with `-j 4`
   on four harts in turns: the same image, byte for byte, the build's
   time in instructions per hart.
4. Domains under OCaml 5 (`-cores-parallel`): the same image again;
   the host's time measured against one core.

## What it costs, roughly

TinyMachine: the harts, their slices, the IPI, about 150 lines; the
domains, a file chosen by dune for OCaml 5 and its twin for 4.14, 40.
entry.tm, the slaves' loop: 30. TinyKernel.ml, start and next, the
free harts: about 100. tiny-build's fix: tens. About 350 lines of the
4,459 left in t-IX's budget (README).

## What several cores will not give

- System calls in parallel: the kernel is one hart's.
- A faster build under OCaml 4.14 or in the web page: the harts take
  turns in one thread there.
- Anything for a program that does not fork: one compiler of one big
  unit (TinyML.ml, 168 s) is as slow as before; only the build's
  units in parallel gain.

## Open questions

- A hart's timer: one for all (hart 0's, which preempts), or each its
  own (a slave preempted without asking hart 0)?
- Should the slaves' loop be in ML after all (a second, tiny runtime
  without collector)? Assembly keeps the kernel's one runtime.
- The partitions' first-fit with several running at once: does it
  fragment the 256 MB under the build's mix (32 MB compilers, 1 MB
  shells)?

## Status

2026-10-20: plan written, from reading. Nothing built, nothing run.
