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

**Status: done** (2026-10-23 to 2026-10-26): spawn, TinyKernelMemory.ml,
segments (`MEMORY=segments`) and pages (`MEMORY=pages`), partitions
the default; each stage's section says what was built and measured.
Left: the guard page under the stack (where a stack ends is the
program's runtime's, mlsys.c's), a text shared between execs under
pages (a cache of a file's pages), swapping (plan_kernel_swap.md is
mini-9pi's), the third segment (the stack's, an exercise); stage 1's
leftovers (the a.out sizes against what programs use, a message for a
program that outgrows its partition, the Makefile relinking on a
`MEM_` change); the four-core self-build numbers
(plan_tiny_multicore.md's Status).

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
in HEAD either, by timing: `tetris.wav` and three pairs of lines of
`trace -f rc -c 'cat f | wc'` interleaved otherwise (session 26).
(Thought then to change from run to run: wrong, every run is the same
for a kernel, by `make check`'s -date and -seed; the 148,894 to
148,936 bytes were runs without them, or other kernels. The records
were behind the kernel; see the Status, 2026-10-26.)

## Stage 3: segments (done, 2026-10-26)

What the plan said first was wrong in one place: the a.out's header
had the image's size, not the text's, and nothing in tiny-assembler
or tiny-linker told text from data (an object is one stream, a
module's code and its statics one after the other). Both compilers
kept their statics in a buffer of their own, emitted after the code,
so the split cost a line in each:

- **tiny-assembler**: `.text` and `.data`, a line `text` or `data` in
  the object.
- **tiny-ml, tiny-c**: `.data` before their statics (the closures,
  strings and exceptions that are static blocks, the globals' tables;
  C's globals). Everything ML writes is there, so a text is code
  alone. `end.tm`'s `_end` is in the data too (mlsys.c's stack of
  values starts past it).
- **tiny-linker -n**: each piece its section (an object starts in the
  text, a piece goes on in its object's: the sweep keeps or drops it
  with it), the text's pieces first, then the data's from the next
  4 KB, Unix's 0410; the header a fourth word, the text's size, and a
  magic number of its own (0x7a0ce6 beside 0x7a0ce5, as 0410 beside
  0407). Without -n the sections are ignored, the images as before
  byte for byte (lite's linker and compilers' recorded cases).
- **tiny-machine**: 32 of status, split, with relocate: below `tbound`
  (a register of control, 17) the text's, at `tbase` (16), a store a
  fault; above it the data's, `base + (a - tbound)`, below `bound`.
- **The kernel** (TinyKernelMemory.ml's Segments, about 120 lines):
  a text a block of its own with its users, keyed by its file (an
  image's file by its address; a disk's by its inode, its date and
  size the stamp; a file of memory not shared), taken by an exec
  while its file is unchanged (a file opened to be written:
  `mem_forget`); fork shares it and copies the data; a word the kernel
  writes in a text (a breakpoint) makes it the process's own, a copy;
  a read's buffer or a call's result in a text is Bad. Every program
  is linked with -n, under partitions too, which load the image as one
  block: the same addresses in both, one set of binaries. The choice:
  `MEMORY=segments`, `/lib/memory` in the image (and the Buildfile's,
  so that self builds the same image), under `_make-segments`; the
  boot line says "in segments".
- entry.tm: k_window's two more words, the slave's mailbox's 24 and
  28; k_enter sets split only when tbound is not 0, by `sltu` and no
  branch (k_step counts its instructions to eret: 31, now 34).

What it costs, the host's instructions in the toolchain session
(tests/icount.c): every process split, partitions too, 321.7 thousand
million against 300.5, 7%; split only with a text, partitions 296.74
against 296.71 (a test more), segments 303.3, 2.2%.

What it gives here: a text read only (a program that writes over its
own code is killed: `*(int*)main = 0`, tried, a fault under segments,
"after" under partitions) and one copy of it for its runs (two cats of
a pipeline took the first's: instrumented once, `[rom 3150798]`). The
memory saved is small beside partitions of megabytes: ml's text is
448 KB of its 532 (as 128 of 205, cc 260 of 339; the data's 77 KB
are mostly libc's heap), so four ml's save 1.3 MB of their 128. The
teaching is the point, as planned: Unix's 0410 by the same few
functions.

Checked: TinyKernel's check under both, against the records
re-recorded for the layout (a program's labels moved: libc's heap
after the code, `main` at 0xfec where it was at 0x1100c; the debug
window's registers; 2 KB less free on the disk, each program up to
4 KB of padding) and for the timing (session 26's background loop);
`toolchain.keys` links ping with -n; self-quick under both (its
recipes' echo with -n; segments' boot line); make test-lite. Not
run: self (hours; `self.expected`'s recipes edited the same way, and
already behind on ld's 48 MB), self-cores, the four-core build.
Left: the third segment, the stack's (an exercise).

## Stage 4: pages, off by default (done, 2026-10-26)

- **tiny-machine**: satp's bit 30, user only: user mode's addresses
  translated, the kernel's physical (the PDP-11's two sets of mapping
  registers). Without it the kernel would need its memory in every
  process's tables, where a process's addresses from 0 overlap the
  kernel's 32 MB; v6's way (both translated, the bit clear) stays, the
  machine's paging test unchanged. A cache of 64 translations, user
  mode's, emptied when satp is written (k_window writes it at each
  run: the kernel's sfence.vma).
- **The kernel** (TinyKernelMemory.ml's Pages, 110 lines of code, xv6's
  kalloc.c and vm.c's part in about as many): the frames above 32 MB a
  free list through the free ones, those never given past `untouched`
  (no list of 57,000 at the boot); a byte of users per frame at
  0xb51000 (TinyKernel.mli's layout); a root per process, a table per
  4 MB made when needed. exec: a root, then the pages the loader writes
  (room for all of them checked first, so that a load does not fail
  half way); a page touched the first time given zeroed (`mem_fault`
  from the trap: the instruction run again); fork shares every page,
  the writable ones read only and copy-on-write (Sv32's software bit)
  in both; a write there copies, or makes it writable when its last
  user. The text's pages read only: a store there kills, as with
  segments. The kernel writes a page only after making it the
  process's own (`mem_writable`, a breakpoint's `mem_store`), and
  reaches a buffer a page at a time: read and write go through stage
  2's bounce when one crosses a page, its first real use.
- **Several cores**: satp in the mailbox (64 bytes a core now); a
  process's tables change only while it is not running, and every run
  writes satp: no shootdown.
- `MEMORY=pages`, `_make-pages`, "in pages" on the boot line.
- Not done: the guard page under the stack (where a stack ends is the
  program's runtime's, mlsys.c's, not the kernel's to know), a text
  shared between execs (a cache of a file's pages), swapping.

What it costs. The host's instructions in the toolchain session
(tests/icount.c), all three on the same machine: partitions 293.6
thousand million (296.7 before stage 4: the translation's function
made smaller, below), segments 300.2, pages 341.8. On the way: a
function call for "paged" at each access cost 7% with partitions; an
`||` in translate's test, 2.5%; the walk's closures made at each access,
cache or not, 8% of pages'. Now translate is one test, the walk a
function of its own (which looks at user only), its closures only on a
miss. The machine's own time for the session (its instructions, by
-cores 2): partitions 713.7 million, segments 709.6, pages 724.4: the
faults' work about what the copies of fork and exec cost the others.

Checked: TinyKernel's check under the three (pages: the paint
session's cursor a few pixels away, its mouse read at another time;
the timing lines of session 26 as in the other two); a pipeline and
four jobs at once on four cores under each; TinyMachine's tests (the
paging test); make test-lite.

## Status

2026-10-23: plan written; stage 1's spawn built and checked (above);
stage 2, TinyKernelMemory.ml, done but for `user_iter`.
2026-10-25: `user_iter` and the bounce (stage 2, above): stage 2
done.
2026-10-26: stage 3, segments, done (above), behind MEMORY=segments.
The same day, stage 4, pages, behind MEMORY=pages: the plan done but
for the guard page (above). `check.expected` re-recorded with stage 3
(its timing lines too). Then the check steadied: nothing in it changes
from run to run (six runs at once, the same bytes), but two parts
moved with any change of the kernel's speed: session 26's `trace -f`,
now a process's lines after another's (`>[2] t` and a grep for each),
and its loops' output among the prompts, now in files shown after
`wait`; `tetris.wav`'s sum, behind since stage 2, re-recorded.
Not measured yet: the self-build on four cores (`-j 6`) with spawn,
beside the same with fork and one core with fork (plan_tiny_multicore.md's
Status will have the numbers).
2026-10-26: done; moved to docs/plans/done/.
