# Plan: compat/, what a twin does only to be its reference byte for byte

Status: **done where it pays (mini-cc, mini-ld, mini-ml); the rest
analyzed and left.** Written 2026-09-26, after the splits it records.
Companions: [`simple.md`](simple.md) (the back ends freed
from the byte contract) and [`opti.md`](opti.md)
(the originals' optimizations, freely).

## The question

The author, 2026-09-26, after mini-ml turned out smaller than mini-cc
while TinyML was bigger than TinyC: a mini twin's size is its
contract's, a tiny variant's its language's. mini-ml's contract is the
behavior (plan_ml.md: "nothing is compared byte for byte"), mini-cc's
the listing, instruction for instruction (plan_cc.md, decision 3).
"What if we were relaxing the constraint on mini-c like we did on
mini-ml?" Then: split the code, the common part in the program's
directory, a `compat/` for what the byte contract forces, a `simple/`
beside it, and a flag. And later: "is this split something we could
apply to the other mini-xxx programs?"

## The rule the measurements gave

A `compat/` pays when the reference's output has **many correct
answers** and matching it takes a whole algorithm of the reference's.
It does not when the bytes **are** the behavior (an error message, a
diff's hunks, a database's file), or when the fidelity is a few lines
scattered in the code. So measure first: the code lines that exist
only for the reference's bytes, against the program's. The cut then
follows the program's passes, and the default stays the twin.

| program | only for the reference's bytes | of | what moved |
|---|---:|---:|---|
| mini-cc | ~1,125 (5c's Sethi-Ullman order, acom, mulcon, register allocator, switch shapes, 12 per-machine quirks) | 4,612 | the back end: `languages/c/compat/` (`Acom`, `Regs`, `Gen`, `Multiply`, `Arm`, `Arm64`) |
| mini-ld | ~150 (follow 95, the pools' policy, the data's hash order, 5l's single rounding) | 1,887 | `follow` only: `linker/compat/` (`Follow`), `mini-ld -nofollow` |
| mini-ml | none (its contract was the behavior already) | 2,561 | `Gas`, GNU's assembly, an output rather than a fidelity: `languages/ml/compat/`, as the author chose |

mini-ld's bulk is encoding, where an instruction has one right
encoding: matching 7l costs nothing there, hence no `simple/` for it,
only the one pass that is 5l's choice of layout.

## Done

- **mini-cc** (`78635e0`, then `e53580c`): one front end
  (`languages/c/`: `Pre`, `Lexer`, `Parser`, `Tree`, `Declare`,
  `Check`, `Machines`, the shared output `Emit`, arm's vlong calls
  `Com64`), the back end `compat/`, the command a library of its own
  whose back end is a record. `acom` left `Check` for compat's `xcom`
  hook; the machines' ABI records left `Arm` and `Arm64` for
  `Machines`; `Emit` split, its output shared, 5c's registers
  (`Regs`) compat's. Checked at each step: `listing.sh 5` and `7`, 241
  files the same; `fuzz.sh`, 300; the executables goken's.
- **mini-ml** (`d40a387`): the front end (`Ast` to `Typing`) in
  `languages/ml/`, `Lower` and `Gen` in `simple/`, `Gas` in `compat/`;
  a pure move, the output of 41 stdlib units and 14 programs the same
  as before (165 of 165), its tests passing.
- **mini-ld** (`cca739e`): `Follow` in `linker/compat/`, each machine
  giving only `ends`; `mini-ld -nofollow`; `golden.sh` 62, `libc.sh`
  byte for byte, `fuzz.py` 5 and 7, and with `-nofollow` the programs
  running the same.
- **The count**: `scripts/stats/loc.py` (`make loc`) and
  `.codemapignore` leave `compat/` out: code kept only for
  compatibility, not part of ix.
- **Comments name modules, not paths** (the author): `Follow`, not
  `compat/Follow.ml`, so that a move changes no comment.

## Remaining

- **compat's `-O2`**: 5c's and 7c's optimizers (`reg.c`, `peep.c`,
  2,700 lines of C per machine) byte for byte, as `compat/Reg` and
  `compat/Peep`. Declined for now (the author chose their ideas,
  freely: opti.md): the reference's bugs would come with it
  (optimized 7c's negative constants, `plan_bugs_goken.md` 5b). Its
  oracle would be goken's default listings.
- **`make test-goken`**: the `-nofollow` libc runs (`libc.sh`'s
  `MINILD_FLAGS=-nofollow`) are not in it yet, the Makefile being
  another session's then.

## Not worth it (analyzed 2026-09-26)

- **mini-rc, mini-mk**: 9base's messages (`file: rc (argv0): can't
  open: why`), rc's sigexit on an error, principia's `whatis` spacing:
  the output is the behavior.
- **mini-ed**: its regular expressions must pick libregexp's match
  (whose threads are not in priority order: the fuzzer found it);
  behavior again.
- **mini-diff, mini-merge3**: Stone's algorithm (Hunt and McIlroy)
  picks among equal longest common subsequences; another algorithm
  would print other hunks, which people read. A different tool, a
  `tiny/` one.
- **mini-chidb**: `EXPLAIN`'s registers, the table printer's 10
  columns, the 28-bit varint and the page split are its behavior and
  its file format; a different split would be another valid file,
  but no smaller.
- **mini-asm**: its own object format; encoding is the linker's.
- **mini-git**: content-addressed; the bytes are the hashes.
- **mini-9pi**: its console is 9pi's (pids spent as 9pi's kernel
  processes spend them, the boot environment so that `ps` shows 9pi's
  sizes), but in a few lines of `Proc` and `Main`, and the twin is
  the point for the book.
- **mini-5i, mini-qemu**: their contract is the instructions'
  semantics, behavioral already.
