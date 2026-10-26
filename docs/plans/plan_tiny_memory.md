# Plan: tiny-kernel's memory: partitions, then segments, then pages

The author (2026-10-23), after the first four-core builds
(plan_tiny_multicore.md) ran into the partitions' limits: "I wonder if
those partitions for the memory are a good idea. Why we didn't do like
classic kernels use virtual memory? What were the pros and cons?";
then, given three ways (keep partitions and fix what hurts; pages;
segments in between): "let's do 1 for now, but I also like 3 for its
teaching value, and also 2 so we could have dynamically the 3 memory
model, switchable at compile-time or runtime with some if and flags in
the kernel and emulator. I like the idea of a spawn, and actually some
OS do not have fork/exec but only spawn, so providing fork, exec, and
also spawn seems good to me. [...] We can add the code for pages but
disable it for now by default"; "hopefully the code does not get too
complicated with segments and pages added in addition to partition or
the code added is behind flag so it's easy to skip for the reader if
needed"; "also please add notes about OS/360 and partitions and
Denning, and segments and PDP11 and 386, and pages and so on, with
cs-history"; "the kernel is special and we already did split in files
for FS, audio, network, graphics, so one more for memory is fine".

## The short answer

```
   one kernel, three ways to give a process memory (TinyKernelMemory.ml)

   partitions (default)     segments                  pages (off by default)
   ┌──────────────┐         ┌──────┐ text, shared     ┌─┬─┬─┬─┬─┬─┬─┐ 4 KB each,
   │ text data    │         │ text │ by its runs      │ │ │ │ │ │ │ │ anywhere,
   │ heap   stack │ one     └──────┘                  └─┴─┴─┴─┴─┴─┴─┘ given when
   └──────────────┘ block   ┌──────────────┐ data,    a table per process:
   base, bound: an add      │ data heap stk│ one      demand-zero, copy-on-
   and a compare            └──────────────┘ block    write fork, a guard page
   OS/360, CDC 6600         PDP-11/45, 8086, 286      Atlas, VAX, 386, RISC-V
```

- **Partitions stay the default** and the first thing a reader meets:
  what tiny-kernel does today, one block a process, a relocating
  window (base, bound).
- **spawn** (stage 1, done): fork and exec in one, beside fork and
  exec, so that a parent of 16 MB does not copy itself to start rc.
- **One file, TinyKernel/TinyKernelMemory.ml** (stage 2), beside
  TinyKernelFS.ml and the others: the few functions the kernel asks of
  memory (a space for a program, a copy for a fork, a user's address
  for the kernel, the window or table to give a core). Partitions
  first in it; segments and pages after, each a section of its own
  that a reader can skip.
- **Segments** (stage 3): tiny-machine's window split in two, the
  text's and the data's; one copy of a program's text for all its
  runs, the text read-only.
- **Pages** (stage 4, off by default): Sv32, which tiny-machine has
  had since v6; demand-zero pages, copy-on-write fork, a guard page.
- **The choice at boot**: a word in the boot image (the Makefile's
  `MEMORY=partitions|segments|pages`), read by the kernel once: one
  `match` in the few functions, no flag anywhere else.

## Why

The report of 2026-10-23 (in the conversation; the gist here). A
partition is one contiguous block, sized by the program's a.out
header (`tiny-linker -a`), found first-fit, never grown; the machine
adds base to every user address and checks it against bound. That is
an add and a compare in tiny-machine, `base + va` in the kernel, and
nothing to flush on the other cores. Its costs all showed in the
first self-builds on four cores:

| What happened | The partitions' part | What fixes it |
|---|---|---|
| `ld` killed linking bin/ml (32 MB) | a size guessed at link time, never grown | pages (a heap that grows), or a bigger guess (done: 48) |
| `as: not found` under -j 6 | memory reserved whole, not used: six compilers of 32 MB | pages (demand-zero); with_room waits (done) |
| a 32 MB hole missing with enough free | external fragmentation, first-fit | pages |
| core 0 73% in the kernel, the others 61-80% idle | fork copies build's 16 MB at each recipe | spawn (stage 1); copy-on-write (pages) |
| four ml's, four copies of its 540 KB | no sharing | segments or pages |
| a partition starts with its last owner's bytes | no zeroing (it cost 35 M instructions an exec) | pages (zeroed when touched) |

## Stage 1: spawn (done, 2026-10-23)

- The kernel's call 28, `spawn(path, argv)`: a slot and a partition of
  the program's size, the program loaded as exec loads it, the
  parent's descriptors and directory; its pid, or -1. Waits for room
  as fork does (`with_room`). Traced when the parent's children are
  (trace -f), as a forked child.
- fork and spawn share `child` and `adopt`; exec and spawn share
  `program` (the path and arguments read from the caller).
- libc's `spawn`, mlsys.c's `u_spawn` (the window system's own,
  which forks, dups five descriptors and execs, renamed
  `u_spawn_window`), TinyCalls' `u_spawn`, the tracer's table.
- TinyLibSystem.shell (tiny-kernel's): the parent writes the script's
  file (named by its pid and a count) and spawns rc on it; old: a
  fork, the child writing the file and exec'ing rc.
- What a fork lets a child do before its exec (a dup, a close) is,
  with spawn, the parent's to do around the call: the child has the
  parent's descriptors as they are. tiny-build needs nothing there.
  rc keeps fork: its redirections and pipes are done in the child.
- Checked: TinyKernel's check (paint, debug, tetris.wav and the
  traces re-recorded: addresses moved by libc's 20 more bytes, and
  timing); a traced build shows `spawn("/bin/rc", ...) = 9`.
- To measure: the self-build on four cores with spawn against fork
  (Status).

Left in stage 1: the a.out sizes (`MEM_*`) against what `-t` and the
counts show each program uses; an out-of-memory message for a
program that outgrows its partition (ld died on an illegal
instruction, bugs/ix.md); the Makefile relinking a program when its
`MEM_` changes (it does not: the ld of 48 MB needed a `rm`).

## Stage 2: TinyKernelMemory.ml, partitions alone (done, 2026-10-23)

Moved out of TinyKernel.ml (1,818 lines to 1,795; the module 95, its
.mli the memory's chapter), no behaviour changed: every screen of the
check the same; tetris.wav's length (17 bytes shorter) and two
processes' lines in trace -f's interleaving re-recorded, the kernel
a few calls slower. On four cores (`-cores 4`), a pipeline and a cat
run as before. The functions take a `mem_` prefix, as TinyKernelFS's
take `fs_` (the kernel has its own `write`, `size`). What was planned:

- a process's memory, a record of its own (`space`: base and size
  today), kept in the process;
- `room` (first-fit) and the list of the spaces used, the module's
  own, no longer a walk of the processes;
- `user space va n` (the kernel's address for a user's bytes),
  `copy` (fork's), `load` (exec's image and arguments), `release`,
  and `window space` (what entry.tm and a core's mailbox get);
- its .mli the memory chapter's header: a partition drawn, the
  history notes (moved from TinyKernel.mli; the layout of the 256 MB
  stayed there, being the kernel's whole, and spawn's note, being a
  call's).

Then (2026-10-25) `user_iter`: the kernel reached a user's bytes as
one address (`user p va n`), used by read, write and the strings. With
pages a buffer crosses pages that are not together; so now:

- `mem_pieces sp va n`, the module's: the buffer as the blocks that
  hold it, (the kernel's address, the length) each; one for a
  partition. `user_iter p va n f` (TinyKernel.ml) calls f on each,
  `user_write` writes a kernel string by it (stat's entry, getcwd's
  path).
- `user p va n` (`mem_address`) stays for what is in one piece: a
  word, a byte (the strings read a byte at a time). pipe's two
  descriptors are two words now, ready's descriptors a word each, the
  tracer's `m` a byte each.
- read and write: a buffer in one piece goes to the device as it is,
  every buffer with partitions. One in several goes through **the
  bounce**, 640 KB of the kernel's at 0xb60000 (TinyKernel.mli's
  layout), a write's bytes copied in before, a read's back after
  (xv6's copyin and copyout, Linux's copy_from_user, do that for
  every call), at each try of a call that waits; at most
  640 KB a call then, a read or a write doing less than asked, as
  Unix lets them. The devices are unchanged: several take a message
  whole (draw, il, a box, the speaker), which a call a page at a time
  would cut.
- The fast path asks `mem_address`, not `mem_pieces`: a list at each
  read and write made the kernel slow enough that the check's last
  session ended in another order (an echo in the background before
  rc's prompt, every run).

Checked (private copies of tiny/, against HEAD's the same way): the
check's screens and text as HEAD's. And with every buffer that
crosses 4 KB cut there (`mem_pieces` by pages, `mem_address` -1 for
them: pages' pieces with partitions under them), the same, but the
order of the last session's lines (as above, the bounce costing
time). That check found a fault of the first version, which copied
both ways not to tell a read from a write: a read that waits is
tried again at every turn of the scheduler, and copied its whole
buffer in each time; `seq 30 | grep 1 | sort -rn | cat | wc -l` was
still at it after 100 s (2 s now). Not the same as `check.expected`,
in HEAD either, by timing: `tetris.wav` (its length changes from run
to run, 148,894 to 148,936 bytes for the same kernel) and three pairs
of lines of `trace -f rc -c 'cat f | wc'` interleaved otherwise
(session 26, without other load too).

## Stage 3: segments

- tiny-machine: a second window, the text's: with bit 17 of status,
  an address below `tbound` is the text's (`tbase + a`, fetches and
  loads only, a store faults), one at or above it the data's
  (`base + a - tbound`, below `bound`). Two registers of control,
  `tbase` and `tbound`. Off, the machine is as today.
- The a.out: the text's size in the header already (the image's);
  tiny-linker -n rounds the data's start to the next 4 KB, as Unix's
  0410 rounded it to the PDP-11's 8 KB.
- The kernel: a text is shared by the runs of one file (its count of
  users), loaded once; fork copies the data only; exec of a program
  already running loads only its data.
- What it gives: one copy of ml's 540 KB for four ml's, code that
  cannot be overwritten (a wild store faults instead of corrupting
  the program). What it does not: fragmentation, sizes guessed, fork's
  copy of the data.
- A third segment, the stack's, growing down (the 8086's SS, the
  PDP-11's stack segment that Unix grew on a fault), is an exercise.

## Stage 4: pages, off by default

- tiny-machine: Sv32 is there (v6's); a small cache of translations
  (a TLB, flushed when satp is written), so that a program under
  pages is not several times slower (TinyMachine.mli's exercise).
- The kernel: a frame allocator (a free list of the 4 KB frames above
  32 MB), a table per process, the faults: a page touched the first
  time is given zeroed; a page written that fork shared is copied
  then (copy-on-write); the page under the stack left unmapped (a
  guard: an overflow faults, with a message).
- Several cores: a process's table changes only while the process is
  on core 0 (its trap, its fault) or not running, so no core holds a
  stale translation of it; a core flushes its cache when given a
  process (the mailbox gets satp). No shootdown: master and slaves
  pay off again (plan_multicore.md's mini-9pi needed one).
- What it costs: the frame allocator and the faults, some 200-400
  lines in TinyKernelMemory.ml (a guess, to compare with xv6's vm.c
  and kalloc.c); the machine's speed (to measure).

## Status

2026-10-23: plan written; stage 1's spawn built and checked (above);
stage 2, TinyKernelMemory.ml, done but for `user_iter`.
2026-10-25: `user_iter` and the bounce (stage 2, above): stage 2
done. Next: stage 3, segments. Seen meanwhile: HEAD's own check
fails on tetris.wav and session 26's trace -f order, both timing
(above), `check.expected` and the wav's sum to re-record by the
author's word.
Measuring: the self-build on four cores (`-j 6`) with spawn, beside
the same with fork and one core with fork (plan_tiny_multicore.md's
Status will have the numbers).
