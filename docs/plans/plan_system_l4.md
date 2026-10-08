# Plan: mini-l4, a microkernel with seL4's model at L4's size, in OCaml on the Pi (`kernels/l4/`)

The author (2026-10-07), with mini-xv6, mini-9pi and mini-rio,
mini-oberon and mini-singularity there: "what else could we add?". Of
the five answers (a microkernel, a hypervisor, a library OS, Inferno,
an image that persists: "After it", at the end) he took the first, in
the form proposed, seL4's model with L4's smallness: "let's do it,
this sel4 model at l4's size! let's write the plan document". What he
said of Oberon holds here as it did for Singularity
([`plan_system_oberon.md`](done/plan_system_oberon.md),
[`plan_system_singularity.md`](done/plan_system_singularity.md)): not an
exact twin, "the idea is more to give this historical [system] a place
here, adapted to OCaml, and reusing some of the existing code in ix";
its "look and feel ... and general approach" kept; and the code "only
in" its directory, the rest by symbolic links.

mini-l4 is **a kernel that does almost nothing**: threads, address
spaces, messages between them, and capabilities, which are the only
way anything is named or allowed. Files, the console, the drivers and
the making of a process are programs, in their own address spaces,
that talk by messages. It is written in OCaml and runs on the bare
Pi 1 and Pi 4 beside the three other kernels, on the same machine
layer, built by the same compiler.

It is here for the comparison that mini-singularity began. ix then
has the three ways to keep a file system apart from who uses it:

| | the file system is | reached by | kept apart by |
|---|---|---|---|
| mini-xv6, mini-9pi | in the kernel | a system call | nothing: the kernel trusts itself |
| mini-singularity | a process in the kernel's address space | a message on a channel, its contract checked | the language |
| **mini-l4** | a process in its own address space | a message to an endpoint, through the kernel | the MMU, and capabilities |

Singularity's papers measure themselves against the third and ix
cannot yet.

What is kept, and what is free:

- **Kept: the approach**, which is seL4's model as its manual tells
  it. *Capabilities*: a thread can do only what a capability in its
  own table allows; a capability is copied, given less rights, moved,
  deleted, and **revoked** with all that was derived from it. *Kernel
  objects made from untyped memory*: who holds memory decides what it
  becomes (a thread, an endpoint, a table of capabilities, a page),
  and takes it back by revoking; the kernel gives none of its own.
  *Synchronous messages*: a send meets a receive, nothing is queued
  but the waiting threads; a call lends a right to reply, once. *All
  the rest outside*: an interrupt is a signal to a driver's thread, a
  fault a message to another thread, a page is mapped by who holds
  its capability.
- **Kept: the feel**, which for seL4 is its tutorials' (there is no
  screen to imitate): a root task that starts with the whole machine
  as a list of capabilities and builds the system by hand, a step a
  tutorial (`hello-world`, `capabilities`, `untyped`, `mapping`,
  `threads`, `ipc`, `notifications`, `interrupts`, `fault-handlers`),
  and the manual's names (`Untyped.retype`, `CNode.mint`, a badge, a
  reply), so that one reads `kernels/l4/` with the manual open.
- **Kept: the size**, which is L4's lesson (Liedtke: a concept is in
  the kernel only if it cannot be outside). What seL4 added since for
  its machines, its proofs and real time is not here (decision 1).
- **Free: what is under**: the layout of an object, the bits of a
  capability, the binary interface. No program of seL4's runs here.
- **Lost, and not to be hidden**: seL4 is the *verified* kernel; its
  name's two letters are that claim. Here nothing is proved. And two
  things its proofs stand on are not true of a kernel in OCaml: it
  has a heap of its own, collected (decision 4), and so no bound on
  how long a call of it takes.

**Status**: the survey done and this plan written (2026-10-07);
nothing else is. The decisions are mine to propose, the author's to
take.

## The survey (2026-10-07, checked by `kernels/l4/survey.sh`)

Two references. **seL4** (`github.com/seL4/seL4`, 16.0.0-dev of
2026-10-04), with its manual in the same repository (`manual/parts/`,
3,811 lines of LaTeX in 11 files) and its tutorials
(`seL4/sel4-tutorials`). **L4Ka::Pistachio** (`l4ka/pistachio`), an L4
of the generation before: threads named by numbers, no capabilities,
pages given by `map` and `grant` messages.

What I read today: seL4's lists (its system calls, objects, methods,
the root task's boot information), its files by their sizes, the
manual's sections by their titles, the tutorials' names; Pistachio by
its files' sizes. The manual's chapters and the papers (Liedtke's
"On µ-Kernel Construction", 1995; Klein and others' "seL4: Formal
Verification of an OS Kernel", 2009; Elphinstone and Heiser's "From L3
to seL4", 2013) I know from before and **did not read again**: to do
before the stage that needs each.

**The licences** (the script counts them): seL4's kernel is GPL
2.0-only (316 of `src/`'s files), its manual too; the library a
program links (`libsel4`) is BSD 2-clause, the tutorials too;
Pistachio is BSD. ix is LGPL 2.1, which cannot take GPL's code. So, as
for Singularity: **read, never copied**; nothing of seL4 in the
repository. The names of its calls are what a program of its links
against, BSD's. (My reading; the author's to confirm.)

| seL4 | lines | what |
|---|---:|---|
| `src/` | 53,356 | the kernel: C, assembly, bitfield declarations |
| `include/` | 29,465 | its headers |
| **the part that is no machine's** | **11,285** | `object` 6,612, `kernel` 2,637, `api` 928, `fastpath` 920, `model` 188 |
| in it, the largest | | `tcb.c` 2,118, `boot.c` 1,130, `objecttype.c` 1,024, `cnode.c` 934, `fastpath.c` 920, `thread.c` 752, `syscall.c` 667, `endpoint.c` 577, `notification.c` 419, `untyped.c` 305, `interrupt.c` 297 |
| `src/arch/arm` | 15,474 | of which arm32's own 5,638, arm64's 4,233 |
| `libsel4` | 11,171 | what a program links: the stubs, the types |

| Pistachio's kernel | lines | |
|---|---:|---|
| `src/` | 85,593 | C++ and assembly, nine machines |
| `src/api/v4` | 13,232 | the kernel proper; its `.cc`: `thread` 1,631, `ipc` 724, `ipcx` 456, `exregs` 455, `space` 430, `schedule` 400, `interrupt` 360 |
| `kdb` | 15,225 | its debugger |

What a small one must have, from seL4's lists:

- **Eight system calls**: Send, NBSend, Call, Recv, NBRecv, Reply,
  ReplyRecv, Yield (and one to print a character, in a debug build).
  All are about a message. **Everything else is a message to the
  kernel**: a Call on a capability to a kernel object, which the
  kernel answers itself.
- **Five kinds of object** that are no machine's: Untyped, TCB (a
  thread), Endpoint, Notification, CNode (a table of capabilities);
  two more for real time (a scheduling context, a reply), which the
  first configuration does without. The machine's: a page, a table of
  pages, of each of its sizes.
- **44 methods** on those: TCB 21, CNode 9, IRQ 4, Untyped 1 (retype:
  the one way an object is made), and 9 for the schedulers; arm and
  arm64 add 31 (pages, tables, and 20 for a hypervisor's and an
  IOMMU's objects).
- **A message**: a label, 120 words at most, the first 4 in
  registers, the others in a page the thread shares with the kernel
  (its IPC buffer); capabilities may go with it; the receiver is told
  the **badge** of the capability the sender used, which is how a
  server knows its clients apart.
- **The root task's start**: one frame of information (`seL4_BootInfo`:
  where its own capabilities are, which slots are empty, and the list
  of untyped memory, the devices' included). Nothing else is running.
- **Its own measure** (`sel4.systems/performance.html`, cycles, the
  first configuration): a call to a server in another address space
  368 and the reply 352 on a Cortex-A9 (arm32), 413 and 426 on a
  Cortex-A57 (arm64); a signal to a thread of higher priority 1,027
  and 1,054; an interrupt to its handler 776 and 886. These are with
  its fast path (920 lines of C for the one common case).

What ix has (the same script):

| a microkernel needs | ix | |
|---|---|---|
| the boot, the traps, a process behind the MMU, a switch of address space, the timer | `kernels/lib_machine`: 849 lines of OCaml, 1,429 of C, 725 of assembly, both boards; what mini-xv6 runs C programs on | there |
| threads, a scheduler, system calls decoded | mini-xv6's `Proc`, `Syscall`, `Exec`: 465 | to write, known ground |
| translation tables, by the board | `Mmu` 232 over `Arch`; it takes a table's page from the kernel's own free list | to write again over `Arch` (decision 5) |
| a program that is no part of the kernel | mini-singularity's: built as for Linux, its system one file of C, 161 lines | the same, with a trap in the call's place |
| a file system to put out | mini-xv6's `Fs` 422 and `File` 208; `Fs` names of the kernel `Machine.Phys`, `fs_base`, `le`, `panic` and `Proc.myproc` | by a link, if those five part cleanly |
| drivers to put out | the UART (in `machine.c`), `Screen` 106, `Usbhost` 178 over `usb.c` 151 | the UART first |
| capabilities | `Cap.*`: an OCaml program's `main` given what it may touch, checked by the types | the idea, not the mechanism |
| the other side of the comparison | mini-singularity: `Process`, `Channel`, `Exchange`, `Abi` 591; its `numbers.sh` | there |

## The rule: one directory

As mini-oberon and mini-singularity: the kernel, the programs that are
the system, their library and the tests are in `kernels/l4/`; what is
shared with the other kernels is there as a symbolic link, one a file.
Unlike mini-singularity, nothing of this system lives in the compiler:
a program is any program, and I see nothing that must be outside.

The layout I propose:

    kernels/l4/
      mkfile  survey.sh  numbers.sh  README.md
      Cap.ml          a capability, a slot, the derivation tree: copy, mint,
                      move, delete, revoke
      Untyped.ml      memory not yet anything; retype
      Thread.ml       a thread and its states; the scheduler
      Endpoint.ml     send, receive, call, reply: the rendezvous
      Notification.ml signals; a thread bound to one
      Vspace.ml       an address space: tables and pages mapped by their capabilities
      Irq.ml          an interrupt made a signal
      Invoke.ml       a message to the kernel: the methods, by the object's kind
      Syscall.ml      the eight calls, the faults
      Boot.ml         the root task made by hand, its boot information
      Main.ml
      machine/        links: Machine, the boards' Arch, machine.c, l.s...
      lib/            what a program links: L4 (the calls and methods, by the
                      manual's names), and what seL4 leaves to libraries:
                      Slots, Memory, Process (a program made a process)
      servers/        root (the root task), console, ramdisk, files, shell
      programs/       the tutorials' steps, each a program; ping, pong, bench
      tests/

(`Cap` is also the name of ix's capabilities library, which this
system's programs may want; if the two meet, this one is
`Capability`.)

## Decisions to take (the author's; my proposals)

0. **The name: mini-l4, `kernels/l4/`.** Not mini-sel4: a `mini-`
   elsewhere in ix is a twin, and seL4's own name is its proof. It is
   an L4 of seL4's generation.
1. **The model: seL4's first configuration, less its machines.** The
   objects: Untyped, Thread, Endpoint, Notification, CNode, Frame,
   PageTable, and the interrupts' two capabilities (the right to make
   a handler, a handler). Not here: scheduling contexts and reply
   objects (its real-time kernel), domains, several processors, a
   hypervisor's virtual processors, the IOMMU, the pools of address
   space identifiers, the pages' other sizes, breakpoints.
2. **A capability is a variant, a slot a record in a tree.** `Null |
   Untyped of ... | Endpoint of endpoint * badge * rights | Thread of
   ... | Frame of frame * rights | Reply of thread | ...`; a slot
   holds one and knows its parent and children, so revoke is a walk.
   seL4 packs a capability in two words and keeps the tree as one
   list in a clever order; nothing of that layout is wanted. The
   rights are read, write and grant (who may send a capability).
3. **A thread's capabilities are one table, one level.** A capability
   is named by its index in the thread's CNode, whose size is chosen
   when it is made. seL4's space is a tree of CNodes with guards,
   walked like a page table, an address read to a depth; the manual
   gives it some 240 lines, and the tutorials' first steps work in
   the root task's one CNode. A loss: no
   CNode inside a CNode, so a server cannot be handed a subtree.
4. **Untyped memory is real for pages, an account for the rest.** An
   untyped is a range of physical pages with a mark; retype moves the
   mark; revoking all its children brings it back: seL4's rule as it
   is. A frame and a page table are pages of that range. A thread, an
   endpoint, a CNode are OCaml records in the kernel's heap, and
   retype charges the untyped what seL4 would (a thread a page...), so
   that who holds little memory can make few objects. **The kernel's
   heap is still its own**, of a fixed size, collected: what seL4
   proves (the kernel uses no memory it was not given) is here an
   account kept, not a fact.
5. **Page tables are objects, as seL4's.** A program that maps a page
   where no table is yet is refused, retypes a `PageTable`, maps it,
   and tries again: seL4's `mapping` tutorial, and the reason the
   kernel never looks for a page of its own. A table goes to the first
   level that lacks one (seL4's rule on arm64), so a program does not
   know that the Pi 1 has two levels and the Pi 4 three. `Mmu`'s own
   `map` takes its tables from the kernel's free list: `Vspace` is
   written over `Arch`'s entries instead, not over `Mmu`. The other
   way, tables hidden and charged to the address space, is shorter in
   the programs and loses the point.
6. **Eight system calls, and about twenty methods.** The calls as
   seL4's, with the character printed. The methods: `Untyped.retype`;
   CNode's copy, mint, move, delete, revoke; Thread's configure (its
   CNode, its address space, its IPC buffer, where its faults go),
   write and read registers, resume, suspend, set priority, bind a
   notification; Frame's and PageTable's map and unmap; the
   interrupts' three (a handler made, its notification set,
   acknowledge). Not here: seL4's 44 less these.
7. **A message as seL4's, smaller.** A label, words (4 in registers,
   the rest in the thread's IPC buffer, a frame the kernel reads by
   its physical address; how many is a constant, less than 120), one
   capability at most (seL4: three). The badge is delivered. A call
   leaves the right to reply in the receiver's thread, used once. **No
   message of bytes**: what is large is a frame mapped by both, which
   is this system's answer to Singularity's exchange heap and goes in
   the table beside it.
8. **Priorities, round robin in each, the timer's tick**: seL4's 256.
   `kernels/lib_machine` has the tick and mini-xv6 already takes a process's
   processor away with it. The kernel itself is never interrupted, as
   seL4's and as the other kernels here.
9. **A fault is a message.** A thread that touches no page, names no
   capability or runs no instruction is stopped, and a message with
   what happened is sent to the endpoint it was configured with; the
   reply starts it again. No fault kills anything in the kernel.
10. **A program is OCaml's, built as for Linux, in its own address
    space.** As mini-singularity's processes: mini-ml, its run-time
    system, the C library, and one file of C (`lib/l4.c`) that is the
    system under them, here a trap. Every program is linked at the
    same address, having its own space: **several instances of one
    program**, which mini-singularity cannot have. No `-safe`: what a
    program writes does not matter, which is the point; mini-cc's C
    would do as well. **One thread an address space**: mini-ml's
    run-time system has one heap and one stack of values, so seL4's
    `threads` tutorial (two threads in one space) becomes two
    processes. A loss, the same as mini-singularity's.
11. **The kernel starts one program, the root task**, as seL4:
    `Boot` makes by hand its CNode, its address space and its thread,
    and fills a frame with what it is given: all the untyped memory,
    the devices' registers as untyped memory of their own, the right
    to the interrupts, and the other programs' images as frames (they
    are in the kernel's image, as mini-singularity's).
12. **A small library in the place of seL4's large ones.** seL4 gives
    a program stubs and nothing more; who keeps track of free slots
    and of untyped memory, and who makes a process (a CNode, a space,
    its tables, its image copied, a thread, its registers) is the
    program's affair, and seL4's own libraries for it are far larger
    than its kernel's interface. Here `lib/`: `Slots`, `Memory`,
    `Process`, each as naive as holds. **Where L4's size may be
    lost**: stage 4 will say.
13. **The system taken out of mini-xv6**: the console (the UART's
    registers and its interrupt given to a driver), a RAM disk, a file
    server (mini-xv6's `Fs` by a link, if it parts from the kernel;
    else a smaller one), a shell of its own. A protocol is a module
    written by hand over labels and words: **nothing checks it**, and
    a server must doubt every message; that too is the comparison with
    mini-singularity's contracts.
14. **The console is the UART**, both boards, mini-qemu and QEMU
    first. No graphics. The kernel prints only by the debug call.
15. **Simple first, the fast path after and apart.** L4's fame is a
    message's cost, got by design and then by a path of its own for
    the common case (seL4's 920 lines). Here the plain path is written
    and measured first; a fast one is a later stage, in a file of its
    own, that can be turned off.

## What is checked

- **The tutorials' steps**, each a program with its expected lines on
  the console, under mini-qemu and QEMU, on both boards; then the
  system's session at its shell, as mini-xv6's.
- **The isolation's own tests**: a program that reads an address it
  has no page at is stopped, its handler told, the system goes on; a
  capability's index that holds nothing is refused; an endpoint
  minted without the write right cannot be sent on; a server sees its
  clients' badges; an untyped revoked takes back the threads made
  from it, which run no more; a driver that faults is made again and
  its clients served.
- **The table** (`numbers.sh`, mini-singularity's with its columns,
  under mini-qemu, in the guest's instructions): a call to the kernel,
  a yield, a message there and back, the same with a megabyte (here a
  frame's capability sent and mapped), a byte of it read and one
  written, a process made and ended; and seL4's own two, a signal and
  an interrupt to its handler. For mini-l4, mini-singularity, and
  mini-xv6 and mini-9pi by their nearest equals. mini-singularity's
  today: a message there and back 27,406 instructions on the Pi 1 and
  19,207 on the Pi 4, a process 11 million.
- **What the instructions do not say.** mini-qemu counts instructions;
  an address space switched costs few of them and many cycles (the
  TLB emptied, the caches), which is the very cost Singularity's
  papers argue from. So the table under mini-qemu will flatter
  mini-l4, and the honest one is **on the boards themselves, by their
  cycle counters**: the author has both. To plan with stage 9.

## The manual's chapters, and where each lands

| the manual (`manual/parts/`) | lines | here |
|---|---:|---|
| `objects.tex`: the kernel's services and objects | 503 | decision 1; `Untyped`, `Invoke` |
| `cspace.tex`: capability spaces | 549 | `Cap`; decisions 2 and 3 (its addressing, some 240 lines of it: not here) |
| `ipc.tex`: message passing | 286 | `Endpoint`; decision 7 |
| `notifications.tex` | 67 | `Notification` |
| `threads.tex`: threads and execution | 794 | `Thread`; decisions 8 and 9 (its scheduling contexts, some 190 lines: not here) |
| `vspace.tex`: address spaces and virtual memory | 383 | `Vspace`; decision 5 |
| `io.tex`: hardware I/O | 490 | `Irq`, its first 50 lines; the rest is x86's ports and arm's IOMMU |
| `bootup.tex`: the system's bootstrapping | 248 | `Boot`; decision 11 |
| `api.tex`, and the methods' reference made from `libsel4` | 332 | `lib/L4`; decision 6 |

## The stages (each checked before the next)

They follow the tutorials.

0. **The ground.** `kernels/l4/mkfile` and the links: a kernel that
   boots on both boards and prints a line (mini-singularity's stage 0,
   again).
1. **`hello-world`: the root task.** A mini-ml program in its own
   address space, in user mode, made by `Boot`, printing by the debug
   call, with its boot information read. The plan's first risk: a
   program built as for Linux running on `kernels/lib_machine`'s traps (mini-xv6
   runs xv6's C there, mini-9pi Plan 9's programs and ix's own built
   for Plan 9; one built as for Linux, put in memory by the kernel's
   hand and not by an `exec`, not yet).
2. **`capabilities` and `untyped`**: `Cap`, `Untyped`, the CNode's
   methods, retype, revoke; endpoints made and deleted with nothing
   yet sent. The tests of refusal.
3. **`mapping`**: frames, tables, `Vspace`; a page mapped, written,
   unmapped, mapped twice.
4. **`threads`, as processes**: the Thread's methods, the scheduler,
   the tick; `lib/Process`; the root task starts a second program,
   then two of the same. The library's size known.
5. **`ipc`**: endpoints, the eight calls whole, badges, a capability
   in a message, the reply; `ping` and `pong`, a server with two
   clients. The first numbers.
6. **`notifications` and `interrupts`**: signals, a thread bound to
   one; the devices' untyped memory; the UART's interrupt to a driver.
7. **`fault-handlers`**: a fault made a message; a program that
   faults stopped, looked at, started again.
8. **The system**: the console's driver, the RAM disk, the file
   server, the shell; the session's check.
9. **The table**, under mini-qemu, then on the boards.
10. Later, each to be decided: the fast path; a server that answers
    xv6's system calls, so that xv6's own programs run on it
    unchanged (L4Linux's idea, small); threads in one address space;
    riscv64 ([`plan_riscv.md`](plan_riscv.md)); the screen and USB as
    drivers.

## The size

A guess, to be held against what is written. The kernel **1,500 to
2,200 lines** of OCaml with its interfaces (seL4's part that is no
machine's is 11,285 of C, a third of it `tcb.c`, `boot.c` and the fast
path; mini-xv6's whole kernel is 1,447 without its interfaces) and
almost no new C or assembly: the traps and the switch are
`kernels/lib_machine`'s. The library **400 to 700** (decision 12: the least
sure). The servers and the shell **600 to 900**, of which `Fs`'s 422
by a link if it comes. The tutorials' programs and the tests **300 to
500**.

## Not checked yet

- the manual's chapters and the papers: not read again (above);
  seL4's sources looked at by their sizes and lists. Nothing was built
  or run, of seL4 or here;
- **stage 1's risk**: what `kernels/lib_machine`'s trap path and `runtime.c`'s
  process slots ask of a program, and whether a mini-ml image linked
  for Linux can be the root task without a change in the compiler or
  the linker;
- how the kernel reads a trap frame's registers one call of C at a
  time (`Machine.tf_get`), and what a message costs so: decision 15
  may come sooner than a later stage;
- that `Arch`'s entries are enough to write `Vspace` without `Mmu`,
  on both boards, and what mapping one frame in two spaces asks of
  the caches on the Pi 1;
- the kernel's heap: how large for the objects a board's memory could
  be retyped into, and what the kernel does when it is full (seL4 has
  no such case);
- `Fs` without `Machine` and `Proc`; whether one thread a server is
  enough for a file server whose disk is another server;
- the devices' interrupts on both boards beyond the timer's and the
  UART's; the debug call and a console driver both writing the UART;
- the cycle counters on the Pi 1 and the Pi 4, and whether user mode
  may read them;
- L4's numbers (Liedtke's, and Elphinstone and Heiser's table of a
  message's cost over twenty years): remembered, not looked up, so
  not written here;
- the licence's reading above.

## After it

The other answers to "what else could we add?", for a plan of their
own if they are wanted, each for the one idea ix lacks:

- **mini-xen** (now [`plan_system_xen.md`](plan_system_xen.md)), a hypervisor: the kernel's processes are whole
  kernels, and the guests exist (mini-xv6 and mini-9pi side by side on
  the Pi 4). Its cost is the machine's: a third privilege level and a
  second translation in mini-qemu.
- **mini-mirage**, a library OS: a program linked with the pieces of
  kernel it needs and nothing else. The kernels are OCaml's already.
- **mini-inferno**, a virtual machine as the process's boundary: the
  same programs on every machine, three once riscv64 is there. Near
  mini-singularity's ground.
- **mini-smalltalk** (now [`plan_system_squeak.md`](plan_system_squeak.md); or KeyKOS's checkpoints): an image that
  persists, no file and no boot. The furthest from what is here, and
  the worst fit for OCaml's heap.
