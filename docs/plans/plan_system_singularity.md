# Plan: mini-singularity, Singularity's processes without hardware, in OCaml on the Pi (`kernel/singularity/`)

The author (2026-10-05), after [`plan_system_oberon.md`](done/plan_system_oberon.md):
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

**Status**: the survey done and this plan written (2026-10-05); the
decisions are mine to propose, the author's to take. Stages 0 and 1
done (2026-10-07: "Status", at the end). Taken by the author
(2026-10-07, "I confirm the 3 things"): decisions 2 and 3 as proposed,
and the licence's reading (read, never copied). The others wait for
their stages.

## The survey (2026-10-05, checked by `kernel/singularity/survey.sh`)

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
| threads, a scheduler | `kernel/xv6` 1,636, `kernel/9pi/processes` 672 (processes behind an MMU); `lib_core/concurrency` 661 (`Thread`, `Event`: channels inside one program) | to write, known ground |
| the boot, the machine | `kernel/lib` 849 and its C and assembly, both boards | there |
| a manifest, resources handed over | the capabilities (`Cap.*`): a `main` given what it may touch | the same idea |
| a file system, a shell as processes | mini-dossrv 250 over `lib_9p` 435; mini-rc 2,146 (wants `fork` and files: too much) | in part |
| contracts and ownership checked by the compiler | nothing | cannot be had |

## The rule: one directory, and what cannot be in it

As mini-oberon: the kernel, **its processes' programs too**, and the
tests are in `kernel/singularity/`; what is shared with the other
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

    kernel/singularity/
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

0. **The ground.** `kernel/singularity/mkfile` and the links: a kernel
   that boots on both boards and prints a line. Settles: what of
   `kernel/lib` a kernel without page tables for processes keeps.
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
   code parts from `lib_9p` cleanly; else a small one).
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
mini-singularity project"). `kernel/singularity/` boots on both boards
and prints its lines:

    mini-singularity
    mini-singularity: no process yet.

- **The directory**: `mkfile` (114 lines, mini-oberon's first one less
  its disk), `Main.ml`, `tests/boot.expected`, and 13 symbolic links, a
  file each: `machine/` (`Machine.ml`, `Machine.mli`, `runtime.c`,
  `usb.c`, `shim.c`, `font1.bin`, from `kernel/lib`), `machine/pi1/`
  and `machine/pi4/` (`machine.c`, `l.s`, `board.h`, each board's),
  `tests/session.py`. The mkfile includes `mkfiles/mkconfig` and
  nothing of `kernel/lib`. `mini-mk` and `mini-mk O=5` make
  `_mk/7/kernel/singularity/kernel8.img` (577,656 bytes) and
  `_mk/5/kernel/singularity/kernel.img` (556,496).
- **`mini-mk check`** (and `O=5`): the two lines on the serial line,
  under mini-qemu and QEMU, the Pi 4 and the Pi 1: 4 ok.
- **What of `kernel/lib` a kernel without page tables for processes
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
- Not done: a `README.md` here (when there is something to use).
  (`./mini-pi mini-singularity` and `mini-singularity4`: added after
  stage 1.)

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
  `kernel/singularity/`.
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
