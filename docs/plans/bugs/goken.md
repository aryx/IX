# Bugs found in goken, from ix

What building ix against goken (`~/goken`) turned up: bugs in goken's
toolchain, in its sources, and behaviour that makes its output depend
on the host; and, for mk, rc, ed and sam, bugs in principia's C and in
the references ix tested those against (9base and plan9port, as Debian
packages them). None is fixed in goken; each is for the author to decide
(goken may be modified). ix reproduces goken's output where the output
is the contract (the listings, the executables' bytes), and says so in
its code where it does. Found 2026-09-23 and 24, while building
mini-mk, mini-rc, mini-ed, mini-asm, mini-ld and mini-cc. Later ones
say their day. Bugs in xix
are in [`bugs/xix.md`](xix.md).

Each entry: what, the evidence and how to reproduce it, what ix does.

## The linkers

### 1. 5l and 7l write the ELF section table inside the data

The section headers go at HEADR+text+data, which is inside the data's
last page, so when the data is large they overwrite its end. The
executable then misbehaves:

- arm, `5c -O0`: goken's `pipe` prints garbage (`^@^@^@^A...`) where
  ix's prints `hello pipe` / `pipe ok`; with `5c` (optimized), goken's
  `dirread` fails (patched with ix's bytes, it passes).
- arm64, `7c -O0`: goken's `args` prints `argv[1]=%s%` for `one`,
  `notify` and `utfmisc` exit 1 without output; `dirread` fails too
  with `7c`.

The bytes are otherwise the same as ix's. Reproduce:
`MINICC=1 linker/tests/libc.sh 5 /tmp/w ~/goken/tests/c/hello_libc/*.c`
(and 7): the lines "SAME but the section table ... RUNS DIFFERENTLY".
ix: mini-ld puts the table after the data; `linker/tests/elfcmp.py`
compares everything else. Fix: place the table after the data, or
page-align it.

### 2. 5l's `immrot` computes in a 64-bit `ulong`

The rotation that decides whether a constant is an immediate runs in
the host's 64-bit `ulong`, so only 0..255 are found immediate:
`$0x400` goes to a literal pool. The code is correct, but longer.
ix: mini-ld does the same, with a `rotate` flag for the real rule
(`linker/Arm.ml`).

### 3. 7l's logical immediates leave out the element size

Below 64 bits, the bitmask encoding drops the element size of the
pattern (known: xix's `docs/claude_notes/arm64_port.md`). ix: mini-ld
reproduces it (`linker/Arm64.ml`, case 53).

### 4. 7l -H6 fails on the darwin libc

`GOOS=darwin H=-H6 linker/tests/libc.sh 7 ...`: 7l itself fails on
`alarm` and `notify`, with redefinitions in the darwin libc.

## The compilers

### 5. 7c -O0 generates code that crashes: `mem` and `stat` on arm64

With `7c -O0`, the hello_libc programs `mem` (segmentation fault) and
`stat` (illegal instruction) crash. mini-cc's executables are the same
bytes and crash the same way; on arm (`5c -O0`) both run. `mem` also
crashed in goken's own optimized build (`plans/plan_asm.md`, mini-ld's
milestone 2 on arm64). Not investigated yet:
the bug is in 7c's code generator or in libc's C that only `-O0`
exposes. Reproduce: `MINICC=1 linker/tests/libc.sh 7 /tmp/w
~/goken/tests/c/hello_libc/*.c` (exit 139 and 132).

### 5b. 7c's optimizer loads a negative 64-bit constant with MOVW

`long long x; x = -(2147483647);` (or `x = -2147483647;`): optimized
7c emits `MOVW $-2147483647,R9` then `MOV R9,x+0(SB)`. A MOVW writes
the 32-bit register and zeroes the upper half, so `x` is 2147483649.
`7c -O0` emits `MOV $-2147483647,R1`, correct. Found by TinyC's
fuzzer (`tiny/TinyC_fuzz.py`), whose reference is now `7c -O0`.

### 5c. `double op float` is computed in float

cck's table of the usual arithmetic conversions (`sub.c`'s `tab`, the
row of TDOUBLE) gives TFLOAT for a double and a float, while a float
and a double give TDOUBLE. So `d * f` loses the double's precision:
7c -O0 on `r1 = d * f; r2 = f * d;` emits `FCVTDS F0,F0` and `FMULS`
for the first, `FCVTSD` and `FMULD` for the second. Probably a typo
in the table. mini-cc reproduces it (`languages/c/Tree.ml`'s
`arith_tab`, which says so).

### 5d. A narrowing cast tested as a condition is not narrowed

`short x = -256; if((uchar)x) ...` is taken: 5c and 7c, at -O0 as
optimized, load the short (`MOVH`) and compare all of it with 0,
while `(uchar)-256` is 0 (gcc agrees). The narrowing between two
registers (txt.c's `gmove`, short to uchar) is a plain move, the
truncation left to a store; in a condition nothing is stored. Found by
TinyC's fuzzer (fuzz44 of `tiny/TinyC_fuzz.py`, seed 11: `x0 ^=
(uchar)((uchar)x3 ? 256 ^ x2 : x5)`), where TinyC is right and 7c the
reference. mini-cc reproduces it, being 7c's twin.

### 6. The code depends on the host's `qsort`

cck's reassociation (`scon.c`'s `acom2`) sorts its terms with `qsort`,
and its comparators (`acomcmp1`, `acomcmp2`) break ties on the
elements' addresses. So which of two equal terms comes first depends
on how the host's `qsort` moves elements. goken links 5c and 7c with
glibc's, a merge sort, which reverses equal terms at each sort; Plan
9's own `qsort` (libc/port/qsort.c, a quicksort) gives other orders,
worked through by hand on `f.txtsz+f.datsz+f.bsssz` in `utilities/kernel/ksize.c`.
The same source may compile to different code on another host (macOS,
Plan 9). ix: Check's `acom2` reproduces the merge sort, and says why.
Fix: break ties on an index kept in the term.

### 7. `nodv2uh` calls `_v2ul`

In cck's `com64.c`, `nodv2uh = fvn("_v2ul", TUSHORT)`: a vlong cast to
`ushort` calls `_v2ul`, like a cast to `ulong`, while every other
conversion has its own function. Probably a typo for `_v2uh`; the
result isn't truncated to 16 bits by the call. Only 5c uses these
calls. ix: the same (`languages/c/compat/Cgen.ml`, `of_v`). Not checked at run
time.

### 8. The multiply table's cache and 0

`mul.c`'s `mulcon0` looks in a cache of 20 entries, all zero at the
start, so `mulcon0(0)` finds "no program" there; once 20 other
constants have replaced them, 0 is searched for instead. What `x * 0`
compiles to could then depend on the constants before it in the file.
Latent: not seen in the corpus. ix:
`Multiply.mulcon0 0` is always "no program". Also, 5ck's `mul.c`
computes in the host's `long` (64 bits), 7c's in `int32`.

### 9. 5ck's listing loses float constants

5ck (and cck's other back ends) print a float constant with `%e`, six
digits: `$4.294967e+09`, so a `5ck -S` listing doesn't reassemble to
the same object. Principia's 5c prints `%.17e` (with Plan 9's fmt,
the fewest digits that read back, then zeros). ix: mini-cc prints as
principia's 5c (`languages/c/compat/Emit.ml`, `e17`).

### 10. cck's `-x` dump: runes and offsets

`prtree` prints an `L"..."` string with `%S` on 4-byte runes, which
comes out as `"\072\z\z\z..."`, and an offset as an unsigned 32-bit
number (`4294967288` for `-8`). Debug output only.
`languages/c/tests/strip_x.py` normalized the first, while mini-cc's `-x`
printed 5c's trees (until 2026-09-24, when the trees became an OCaml
ADT and `-x` its own dump; the script is in the history).

## The sources

### 11. hoc: `EQ` is a macro and an enumerator

`utilities/calc/hoc`: the grammar's tokens are `#define`d (`EQ` among
them) before `y.tab.c` includes `libc.h`, whose `base/ord.h` has
`enum { EQ = 0, ...}`. 5c and 7c fail with a syntax error:
`printf '#define EQ 1\n#include <u.h>\n#include <libc.h>\n' > h.c;
5c -I$HOME/goken/include -I$HOME/goken/include/ALL
-I$HOME/goken/include/arch/arm h.c`.

### 12. grep: `literal` is `int` and `bool`

`utilities/text/grep`: `grep.h` declares `extern int literal;` and
`globals.c` defines `bool literal;` (a `u8`). 5c reports "external
redeclaration of: literal", prints its listing anyway, and exits 1.

### 13. awk and diff don't compile with their mkfiles

`utilities/text/awk` and `utilities/compare/diff` include `ctype.h`
and `stdio.h`, which are only under `include/APE`, and their mkfiles
don't add it. Known: `utilities/mkfile` has them commented out
("TODO: awk must be relpized after the removal use of APE in it").

## mk, rc, ed and sam: principia's C, 9base, plan9port

From the differential tests of mini-mk, mini-rc and mini-ed (their
plans' Status sections: `plans/plan_mk.md`, `plan_rc.md`,
`plan_ed.md`).

### 14. principia's mk loses a `:R:` rule's arcs

principia's refactored `graph.c` drops the arcs of a regular-expression
rule; 9base's does not, and mini-mk follows 9base.

### 15. mk swallows a `}` after an unbraced name

`shprint.c`'s `vexpand()`, printing a recipe: `{cmd $X}` prints
without its `}` (9base's mk). mini-mk prints the same, as its tests
compare the printed lines.

### 16. mk exports an empty variable as one empty word

`SYSLIBS=` reaches rc as `SYSLIBS=`, which plan9port's rc reads as one
empty word (`$#E` is 1), so `ocamlc $SYSLIBS` gets an empty argument
and fails: found building xix's `generators/lex/`. On Plan 9 an empty
`/env` file is `()`. omk skips empty variables (its comment says its
author met this with plan9port's mk); mini-mk doesn't export them, a
documented difference (`empty_rc`).

### 17. mk(1) is wrong about command-line assignments

The man page says a command-line `CC=z` overrides "the first (but not
any subsequent)" assignment; mk overrides every assignment to `CC`
(checked on plan9port's mk; omk agrees with the program).

### 18. libregexp takes an overflowed thread list for a match

`regaux.c` and `rregexec.c`: an OR's dedup looks only at the threads
not yet run (it passes its own place, `tlp`, not the list's start: the
"optimization" its comment calls a bug), so a loop that can match empty
adds the same instruction until the list of 10 overflows, then the one
of 50; `rregexec` returns -1, which ed takes for a match. `((x?)?)*` on
`xxb` matches the empty string. When the list overflows before any
match, 9base's ed segfaults (exit -11, dosub reading a null pointer).
mini-ed reproduces the lists, sizes and all.

### 19. 9base's sam: character classes, and a stray `d`

`[a-c]` matches only `a` and `c`, `[^ab]` a newline; and it prints a
`d` after its numbers (plan9port's `%lud`). TinyEditor's tests use no
class, and take the `d` out.

### 20. 9base's rc ignores SIGTERM

`timeout` can't stop it; the harness uses `timeout -s KILL`.

### 21. 9base's rc: a missing program ending a subshell leaves status 0

The last command of a subshell is exec'ed without a fork, so a missing
program there leaves `$status` 0 where rc means 1 (an artifact of the
optimization; mini-rc keeps 1, a documented difference). And in a
pipe, a missing program's stage exits with the `$status` it inherited
(`scsicodes`; not copied).

### 22. principia's mkenam scripts name a moved path

`compilers/5c/mkenam` names `include/obj/5.out.h` by a path that moved;
`8c/mkenam` no longer fits its header, and both eds fail on it alike.

### 34. xd -r loses the file's end after lines that are the same

Found 2026-10-07, by utilities/tests/differential.sh (mini-xd against
principia's arm xd under mini-5i; goken's `utilities/byte/xd.c` is the
same source). xd reads 32 bytes and shows 16 ("so that runes are
happy"), keeping the other 16 for the next turn (`nleft`, a memmove at
the loop's end). With -r, a line that is the one before is skipped by a
`continue`, which also skips that memmove: the 16 bytes kept are lost,
and the next read starts 16 bytes further in the file. A file of 72
`a`, then `b\tc\n`:

```
% xd -r -c same          principia's            mini-xd
0000000   a  a  a ...    the same               the same
*                        *                      *
0000030                  (the end: 0x30)        0000040   a  a  a  a  a  a  a  a  b \t  c \n
0000030                                         000004c
```

The last 12 bytes are not shown and the address at the end is 0x30,
not the file's length. mini-xd shows them: not copied (the two cases
are not in the differential test).

## libc

### 23. sbrk starts at `end`, which Linux's ASLR moves away from

`port/sbrk.c` hands out memory from `end` (the bss's end) up, moving
the break with `brk`; Linux, randomizing, puts the program's break
elsewhere (`start_brk` past a random gap), and refuses a `brk` below
it, so the first `sbrk` fails and a program using what it returns
crashes. Found 2026-09-26 by tiny-ml's runtime, which segfaults on its
first allocation when its semispaces came from `sbrk`, and runs under
`setarch -R` (and gdb, which turns ASLR off). Fix: start `bloc` at
`brk(0)`'s answer, the current break. ix: TinyML's runtime takes its
heap from the bss (`TinyML_runtime.c`), since `malloc` is a bump
allocator of 64MB whose `free` does nothing (`port/minimal_malloc.c`,
by design a stand-in) and can't hold a copying collector's halves as
they grow.

### 24. 7l builds a negative offset below -256 from SP

`MOV R0, -264(R26)`: the offset is out of the unscaled form's range, so
7l builds it in R17 and stores register-indexed, but builds it with an
ADD from register 31 as if it were ZR, where an ADD's 31 is SP:
`add x17, sp, #0xef8` (7l says so on stderr: `omovlit add -264
(0xfffffffffffffef8)`). Found 2026-09-26 by mini-ml, whose frames on
its value stack are below R26: a function of more than 32 slots crashed.
Reproduce: `printf '\tTEXT\t_main(SB), $-8\n\tMOV\tR0, -264(R26)\n\tRETURN\n'
> t.s; 7a t.s; 7l -H7 -s t.7`, then `objdump -D -b binary -m aarch64`.
ix: mini-ld makes the same bytes (it is 7l's twin); mini-ml computes
such a slot's address itself (`languages/ml/simple/Gen.ml`, `slot_ref`). Fix:
a MOVN (or a MOVZ/MOVK sequence) for a negative constant, as for a
positive one.

### 25. libc's floats: sqrt, sin and cos lose their last bits; %.17g prints 16 digits

`sqrt(0.1)` is 0.31622776601683795 where the correctly rounded value
(IEEE 754 requires it of a square root; glibc's) is
0.31622776601683794; `sin(1.0)` 0.8414709848078964 against glibc's
0.8414709848078965, `cos(2.5)` and others alike; and `%.17g` prints 16
significant digits. `tan`, `sinh`, `cosh`, `tanh` and `fmod` are declared
(`include/math/`) but not implemented. Found 2026-09-26 by mini-ml's
runtime, whose floats are libc's: ocaml-light's `test/fft.ml`, whose
output is its transform's rounding error, prints errors 16 times
glibc's. ix: mini-ml's runtime defines the five missing from the others;
fft's comparison is left failing, documented (plan_ml.md's Status).

### 27. 7c and 7l: `~x` of a 32-bit unsigned is an illegal instruction

`unsigned int f(unsigned int b, unsigned int d) { return ~b & d; }`:
7c compiles the `~` as `EORW $4294967295, R0`, and 7l encodes the
constant as a 32-bit logical immediate of all ones, which has no
encoding (`0x52007c21`, undefined: objdump's `.inst`); the program is
killed by SIGILL. A `uvlong`'s `~` is `EOR $-1`, which works. Found
2026-10-01 by mini-ml's runtime, whose MD5 has `(b & c) | (~b & d)`.
Reproduce: the function above called from a `main`, `7c`, `7l -H7`,
run. ix: mini-cc and mini-ld make the same bytes (7c's and 7l's
twins), so the runtime's MD5 is written without `~` (`runtime.c`,
`md5_block`: `d ^ (b & (c ^ d))`, and `0xffffffff - d`). Fix: 7l's
`EORW` of all ones as `MVNW` (ORN with ZR), or 7c's `~` as `MVNW`; then
mini-ld (or mini-cc) the same.
ix, 2026-10-02: goken's own libc has one (`dirfwstat`'s `~d->mode`,
which every rename reaches), so a program built by ix's mkfiles died
at its first `Sys.rename` (tiny-vcs). mini-ld now writes `MVNW` for
`EORW` of 32 ones (and the register forms for `ANDW`, `ORRW`, `ANDSW`):
there it is no longer 7l's bytes. goken's 7l still to fix.

### 28. 7c: `-x` of a double is `0.0 - x`

`double neg(double x) { return -x; }` is `FMOVD $0.0, F0; FSUBD F1,
F0`, with and without `-O0`. So `-(0.0)` is `0.0`, not `-0.0`, and a
nan negated is another nan (`0x7ff0000000000001` gives
`0x7ff8000000000001`: quieted, its sign unchanged), where C's unary
minus flips the sign's bit (`FNEGD`). Found 2026-10-01 by mini-ml's
`tests/modern/floats.ml`, whose `-. 0.0` printed `0.0`'s bits.
Reproduce: the function, its result's bits printed (`*(uvlong*)&r`).
ix: mini-cc is 7c's twin here; mini-ml's runtime negates and takes an
absolute value on the bits (`caml_negfloat`, `caml_absfloat`). Fix:
`FNEGD`.

### 29. libc's `ceil` and `floor` lose a zero's sign

`ceil(-0.3)` is `0.0` where C's is `-0.0`, and `floor(-0.0)` is `0.0`:
a zero result should have its argument's sign (so that `1/ceil(-0.3)`
is `-inf`, and OCaml's `Float.round (-0.3)` is `-0.`). Same test, same
day. ix: the runtime's `ceil_float` and `floor_float` put the sign
back (`signed_zero`).

### 30. libc on Linux: no `chdir`, no `fma`; `dirwstat` renames in a directory only

Limits, not bugs. `chdir` is declared (`include/os/`) and not in the
Linux libc (`os/linux/`): mini-ml's `Sys.chdir` stays a stub. No `fma`
(a multiply-add rounded once; an instruction on arm64): `Float.fma`
too. And a rename is Plan 9's, `dirwstat` with a new last name, so a
file is not moved to another directory (though `os/linux/dirwstat.c`
calls `renameat2`, which could): mini-ml's `Sys.rename` refuses two
directories. Read in `dirwstat.c`, not run: after the rename it opens
the file `ORDWR` for its other fields, which fails for a directory or a
read-only file, so the call would fail with the rename done.

### 31. `long` is 32 bits on arm64, and `_syscall6` is declared with it

Not a bug: Plan 9's C has `long` of 32 bits on every machine, `vlong`
for 64. But code from Linux, where a `long` holds a pointer, loses the
pointer's high half silently, and what is left in the register's is
whatever was there: `static long arg(value v) { return v; }` gave the
kernel `0x3e800454f88` for the string at `0x454f88`. Found 2026-10-01
by mini-ml's `unix_syscall`. `syscall_linux_arm64.h` declares
`_syscall6`'s arguments `vlong` and its result `long`: the result's
high half is lost too (an offset past 2 GB from `lseek`), which
`_syscall6v` is there for. ix: the runtime declares `_syscall6` with
words (`intptr`) for its arguments and its result.

### 32. arm's `_v2d`: the smallest vlong converted to a double is 2^63

`port/vlrt.c`'s `_v2d` (a vlong to a double, on a machine of 32 bits)
negates a negative value then converts its high word as signed:
`-((long)x.hi*4294967296. + x.lo)`. The smallest vlong is its own
opposite, its high word still `0x80000000`, so `(double)(vlong)1<<63`
is `+9.2233720368547758e18`, not minus it. Found 2026-10-04 by
`lib_core/libc/tests/vlrt_check.c`, each function of ix's shorter
`vlrt.c` against gcc's 64 bits (the first version had Plan 9's line).
Reproduce: `vlong v = (vlong)1<<63; double d = v;` compiled by 5c, `d`
printed. ix: `lib_core/libc/ix/vlrt.c` converts the high word as
unsigned after the negation. Fix: the same.

### 33. `strtod("-0")` is `0.0`

`fmt/strtod.c` ends with `d = -d` for a number with a minus sign: by
bug 28 that is `0.0 - 0.0`. So `float_of_string "-0."` under mini-ml
was `0.`, and `%.17g` of `-0.` did not read back. Found 2026-10-04 by
`languages/ml/tests/modern/float_formats.ml`. ix: `ix/fmt.c`'s `strtod`
sets the sign's bit.

### 35. cos(0) is not 1

`libc/port/sin.c` (Plan 9's: Hart and Cheney's rational approximation
on a quarter turn) computes `cos(x)` as the sine of the quarter after,
so `cos(0)` is the quotient of its two polynomials at 1: 0.99999999999999956,
4 ulp short of 1 (and `sin` of a quarter turn the same; elsewhere it is
within 2 ulp of glibc's, bug 25: `cos(1)` 2, `sin(1)` 1). So a rotation by 0
degrees is not the identity: every point it is applied to moves by
its last bits. Found 2026-10-07 by the playground's Tetris
(`docs/plans/plan_playground.md`): its frame by mini-ml's build and by
OCaml's differed in 99 pixels of a million, where an edge fell on a
pixel's border. Reproduce: `Printf.printf "%.17g\n" (cos 0.)` by
mini-ml (ix's libc) prints 0.99999999999999956. ix:
`lib_core/libc/port/sin.c` returns 1 and -1 where the reduced argument
is exactly a quarter turn (+7 lines). Fix: the same.

## The archiver

### 26. iar writes a byte past a member of odd size

An archive pads a member of odd size with one byte. `arread` allocates
the member's size exactly (`armalloc(n)`, zeroed) and `arwrite` then
writes `size+1` bytes of it (`linkers/ar/ar.c`): the pad is the byte
after the buffer, whatever the heap holds there. So the same objects
make different archives, `-D` or not, and it is a read out of bounds.
Found 2026-10-01 by `build_principia.sh`: principia built twice, APE's
`libbsd.a` (and `lib9.a` and `libap.a` on arm) differ by that one
byte. Reproduce, in a directory of objects with one of odd size:
`for i in 1 2 3; do rm -f /tmp/x.a; iar vuD /tmp/x.a *.5; sha256sum <
/tmp/x.a; done` prints three sums. ix: nothing to do, the programs linked from these archives
are the same; `build_principia.sh` lists such archives as differing by
one byte. Fix: allocate `n + (n&1)` in
`arread`, the pad then being 0.

## How they were found

The runners that compare ix with its reference, case by case or file
by file: mini-mk's, mini-rc's and mini-ed's `differential.sh` and
fuzzers, against 9base; `languages/c/tests/front.sh` (trees, while they were 5c's),
`languages/c/tests/listing.sh` (listings), `linker/tests/libc.sh`
(executables, and running them) and `linker/tests/fuzz.py`, against
goken; `tiny/TinyC_fuzz.py`, against 7c; `builder/tests/build_principia.sh`
(principia built by goken's mk and by mini-mk, the trees compared); and
reading the C while porting it.
