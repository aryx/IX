# lib_core/libc: the C library under mini-ml's runtime

goken's libc (github.com/aryx/goken9cc, `lib_core/libc/` and
`include/`), which is Plan 9's made portable to Linux: the files a
program compiled by mini-ml links, for arm and arm64, and the headers
they include. 56 sources and 43 headers, about 6,450 lines. **All but
`ix/`**, which is ix's own (below).

**Copied as they are**, at goken's `e549ce551` (2026-09-23), with no
line added: a file's origin and license are said here, not in a header
of its own, so that the files stay the same bytes as goken's and a diff
shows what ix changed:

    lib_core/diff_goken_libc.sh        # each file against ~/goken's

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

**Later**: the math functions (`port/pow.c`, `exp.c`, `log.c`, `sin.c`,
`atan.c`...) are what is left to trim to what the runtime calls.
