# lib_core/libc: the C library under mini-ml's runtime

goken's libc (github.com/aryx/goken9cc, `lib_core/libc/` and
`include/`), which is Plan 9's made portable to Linux: the files a
program compiled by mini-ml links, for arm and arm64, and the headers
they include. 69 sources and 45 headers, about 5,400 lines. Each file
says in its first lines where it comes from: Plan 9's, by principia
and goken; goken's own, around it; or ix's (`ix/`, below).

**Taken at goken's `e549ce551`** (2026-09-23), as they were until
2026-10-08, when they were trimmed (the author: "ok let's do the libc
trimming you mentioned"; 7,748 lines then): **the code is goken's, the
comments are not anymore**. What changed:

- the comments, which were long and about goken (its other systems and
  machines, how each thing was found), are a few lines saying what the
  file is for ix; a file's nine-line license block is ix's two lines.
  Plan 9's own files have lost their syncweb marks (`/*s: ... */`:
  principia's, no document of ix's reads them; the author: "you can
  remove the syncweb comments") and nothing else;
- `os/linux/stat.c` is `stat_arm.c` and `stat_arm64.c` in one (the
  kernel's struct, and one call, differ);
- `syscall/os/linux/zsyscall_linux.c` and `syscall_linux.h` are goken's
  two generated files and their two headers in one, without the calls
  nothing of ix asks (brk, dup, pipe, kill, the signals, the clocks:
  12 functions), and the two tables of numbers have the numbers left;
- `port/seek.c` and `port/getcallerpc.c` have lost their `#ifdef` of
  the machines ix has not;
- in the headers, the declarations that were commented out are gone.
  Those of what ix's libc has not (the formatter's `Fmt`, the runes,
  `assert`, `qsort`...) stay: mini-9pi's pixels in C (`PIXEL=c`) use
  them.

Checked then: every C file's object the same bytes as before, for
Linux on arm64 and arm and for Plan 9 (mini-cc's objects do not say
the lines), the assembly's text the same without its comments, and
the calls left in `zsyscall_linux.c` the same code.

    lib_core/diff_goken_libc.sh -v     # each file against ~/goken's: its code is in the diff

**Not the original anymore: `ix/`** (2026-10-04, the author: "let's do
it, but let's clearly mark it's not the original anymore"). Two files
written for ix, each with ix's header, in the place of goken's:

| ix's | in the place of | lines |
|---|---|---:|
| `ix/fmt.c` | `fmt/` (`dofmt.c`, `fltfmt.c`, `strtod.c` and nine others), `math/nan.c`, `port/strtod.c` | 603 for 2,413 |
| `ix/vlrt.c` | `port/vlrt.c` | 337 for 760 |

`ix/fmt.c` is what mini-ml's runtime asks of the formatter and no more:
`snprint` and `sprint` with C's conversions, `strtod`, `NaN`, `Inf`,
`isNaN`, `isInf`. No `print` or `fprint`, no `fmtinstall`, no runes, no
`%r`: C that wants Plan 9's `print` needs goken's `fmt/` back. Its
floats are exact both ways, by one multiplication on large numbers (the
file's header), where Plan 9's are faster and longer. With `fmt/` gone,
nothing asks for `utf/`, `port/ctype.c`, `port/assert.c`, `port/errno.c`
and `port/strerror.c`: out too (461 lines; the headers stay).
`ix/vlrt.c` is Plan 9's `vlrt.c` written shorter: the same functions and
algorithms, for a little-endian machine only.

    lib_core/libc/tests/check.sh       # both against glibc and gcc, on the host

**Plan 9's files** (2026-10-05, plan_rio.md: ix's programs on
mini-9pi; arm only today), goken's `GOOS=plan9`, as they are too:
`syscall/os/plan9/` (`svc_arm.s`: a name is the kernel's call, `open`,
`pread`, `rfork`, `await`...; `sys.h`, their numbers), `os/plan9/`
(`fork`, `getenv`, `getwd`, `_exits`, the directory entries' format:
`stat`, `dirread`, `convM2D`, `convD2M`), and `port/sbrk.c`,
`dirwstat.c`, `strcmp.c`. `lib_core/mkfile` takes them for
`mini-mk O=5 OS=plan9`, in the place of `os/linux/` and of the `port/`
files that put Plan 9's names over POSIX's calls (`seek`, `remove`,
`exec`, `wait`...). Not taken: `os/plan9/wait.c`, which asks
`tokenize` and the runes (550 lines): the runtime reads `await`'s line
itself. One file of ix's own with them: `ix/syscall6_plan9_arm.s`,
`_syscall6` for a call of Plan 9's by its number (as
`syscall/os/linux/svc_arm.s`'s is Linux's), for `Unix`.

**License.** Plan 9's code is Copyright (c) 2021 Plan 9 Foundation,
under the MIT license; goken's own additions (the Linux system calls,
`os/linux/`, `syscall/`) are under the same, by their authors. goken's
`copyright.txt` and `license.txt` are in [`LICENSE`](LICENSE).

**The layout** is goken's: `port/` (C that is the same everywhere),
`os/linux/` and
`syscall/os/linux/` (Linux's system calls), `arch/arm/` and
`arch/arm64/` (the start, and arm's divisions), `include/`. Two
differences, for goken reaches them through symbolic links:
`include/os/posix/errno.h` is its `include/os/unix/errno.h`, and
`utf.h` is found by `-Iinclude/utf`.

**Which files**: those mini-ld takes from goken's whole libc (139
objects) for mini-ml's runtime (`IX_LOG=info mini-ld ...` says each
"from a library"): 48 objects on arm64, 51 on arm (67 and 70 before `ix/`). `lib_core/mkfile`
lists them, and makes `libc.a` with mini-cc, mini-asm and mini-ar.

**The math functions** (11 files of `port/`, 592 lines) are all called
(looked at on 2026-10-08, to trim them): the runtime's `floats.c` asks
`exp`, `log`, `log10`, `sin`, `cos`, `asin`, `acos`, `atan`, `atan2`,
`pow`, `floor`, `ceil`, `frexp`, `ldexp` and `modf` for `Pervasives`'
and `Float`'s functions of those names, and `fabs` and `sqrt` are
called by the others (`frexp.c`; `asin.c`, `pow.c`). What the runtime
could write itself it already does (`tan`, `sinh`, `cosh`, `tanh`,
`fmod`; its `sqrt` is the processor's): goken's files for those are
not here. Fewer would mean an OCaml function less in the stdlib.

**The machines' memmove and memset** (2026-10-23, plan_pi4.md; the
author: "on principia and plan9 most archi provides their own memmove
in assembly", "9front probably has the arm64 assembly", and of Plan 9's
way: "you can read both versions (and possibly switch and benchmark
too)"). goken has only `port/`'s C, a byte at a time; as in Plan 9, a
machine's file now takes the place of port's of the same name
(`lib_core/mkfile`'s `LIBC_MEM5`, `LIBC_MEM7`: port's names written
there instead switch back to the C, which stays):

| file | from | lines |
|---|---|---:|
| `arch/arm/memmove.s`, `memset.s` | principia's (Plan 9's), as they are | 216, 63 |
| `arch/arm64/memmove.s`, `memset.s` | 9front's (`sys/src/libc/arm64`, MIT as Plan 9's), the size read as 32 bits (a `ulong` for 7c and mini-cc; 9front's read 64, whose upper half a caller here does not write) | 56, 32 |

9front's arm files are principia's but for one line (memmove returns
at once when the two places are the same; principia's copies onto
itself). arm64's are
short: a pair of words loaded and stored 16 bytes a turn, at any
alignment (arm64 allows it in memory that is not a device's), then
bytes; arm's are long for the case where the two places are not
aligned alike (`LDM` and `STM` want words: words read aligned and
shifted into place). What it took of mini-asm and mini-ld: 7a's
write-back operands (`(R1)16!`, `-16(R1)!`), `MOVP` (LDP and STP:
goken's 7l has none, 9front's is the reference), `BIC`; on arm, 5a's
`R(expr)` registers in a shift and in a list. Checked:
`tests/mem_check.sh` (every alignment and overlap against a byte's
loop, on both machines, under qemu), the arm files' bytes the same as
goken's 5a and 5l (`linker/tests/golden.sh`). The Pi 4's kernel by
ix's tools reached its prompt under mini-qemu in 65 s with port's
memmove, 32 s with this one (memmove 49% of its instructions, then 2%).
