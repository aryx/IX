# Plan: modern designs, where ix followed Plan 9's

Status: **candidates, none started.** Written 2026-09-27. Companions:
[`compat.md`](compat.md), [`simple.md`](simple.md),
[`opti.md`](opti.md), [`ssa.md`](ssa.md), [`redesign.md`](redesign.md).

## The question

The author, 2026-09-27, while SSA was being planned for mini-ml ("SSA
is kinda the modern way to write a compiler backend (C-- could have
also been good)"): "I wonder if there are other opportunities for
'modern' variants and pipelines in the other programs in this
project", and "maybe there are other modern ways for the other projects
we didn't pursue because we tried to follow what Plan 9 did?"

Each twin reproduces one classic design, Plan 9's or principia's. Where
the field has since found another, a variant beside the twin teaches
both: the twin stays, the variant is optional (a flag, or a directory
as `simple/` and `ssa/`), tested against the twin's behavior, and out
of `make loc` as `compat/` and `opti/` are. Two kinds: **algorithms and
data structures** (a better way to compute the same answer), and
**conventions and architecture** (what Plan 9 chose where modern
systems chose otherwise).

## Algorithms and data structures

Ranked by what they teach against what they cost.

1. **mini-diff: Myers, patience, histogram.** principia's diff is
   Stone's (Hunt and McIlroy, 1976); git's default is Myers' O(ND)
   (1986), and its patience and histogram diffs give better hunks on
   code. As `-myers`, `-histogram`: each short, all checked by one
   property (the diff, applied by patch, gives the new file) and
   compared by the hunks they print. References: Eugene Myers, "An
   O(ND) Difference Algorithm and Its Variations" (Algorithmica, 1986);
   Bram Cohen's patience diff (2006); git's `xdiff/`.
2. **mini-mk: build systems à la carte.** mk rebuilds by timestamps,
   in a fixed order. A variant rebuilding by content hashes (verifying
   traces), with early cutoff (an unchanged output stops the rebuild)
   and dependencies found while building. Reference: Andrey Mokhov,
   Neil Mitchell and Simon Peyton Jones, "Build Systems à la Carte"
   (ICFP 2018), which places make, Shake, Bazel and redo in one space.
3. **mini-chidb: queries compiled, or vectorized.** chidb interprets
   bytecode (its DBM, SQLite's VDBE). A plan compiled into OCaml
   closures (Thomas Neumann, "Efficiently Compiling Efficient Query
   Plans for Modern Hardware", VLDB 2011), or run a vector at a time
   (Boncz, Zukowski and Nes, "MonetDB/X100", CIDR 2005); checked
   against chidb's output.
4. **mini-ed: regular expressions by derivatives, or a lazy DFA.**
   Brzozowski's derivatives (Owens, Reppy and Turon, "Regular-expression
   Derivatives Re-examined", JFP 2009), or RE2's DFA built as it runs
   (Russ Cox's articles). The constraint: as a drop-in it must choose
   libregexp's match; as a teaching variant it need not.
5. **The emulators: blocks compiled once** (QEMU's TCG, freely: OCaml
   closures, threaded code): in [`opti.md`](opti.md).
6. **mini-ml's collector: generational.** mini-ml's Cheney is simpler
   than its original's: ocaml-light's is generational (a minor heap,
   a major one marked and swept). A minor heap and a write barrier, as
   OCaml's; measured on `bench/maps` and `tests/tiny/gc`. Reference:
   Richard Jones, Antony Hosking and Eliot Moss, *The Garbage
   Collection Handbook* (2011).
7. **mini-ed's buffer: a piece table, or a rope** (VS Code's piece
   tree, xi's rope), beside the plain one.
8. **mini-chidb's storage: a write-ahead log** (SQLite's since 2010),
   or LSM trees (LevelDB, RocksDB): heavy, and far from chidb's course.

## Conventions and architecture

1. **The calling convention.** Plan 9's: the first argument in R0, the
   others on the stack, every register the caller's. So `regs` saves
   its variables around every call, and part of `fib`'s cost is there.
   AAPCS64's arguments in X0-X7 and callee-saved X19-X28 would not.
   With [`ssa.md`](ssa.md): code by `-ssa` could call itself by a
   register convention, Plan 9's kept at the boundary with libc and the
   simple back end.
2. **An IR with its own syntax: C-- or QBE's.** `ssa.md`'s SSA as a
   small language, printed and parsed: both compilers emit it, one back
   end compiles it, a test can be written in it, `-dssa` prints it back.
   QBE (SSA-based, ~10,000 lines of C) as the model; C-- (Peyton Jones,
   Ramsey and Reig, "C--: a Portable Assembly Language that Supports
   Garbage Collection", PPDP 1999) for its runtime interface, the
   roots and the handlers mini-ml needs. Both are in
   notes_cc_related_work.md.
3. **Relocatable objects.** Plan 9's objects hold instructions not yet
   encoded; the linker encodes, and there are no relocations. Modern
   toolchains use relocatable ELF `.o`, which binutils read (`objdump`,
   `gdb`, `ld`). A large change, and Plan 9's may be the better lesson
   (notes_asm.md): a candidate to argue about, not to do.
4. **Frames and unwinding.** Plan 9's linker writes a function's
   prologue from its frame's size; no frame pointer, no unwind table.
   Modern compilers write their prologues and DWARF's call-frame
   information, so that a debugger or a profiler walks the stack: worth
   it the day ix has either.
5. **The emulators' decoders from ARM's specification.** Written by
   hand and checked against objdump; modern ones generate them from
   ARM's machine-readable specification (ASL, as Sail does): correct by
   construction, a large dependency.
6. **mini-cc's dialect.** Plan 9's C89 with `u.h`; C99's designated
   initializers and compound literals are out because the corpus needs
   none. A dialect switch, if a program ever asks.

## Not worth it

- **mini-rc**: the modern shells (nushell's structured pipelines) are
  another language.
- **mini-git**: it is git's format already; protocol v2 and the
  commit-graph add formats, not a better design.
- **The kernels**: the twin is their point (mini-9pi), and the free
  kernel is already the xv6 convergence's (plan_kernel.md).

## Order

With [`ssa.md`](ssa.md) under way: its IR given a syntax (conventions,
2) and a register convention inside it (conventions, 1) belong to its
phases. Then, one at a time, each measured and each with its tutorial
section: diff's algorithms (1), build systems à la carte (2),
compiled queries (3), the generational collector (6).
