# Plan: the gaps, the techniques a textbook of each part of ix teaches that ix does not have yet (all of ix)

The author (2026-10-29), after plan_dotnet.md's table of the
techniques in `languages/` ("that way we would have in languages/ a
good coverage of compiler techniques. c/, pascal P code, smalltalk
vm, scheme SECD, prolog WAM, ML functional language, and dotnet JIT
with tiger (And mini C#)"): "I wonder if we have such good coverage
for other parts of IX"; then "let's start a plan_gaps.md plan
document. note that mini-9pi has a networking TCP/IP stack".

**Status: a survey, nothing built.** This plan is a list to choose
from, not an order of work: each gap, when taken, gets a plan of its
own or a stage in an existing one.

## The measure

`languages/` is good not because it has many languages but because
each is a different way of running one, side by side: a compiler to
the machine, P-code, a bytecode VM, CESK and SECD, the WAM, threaded
code, a fixpoint, soon a JIT. A reader compares them. So a gap here
is a technique that a textbook of the part teaches, that ix has no
program showing, and that would teach something **beside** what ix
already has: a second way, not a bigger first one. The best gaps make
a pair with what exists (greedy and total-fit line breaking; a B-tree
and an LSM tree).

How this was surveyed (2026-10-29): each part's READMEs, its plans
and the headers of its `.mli`, not its code. What is marked *checked*
was read in the code; the rest is what the documents say. The first
pass got two wrong, both corrected here: mini-9pi has its own TCP/IP
stack, and its fork copies on write.

## Where ix already compares

Parts where the techniques are already side by side, as in
`languages/`:

- **Kernels** (`kernels/`): xv6 (a monolithic Unix, processes
  isolated by the MMU), 9pi (Plan 9: everything a file, a namespace
  per process, demand paging and copy on write, *checked*:
  `memory/Fault.ml`), Singularity (isolation by the language,
  channels with contracts), Oberon (one loop, viewers, text as
  commands), Squeak (the image as the system); planned: L4, Xen, DOS.
- **GUI** (`lib_gui/`): four architectures, immediate, retained, MVC,
  MVU.
- **Games** (`games/`): a raycaster, BSP, PVS and a surface cache,
  a z-buffer.
- **Compression** (`lib_compression/`): Huffman, LZW, PackBits,
  deflate (LZ77 and Huffman).
- **Regular expressions**: backtracking (`browsers/javascript/`'s
  `Js_regexp`, Spencer's way) and leftmost-longest without it
  (`lib_core/commons/Regex`, libregexp's answers), *checked*; not yet
  told as a pair.
- **Text in editors**: a gap buffer (emacs), an array of lines (ed),
  pieces (Oberon's `texts/`, *checked*).

## The gaps, by part

Each: what is there, what is missing, and its natural pair. "Planned"
points to the plan that already has it.

### Kernels (`kernels/9pi/`, `kernels/xv6/`)

There: demand paging, copy on write, one run queue (`Proc.mli`,
*checked*), FAT, xv6's file system, kfs.

- **Page replacement** (clock, LRU's approximation): planned,
  `plan_kernel_swap.md`, not begun.
- **Schedulers side by side**: round robin against a multilevel
  feedback queue, lottery, or Linux's fair one; switchable, measured
  on the same load. Small, and one of the most taught.
- **A journal**: a file system that survives a crash mid-write
  (xv6's own log, the simplest one), against FAT's that does not.
- **SMP and locks**: planned, `plan_multicore.md`.
- An exokernel or a library OS: the one isolation design still
  missing beside the five, if L4 and Xen come.

### Networking (`kernels/9pi/network/`, `lib_networking/`)

There, *checked*: mini-9pi's own stack, principia's (Ethernet over
USB, IPv4, ARP, routes, ICMP, UDP, TCP: `network/ip/`, 854 lines);
TCP with its window, go-back-N from the clock, FIN both ways. Above
it TLS 1.2 and 1.3, HTTP/1.1, 9P, DNS, SNTP.

- **Congestion control** (Van Jacobson's slow start and avoidance,
  1988) and **an out-of-order queue**: `Tcp.mli`'s own wib says they
  are what makes TCP work on a real network. To be shown, the
  emulated link must lose and delay packets: a lossy link in
  mini-qemu's or the board's Ethernet, switchable, then the same
  transfer with and without.
- **DHCP**: an address asked, not configured.
- **A server's loop of events** (select, or Plan 9's way of a process
  per connection, which mini-httpd may already be), as a pair.

### Database (`database/`, mini-chidb)

There: a pager, a B-tree, cursors; a register VM as SQLite's VDBE;
SQL compiled to it, selections pushed down a join. `plan_db.md`'s
"Out of scope" (*checked*): transactions and a journal, overflow
pages, deletes, updates, a cost-based optimizer.

This is the part with the most textbook left, and the most valuable:

- **Transactions and a journal**: SQLite's rollback journal first,
  then a write-ahead log, the pair; a crash in the middle and the
  database after, checked.
- **Deletes and updates**, which the B-tree's merge and rebalance
  need.
- **An LSM tree**, a second storage beside the B-tree: writes to a
  log and a sorted memory table, flushed to sorted runs, compacted.
  The pair of storage engines is the lesson.
- **The Volcano model** (open, next, close) against the VDBE's
  registers: two ways of running a plan.
- **A cost-based optimizer**: join orders by statistics, against the
  rules there.
- **MVCC**: later, when there are transactions to make concurrent.

### The machine (`machine/`, `raspberry/`)

There: interpreters for arm and arm64 with a cache of decoded
instructions, MMUs, Linux's and Plan 9's system calls; the page's
translator to JavaScript (`raspberry/web/jit`).

- **Translation by blocks natively**: closures per basic block, or
  host code; `plan_mini_qemu_speed.md`'s point 4 names it. With
  plan_dotnet.md's JIT, ix would have both kinds: a method JIT of a
  typed code, and a binary translator of a machine's.
- RISC-V: planned, `plan_riscv.md`.

### Debugging and profiling (`debuggers/`, `profilers/`)

There: nm, where (tracebacks), the frames named at a suicide,
profiles by counting the emulator's instructions.

- **Breakpoints and single steps**: planned, `plan_debugger.md`
  (mini-acid).
- **A sampling profiler**: the clock's interrupt recording the pc,
  against the exact counts there; and gprof's call graph.

### Typesetting (`typesetting/`)

There: troff and its preprocessors, LaTeX's subset, one document
model, lines filled greedily.

- **Knuth and Plass's line breaking** (a paragraph as a whole, its
  badness minimized), the pair of the greedy filling; TeX's boxes,
  glue and penalties under it.
- **Liang's hyphenation patterns**, which line breaking wants.

### Version control (`version_control/`, mini-git)

There: objects by content, trees, packs and deltas, diff by Hunt and
McIlroy's (Stone's) algorithm, a three-way merge, git's wire.

- **Myers's diff** (1986, git's own), beside Hunt and McIlroy's: the
  same output, two algorithms.

### Editors (`editors/`)

There: ed, emacs, Turbo Pascal's IDE, DrScheme.

- **sam's structural regular expressions** and acme's mouse: the
  Plan 9 editors, which ix's other Plan 9 parts make expected.
- **A rope**, beside the gap buffer and the pieces.
- A modal editor (vi), if wanted; collaborative editing (OT, CRDT),
  later.

### Graphics and GUI (`lib_graphics/`, `lib_gui/`, `windows/`)

There: Bresenham, scanline fill, Hershey's stroke fonts, bitblt;
JPEG, PNG, GIF; PDF, SVG; a window system as a file server (rio).

- **Outline fonts**: TrueType's quadratic curves rasterized, with
  coverage (anti-aliasing), against the stroke fonts and bitmaps.
- **A constraint layout** (Cassowary), against the boxes there.
- **Damage and compositing** in the window system.

### Compression (`lib_compression/`)

- **Arithmetic coding** (or ANS), the pair of Huffman.
- **The Burrows-Wheeler transform** (bzip2), a third family beside
  the dictionaries and the codes.

### Browsers (`browsers/`)

There: the cascade, box, flex, table and grid layouts; a JavaScript
interpreter on trees, with quickening and closures (`opti/`).

- **A bytecode VM with inline caches** for JavaScript: the hidden
  classes that make property access fast, the technique V8 made
  known. Possibly after plan_dotnet.md's JIT, reusing its lessons.
- Incremental layout (dirty bits).

### Tools a programmer uses

Four that came up in plan_apps.md's survey of the applications, and
are a programmer's rather than a user's (the author: "plan_gaps is
really for the 'principia softwarica' hardcore aspect; stuff a
programmer should know, programs that a developer use. but apps/ is
different").

- **Search by an index**, the pair of grep (`utilities/text/Grep.ml`),
  which reads everything each time: an inverted index, its lists of
  places compressed, results ranked (tf-idf, BM25); and for code, Russ
  Cox's trigram index, a regular expression turned into the trigrams
  a match must have, the files that have them then grepped.
- **Sync by rsync's rolling checksum** (Tridgell, 1996): two copies of
  a file made the same by sending what differs, without either side
  having both; and chunks cut by their content, each stored once
  (Plan 9's venti). The pair of mini-git's deltas, which have both
  files at hand.
- **A password store**: Plan 9's secstore (the keys kept encrypted
  under one password) and factotum (a process holding them, that
  answers the protocols for the others, so no program sees a key).
  Over `lib_crypto`'s AEADs; it wants bcrypt or scrypt, below.
- **Symbolic algebra**: expressions differentiated and simplified
  (SICP's example, Macsyma's descendants), and a function plotted,
  beside `utilities/calc`'s hoc, bc and dc, which compute numbers.

### Smaller

- **Utilities**: a DFA (Thompson's construction then the subset's) as
  a third regex engine; an external merge sort.
- **Crypto** (`lib_crypto/`): SHA-3's sponge beside SHA-2's
  Merkle-Damgård; finite-field Diffie-Hellman beside X25519; a Feistel
  cipher (DES) beside AES; bcrypt or scrypt.
- **Linker**: relocations and dynamic linking (PLT, GOT) are what ix
  does not do by Plan 9's choice; a note says why, rather than a
  program.
- **Audio**: lossless coding (FLAC), a phase vocoder.

## Proposed, by value for the cost

1. **The database's transactions and journal**, then the LSM tree:
   the largest gap of the most taught part.
2. **TCP's congestion control** with a lossy link: the stack is
   there, its own header says what is missing.
3. **Schedulers side by side** in mini-9pi: small, measured, taught
   everywhere.
4. **Knuth and Plass** with Liang's hyphenation: a famous algorithm
   and its pair already in the tree.
5. **Myers's diff**: small, a pair.
6. **Arithmetic coding and the BWT**.
7. **Translation by blocks in mini-5i**, after plan_dotnet.md's JIT.
8. Those already planned, by their plans: swap, the debugger,
   multicore, RISC-V.

## Open questions

- Is the measure right: pairs beside what exists, rather than the
  part's most important missing piece?
- Do the regex engines, the text structures and the GUI's
  architectures want a page each that tells them as a pair (a README
  in the part, as `languages/README.md`), before any program?
- The lossy link (gap 2): in mini-qemu's Ethernet, in the board's, or
  a program between two machines?

## Status

2026-10-29: survey written. Nothing built.

2026-10-30: `languages/`'s own gaps in
[plan_gaps_languages.md](plan_gaps_languages.md).

2026-10-29: "Tools a programmer uses" added, four from plan_apps.md's
survey (search by an index, rsync, a password store, symbolic
algebra). Nothing built.
