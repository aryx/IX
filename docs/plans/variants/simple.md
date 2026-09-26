# Plan: simple/, a twin's back end whose contract is the behavior

Status: **done for mini-cc (`-simple`, arm and arm64) and mini-ml
(its back end, moved); mini-ld has the flag, not the directory.**
Written 2026-09-26. Companions: [`compat.md`](compat.md)
(what the byte contract forced, moved out) and
[`opti.md`](opti.md) (passes on simple's code).

## What simple/ is, next to compat/ and tiny/

- **compat/**: the twin's code that exists for the reference's bytes.
- **simple/**: the same program, the same features and the same
  behavior, no longer held to the reference's internal choices: the
  shortest code that a behavior test accepts.
- **tiny/**: a different, smaller program in one file, its features
  chosen by what they cost in lines (the author's rule for the tiny
  variants).

So a `simple/` is worth having only where the reference's choices cost
real lines (compat.md's table); elsewhere the twin already is
simple, or the free program is `tiny/`'s.

## Done

### mini-cc -simple (`e53580c`)

`languages/c/simple/`: `Lower` (the typed tree to a stack machine:
values of 1 to 8 bytes, floats, a block's address; the frame's
temporaries and outgoing area; 7c's calling convention, so that what
it compiles calls libc and is called by it) and `Gen` (the stack in
registers, the slot at depth i Ri or Fi: R1-R15/F1-F15 on arm64,
R1-R7/F1-F6 on arm; a call spills the live slots). On arm a vlong is a
block and its operations libc's calls (`Com64`, shared with compat).
`mini-cc -simple`, and `-dir` for the stack machine's code. 561 lines
of code (with `-dir` and the forms opti makes) against compat's 1,622;
the tutorial's §10 (notes_cc.md) explains it with §1's `sum`.

What the tests found, each fixed (notes_fuzzing_techniques.md, 10 to
12): CBZ, which mini-ld's flow cannot invert (7c never emits it); a
label no jump reaches, taking its stack depth from dead code (`x ||
255`); an address held across `setjmp` in a spill slot a later call
reused (so a call's value is computed before the address it is stored
to); arm's 7 registers (Ershov's order: the deeper operand first).

Checked by behavior, `languages/c/tests/simple.sh 5|7` (all of goken's
libc compiled by -simple, and the programs), 227 of 228 on each
machine: goken's 17 hello_libc, the 11 TinyC_tests, 200 random
programs of `TinyC_fuzz.py` (`--32` on arm). The two left are the
reference's: `mem` crashes as goken's own `-O0` build does, and
goken's `pipe` prints garbage (5l's section table inside the data,
`bugs/goken.md` 1). On `args`, `stat`, `utfmisc` and `pipe`
-simple's executables are right where goken's are not.

### mini-ml

Its back end was a stack machine from the start (`Lower`, then `Gen`
for arm and arm64), the contract being ocamlopt's behavior; moved to
`languages/ml/simple/` (`d40a387`), its output unchanged.

### mini-ld -nofollow

No directory: the code in the objects' order instead of along its
flow (5l's `follow`, now `Follow` in compat), the programs running the
same (`cca739e`).

## Remaining

- **`make test-goken`**: `simple.sh 5` and `7` (with `SIMPLE_FLAGS=-O`
  too) are not in it yet: the Makefile had another session's edits.
- **arm's registers**: R1-R8 are the stack's and R9-R15 reserved or
  special, so an expression deeper than 7 slots is refused (none of
  the random programs since Ershov's order) and opti's `regs` has no
  register to give a variable there. A stack of 5 and two variables'
  registers, or a spill of the deepest slots, when a measure asks.
- **`mem` on arm64**: -simple's `mem` crashes in `sbrk` as goken's
  `-O0` build does, and runs with TinyC_test.sh's reference; to explain
  (`bugs/goken.md` 23, sbrk under ASLR, is the likely cause).

## Not worth it

A `simple/` for the other twins (compat.md's list): their
byte contract is their behavior, so there is nothing to relax, and the
free program is their `tiny/`. mini-ld: its fidelity is ~8% of it,
one pass, which the flag covers.
