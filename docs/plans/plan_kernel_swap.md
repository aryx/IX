# Swap in mini-9pi: memory a machine has not

**Status: planned, not begun.** What is done is before it: the kernel
no longer stops when no page is left (it ends the process that asked,
2026-10-10), and its boot line says its own numbers, "0M swap" among
them. Nothing of a pager is written.

The author (2026-10-10), of `page shapes.pdf` under mini-rio on
mini-9pi, which stopped the machine: "this is pretty serious issue",
"using too much memory can happen", "the kernel should handle that
situation", "it should handle running out of memory"; then "first we
should add a swap", "and the card could have a file or partition for
the swap"; then "let's fix the wrong swap displayed. let's write a
plan_kernel_sawp.md document".

The numbers are `scripts/stats/swap_survey.sh`'s.

## What happened, and what is there now

mini-9pi gives processes the pages from 256 MB to 448 MB on the Pi 1
(`Arch.pages`: 192 MB, 49,152 pages; 128 MB on the Pi 4's build), each
at its first touch (`Fault`). When none was left, `Fault` raised
`Error enovmem`, and the trap's guard made any exception a panic: one
program asking too much stopped the machine, the mouse with it.

Since 2026-10-10 (`docs/plans/bugs/ix.md`):

- **The process that asked is ended** by a note (`sys: trap: fault:
  virtual memory allocation failed va=...`), its pages given back,
  and the system goes on. `make check-hog` in `kernels/9pi` (six
  programs at once asking more than there is, 10 s under QEMU) checks
  it, and shows the panic on the kernel of before.
- **The boot line is this kernel's**: "448M memory: 256M kernel data,
  192M user, 0M swap", where it was 9pi's own line with "1696M swap",
  said so that the consoles compare equal; they are compared without
  the numbers now. `/dev/swap` gives the same numbers, and the pages
  taken.

Not done by that, and this plan's first stage: a page refused inside
a system call (`rfork`'s copy of a segment, `exec`'s table) is an
error to the caller, and the pages already taken for it are not given
back (read, not tried).

Since the same day, **more of the board is the processes'**
(the author: "let's use more of the available memory and let's give
more to user programs"): the kernel's own memory ends at 96 MB, where
it ended at 256 (it has taken 18 MB at its prompt, 30 after mini-page
drew a page: `/dev/swap`'s "kernel malloc" says it now); and the
pages go up to what the firmware gives the ARM, asked of it (496 MB
on the Pi 1 with the card's `gpu_mem=16`, 448 under QEMU), where they
stopped at 448. 352 MB for processes under QEMU, 400 on the board,
where 192 were. `page shapes.pdf` on the bare screen draws its page
there. The boot line says the board's 512 MB and the VideoCore's part
of them: "512M memory: 64M video, 96M kernel data, 352M user, 0M
swap" under QEMU (the author: "it's weird to see 448M when the Pi1 is
advertised with 512MB"). The numbers below, of 192 MB, are of before.

## Why a program asks so much

Before a swap: what fills the memory is mostly one thing. A program
built by mini-ml holds **two halves of a heap**, each a power of two
at least twice what is alive (`languages/ml/runtime/gc.c`: a copying
collector; on Plan 9 a half is at most 64 MB). So 17 MB alive are 128
MB touched, and both halves are written at every other collection.
mini-page on a file of 12 KB is 67 MB by that (arm64 on Linux), and
three such programs are the Pi 1's 192 MB.

This matters for a swap twice: it is why memory runs out, and it is
why a swap helps such a program little. A copying collector reads
everything alive and writes it elsewhere at each collection: every
page of it is wanted again within a second or two. A program larger
than memory does not slow down under a pager, it thrashes. What a
swap gives here is room for the programs that are **not running**:
the shell under a window, the editor left open, the second window's
game. That is worth having; it is not what makes `page` fit.

## Plan 9's pager

`kernel/memory/swap.c`, 491 lines of C, sixteen functions, and 31
lines in `page.c`, `fault.c`, `segment.c`, `devcons.c` and `main.c`
that name them or ask whether a page is out.

- **The swap is a channel**, not a partition known to the kernel:
  a program writes a file descriptor's number to `/dev/swap`
  (`swap /dev/sdM0/swap`, in `/rc/bin/termrc`), and the kernel keeps
  the channel (`setswapchan`). A file or a partition, the kernel does
  not know.
- **A kernel process, `kpager`**, sleeps until pages are needed
  (`needpages`: the free ones under a mark), then walks the
  processes, and in each its segments: a text page is dropped (it is
  in the program's file); a data, bss or stack page whose "referenced"
  mark is off is given a place in the swap (`newswap`), unmapped,
  queued, and the queue written (`executeio`).
- **A page that is out** is a segment's entry that is a swap address
  with a low bit set, not a page (`pagedout`, `onswap`); the fault
  that finds one reads it back (`pio`). A fork copies the entry and
  counts the swap's place twice (`dupswap`).
- **Referenced** is not the processor's bit on arm: the kernel marks a
  page when it maps it, and `gentick` ages the marks, a page unmapped
  to see whether it is asked again.
- **With no swap channel**: `print("out of memory")`, and
  `killbig`: the largest process is ended, not the one that asked.

## What mini-9pi would have

mini-9pi's memory is 330 lines (`Fault`, 98; `Mmu`, 232). A segment is
a table from a page's address to its physical page
(`Types.segment.pages`); a physical page is a number in a list of the
free ones.

1. **A page's entry that can be out**: a segment's table says, for an
   address, a page in memory or a place in the swap (a variant, where
   it is an int). `Fault.fill` reads it back; `Fault.dup` and
   `release` count the swap's places as they count pages.
2. **The swap's places**: a map of the device's pages, each free or
   counted (a `Bytes`: 64 MB of swap are 16,384 of them).
3. **Where it is written**: the kernel's own SD driver (`Devsd`, which
   `Kfs` already reads and writes the second partition with), on a
   third partition of the card, of the type Plan 9 gives its own
   (0x39) or by its place alone. No file system under it: a pager
   that needs the file system needs memory to free memory.
   `mini-mkcard` writes two partitions today; a third, `-swap n`.
4. **The pager**: a kernel process (`Proc.kernel_work`, as the others
   it has), woken when the free pages go under a mark; and the fault
   that finds none waits for it, where today it ends the process.
5. **Which page goes**: no "referenced" mark at first. A segment's
   pages in the order they came (the oldest first), text pages
   dropped before any is written, the running process's last. What a
   mark would add is measured after, not written before.
6. **When the swap is full too**: a process is ended, as now. Which
   one is a decision below.

By Plan 9's 491 lines of C: about 250 of OCaml, an estimate; and
`mini-mkcard`'s partition, about 20.

## Stages (each checked before the next)

- **A. No page left, everywhere.** What `check-hog` does for a fault,
  for a system call: `rfork` and `exec` refused give back what they
  took; a test that forks until refused, then runs a program. The
  kernel's own heap, when it is full: what happens is found out and
  written here.
- **B. The numbers.** Begun (2026-10-10; the author: "would be great
  to have a free command actually displaying various statistics", "or
  a kernel device doing so"): `/proc/n/segment` has a last column,
  the segment's pages in memory, and `free` (`utilities/process`'s
  `Free`, on the card) prints `/dev/swap`'s numbers in megabytes and
  a line a process: what it holds, what it asked for, its name. Left:
  `/dev/swap` and a line of `ps` say what each
  process holds; `make check-hog`'s console says who was ended and
  how much it had. (Before a pager: to see what one would do.)
- **C. The card's third partition**, `mini-mkcard -swap`, seen by
  `mini-fdisk` and by the kernel (`#S/sdM0/swap`), zeros. Nothing
  pages yet.
- **D. A page written and read back**, by hand: a segment's page put
  out by a write to a debugging file, the process going on and
  finding its bytes. The entry, the map, the driver; no policy.
- **E. The pager.** The mark, the kernel process, the order.
  `check-hog` with a swap: the six programs all end by themselves,
  none ended by the kernel; the time it takes, under QEMU and on the
  Pi 1's card.
- **F. With mini-rio**: programs left in their windows while another
  asks for memory; the time to come back to one. `page` on the book.

## Decisions to confirm

1. **A partition, not a file.** A file is easier to make (no card
   written again) and needs the file system at the worst moment. The
   author said either.
2. **The kernel knows the partition**, where Plan 9 is told a channel
   by a program. Plan 9's way keeps the kernel ignorant of disks and
   costs a program and a boot line; here the kernel reads the card
   itself already.
3. **Who is ended when nothing is left**: the one that asked (today),
   or the largest (Plan 9's `killbig`). The one that asked may be the
   shell; the largest is nearly always the cause.
4. **No "referenced" marks at first** (5 above).
5. **The Pi 1's build first**; the Pi 4's has the same code and
   128 MB of pages.
6. **mini-ml's collector is not this plan's.** A heap that gives a
   half back, or does not double, would save more than a swap gives;
   it was tried once and not kept (`gc.c`'s comment: Linux's madvise,
   one system's call). On Plan 9 the same would be `segfree`. Its
   own plan, if wanted.

## Open questions

- **An SD card's speed**: a page is 4 KB; the Pi 1's card reads and
  writes how many a second through `Devsd`? Measured in D. A swap
  that gives 50 pages a second is 5 s for a megabyte.
- **The card's wear**: a swap writes much. A card is cheap; it is
  said here so that it is known.
- **mini-qemu**: its SD card is a file; nothing new is expected, and
  the checks run there too.
- **A process's pages while it is in a system call**: the kernel
  reads and writes a user's memory by its physical pages
  (`validaddr`, then `Phys`); a page put out between the two is the
  bug to avoid. Plan 9 holds a lock on the segment; here the kernel
  is not preempted, which may be enough: to check in D.
- **The draw device's images** are the kernel's memory, not a
  process's: a window system with many windows fills the kernel's
  256 MB, which no swap helps. Not measured.
