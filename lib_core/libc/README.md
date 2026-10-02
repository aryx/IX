# lib_core/libc: the C library under mini-ml's runtime

goken's libc (github.com/aryx/goken9cc, `lib_core/libc/` and
`include/`), which is Plan 9's made portable to Linux: the files a
program compiled by mini-ml links, for arm and arm64, and the headers
they include. 75 sources and 45 headers, about 9,300 lines.

**Copied as they are**, at goken's `e549ce551` (2026-09-23), with no
line added: a file's origin and license are said here, not in a header
of its own, so that the files stay the same bytes as goken's and a diff
shows what ix changed. Today nothing:

    lib_core/diff_goken_libc.sh        # each file against ~/goken's

**License.** Plan 9's code is Copyright (c) 2021 Plan 9 Foundation,
under the MIT license; goken's own additions (the Linux system calls,
`os/linux/`, `syscall/`) are under the same, by their authors. goken's
`copyright.txt` and `license.txt` are in [`LICENSE`](LICENSE).

**The layout** is goken's: `port/` (C that is the same everywhere),
`fmt/` (print and its floats), `utf/`, `math/`, `os/linux/` and
`syscall/os/linux/` (Linux's system calls), `arch/arm/` and
`arch/arm64/` (the start, and arm's divisions), `include/`. Two
differences, for goken reaches them through symbolic links:
`include/os/posix/errno.h` is its `include/os/unix/errno.h`, and
`utf.h` is found by `-Iinclude/utf`.

**Which files**: those mini-ld takes from goken's whole libc (139
objects) for mini-ml's runtime (`IX_LOG=info mini-ld ...` says each
"from a library"): 67 objects on arm64, 70 on arm. `lib_core/mkfile`
lists them, and makes `libc.a` with mini-cc, mini-asm and mini-ar.

**Later**: trimmed to what the runtime calls, as the stdlib was (the
formats, `strtod` and the math functions are most of it).
