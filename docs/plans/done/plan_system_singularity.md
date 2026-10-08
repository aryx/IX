# Plan: mini-singularity, Singularity's processes without hardware, in OCaml on the Pi (`kernels/singularity/`)

The author (2026-10-05), after [`plan_system_oberon.md`](plan_system_oberon.md):
"ok now what about a similar question, but for the Singularity system
this time?"; then: "let's write a plan_system_singularity.md". What he
said of Oberon holds here: "we don't have to match exactly ... The
idea is more to give this historical [system] a place here, adapted to
OCaml, and reusing some of the existing code in ix"; "we definitely
want though to match the look and feel of the original, and general
approach"; and the code "only in" its directory, the rest by symbolic
links, "so one can just look at one directory and know everything is
in there".

mini-singularity is Microsoft Research's Singularity (2003-2010) as
its papers tell it: **an operating system whose processes are
isolated by the language, not by the hardware**, written in OCaml,
running on the bare Pi 1 and Pi 4 beside mini-xv6 and mini-9pi, which
isolate theirs by the MMU. The same boards, the same compiler: the
two ways side by side, and measured.

Singularity has no screen to imitate (a shell on a console) and no
book. What is kept, and what is free:

- **Kept: the approach**, which here is the system's three ideas.
  *Software-isolated processes*: every process in the kernel's
  address space and at its privilege, no page table switched, each
  with its own heap, collector and run-time system, sealed (no code
  added, no memory shared). *Channels with contracts*: the only way
  two processes talk; a contract is a state machine of messages; data
  moves by a block's ownership passing, not by a copy. *Manifests*: a
  program says what it needs (channels, a device's memory, an
  interrupt) and is given that and no more; drivers, file systems and
  the shell are processes like the others.
- **Kept: the feel**: the shell's session; a driver that fails is a
  process that ends, the system goes on.
- **Free: what is under**, and one thing that is not under: Sing#
  checks contracts and ownership **when a program is compiled**; OCaml
  cannot, and here they are checked **when it runs** (decision 4).
  That is the plan's main loss and is not to be hidden.

**Status: done** (2026-10-07; the author: "let's move the plan to
done/ marking the remaining things to do clearly"), and this file kept
as its record: stages 0 to 5 and the first half of 6, each with what
it found, in "Status" at the end. What the system is now, how it is
run and checked: [`kernels/singularity/README.md`](../../../kernels/singularity/README.md);
how it is used, by its own files:
[`tutorial.md`](../../../kernels/singularity/tutorial.md). In a
sentence: it boots to a shell on both boards under the emulators;
OCaml programs run as processes in the kernel's address space, kept
apart by a look at their source (`mini-singml -safe`), talk by
channels whose contract the kernel checks at each message, pass
blocks of an exchange heap without a copy, and a driver is a process
given its registers by its manifest.

The decisions below were the plan's proposals. Confirmed by the author
(2026-10-07, "I confirm the 3 things"): 2 and 3, and the licence's
reading (read, never copied). **Taken as proposed and never confirmed
by him**, though the code rests on them: 4 (contracts and ownership
checked when the program runs), 6 (cooperative first), and 1, 5, 7, 8
in the forms the Status sections say (1 in mini-singml and not in
mini-ml; 5 a module `Given` and not a record; 7 the serial line only;
8 as proposed).

## What is left (2026-10-07)

For a plan of their own if they are wanted. Nothing here is started.

**Of this plan's stages:**

- **Stage 6's rest.** The name service: a name bound to an endpoint,
  so that a process asks for a service; today a process has only the
  endpoints its parent gave it, and the system's wiring is `init`'s
  code, not a table. A driver that ends started again, its clients
  seeing the channel closed. The keyboard and the screen as drivers
  (the serial line only today). Arguments for a program run from the
  shell.
- **Stage 7, a file service**: a RAM disk and a file system as two
  processes. Not begun; whether mini-dossrv's FAT parts from `lib_networking/9p`
  was never looked at.
- **Stage 8, the table**: the four costs for mini-xv6 and mini-9pi by
  their nearest equals, on the same boards. mini-singularity's own are
  measured (`numbers.sh`); the others' are not, and **the comparison
  the system is here to show does not exist yet**.
- **Stage 9**: preemption; relocations in mini-ld and a loader
  (several processes of one program, programs from a disk); the MMU
  turned on for a process, and its cost; the SD card.

**Limits of what was built**, each said where it was met:

- one process of a program at a time; one thread a process;
- cooperative: a process that never calls the kernel holds the
  processor, and starves a driver waiting for its interrupt;
- a message is a tag, one integer, and one block or endpoint at most;
  a select takes three endpoints at most; a process has 16 handles;
- one interrupt is known to the kernel (the serial line's);
- what a program prints goes by the kernel's debug line, not through
  the console's driver;
- the kernel does not check that an address a process's library gives
  it is in that process's memory;
- nothing was made fast: a yield is 8,000 instructions on the Pi 4, a
  message there and back 19,500 (the paper's: 365 and 1,040 cycles);
  the scheduler's search of its 64 slots and a process's 4.8 MB of
  bss cleared at each start are what I would look at first, and I
  measured neither;
- the build is slow: the 13 programs are in the image as a million
  `DATA` lines for mini-asm. A directive that includes a file's bytes
  is the cure, and is a change outside `kernels/singularity/`.

**Not verified:**

- **never run on a Pi 1 or a Pi 4 itself**: mini-qemu and QEMU only.
  One known doubt there: the instruction cache after a program's copy
  on the Pi 1 (stage 1);
- **what `-safe` trusts**: that mini-ml's type checker is sound, and
  that every function of the 31 modules a program may name is safe
  for any argument. Neither was audited (stage 5);
- `./mini-pi mini-singularity` typed at by hand: the check's session
  drives the same serial line, a terminal was not tried;
- its check is in none of ix's suites (`make test`,
  `tests/kernels_ix.sh`): `mini-mk check` and `singml/tests/check.sh`
  are run by hand;
- Singularity's design notes were never read, their titles only (the
  table below); the 2007 paper and the sources named in the survey
  are what this was written from.

## The survey (2026-10-05, checked by `kernels/singularity/survey.sh`)

The reference is the **Singularity Research Development Kit 2.0** (a
mirror: `github.com/lastweek/source-singularity`, 930 MB with its
tools), and in it `docs/`: 9 papers, 2 technical reports and **37
design notes** (SDN4 Process Model, SDN5 Channel Contracts, SDN6
Exchangeable Types, SDN12 The Application Manifest, SDN20 Application
Binary Interface, SDN29 Hardware Process Isolation...): the nearest
thing to a book. I have read the 2007 paper ("Singularity: Rethinking
the Software Stack", Hunt and Larus) and looked at the sources named
below; **of the design notes, their titles only**.

**The licence** (the kit's `Singularity RDK 2.0 License.pdf`, read):
Microsoft's research licence, "Non-Commercial Academic Use Only";
derived works under the same terms, and no right to put the software
under a licence that asks for the sources' distribution. ix is LGPL.
So: **read, never copied**; nothing of the kit in the repository, not
a contract's text nor a document. (My reading; the author's to
confirm.)

| part | lines | what |
|---|---:|---|
| `Kernel/` | 159,297 | all of it: C#, Sing#, C++ and assembly |
| `Kernel/Singularity` | 50,928 | the kernel proper: Memory 10,274, Isal 7,110 (the machine), Io 6,761, V1 4,658 (the ABI's side), Scheduling 3,299, Channels 1,945, Loader 1,336 |
| `Kernel/Native` | 48,113 | the C++ and assembly under it (the boot, the debugger's stub) |
| `Libraries/` | 44,498 | what a process links |
| `Contracts/` | 5,162 | 56 contracts, 602 messages, 206 states (93 contracts in the kit) |
| services (processes) | | Fat 17,196, NetStack 20,264, Smb 10,623, ServiceManager 3,609, Iso9660 2,866, RamDisk 1,369 |
| drivers (processes) | | Network 4,731, Disk 2,699, Vesa 911, LegacyKeyboard 803 |
| applications | | 68 directories; Shell 3,587 |

A research system of its day's size, with three machines (x86, x64,
ARM), a debugger and a network: nothing to be twinned. What a small
one must have, read in the paper and the sources:

- **The ABI**: 147 functions in six groups
  (`Singularity.V1.ABI.Txt`: process and execution context 31,
  hardware I/O 13, channels 6, page table and shared heap 34, stacks
  20, threads and synchronization 43; the paper's table 2 says 192).
  A call, not a trap. **No reference crosses it**: the kernel's
  collector and a process's never meet; what the kernel holds for a
  process is a handle in a table.
- **Memory**: the kernel's object space, one a process, and the
  **exchange heap**. A pointer of a process points into its own space
  or to a block of the exchange heap it owns; the exchange heap points
  only to itself. So a process is collected, and ended, without the
  others.
- **A contract**, the smallest (`PongContract.sg`): the messages `in
  Ping(int)`, `out Pong(int)`, `out PongReady()`; the states `Start:
  PongReady! -> ReadyState` and `ReadyState: Ping? -> Pong! ->
  ReadyState`. A channel has two endpoints, the importing and the
  exporting; an endpoint may itself be sent in a message, which is how
  a process is given a service (a capability).
- **A driver's manifest**, the keyboard's: two I/O ports, an
  interrupt, an endpoint to its parent and one where it serves
  `KeyboardDeviceContract`; the kernel fills an object with those at
  the start, and the driver has no other way to a device.
- **The paper's measure** (its table 1, cycles on an Athlon 64): a
  call to the kernel 80, a thread's yield 365, a message there and
  back 1,040, a process made 388,000; Linux's 437, 906, 5,800 and
  719,000. And its "unsafe code tax": the same system with the
  hardware's isolation turned on, slower.

What ix has (the same script):

| Singularity | ix | |
|---|---|---|
| a safe language, its compiler trusted | mini-ml: types checked, an index out of bounds raises. **No safe mode**: a program may write `external`, `Obj.magic`; `lib_core` itself has 255 `external` | to add |
| a process's own run-time system and heap | every mini-ml program is linked with its own `runtime.c`, whose heap is three static arrays in its image | there |
| processes in one address space | mini-ld places an image at `-T address`, final: "no relocations in the objects or here" | by the build, or to add |
| threads, a scheduler | `kernels/xv6` 1,636, `kernels/9pi/processes` 672 (processes behind an MMU); `lib_core/concurrency` 661 (`Thread`, `Event`: channels inside one program) | to write, known ground |
| the boot, the machine | `kernels/lib_machine` 849 and its C and assembly, both boards | there |
| a manifest, resources handed over | the capabilities (`Cap.*`): a `main` given what it may touch | the same idea |
| a file system, a shell as processes | mini-dossrv 250 over `lib_networking/9p` 435; mini-rc 2,146 (wants `fork` and files: too much) | in part |
| contracts and ownership checked by the compiler | nothing | cannot be had |

## The rule: one directory, and what cannot be in it

As mini-oberon: the kernel, **its processes' programs too**, and the
tests are in `kernels/singularity/`; what is shared with the other
kernels is there as a symbolic link, one a file.

But this system's idea lives in the compiler, and three things are
outside by their nature; the plan names them so that nobody looks for
them in vain:

- mini-ml's safe mode (`languages/ml/`: decision 1);
- the C library's and the run-time system's side for a process of
  this kernel (`lib_core/libc`, `languages/ml/runtime`: a third target
  beside Linux and Plan 9, decision 3);
- mini-ld, only if relocations come (decision 2's second half).

The layout I propose:

    kernels/singularity/
      mkfile  survey.sh  numbers.sh
      Abi.ml          the kernel's functions a process may call, numbered
      Process.ml Thread.ml Sched.ml
      Exchange.ml     the exchange heap: blocks, their owners
      Channel.ml      endpoints, the contract's machine, send, receive, select
      Manifest.ml     a program's needs; the system's image as a list of them
      Main.ml
      machine/        links: Machine, the boards' Arch, machine.c, l.s...
      lib/            what a process links to reach the ABI: Sip.ml, Contract.ml
      contracts/      one file a contract
      programs/       shell, names (the directory service), kbd, console,
                      ramdisk, hello, ping, pong: one directory a process
      tests/

## Decisions to take (the author's; my proposals)

1. **Safety by mini-ml, said as what it is.** A process's own code is
   compiled with a new `-safe`: no `external`, no `Obj`, no `Marshal`
   reading, no `-unsafe-types`; the modules it may name are a list.
   Its library (`lib_core`, with its externals) and its `runtime.c`
   are trusted, as each of Singularity's processes had a trusted
   run-time system. The trusted base is then: mini-ml, mini-ld, the
   runtime, `lib_core`, the kernel. Singularity verified a program's
   intermediate code when it was installed; here **the image is built
   whole from sources, and the build is what is trusted**. A weaker
   claim.
2. **One address space by the build first.** The system is sealed:
   its programs are known when the image is made (the system's
   manifest). Each is linked at its own address (`mini-ld -T`), with
   its own run-time system and so its own heap, and put in the image;
   the kernel jumps there. No loader, no relocation. The price: **one
   instance of a program at a time** (its data is at one place; a
   pristine copy of it lets a program run again after it ended), and
   no program from a disk. Then, a later stage: relocations kept by
   mini-ld and applied by a loader in the kernel (Singularity's Loader
   is 1,336 lines): several instances, programs in files. It is the
   loader mini-oberon put off too; one work for both.
3. **The ABI: a table of calls, a dozen or two.** Pages, threads
   (create, yield, exit), channels (create, send, receive, select,
   close), the exchange heap (allocate, free, read, write), processes
   (create from a manifest's name, start, join), the time, the debug
   line. A process calls through a table whose address it is given at
   its start; the arguments are integers and handles, bytes are
   copied: no OCaml value of one heap is seen by the other's
   collector. For a process this is a third system under the run-time
   system, beside Linux and Plan 9 (`Sys.os_type`). Crossing it means
   leaving one mini-ml program's registers (its heap's pointer, its
   handler) for another's: the hard part of stage 1.
4. **Contracts and ownership checked when the program runs.** A
   contract is a value: its messages, each with its direction and its
   arguments' kinds, its states and their transitions. The kernel
   keeps a channel's state and refuses a message the state does not
   allow: the sender is ended, its peer told the channel closed. A
   block of the exchange heap has one owner; sending it gives it away,
   and its handle, used after, raises. Over this, one small module a
   contract (`Pong.ping ep 3`, `Pong.receive ep`), written by hand at
   first. What Sing# proves before the system runs is here found by
   the tests, or by the user. The road not taken, to say why: session
   types by phantom types need linearity OCaml has not; a checker of
   our own over mini-ml's tree is a research project.
5. **A manifest is OCaml, and its resources are capabilities.** A
   program's `main` takes a record of what it was given: endpoints
   (typed by their contract), a device's registers (a range it may
   read and write through the ABI's hardware group, nothing else), an
   interrupt. The system's manifest, in the image, lists the programs,
   who starts whom, and who is given what. `-safe` is what makes it
   hold: a driver cannot reach a register it was not given.
6. **Cooperative first.** A thread yields at an ABI call (a receive
   that waits, a yield). A process that loops holds the processor
   until a later stage adds the clock's preemption, which here
   interrupts code at the kernel's own privilege: new assembly, on
   both boards. Singularity's is preemptive; one processor here.
7. **The console is the UART and the screen's text**, both boards,
   QEMU and mini-qemu first. No graphics.
8. **Its own shell**, small (a command, its arguments, the built-ins
   to list the processes and the names): mini-rc wants `fork`, pipes
   and files this system does not give as Unix does.

## What is checked

- **Sessions on the console**, as mini-xv6's: the commands typed, the
  text expected, under mini-qemu and QEMU, on both boards.
- **The isolation's own tests**: a message the contract refuses ends
  its sender and the system goes on; a block used after it was sent
  raises; a program with an `external` does not compile under
  `-safe`; a driver that ends is started again and its clients see
  the channel closed.
- **The paper's table 1, here** (`numbers.sh`): the four costs (a
  call to the kernel, a yield, a message there and back, a process
  made), in the guest's instructions under mini-qemu, for
  mini-singularity and, the same four by their nearest equals (a
  system call, a yield, a byte through two pipes, `fork` and `exec`),
  for mini-xv6 and mini-9pi on the same board. This table is what the
  system is here to show.

## The design notes, and where each lands

By their titles only (to read before the stage that needs each).

| the notes | here |
|---|---|
| SDN4 Process Model; the 2007 "Sealed Processes" paper | `Process.ml`; decision 2 |
| SDN5 Channel Contracts, SDN6 Exchangeable Types; the 2006 EuroSys paper | `Channel.ml`, `Exchange.ml`, `contracts/`; decision 4 |
| SDN20 Application Binary Interface | `Abi.ml`; decision 3 |
| SDN12 The Application Manifest, SDN24 Self Describing Boot | `Manifest.ml`; decision 5 |
| SDN18 IO Subsystem Fundamentals | the drivers in `programs/` |
| SDN11 Name Server, SDN27 Directory Service | `programs/names` |
| SDN10 Resource Management and Scheduling | `Sched.ml`; decision 6 |
| SDN29 Hardware Process Isolation; the 2006 "Deconstructing Process Isolation" paper | a late stage: the MMU turned on for one process, the tax measured |
| SDN25 Bytecode Verifier | lost: decision 1 |
| SDN17, 21, 22, 23, 32 (Sing#, its compile-time reflection) | not here: the language is OCaml |
| SDN9, 26, 35, 38, 39 (security, permissions, credentials, the TPM); SDN30, 37 (several processors) | not in this plan |

## The stages (each checked before the next)

0. **The ground.** `kernels/singularity/mkfile` and the links: a kernel
   that boots on both boards and prints a line. Settles: what of
   `kernels/lib_machine` a kernel without page tables for processes keeps.
1. **A second program in the image.** `hello`, a mini-ml program
   linked at its own address with its own run-time system, started by
   the kernel, printing by an ABI call, ending. The third target of
   the run-time system and the C library. The plan's first risk
   (decision 3's crossing): if two mini-ml programs cannot call each
   other cleanly, everything after changes.
2. **Threads and processes**: several programs, each a process with
   its threads; yield, exit, join; the kernel's handle table; a
   process ended has its pages back.
3. **Channels and the exchange heap**: endpoints, send, receive,
   select; blocks and their owners; `ping` and `pong`. First numbers
   of the table.
4. **Contracts**: the machine checked at each message; the contract's
   module; an endpoint sent in a message; the tests of refusal.
5. **`-safe`** in mini-ml, and the processes built with it.
6. **Manifests, the names, the drivers**: the system's manifest; the
   directory service (a name bound to an endpoint); the keyboard and
   the console as processes given their registers; the shell. The
   session's check.
7. **A file service**: a RAM disk and a file system as two processes
   (mini-dossrv's FAT by a link, a contract in place of 9P, if its
   code parts from `lib_networking/9p` cleanly; else a small one).
8. **The table**, whole, against mini-xv6 and mini-9pi.
9. Later, each to be decided: preemption; relocations and a loader;
   the MMU for a process (the tax); the SD card.

## The size

A guess, to be held against what is written: the kernel **1,500 to
2,500 lines** of OCaml (Singularity's Channels are 1,945 and its
Scheduling 3,299, for far more than is wanted here) and a few hundred
of C and assembly for the crossing; the processes' programs and their
contracts **1,000 to 1,500**; the compiler's and the run-time system's
side **300 to 600** (Plan 9's target cost 1,272 lines copied from
goken and 95 written: `plan_rio.md`, stage 1; here nothing to copy).
Less sure than mini-oberon's: stage 1 will say.

## Not checked yet

(As the plan was written, 2026-10-05. Since: the crossing, the
programs linked at several addresses and a process's memory are
answered in stages 1 and 2; `-safe`'s list in stage 5, in part. What
is still not verified is in "What is left", above.)

- the design notes: not read; the kernel's sources: looked at by
  their directories, a contract, a driver's declaration, the ABI's
  list. Nothing was built or run;
- **decision 3's crossing**: what registers and what state of
  `runtime.c` two mini-ml programs in one address space must save and
  restore around a call, on arm and arm64;
- that mini-mk can link several programs at several addresses and put
  them in one image (`-T` is there; the images are `.incbin`'d today);
- how much memory a process's static heap costs, and whether a
  process should ask the kernel for its pages in place of it;
- what `-safe` must refuse beyond `external` and `Obj` (a list to
  make from mini-ml's grammar and `lib_core`'s interfaces);
- mini-dossrv without 9P; the licence's reading above.

## Status

2026-10-07, **stage 0: the ground** (the author: "ok let's start the
mini-singularity project"). `kernels/singularity/` boots on both boards
and prints its lines:

    mini-singularity
    mini-singularity: no process yet.

- **The directory**: `mkfile` (114 lines, mini-oberon's first one less
  its disk), `Main.ml`, `tests/boot.expected`, and 13 symbolic links, a
  file each: `machine/` (`Machine.ml`, `Machine.mli`, `runtime.c`,
  `usb.c`, `shim.c`, `font1.bin`, from `kernels/lib_machine`), `machine/pi1/`
  and `machine/pi4/` (`machine.c`, `l.s`, `board.h`, each board's),
  `tests/session.py`. The mkfile includes `mkfiles/mkconfig` and
  nothing of `kernels/lib_machine`. `mini-mk` and `mini-mk O=5` make
  `_mk/7/kernels/singularity/kernel8.img` (577,656 bytes) and
  `_mk/5/kernels/singularity/kernel.img` (556,496).
- **`mini-mk check`** (and `O=5`): the two lines on the serial line,
  under mini-qemu and QEMU, the Pi 4 and the Pi 1: 4 ok.
- **What of `kernels/lib_machine` a kernel without page tables for processes
  keeps**: for now all that mini-oberon keeps, by the links, unbent.
  `runtime.c`'s processes (their table, their kernel stacks, the trap
  frames, `mmu_switch`) are linked and idle; `usb.c` is linked because
  `Machine` names its functions; `machine.c` names a disk
  (`fs_image`), given here as one word of size 0. `Page`, `Mmu` and
  `Arch` are not linked: no table is made for a process. The kernel's
  own table is `l.s`'s, as the other kernels'. Whether stage 2's
  threads can be `runtime.c`'s slots (`proc_context`, `k_swtch`: a
  stack each, scanned by the kernel's collector) or want a file of
  this kernel's own is stage 2's to see; a process's threads run on
  another program's heap, which those slots do not know.
- The kernel's heap is 1M words a half (mini-oberon's is 4M): its
  processes will have theirs.
- (`./mini-pi mini-singularity` and `mini-singularity4`: added after
  stage 1; `kernels/singularity/README.md`: after stage 4.)

2026-10-07, **stage 1: a second program in the image** (the author:
"I confirm the 3 things. Let's go!"). `programs/hello/Main.ml`, an
OCaml program as any other (the standard library's `print_string`,
`Printf`, `exit 3`; a million list cells through a heap of 256k words),
runs as a process in the kernel's address space, twice, each time from
its pristine copy:

    mini-singularity
    hello: a process in the kernel's address space
    hello: run 1, 1000000 cells
    mini-singularity: hello ended, status 3.
    hello: a process in the kernel's address space
    hello: run 1, 1000000 cells
    mini-singularity: hello ended, status 3.
    mini-singularity: no process left.

`mini-mk check` and `O=5`: those lines under mini-qemu and QEMU, the
Pi 4 and the Pi 1: 4 ok. Not run on the boards themselves.

- **The plan's first risk is answered: two mini-ml programs call each
  other cleanly, and a crossing keeps two registers.** Each program
  has its own static base (R12 on arm, R28 on arm64: mini-ld's
  `setR12`, `setSB`) and its own value stack, whose top its ML code
  holds in a register (R10, R26) that C never touches and that ML
  expects back after a call of C. The kernel's `cross_arm.s` and
  `cross_arm64.s` (41 and 44 lines) save the caller's two and set the
  kernel's static base; the kernel's value stack top is in its
  `ml_vsp`, where its ML left it. Everything else is the callee's to
  lose by 5c's and 7c's convention, or is a program's own data found
  from its static base (the heap, the handler, the roots). `cross.c`'s
  header says it.
- **No third target of the run-time system and the C library**
  (decision 3 said one; "what cannot be in it" named
  `lib_core/libc` and `languages/ml/runtime`). A process is built as
  for Linux, as the kernel itself is, and its "system" is one file of
  this directory, `lib/sip.c`: `_syscall6`, where `write` is the ABI's
  debug line and `exit` the process's end, as the kernel's
  `machine/shim.c` is the UART. Nothing was changed outside
  `kernels/singularity/`.
- **The ABI** (`Abi`): a process is given one address at its start, the
  kernel's `abi_entry`, and calls it with the address of its call's
  words (the number, the arguments); what a word points at is copied
  into the kernel's heap (`abi_bytes`). Two functions: 0 the end, 1 the
  debug line. A table of addresses was not needed: one entry, a number.
  The kernel does not check yet that an address a process gives is in
  its memory (the process's code that makes them is the trusted
  `sip.c`; `-safe`, stage 5, is what keeps the rest from making one).
- **A process's end is a return**: `Process.run` enters the image
  (`sip_enter`, which keeps the stack's place) and the end's call,
  once the kernel's ML has returned from it, drops what the process
  left on the stack (`sip_leave`). The machine's stack is shared: a
  process runs on its caller's. Stage 2's threads replace both.
- **The build** (`mkfile`, 179 lines): `PROGRAMS`, each a directory of
  `programs/` with its `Main.ml`, linked with `lib/`'s start, the
  standard library, its own `runtime.c` (`PHEAP`) at its slot's
  address (`mini-ld -H0 -T`), and put in the kernel's image as data
  with a table (the copy's address, its bytes, the address it is
  linked at, its slot's bytes). So mini-mk links several programs at
  several addresses into one image: "Not checked yet"'s third item.
- **What a process costs in memory**: 5,359,424 bytes on the Pi 4 and
  2,973,272 on the Pi 1 (its image 555,800 and 538,344: the whole
  standard library; the rest its bss: two halves of 256k words, a
  value stack of 64k). A slot is 16 MB; the image's second word is its
  bss's end, and `Process.run` refuses a program larger than its slot
  (tried with a slot of 1 MB: the panic's line).
- **Found the hard way: the C library's `malloc` is 64 MB of bss**
  (`minimal_malloc.c`, goken's placeholder, which the run-time
  system's channels ask for). The kernel's bss so ends near 92 MB, and
  a process first linked at 64 MB had its heap over the kernel's: a
  fault in the kernel at the first call. The processes are now from
  128 MB, and a process has its own small one in `lib/sip.c` (64 KB,
  all of that file's names, so that the library's is not linked). The
  kernel keeps the library's: 64 MB the Pi 1 could use (its 512 MB
  hold 24 slots after 128 MB), to take back when it matters.
- **The size so far**: OCaml 106 lines with the interfaces (`Process`
  49, `Abi` 39, `Main` 18), C 223 (`cross.c` 94, `lib/sip.c` 129),
  assembly 150, `hello` 18.
- Not done, for the stages that want them: a process's pages asked of
  the kernel (`m_alloc`'s `mmap` says ENOSYS in a process: `Marshal`
  and `Thread` there would fail); the instruction cache after the
  copy on the Pi 1 itself (`Machine.mmu_switch 0` flushes the Pi 4's;
  the emulators do not care); the kernel's interrupts while a process
  runs (none is taken yet).

2026-10-07, **stage 2: the processes** (the author: "what's next?";
decision 6 as proposed, to be confirmed). The kernel starts `init`,
which starts the others and waits for them; `tick` and `tock` run
together, a line each in turn; `hello` twice, one after the other:

    mini-singularity
    init: started
    init: no second tick while one runs
    init: no program nobody
    tick 1
    tock 1
    tick 2
    tock 2
    tick 3
    tock 3
    init: tick ended with 1, tock with 2
    hello: a process in the kernel's address space
    hello: run 1, 1000000 cells
    init: hello 1 ended with 3
    hello: a process in the kernel's address space
    hello: run 1, 1000000 cells
    init: hello 2 ended with 3
    mini-singularity: init ended, status 0.
    mini-singularity: no process left.

`mini-mk check` and `O=5`: those lines under mini-qemu and QEMU, the
Pi 4 and the Pi 1: 4 ok. Not run on the boards themselves.

- **The ABI has six functions** (`Abi.mli` lists them): the end, the
  debug line, and now yield, create (a process of the program of a
  name, not started), start, join (waits for the end: the status).
  For a program they are `lib/Sip` (`Sip.yield`, `create`, `start`,
  `join`), linked after the standard library; `Sip.process` is
  abstract.
- **A handle** is an index in the process's own table (16 entries,
  `Process`): what `create` gives, what `start` and `join` take; a
  number that is no handle of the caller's is refused (-1). Only
  processes are held so far; stage 3's endpoints go in the same table.
- **A process's thread in the kernel is one of `machine/runtime.c`'s
  slots** (stage 0's question): mini-xv6's `proc_context`, `k_swtch`
  and `proc_free`, by the link, unbent: a kernel stack (16 KB) and a
  kernel value stack each, the scheduler on the boot's. So a call may
  wait in the kernel (join) while the others run, and the kernel's
  collector sees every waiting call's values. `Process.schedule` is
  the loop: the next ready one, round robin, until none is.
- **Two stacks a process**: its program runs on a stack at its slot's
  end, in its own memory (the 16 MB less its image and bss: 10 MB on
  the Pi 4); the kernel's code for it on its kernel stack. The
  crossing switches them (`cross_arm.s` 50 lines, `cross_arm64.s` 61:
  the thread's two stack pointers are `cross.c`'s `sip_cur`, said
  again after each call, as others may have run).
- **One thread a process.** The plan said "each a process with its
  threads"; not done. Two ways, to choose when a program wants them:
  the standard library's `Thread` inside the process (its scheduler is
  OCaml's; it asks the system for a stack's memory, `mmap`, which
  `lib/sip.c` does not serve yet), a call that would wait coming back
  to that scheduler; or the kernel's, which needs the process's
  run-time system told at each switch which value stack runs.
- **A process ended has its memory back** by what decision 2 made of
  memory: a program's slot is its own, and free again when its process
  is joined (`hello` twice), or at its end when nobody will wait for
  it (the kernel's `init`; a child whose parent ended). A second
  process of a running program is refused.
- **`Programs`**: the mkfile's `PROGRAMS` written as an OCaml array of
  names for the kernel, in `_mk`: the seed of the system's manifest
  (stage 6).
- **Found: mini-asm overflowed its stack on a long file** (four
  programs as data are 278,857 lines; `List.map` in its
  preprocessor): fixed in `assembler/Lexer_asm.ml`, the one change
  outside this directory; `docs/plans/bugs/ix.md`. The images as
  `DATA` lines are slow to assemble (the kernel's image is 2.8 MB);
  a directive that includes a file's bytes would be the cure.
- **The size so far**: OCaml 240 lines with the interfaces (`Process`
  183, `Abi` 45, `Main` 12), `lib/Sip` 33, C 250 (`cross.c` 115,
  `lib/sip.c` 135), assembly 176, the four programs 75; the mkfile
  187.
- Not done: a process that loops holds the processor (decision 6);
  the kernel does not check an address a process gives; a thread's
  kernel stack is 16 KB, enough for the calls so far.

2026-10-07, **stage 3: the channels and the exchange heap** (the
author: "let's commit and move forward"; decision 4 as proposed).
After stage 2's lines, init gives `ping` and `pong` the two ends of a
channel, and asks which of two endpoints of its own has a message:

    init: the endpoints are no longer its own
    ping: sent 1, got 2 back (tag 1)
    ping: sent 2, got 3 back (tag 1)
    ping: sent 3, got 4 back (tag 1)
    ping: the block is no longer its own
    pong: a block of 32 bytes: bytes that changed hands
    pong: the channel is closed
    init: ping ended with 0, pong with 0
    init: of two endpoints, number 1 has a message: 42
    pong: the channel is closed
    mini-singularity: init ended, status 0.
    mini-singularity: no process left.

`mini-mk check` and `O=5`: the 29 lines (`tests/boot.expected`) under
mini-qemu and QEMU, the Pi 4 and the Pi 1: 4 ok. Not run on the boards
themselves.

- **A channel** (`Channel`, 102 lines): two endpoints, each held by
  one process, a queue each; a message is a tag, an integer and maybe
  a block. Sending never waits; a receive waits in the kernel (stage
  2's kernel stacks), and select waits for one of three endpoints at
  most (the call's words). An endpoint closed, or held by a process
  that ends, tells the other end once its queue is empty (`pong`'s
  last line; the second is `bench`'s pong).
- **The exchange heap** (`Exchange`, 53 lines): a block is bytes **of
  the kernel's heap**, with its owner, 1 MB a block and 4 MB in all at
  most. A process never has a block's address: it reads and writes it
  by calls that copy between the block and its own heap. So a message
  passes a block without a copy, as Singularity's, but using it costs
  one at each end, where Singularity's process points into the
  exchange heap. The reason: a pointer into memory that another
  process may be given, in a language whose compiler does not prove
  that it is not kept, is the end of the isolation. A loss beside
  decision 4's, to say with it.
- **Ownership is checked when the program runs** (decision 4's
  second half): a block sent, an endpoint given to a child, is no
  longer a handle of the sender's, and its use is refused by the
  kernel (-2), which `Sip` raises as `Not_held` (ping's and init's
  lines). A process that ends has its endpoints closed and its blocks
  freed; a block in a message never received is freed with its queue.
- **The handles** are of three kinds now (`Process.held`: a child, an
  endpoint, a block), in the one table of 16; a call checks the kind.
- **How a process is given a channel**: its parent makes it, and gives
  an end to the child before it starts (`Sip.give`); the child finds
  it as `Sip.given 0`. The manifest's seed (decision 5): what a
  program is given is decided by who starts it.
- **The ABI has 18 functions** (`Abi.mli` lists them); for a program
  all are `lib/Sip` (153 lines), written in OCaml over three C
  functions: a call of integers, one whose first argument is a
  string's address, a word of the last answer. `lib/sip.c` no longer
  has a function a call.
- **The first numbers** (`kernels/singularity/numbers.sh`;
  `programs/bench` measures each in the board's microseconds, 1,000
  times, a process 10 times, and under mini-qemu a microsecond is 30
  instructions, the same at every run):

  | the guest's instructions | a call | a yield | a message there and back | a process made and ended |
  |---|---:|---:|---:|---:|
  | the Pi 1 | 552 | 16,273 | 34,377 | 10,701,210 |
  | the Pi 4 | 645 | 7,809 | 26,762 | 11,534,637 |
  | the paper's (cycles, an Athlon 64) | 80 | 365 | 1,040 | 388,000 |

  Far from the paper's, and nothing was made fast: a call is a call
  of C, then a callback into the kernel's OCaml, a `match` on the
  number, and the clock read (on the Pi 4 two 64-bit divisions); a
  yield is `Process.schedule`'s search of the 64 slots with a closure
  and a remainder a slot (a division in software on the Pi 1), and two
  switches of stacks; a message there and back is four calls and two
  such switches; a process is its image copied (0.55 MB), its bss
  cleared (4.8 MB) and its run-time system and standard library
  started. mini-ml's code is a stack machine's, not optimized. What
  the table is for is the comparison with mini-xv6 and mini-9pi on the
  same boards with the same compiler: stage 8.
- **The size so far**: the kernel's OCaml 583 lines with the
  interfaces (`Process` 249, `Abi` 167, `Channel` 102, `Exchange` 53,
  `Main` 12), `lib/Sip` 153, C 304 (`cross.c` 155, `lib/sip.c` 149),
  assembly 186, the eight programs 197; the mkfile 189, `numbers.sh`
  22. The kernel's image is 5.2 MB on the Pi 4 (eight programs of 0.55
  MB, each with the whole standard library).
- Not done: select of more than three endpoints; a message's bytes
  other than in a block (a tag and one integer); the exchange heap's
  bytes are not counted against a process; a contract (stage 4), so a
  tag is any number.

2026-10-07, **the blocks reached where they are** (the author, of
stage 3's exchange heap: "I'm worried about those block copy; the
whole point of singularity ... no cost to message passing ... because
things do not need to be copied but instead ownership is passed, and
I feel we're losing that here"). He was right, and the loss was
stage 3's choice, not a decision's: what is said above of the
exchange heap ("bytes of the kernel's heap", "a process never has a
block's address", "using it costs a copy at each end") **no longer
holds**.

- **The exchange heap is memory of its own** (`Exchange`, 91 lines):
  the board's from 96 MB to the programs' 128, in whole pages, first
  fit, zeros when given. A block is its owner, its address, its bytes.
- **Its owner reads and writes a block in place, with no call of the
  kernel.** `alloc` and `receive` answer the block's address and
  bytes with its handle; only the process's trusted library sees them
  (`lib/sip.c`'s table, a handle's address and length), and a program
  has the abstract `Sip.block`: `Sip.get`, `set`, `sub`, `write` look
  at the table and at the bounds. A block sent or freed is forgotten
  there by `Sip`, and its use raises `Not_held` without asking the
  kernel. What I wrote at stage 3, that such an address is the end of
  the isolation, was wrong: it is kept by the library the process
  already trusts for every call (it is what makes the addresses the
  kernel is given), and `-safe` (stage 5) is what keeps a program from
  reaching past it. The trusted base is the same as before.
- **The ABI has 15 functions**: the three that copied a block's bytes
  are gone.
- **The kernel has the processes' small malloc** (`lib/malloc.c`, one
  file linked in both): with the C library's 64 MB the Pi 4's kernel
  reached past 96 MB (`Exchange` stops the boot then, which is how it
  was seen). Stage 1's "to take back when it matters" is done.
- **The numbers**, with two more (`programs/bench`: a megabyte's block
  that goes with a message and comes back; a byte of it read and
  another written):

  | the guest's instructions | a call | a yield | a message there and back | the same with a block of 1 MB | a byte read and one written | a process made and ended |
  |---|---:|---:|---:|---:|---:|---:|
  | the Pi 1 | 511 | 16,252 | 34,398 | 26,357 | 708 | 10,744,629 |
  | the Pi 4 | 586 | 7,910 | 26,862 | 17,928 | 695 | 11,587,728 |

  A megabyte costs no more than nothing to pass (less: pong sends the
  block back as it is, and a number one more), and no call to use. The
  rest is still what stage 3 said: nothing made fast. A byte is two
  calls of C from mini-ml's code.
- `mini-mk check` and `O=5`: the same 29 lines, 4 ok.
- **Asked of the author, not answered**: the contracts' form. He
  speaks of "our planned mini-ml extension for imitating Sing#"; the
  plan has none (decision 1's `-safe`; decision 4's contracts as
  values, their modules written by hand). Proposed to him: a contract
  as an extension node that is still OCaml's syntax
  (`[%%contract type request = Ping of int  type reply = Ready | Pong
  of int  let rec start = send Ready >> ready and ready = recv Ping >>
  send Pong >> ready]`), from which mini-ml makes the contract's
  module (the two endpoints' types, an operation a message: a
  message's type and direction are then OCaml's to check, its state
  the kernel's); the same for a manifest (`[%%manifest type given =
  {...}]`); one contract written by hand first, to know what the
  extension must make.

2026-10-07, **stage 4: the contracts** (the author: "one contract by
hand first"). A channel has a contract and a state, and the kernel
refuses a message the state does not allow; `Pong` and `Intro` are
written by hand, as what a declaration is to become. After `hello`'s
lines:

    init: the endpoints given are no longer its own
    init: an Intro's end is not a Pong's importing end
    ping: was sent an endpoint, and pong is ready there
    ping: sent 1, got 2 back
    ping: sent 2, got 3 back
    ping: sent 3, got 4 back
    ping: the block is no longer its own
    pong: a block of 32 bytes: bytes that changed hands
    pong: the channel is closed
    init: ping ended with 0, pong with 0
    mini-singularity: rogue ended: Pong.Ping is not allowed in state 2.
    pong: the channel is closed
    init: rogue ended with 255, pong with 0
    init: of two endpoints, number 1 has a message

`mini-mk check` and `O=5`: the 34 lines under mini-qemu and QEMU, the
Pi 4 and the Pi 1: 4 ok. Not run on the boards themselves.

- **A contract is a value** (`lib/Contract`, 113 lines, linked in the
  kernel and in every program: the one description): its messages,
  each with the end that sends it and what it carries besides its
  integer (nothing, a block, an endpoint of a named contract and
  end), and its states, each with the tags it allows and the state
  after. A channel's maker gives it to the kernel as bytes
  (`Contract.encode`; the kernel reads them again, and refuses what is
  no contract).
- **The kernel checks each message** (`Channel.allowed`): the tag is
  one of the contract's, sent from its end, allowed in the channel's
  state, and carries what the contract says (an endpoint: of that
  contract, that end). The state is one for the channel, moved when a
  message is sent: right for a contract where one end at a time may
  send, as Sing#'s rules ask; nothing here checks that a contract is
  so made.
- **A message refused is its sender's end** (decision 4): the kernel
  says why on the console, the sender ends with 255, and its peer sees
  the channel closed (`rogue`, which sends a second Ping before the
  first's Pong: it compiles; pong goes on to its own end; init goes
  on).
- **An endpoint goes in a message** (`Intro`: `Meet(Pong.Imp)`): ping
  is given no Pong channel but one where it is told, and receives the
  Pong's importing end, then its own. How a process is given a
  service; the directory (stage 6) is this with names.
- **A contract's module, by hand** (`contracts/Pong`, 146 lines with
  its interface; `Intro`, 63): the contract's value; `Pong.imp` and
  `Pong.exp`, abstract; a variant of what each end receives
  (`request`, `reply`); `Pong.channel`; and for each end a module with
  an operation a message it may send (`Pong.Imp.ping`,
  `Pong.Exp.pong`...), `receive`, and `of_endpoint`, which asks the
  kernel whether an endpoint is that contract's, that end (the ABI's
  16th function). **So OCaml's types check a message's direction and
  arguments when a program is compiled, and the kernel its state when
  it runs**: `Pong.Exp.ping` is no value, `Pong.Imp.ping e "x"` no
  type; `Pong.Imp.ping` twice compiles.
- **What the extension must make**, seen from the two written: from
  the messages (name, end, arguments) and the states, in order: the
  tags (a message's place); `Contract.make`'s call; the two variants,
  a constructor a message, by the end that receives it; in `Imp` and
  `Exp` a function a message that end sends, calling `Sip.send`,
  `send_block` or `send_endpoint` by what it carries; `receive`, a
  `match` on the tag and what is carried; `of_endpoint`, `endpoint`,
  `close`. All of it mechanical: nothing in `Pong.ml` but the two
  tables is thought. What is not there to copy: the states' names
  (numbers here, and in the refusal's line), a message of several
  integers (one today), and a check that the contract is well made
  (each state's messages from one end).
- **mini-ml wants a record's fields named by their module** in another
  one (`{ Contract.label = ... }`), or an annotation it can see: the
  contracts say `Contract.message` and `Contract.make`, two functions,
  in place of records.
- **The numbers** (`numbers.sh`), each message now checked against its
  contract and sent through the contract's module:

  | the guest's instructions | a call | a yield | a message there and back | the same with a block of 1 MB | a byte read and one written | a process made and ended |
  |---|---:|---:|---:|---:|---:|---:|
  | the Pi 1 | 520 | 16,257 | 27,406 | 30,744 | 708 | 11,064,525 |
  | the Pi 4 | 602 | 7,918 | 19,207 | 22,518 | 695 | 11,929,293 |

  (A message is less than before the contracts, and the megabyte's
  more: pong's code changed with them, a `match` on a variant in the
  place of stage 3's on a record; I have not looked further.)
- **The size so far**: the kernel's OCaml 727 lines with the
  interfaces (`Process` 251, `Abi` 200, `Channel` 173, `Exchange` 91,
  `Main` 12), `lib/` 319 of OCaml (`Sip` 206, `Contract` 113), the
  two contracts 209, the nine programs 237.
- Not done: the contract's module made by mini-ml (the extension:
  the author's to decide when); a channel's state said by its name;
  a contract checked to be well made.

2026-10-07, **mini-singml: a contract's declaration made its module**
(the author: "would it be possible to add the extensions in the
singularity directory? ... so we don't polluate the main
languages/ml/ code"; then "let's start mini-singml ... maybe just
singml/ ... let's keep the handwritten simple Pong contract in
contracts/ as it helps to understand").

- **`kernels/singularity/singml/`**, a program of its own, mini-singml
  (429 lines with its interfaces: `Description` 222, a declaration
  read; `Output` 124, its module written; `CLI` 78; `Main` 5). It
  links mini-ml's front end (`Ast`, `Parser`, `Lexer`) and **changes
  no line of `languages/ml`**. Built by dune (`bin/mini-singml`, which
  the kernel's mkfile runs) and by mini-mk (`singml/mkfile`, over
  `_mk`'s objects of `languages/ml`): the two write the same bytes.
- **A declaration is OCaml's syntax, in a file of its own**
  (`contracts/Intro.contract`), not an extension node in a program:
  mini-ml's parser reads it as it is, so nothing was added to the
  grammar. What I proposed before (`[%%contract ...]`, `send Ready >>
  ready`) asked for both. The messages are the constructors of its
  variant types; the states its one `let rec`, the first the start,
  said from the exporting end as Sing#'s: `function | M _ -> s` a
  message received, `send M; s` one sent, `s1 || s2` one or the other
  sent, a state's name, `()`. Who sends a message is where it stands;
  a type's messages are all one end's.
- **Checked when the module is made**, which the hand-written ones
  were not: a state where both ends may send, a message sent by one
  end here and the other there, a message in no state, a state that is
  not one, an argument that is not an int, a `Sip.block` or another
  contract's end (`singml/tests/bad/`, 7 declarations, each with its
  message).
- **The states have names** (`lib/Contract`: a state is its name and
  its moves): a named state's, and for one in between the state's and
  the message's (`Serve/Ping`). The refusal's line says it: "Pong.Ping
  is not allowed in state Serve/Ping".
- **`contracts/Pong.ml` and `Pong.mli` stay, by hand**, to be read;
  `Intro` is now its declaration (16 lines for the 63 by hand), made
  into `_mk`. `singml/tests/Pong.contract` is Pong's declaration, and
  `singml/tests/check.sh` holds the made module against the
  hand-written one: the same states, the same interface but for the
  comments, and the nine programs compile with it in its place: 4 ok,
  with the mini-singml dune built and the one ix built.
- `mini-mk check` and `O=5`: the same 34 lines (one changed: the
  state's name), 4 ok.
- **Found on the way** (not this directory's): `_mk`'s objects of
  `languages/ml` and of `lib_core` were of 2026-10-05, before
  mini-yacc's parsers had `Parser.Error` and before `Files` became
  `FS`: `mini-mk` in `lib_core` and the parser's three objects in
  `languages/ml` made again. ix's `Fpath` has no `basename`.
- Not done: a message of several integers (the kernel's message has
  one); `-safe`, the next thing here (`singml/`'s second half); a
  manifest's declaration.

2026-10-07, **stage 5: `-safe`** (the author: "let's commit and move
forward"), in mini-singml and not in mini-ml: decision 1 as proposed,
but for where it is.

- **`mini-singml -safe [-allow Module]... file.ml`** (`singml/Safe`,
  156 lines with its interface): a walk of mini-ml's tree of the
  source. Refused, each with its line: `external` (in a module of the
  program's too, and in a signature); a module named, opened or
  renamed that is not in the list (31 of the standard library, those
  that only compute, and `Sip`, `Contract`), nor `-allow`'s (the
  contracts), nor one the program defines; a name whose last part
  starts with `unsafe_` (`String.unsafe_get`, `Array.unsafe_set`,
  `Bytes.unsafe_to_string`, `Char.unsafe_chr`: by the name, wherever
  it is from); `input_value`; an extension (`[%bits]`, `[%mli]`,
  `[%using]`: code this walk does not see).
- **The image's programs are built with it**: the mkfile runs it on
  each of `programs/` before mini-ml, and the image is not made if one
  is refused (tried: `Obj.magic` added to `tick`). The nine pass as
  they were. `lib/Sip`, `lib/Contract` and the contracts' modules are
  not looked at: they have `Bytes.unsafe_to_string` and externals, and
  are trusted, as decision 1 says of a process's library.
- **Checked** (`singml/tests/check.sh`, now 6 ok, with both builds of
  the tool): the nine programs and `tests/unsafe/fine.ml` let through;
  seven sources refused (`tests/unsafe/`: an external, `Obj.magic` to
  forge a block's handle, `String.unsafe_get`, `open Marshal` and
  `Array.(unsafe_get ...)`, an external in a module of its own and
  `module Sys_ = Unix`, `input_value` and `Obj.t` in a type, an
  extension), each line with its reason. `mini-mk check` and `O=5`:
  the same 34 lines, 4 ok.
- **What it does not prove, and "Not checked yet"'s fifth item only
  half answered.** The list of what to refuse was made from mini-ml's
  tree (every node of `Ast` is walked) and from the interfaces of
  `lib_core` (a search for `unsafe`, `magic`, `%identity`,
  `input_value`). Not done: mini-ml's type checker taken as sound,
  never audited (one hole was found in it on 2026-10-05, a record
  taken for another of the same shape: `bugs/ix.md`); each function of
  the 31 modules taken as safe for any argument (their own externals
  were not read one by one: a `blit` that does not check its bounds
  would be a hole); `Printf`'s formats taken as typed. So the claim
  is: **a program that passes is not unsafe by anything it says
  itself**; that nothing it may call is, is trusted.
- mini-singml is 602 lines with its interfaces (`Description` 222,
  `Safe` 156, `Output` 124, `CLI` 95, `Main` 5), none in
  `languages/ml`.

2026-10-07, **stage 6, but the names: manifests, the console's
driver, the shell** (the author: "let's commit and move forward!";
decisions 5, 7 and 8 as proposed, 7 for the serial line only). The
system now boots to a shell:

    mini-singularity
    mini-singularity's shell (help: what it knows)
    sing> ps
     0 init       waiting
     1 console    waiting
     2 shell      running
    sing> hello
    hello: a process in the kernel's address space
    hello: run 1, 1000000 cells
    hello ended with 3
    sing> crash
    crash: about to fail
    Fatal error: uncaught exception Failure("hd")
    crash ended with 2
    sing> nosuch
    nosuch: no such program, or it runs already

`mini-mk check` and `O=5` are now **a session typed at the shell**
(`tests/session.cmds`: `help`, `ps`, `hello`, `crash`, a name that is
none, two words, `selftest`, `exit`; `tests/session.expected`, 66
lines), under mini-qemu and QEMU, the Pi 4 and the Pi 1: 4 ok. Not run
on the boards themselves. Stage 2 to 4's lines are `selftest`'s, a
program run from the shell (what `init` was).

- **A program's manifest** (`programs/console/Main.manifest`), in
  OCaml's syntax as a contract's declaration, a name a resource: `let
  uart = registers 0x201000 0x1000`, `let keys = interrupt 57`.
  mini-singml reads it (`singml/Manifest`, 77 lines) and makes two
  things: for the kernel, the list of what to give
  (`Programs.grants`, in `_mk`); for the program, its module `Given`
  (`Given.uart : Sip.registers`, `Given.keys : Sip.interrupt`, and
  `Given.endpoint i`, what its parent gave it). Not decision 5's
  record passed to `main`: a module, one a program, each linked with
  its own; no attribute, no extension, nothing for mini-ml's grammar.
- **The kernel gives at the start what the manifest asks**, as the
  process's first handles, and the ABI's hardware group checks them:
  `io_read` and `io_write` take a registers' handle and an offset in
  it, and there is no call that takes an address; `wait` takes an
  interrupt's. A program without a manifest has no registers. One
  interrupt is known, the PL011's (a character received); another's
  number stops the boot.
- **The console's driver is a process** (`programs/console`, 33
  lines): the PL011 by its two registers, serving `Console`
  (`contracts/Console.contract`: a text's block lent and had back, a
  key waited for). **The shell** (`programs/shell`, 72 lines; decision
  8) is its client: a line read with its echo and backspace, `help`,
  `ps`, `exit`, or a program's name, started and waited for. **init**
  (25 lines) is the system's wiring: the channel made, an end to
  each; the system's manifest of decision 5 ("who starts whom, who is
  given what") is so a program today, not a table.
- **Waiting for an interrupt** (decision 6 holds: none is taken):
  `Sip.wait` puts the process to sleep; when nothing can run and some
  sleep, the kernel stops the processor (`Machine.wait_interrupt`),
  and the sleepers look at their devices when one has come. A process
  that never yields starves the driver: cooperative.
- **Three more calls** (21 in all): `stop` (a parent ends its child
  where it is: init the driver, at the shell's end), `info` (the
  processes, or the programs, as text in a block of the caller's: the
  shell's `ps` and `help`).
- **What a program prints still goes by the kernel's debug line**,
  not through the driver: the C library's `write` is one call, with no
  endpoint to find. Decision 7's "the console is the UART and the
  screen's text": the UART only, and for the shell's side only.
- **The numbers** (`numbers.sh` now types `bench` at the shell), as
  before within a few percent: the Pi 1 544, 16,297, 27,541, 30,879,
  712, 11,212,389; the Pi 4 642, 7,999, 19,489, 22,803, 695,
  12,084,840.
- **`kernels/singularity/tutorial.md`** (the author: "the README for
  singularity will need to contain a mini tutorial probably, or maybe
  it could be a kernels/singularity/tutorial.md separate document?"):
  separate, linked from the README; it walks the system by its own
  files (hello, tick and tock, the Console contract with its server
  and client, the shell's block, the driver's manifest, what is
  refused and when).
- **The size**: the kernel's OCaml 825 lines with the interfaces
  (`Process` 312, `Abi` 236, `Channel` 174, `Exchange` 91, `Main`
  12), `lib/` 360 of OCaml, mini-singml 699, the 13 programs 396, the
  contracts 181. The image is 8.5 MB on the Pi 4 (13 programs of 0.55
  MB), and `images.s` near a million lines for mini-asm: slow to
  build; a directive that includes a file's bytes is wanted more.
- **Not done of stage 6**: the name service (a name bound to an
  endpoint: a process is given its endpoints by its parent only); a
  driver that ends started again, its clients seeing the channel
  closed; the keyboard and the screen (the serial line only);
  arguments for a program run from the shell.

2026-10-07, after the plan was moved here: **`make loc` does not count
`kernels/singularity/`** (the author: "let's not count singularity as
part of make loc (as well as other kernels really; only 9pi and maybe
xv6 (and lib) should count really"). `scripts/stats/loc.py` counts in
m-ix `kernels/9pi`, `kernels/xv6`, `kernels/lib_machine` and `kernels/tools`; every
other directory of `kernels/` is a row of its own among what is not
counted, as mini-oberon's was (2,966 lines here without the tests;
m-ix 80,654 to 77,688).
