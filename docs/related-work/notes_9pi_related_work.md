# Related work: Plan 9, its kernels, and Plan 9 on the Pi

Where mini-9pi ([`plan_9pi.md`](../plans/plan_9pi.md)) sits. Kernels
in languages with a collector, and xv6, are in
[`notes_kernel_related_work.md`](notes_kernel_related_work.md); the
machine in [`notes_pi_related_work.md`](notes_pi_related_work.md); the
window system on top in
[`notes_rio_related_work.md`](notes_rio_related_work.md). The dates of
the lineage are principia's (`~/principia/kernel/lineage.txt`, read).
What is said beyond a name and a date is **from memory** where marked,
to check before it is quoted in a `.mli`.

## From Research Unix to Plan 9

- **UNIX V8** (1985), **V9** (1985) and **V10** (1989), Bell Labs'
  last: the Blit, a network file system, and in V9 "mount with a
  program at the other end" (the lineage's words: Plan 9's ancestor);
  in V10 the tools Plan 9 kept, mk and rc. From memory: `/proc` as
  files (Killian, V8) and streams (Ritchie) are of those years too.
- **Plan 9** (1993 in the lineage; from memory: shown in 1990, a first
  edition for universities in 1992, a second in 1995, a third in 2000,
  open and with rio and draw, a fourth in 2002 with 9P2000): the same
  group starting again, for a network of terminals, CPU servers and
  file servers.
- **Inferno** (1998; 4.0 in 2007): Plan 9's ideas under a virtual
  machine (Dis) and a safe language (Limbo), as a kernel or hosted on
  another system (from memory).

## The ideas

- **Every resource a tree of files, one protocol for them** (9P; from
  memory: Styx in Inferno, 9P2000 from the fourth edition): the
  console, the processes, the network, the screen and the mouse are
  read and written; a dozen messages (attach, walk, open, read, write,
  clunk, stat...) carry all of it, to a device in the kernel or to a
  program across a network. No ioctl, no sockets.
- **A name space for each process** (bind, mount, union directories;
  rfork's flags say what a child shares): what a program sees is put
  together for it, so the same name is another thing in another
  window (rio), on another machine (import, cpu), in a sandbox. From
  memory: Linux's clone and its mount name spaces come from here.
- **The kernel as a switch of file servers**: a channel (Chan) for
  each open file, a table of devices each with the same ten or so
  functions (attach, walk, open, read, write...), and one device, the
  mount driver, that turns those calls into 9P messages for a server
  outside. mini-9pi's `Chan`, `Dev` and `Devmnt` are that.
- **Devices and services out of the kernel**: the file system on the
  disk is a program (dossrv, kfs, fossil); a USB keyboard is a
  program writing in a kernel file (usbd, `usb/kb`); the window system
  one more file server.
- **Notes** in place of signals (a string, a handler, `noted`); a
  process's last words a string (`exits`, `$status`); errors strings
  (`errstr`).
- **UTF-8** (from memory: Thompson and Pike, 1992, for Plan 9) and
  runes throughout.
- **A small system-call interface**: principia's kernel has 40, where
  Linux has several hundred; most of what a Unix adds calls for is a
  file here.

## Its descendants, and where its ideas went

From memory, to check:

- **9front** (2011-): the fork that is alive: new drivers, a new
  boot, arm64, its own git (git9, mini-git's twin: plan_vcs.md).
- **9legacy**: Bell Labs' last tree with patches kept applied.
- **Plan 9 from User Space** (plan9port; Russ Cox, 2003-): its
  programs and libraries on Unix (rc, mk, acme, sam, 9P servers); what
  ix's differential tests run as "9base's rc" comes from it.
- **9vx** (2008): the kernel as a Unix process, its user programs run
  by a sandbox.
- **NIX** (2011): Plan 9 for many cores, with cores given whole to
  applications. **Akaros** (Berkeley): a research kernel that took
  Plan 9's devices and name space. **Harvey** (2015): Plan 9 built by
  gcc and clang, with an ANSI/POSIX layer. **Jehanne**: a fork that
  redid the system calls.
- **r9**: a Plan 9 kernel being written in Rust.
- **In other systems**: Linux's `/proc`, `clone` and name spaces, and
  v9fs, its 9P client (QEMU's and WSL's shared folders); FUSE (a file
  system as a program, without the name space for each process);
  Redox's schemes; containers, which rebuild with several mechanisms
  what one bind did.

## Plan 9 on the Raspberry Pi

- **9pi** (Richard Miller, 2012; from memory): Bell Labs' kernel for
  the Pi 1, then the Pi 2, 3 and 4; the `bcm` kernel of the fourth
  edition's `sources`, and of 9front (which has a 64-bit one too).
  From memory: the port is where the Pi's USB controller (the DWC2)
  got its Plan 9 driver.
- **principia's 9pi** (`~/principia/kernel`, surveyed 2026-09-26): the
  author's, for the Pi 1, the kernel his book explains (`Kernel.nw`):
  about 67,500 lines of C and assembly with its libraries, 40 system
  calls numbered its own way, a bootdir with rc, dossrv on the SD
  card's FAT as the root, USB's keyboard and mouse in user space, the
  IP stack configured in and no network driver. mini-9pi's
  specification.
- **Inferno on the Pi** (several ports; from memory).
- **xix's kernel** (the author, 2017; surveyed 2026-09-26): 3,635
  lines of OCaml, bytecode, over a C Plan 9 on a Pi 2: threads and a
  timer; it never ran a user program.
- **The other small systems on the same board**: xv6's ports
  (notes_pi_related_work.md), and ix's own, mini-xv6.

## Plan 9, and a safe language

Inferno took one road: keep the kernel in C, make the programs safe,
compiled to a virtual machine with a collector; the protection
between them could then be the language's. Singularity took it to
the end (notes_kernel_related_work.md;
[`plan_system_singularity.md`](../plans/plan_system_singularity.md)).
mini-9pi takes the other: the **kernel** in a safe language with a
collector, the programs as they were, Plan 9's own binaries in C,
protected by the MMU. Biscuit (Go, POSIX, 2018) is that road's
measured example; mini-9pi asks the same of Plan 9's design, where a
kernel is mostly tables of functions over channels, and of OCaml's
variants and records.

## The documents

From memory, to check:

- R. Pike, D. Presotto, S. Dorward, B. Flandrena, K. Thompson, H.
  Trickey and P. Winterbottom, "Plan 9 from Bell Labs" (Computing
  Systems, 1995; a first version at UKUUG, 1990).
- R. Pike et al., "The Use of Name Spaces in Plan 9" (1992); D.
  Presotto and P. Winterbottom, "The Organization of Networks in Plan
  9" (1993); R. Pike et al., "Process Sleep and Wakeup on a
  Shared-memory Multiprocessor" (1991).
- Plan 9's manual: section 2 for the system calls, 3 for the kernel's
  devices, 5 for 9P (intro(5)).
- F. Ballesteros, "Notes on the Plan 9 3rd Edition Kernel Source"
  (2001-), the one commentary on the whole kernel before principia's;
  and his *Introduction to Operating Systems Abstractions Using Plan 9
  from Bell Labs* (2006).
- S. Dorward, R. Pike, D. Presotto, D. Ritchie, H. Trickey and P.
  Winterbottom, "The Inferno Operating System" (Bell Labs Technical
  Journal, 1997).
- principia's `Kernel.nw` and its lineage, read.

## Where mini-9pi sits

It is a twin, not a fork: principia's 9pi written again in OCaml
(10,173 lines with their comments, 2026-10-06, over `kernel/lib`,
against the C's 67,500 with its libraries, not all of which it has),
running principia's own programs from principia's own SD card, and
compared with the C kernel under QEMU and mini-qemu: the console's
bytes, then the screen's pixels. Among Plan 9's kernels it is, as far
as this survey knows, the one in a language with a collector that
boots to rc and runs rio; among kernels in such languages
(notes_kernel_related_work.md) the one whose specification is Plan 9
and not Unix. Since then it also runs ix's own programs and mini-rio
(plan_rio.md).
