# kernel/xv6/

mini-xv6: xv6 in OCaml, one kernel on two boards, the Raspberry Pi 1
(ARMv6, arm32) and the Pi 4 (ARMv8, arm64). It runs each board's xv6
port's own user programs, from that port's own `fs.img`
(xv6-multiarch's arm-pi1 and arm64-pi4: init, sh, the utilities,
usertests), with xv6-riscv's semantics. Its plans:
[`docs/plans/plan_kernel.md`](../../docs/plans/plan_kernel.md) (the
kernel) and
[`plan_kernel_mini_ml.md`](../../docs/plans/plan_kernel_mini_ml.md)
(the same kernel built by ix's own tools); its tutorial,
[`notes_kernel.md`](../../docs/tutorials/notes_kernel.md).

The kernel is xv6's, as OCaml says it: a process's state carries what
matters in it, a file is a pipe's end, an inode or a device and not a
tag and three pointers, and xv6's "return -1 and undo" is an
exception. The user programs are xv6's C, unchanged.

## Running it

    ./mini-pi mini-xv6-pi1          the Pi 1, sh's prompt in this terminal
    ./mini-pi mini-xv6-pi4          the Pi 4 (arm64)
    ./mini-pi -g mini-xv6-pi1       its console drawn in a window, a USB keyboard and mouse

from ix's root (`-q`: QEMU in mini-qemu's place; `-n`: no build).
The file system is xv6's, from `$XV6` (default `~/xv6`, xv6-multiarch
with its ports built): it is not in ix.

Two builds of the same sources, here by hand:

    make [BOARD=pi4]     by ocaml-light, gcc, GNU's as and ld:
                         kernel-pi1.img, kernel-pi4.elf
                         (../ocaml-light.sh arm|arm64 first)
    make run             under mini-qemu (Ctrl-A x quits)
    make check           the session below, and usertests under QEMU

    mini-mk [O=5]        by ix's own tools (mini-ml, mini-cc, mini-asm,
                         mini-ld): _mk/7/kernel/xv6/kernel8.img (O=5:
                         the Pi 1's, _mk/5/kernel/xv6/kernel.img)
    mini-mk run
    mini-mk check        the same session, the same expected lines

## What is in this directory

The kernel's own modules; the machine under them is `kernel/lib_machine/`,
which mini-9pi shares (and mini-oberon and mini-singularity, by
links).

| module | lines | what (xv6's files) |
|---|---:|---|
| `Types` | 71 | the data every module shares (proc.h, file.h, fs.h) |
| `Proc` | 84 | the table, sleep and wakeup, the scheduler (proc.c); no locks: one core, never interrupted in the kernel |
| `Fs` | 422 | xv6's file system, on a disk that is RAM (fs.c, sysfile.c's names); with one extension of ix's, files past 314 KB, marked as such |
| `File` | 208 | open files: a pipe's end, an inode, the console (file.c, pipe.c, console.c) |
| `Exec` | 119 | a program's ELF made a process's memory (exec.c) |
| `Syscall` | 262 | the system calls, and fork, exit, wait (syscall.c, sysproc.c, sysfile.c) |
| `Main` | 103 | the boot, the traps, the first process |

(Lines of the `.ml`, 2026-10-07; each has a `.mli` that says what it
is and how it differs from xv6's.)

In `kernel/lib_machine/`: `Machine` (the board's primitives), `Arch` (what
else differs between the boards: `pi1/`, `pi4/`), `Mmu` and `Page`
(pages and address spaces), `Screen` (the console on the framebuffer),
`Usbhost` (a USB keyboard and mouse behind the hub, polled: a kernel's
that asks for it, here and mini-oberon's), and the C and assembly (the boot, the trap frames, the switch between
kernel stacks, the DWC2's primitives).

`expected-pi1`, `expected-pi4`: the check's session as xv6's C kernel
answers it (`make expected` records them); `expected-pi1.ppm.gz`, its
screen on the Pi 1.

## The check

`make check` (and `mini-mk check`, for the build by ix's tools) types
a session at sh (`ls`, `cat README`, `echo`, `mkdir`, `ln`, `wc`,
`rm`, `grep`, `forktest`, two errors) under mini-qemu and under QEMU,
and compares what is printed with **what xv6's own C kernel prints**
for the same session (`expected-$(BOARD)`). Both also
compare the screen (the same under both emulators, and on the Pi 1
the same pixels as the C kernel's), types the session again on a USB
keyboard with the mouse moved, and run xv6's `usertests` under QEMU.

    make check              the Pi 1
    make BOARD=pi4 check    the Pi 4
