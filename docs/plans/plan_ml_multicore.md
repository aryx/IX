# Plan: several cores for mini-ml's programs, then for mini-dotnet's (`languages/ml/runtime/`, `lib_core/parallel/`, `languages/dotnet/`)

The author (2026-10-31), after mini-datalog's speed work (plan_datalog.md,
3290d9bc), where one rule of mini-ml's pointer analysis is 81 s of 95:
"in theory we can also use the 64 cores on this machine", then "maybe
we should start thinking about multicore support in mini-ml", "and then
in mini-dotnet itself (via its compilation by mini-ml)"; then "let's
start a plan_ml_multicore.md for mini-ml (and possibly used for
mini-dotnet compiled by mini-ml)".

[plan_multicore.md](plan_multicore.md) is the kernel's and the
emulator's side (mini-9pi under one lock on the Pi 2's four cores,
mini-qemu's guest cores on OCaml 5's domains);
[plan_tiny_multicore.md](plan_tiny_multicore.md) is t-IX's. Neither
touches what a program compiled by mini-ml may do with several cores:
today nothing. This plan is that.

**Nothing here was built or run.** What is said of the tree was read
on 2026-10-31; what is said of OCaml 5's runtime, of ARM's memory model
and of the CLR is from memory and is marked so.

## The short answer

```
   OCaml 5 (dune's build)           mini-ml (proposed)
   ------------------------------   ------------------------------------
   Domain.spawn, Mutex, Atomic      the same names, lib_core's
   a minor heap a domain,           an allocation area a domain, cut
   one major heap, collected        from the one heap; the collector
   by all domains together,         stops every domain and copies alone
   mostly concurrently              (Cheney's, as today)
   a domain = a system thread       a domain = clone(CLONE_VM) on Linux,
                                    rfork(RFMEM) on Plan 9
   the domain's state in a          the domain's state in a block found
   register (r14 on amd64)          from a register mini-ml has
```

- **Stop the world, collect alone.** A domain allocates in its own
  piece of the young generation, with no lock (the 9 instructions of
  `alloc_in_place` stay 9, or 10). When one is full, every domain is
  brought to a stop at its next allocation, and one collects, as the
  collector does now. A collector that copies with all the cores at
  once is a later stage, if the numbers ask for it.
- **The first program is mini-datalog's round**: each domain takes a
  slice of the new tuples, tests the head against `Tuples` (read only
  during the round) and keeps what is new in its own list; one merges
  at the end. 98% of the firings find the tuple there, so the merge is
  small (6.6 million tuples for 372 million firings).
- **Measure under OCaml 5 first.** `lib_core/parallel` already has
  domains under OCaml 5.5.1 (a switch on this machine): the round on
  64 cores there says what mini-ml's runtime work would buy, before
  any of it is done.
- **mini-dotnet comes last**: once mini-ml's programs have domains,
  mini-dotnet's `System.Threading` is a layer over them; the CLR's
  memory model is a question of its own (below).

## The survey (2026-10-31, read; nothing run)

### mini-ml's runtime (`languages/ml/runtime/`, 4,087 lines of C)

- **One heap, one collector, written for one thread** (`gc.c`, 881
  lines): two halves in the bss, Cheney's copying collector, and a
  young generation (`young[YOUNG]`, at most 1 M words) with a
  remembered set of old fields (`ml_store`, `ml_refs`). A large block
  of no pointers goes outside the halves (`large_alloc`).
- **The state a domain would need of its own is globals**: `ml_hp` and
  `ml_limit` (the allocation pointer and its end, read and written by
  the generated code, `Emit.alloc_in_place`, `Gen`); `ml_vsp` (the
  value stack's top, handed to C at each call of C), `ml_handler` (the
  exception handler), `local_roots` (C's roots), `ml_refs` (the
  remembered set), `ml_raise_pc`/`_sp`/`_lr` (a raise's place),
  `stack_now`. Each is one word; `exceptions.c` has the exceptions'
  constants, which are shared and never written after the start.
- **Several stacks already exist, for threads that take turns**:
  `ml_stack_switch` and `thread_new`/`thread_switch` (up to 257
  stacks: lib_core/concurrency's `Thread`, cooperative, its scheduler
  in OCaml), and the collector scans every stack. A domain is a stack
  of these that runs at the same time as another: the scanning is
  there, the stopping is not.
- **A way to make the generated code enter the runtime already
  exists**: `ml_store` sets `ml_limit = ml_hp` when the remembered set
  is nearly full, so the next allocation calls `ml_alloc`. That is
  the safe point a stop of the world needs: set every other domain's
  limit so, and each comes in at its next allocation.
- **A loop that allocates nothing never comes in.** OCaml 5.2 added
  polls at loops' back edges and functions' entries for that (from
  memory). mini-ml has none; a loop over an int array (Tuples's
  `find`) does not allocate.
- **Registers**: the value stack's top is in R10 on arm, R26 on arm64
  (`Gen.arm`, `Gen.arm64`); arm has 8 registers to allocate, arm64 15.
  A domain's state needs a register, or a way to find it from one
  already there (decision 3).
- **No atomic instruction in ix's toolchain for arm**: plan_multicore.md
  found that `assembler/` has no `ldrex`/`strex` (grep, again today:
  none); the linker's `Arm64.ml` knows `DMB`. arm64's `LDAXR`/`STLXR`
  were not looked for in the linker beyond that grep.
- **The runtime makes processes, not threads**: `sys.c` has `fork`;
  nothing calls `clone`.

### What ix already has for several cores

- **`lib_core/parallel/Parallel.mli`**: `available`, `spawn`, `lock`,
  `cond`; under 4.14 a single thread (`available` false, the work in
  turns), under OCaml 5 domains, by two dune rules on
  `%{ocaml_version}`. Not built by mini-ml today. Written for
  mini-qemu's Pi 2 (plan_multicore.md, decision 10).
- **`lib_core/concurrency/`**: OCaml's `Thread`, `Mutex`, `Condition`,
  `Event`, `Atomic` for mini-ml, cooperative. `Atomic` is OCaml's
  file; with one thread at a time it needs no instruction.
- **mini-netscape's `Worker_spawn`** (a thread under 4.14, a domain
  under 5, a large cooperative thread by mini-ml) and
  **`Per_domain`** (a global made one a domain).

### mini-dotnet (`languages/dotnet/`)

- An OCaml program built by dune and by mini-ml: interpreter, JIT,
  runtime (`runtime/Value`, `Library`, `Types`). Nothing of
  `System.Threading` is there (grep for `Thread`, `Monitor`,
  `Interlocked`: none).

## Decisions (proposed, for the author)

1. **OCaml 5's names, in lib_core, for mini-ml's programs**: `Domain`
   (`spawn`, `join`, `self`), `Mutex`, `Condition`, `Atomic`, as
   lib_core keeps OCaml's API elsewhere (the stdlib's). `Parallel`
   stays what a program uses to be built by all three compilers: its
   third file, mini-ml's, says `available = true` once the runtime has
   domains, and `false` until then (stage 1).
2. **Stop the world, one collector** (above). The alternative, OCaml
   5's minor heap a domain with a shared major heap collected
   concurrently, is the work of a team over eight years (cs-history
   below); a stop is a few hundred lines and keeps Cheney's collector
   as it is.
3. **A domain's state is a block found from a register.** Two ways, to
   measure before choosing:
   - (a) a register of its own (OCaml 5's way): arm64 can spare one of
     15; arm's 8 would be 7.
   - (b) no new register: each domain's value stack is aligned to its
     size (a power of two), and its state is at the stack's base, so
     `vsp AND NOT (size - 1)` finds it: one instruction more in
     `alloc_in_place`, none elsewhere.
   (b) first, for arm; (a) if a Pi's numbers say the extra instruction
   costs.
4. **A domain is the system's thread of the same memory**: Linux's
   `clone` (CLONE_VM, CLONE_FS, CLONE_FILES, CLONE_SIGHAND,
   CLONE_THREAD) with a stack the runtime gives; Plan 9's `rfork`
   (RFPROC, RFMEM). mini-9pi's kernel must then give RFMEM (to check),
   and computes on the Pi 2's four cores only after plan_multicore.md's
   big lock.
5. **Atomics are instructions of the runtime's assembly, not of
   mini-cc**: the assembler and linker learn arm64's `LDAXR`, `STLXR`,
   `DMB` and arm's `LDREX`, `STREX`, `DMB` (ARMv7; the Pi 1's ARMv6 has
   `LDREX`/`STREX` and its barrier is a CP15 write, from memory); a
   compare-and-swap and a fetch-and-add in the start object, as
   `ml_swtch` is; `Atomic`'s functions call them. mini-ml does not
   compile `Atomic` itself (its `get` and `set` are a load and a store
   with a barrier: later, if they are seen in a profile).
6. **OCaml 5's memory model, as far as mini-ml can give it**: a
   program without data races behaves as if one domain ran at a time
   (Dolan, Sivaramakrishnan, Madhavapeddy, PLDI 2018). A block is
   filled before it is published: a barrier (arm's `DMB ISHST`) between
   a block's initialization and the store that makes it reachable from
   a shared field. Where mini-ml puts it, at every mutable store as
   OCaml 5 does on arm64 (from memory: a `DMB ISHLD` before), or only
   at `Atomic.set` and the lock's give, is measured at stage 4.
7. **A loop that never allocates delays a stop; not polled at first.**
   The cost is said in `Parallel.mli` and measured on Tuples's loops;
   polls at back edges (OCaml 5.2's) are a stage of their own if a stop
   is seen to wait.

## The stages (each checked before the next)

0. **The ceiling, under OCaml 5.5.1.** mini-datalog's semi-naive round
   on `Parallel` (dune's build, the 5.5.1 switch; 4.14's build keeps
   the loop of today): the new tuples cut in slices, a domain a slice,
   each its candidates in a list, one merge. mini-analyze on mini-ml
   and the assembler (95 s today, 81 of them one rule) on 1, 2, 4,
   8, 16, 32, 64 domains; the same tuples, compared whole. `Tuples`
   and the indexes are only read during a round, so nothing is locked.
   If 64 cores give less than 8 times, the rest of this plan waits:
   the bound would be memory's, not the runtime's.
1. **`Parallel` built by mini-ml, `available` false.** A third host
   file, mini-ml's mkfile takes it; mini-datalog's round written once
   for all three compilers. Nothing else changes.
2. **A domain's state, one domain.** The globals of the survey into a
   block (decision 3), the generated code and the runtime reading them
   there; `make test`, mini-ml's benchmarks and ix built by ix, by
   both ways of decision 3: what each costs, on arm64 and under
   mini-5i on arm.
3. **Atomics.** The instructions in the assembler and linker (tests
   beside theirs, against goken's where it has them); a CAS and a
   fetch-and-add in the start object; `Atomic` over them, tested by a
   program that counts with several processes sharing a page first
   (no domains yet).
4. **Domains.** `Domain.spawn` and `join` by `clone`; a domain's piece
   of the young generation; the stop (each other domain's `ml_limit`
   set, a counter of those stopped, the collector run by the last to
   come in, the others waiting on a futex, then their limits back);
   the remembered set a domain; `Mutex` and `Condition` by futexes.
   Tests: a counter, a queue between two domains, a collection in the
   middle of both, a domain that raises. Then stage 0's round under
   mini-ml's build: its numbers beside OCaml 5's.
5. **Plan 9.** `rfork(RFMEM)`, Plan 9's `semacquire` for the waits;
   on mini-9pi on one core first (domains taking turns by the
   scheduler), on the Pi 2's four after plan_multicore.md.
6. **mini-dotnet's threads.** `System.Threading.Thread`, `Monitor`
   (`lock` in C#), `Interlocked`, `Volatile`, and
   `System.Threading.Tasks.Parallel.For` over the domains; the
   interpreter's and the JIT's state a thread (what is a global today
   is looked for then). A C# program that sums on 64 cores against
   Microsoft's .NET (plan_dotnet_languages.md's measurements).
7. **(If stage 4's numbers ask) the collector on several cores**:
   each domain copies its own roots, work stolen from the others'
   queues (Flood, Detlefs, Shavit, Zhang 2001), each copying into its
   own piece of the half.

## What several cores will not give

- **The analysis's own waste**: rule 81 is 372 million firings for 6.6
  million tuples. Collapsing cycles of assignments (Hardekopf and Lin,
  plan_datalog.md) removes firings for every core count; it may be
  worth more than stage 4, and it is the analysis's change, not the
  runtime's.
- **Memory**: the run is 2.0 GB under dune's build; mini-ml's halves
  are at most 512 MB on 64 bits (`MAXHEAP`), and a copying collector
  needs twice what is alive. mini-analyze over mini-ml by mini-ml's
  build is a question of the heap before it is one of cores.
- **Repeatable runs**: a round's merge in a fixed order (the domains'
  lists taken in their order) keeps the tuples' order the same each
  time; what a domain finds in which order does not leak out.

## Open questions

- Decision 3's (a) or (b): measured at stage 2.
- Does mini-9pi give RFMEM, and do its processes that share memory
  work today (plan_multicore.md, "to check: what ix's libc does for
  its locks")?
- The CLR's memory model (ECMA-335, I.12.6: stores may be reordered
  except volatile ones; .NET's own model since 2.0 is stronger, every
  store a release on arm64, from memory): which one mini-dotnet gives,
  and whether OCaml 5's is enough for it (a C# program with a data
  race may expect more).
- tiny-ml: not in this plan; plan_tiny_multicore.md keeps t-IX's
  programs on one core each and uses several by processes.

cs-history:
Multiprocessor collectors: Halstead's Multilisp (1985) gave each
processor its own heap; Appel, Ellis and Li (1988) stopped the world
with the virtual memory's help; Doligez and Leroy (POPL 1993) wrote a
concurrent collector for Caml with a heap per thread for the young,
which OCaml did not adopt, and OCaml kept one runtime lock until 5.0
(December 2022: Sivaramakrishnan, Dolan and others, "Retrofitting
Parallelism onto OCaml", ICFP 2020). Java's HotSpot stops the world
with safepoints polled by the compiled code, the scheme of decision 7.

## References

- KC Sivaramakrishnan, Stephen Dolan, Leo White, Sadiq Jaffer, Tom
  Kelly, Anmol Sahoo, Sudha Parimala, Atul Dhiman, Anil Madhavapeddy,
  "Retrofitting Parallelism onto OCaml", ICFP 2020.
- Stephen Dolan, KC Sivaramakrishnan, Anil Madhavapeddy, "Bounding
  Data Races in Space and Time", PLDI 2018 (OCaml 5's memory model).
- Damien Doligez, Xavier Leroy, "A concurrent, generational garbage
  collector for a multithreaded implementation of ML", POPL 1993.
- Christine Flood, David Detlefs, Nir Shavit, Xiaolan Zhang, "Parallel
  Garbage Collection for Shared Memory Multiprocessors", JVM 2001.
- ECMA-335, Common Language Infrastructure, partition I, 12.6 (the
  memory model).

## Status

2026-10-31: written; nothing built. Stage 0 is the next step, and the
one that decides whether the others are worth it.
