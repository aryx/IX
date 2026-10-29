# Where ix's programs run: ix's kernels, Linux, macOS

Most of ix's programs are not tied to ix's kernels. A utility, the
shell, the compilers, a game: each is an OCaml program that asks its
system for files, processes and a screen through a small interface,
and that interface has a side for each system. So the same source runs
under mini-9pi (on a Pi, under mini-qemu or QEMU), under tiny-kernel
(t-ix's, on tiny-machine), and directly on Linux and macOS. Some
programs are different. They are made of what only a Plan 9 kernel
gives, its namespaces and its device files, and on another system they
build but cannot work. mini-rio is the clearest case: a window system
that *is* a file server for its windows.

This page says which programs are which, and why. "Verified" rows were
read in the code (the file is named); the few marked *inferred* were
reasoned out and not run. Its survey is of 2026-10-29.

## 1. The two ways a program reaches a host

| built by | what it is | where it runs |
|---|---|---|
| dune, with OCaml (`bin/mini-*`, `_build/default/`) | a native program of the host | Linux and macOS (`./configure` knows both, macOS through Homebrew) |
| mini-mk, with ix's own toolchain (`_mk/7/`, `_mk/5/`) | an ELF for arm64 or arm Linux, by mini-ml, mini-asm and mini-ld | Linux on arm (this machine), or under `qemu-arm`/binfmt, or under mini-5i |
| mini-mk `O=5 OS=plan9` (`_mk/5-plan9/`) | a Plan 9 a.out | mini-9pi |

Three facts decide the rest:

- **Off Plan 9, the namespace calls fail.** `Sys_plan9` (lib_core) has
  two sides. On Linux and macOS, `bind`, `mount` and `unmount` raise
  `ENOSYS`, `rfork` is `fork`, and a child's last words and times are
  empty (`lib_core/commons/Sys_plan9.ml`); the real calls are
  `lib_core/system/plan9/`'s.
- **The graphics library is the client of Plan 9's draw device.**
  lib_graphics opens `/dev/draw/new`, `/dev/mouse` and `/dev/cons`
  (`Display.ml`, `Keyboard.ml`), which only mini-9pi serves. A program
  that wants a window on Linux or macOS gets it from an SDL host
  instead, which only dune builds (SDL is outside what mini-ml
  compiles: `lib_playground/platforms/sdl/dune`).
- **mini-mk builds a graphical program for Linux without a window.**
  The top mkfile picks the playground's platform by the system:
  `draw` and `software` for Plan 9, `ppm` otherwise
  (`mkfile`'s `PLATFORMS`): such an ELF writes its frames to files.

## 2. m-ix

| program | Linux | macOS | only on mini-9pi? |
|---|---|---|---|
| the utilities (cat, ls, cp, grep, sed, awk, hoc, dc, bc, tar, gzip, date, cal, ...) | yes, dune and mini-mk | yes, dune | no. ls, cp, mv and chmod fill Plan 9's directory entry from Unix's stat (`utilities/files/Ls.ml`) |
| bind, mount, unmount | build, always fail | the same | **yes**: namespace calls |
| ps, free, kill | run, find nothing | the same | **yes**: they read Plan 9's `/proc` and `/dev/swap`, kill writes `/proc/n/note` (`utilities/process/`) |
| time | runs, its times zeros | the same | partly: the times are Plan 9's `last_times` (`Time.ml`) |
| mini-rc, mini-ed, mini-mk, mini-troff, mini-man | yes, dune and mini-mk | yes, dune | no (rc picks its rcmain by the system: `shell/CLI.ml`) |
| the toolchain: mini-cc, mini-ml, mini-asm, mini-ld, mini-ar, mini-lex, mini-yacc | yes; they write Linux's ELF (`-H7`) or Plan 9's a.out (`-H2`) | the tools, by dune; mini-ld writes Mach-O (`-H6`) for C and assembly programs (goken's libc), not yet for mini-ml's (ix's libc has Linux's and Plan 9's system calls only: `lib_core/libc/syscall/os/`) | no |
| mini-emacs | in a terminal (`mini-emacs-tty`, dune and mini-mk) and in an SDL window (dune) | the same, by dune | its `draw/` build only, in a window of mini-rio |
| **mini-rio** | builds, cannot work | the same | **yes**: it draws through `/dev/draw`, serves its windows as a file server posted in `/srv`, and gives each window a namespace of its own by `bind` and `mount` (`windows/Rio.ml`, `lib_networking/9p/P9_server.ml`) |
| lib_graphics's programs (hellodraw, hellokbd, hellomenu, hellorio) | no | no | **yes**: `/dev/draw`, `/dev/winname` |
| the games, lib_playground | in an SDL window, dune (`bin/mini-doom`); mini-mk's: frames to files | dune, SDL | no; their `draw` and `software` platforms are mini-9pi's |
| mini-netscape | SDL, dune; mini-mk's: frames to files | dune; a known bug, deep recursion in async JavaScript dies by SIGBUS (a thread's stack of 512 KB: `docs/plans/bugs/ix.md`) | no |
| mini-office, mini-drscheme, mini-squeak | SDL, dune | dune | no |
| mini-chidb, mini-git, mini-diff, mini-merge3 | yes, dune and mini-mk | dune | no |
| mini-curl, mini-timesync | yes, dune and mini-mk | dune | no; on mini-9pi through `/net` (`lib_networking/tcp/plan9/`) |
| mini-httpd | yes | dune | **the other way: Linux's only**, sockets, no Plan 9 build (`networking/mkfile`) |
| mini-5i | yes | dune; how an arm64 ELF of ix's runs off Linux | no. Its Plan 9 calls have no `bind`, `mount`, `unmount`, nor `/dev/draw` (`machine/process/Plan9.ml`): a Plan 9 program that needs them runs only on mini-9pi |
| mini-qemu | dune, an SDL window | dune, SDL | it is a host's program: what boots mini-9pi |
| mini-9pi | under mini-qemu or QEMU, or on a Pi | under mini-qemu (the Pi 1's kernel needs Homebrew's llvm and lld) | it is the kernel |
| mini-dossrv | builds; *inferred*: fails to post in `/srv`, which Linux has not | the same | **yes**: a file server mounted by the kernel; its FAT code is tested on the host (`kernels/9pi/filesystems/lib_fat/tests/fat.sh`) |
| mini-fdisk | *inferred*: prints a disk image's partitions (`-p`) | the same | writing a partition table is mini-9pi's (`/dev/sdM0/ctl`) |
| mini-usbd | builds, cannot work | the same | **yes**: `#u/usb` |

Why build mini-rio, the hello programs, mini-dossrv and mini-usbd for
Linux at all, then? The top mkfile's directories are built for every
system: on Linux they are a check that they compile, not programs to
run.

## 3. t-ix

| program | Linux | macOS | only on tiny-machine? |
|---|---|---|---|
| the tools: tiny-shell, tiny-editor, tiny-utils, tiny-build, tiny-db, tiny-vcs, tiny-prof | yes, dune: `TinyLibSystem`'s host side, over Unix (`tiny/TinyKernel/host/`) | yes | no |
| the toolchain: tiny-c, tiny-ml, tiny-assembler, tiny-linker | yes | yes | no |
| tiny-cpu, tiny-machine | yes: they are the host's programs | yes | they are the machine; tiny-machine also runs in a browser (the website's t-ix.html) |
| tiny-office, tiny-www, tiny-troff, tiny-tetris, tiny-calculator | in an SDL window, without the machine (`tiny/sdl/`) | the same (*inferred*) | no |
| tiny-windows, tiny-temperature, the network's get, httpd and ping | no | no | **yes**: tiny-windows is a program of tiny-kernel's (OCaml only checks its types: `tiny/dune`), and the others have no host side |
| tiny-kernel, its graphics, file system and network | — | — | they are the kernel |

## 4. Windows

None. No `Win32`, Cygwin or MinGW case is in any dune file, mkfile,
`configure` or source file, and `configure` knows Linux and macOS
only. The programs use Unix's calls (fork, pipes, a terminal's modes),
which a native Windows OCaml does not have, so a port would need a
side of its own for those. *Inferred*: WSL is Linux, and the Linux
builds may well run there; nothing has tried. The two pages of the
website run anywhere a browser does: mini-qemu and tiny-machine
compiled to JavaScript.

## 5. What is not settled

- macOS: the SDL programs are built by dune there, but no run of them
  is recorded; only the netscape bug and the notes of
  `plan_tiny_utilities.md` show macOS in use.
- ix's own programs as Mach-O need a libc for macOS's system calls
  beside Linux's and Plan 9's; none is planned.
- mini-dossrv's and mini-fdisk's use on a host (a disk image) was not
  tried.
