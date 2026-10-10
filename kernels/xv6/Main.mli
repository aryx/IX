(* mini-xv6 (plan_kernel.md): xv6 in OCaml, one kernel on two boards,
 * the Raspberry Pi 1 (ARMv6, arm32) and the Pi 4 (ARMv8, arm64), each
 * running its xv6 port's own user programs from that port's own fs.img
 * (xv6-multiarch's arm-pi1, arm64-pi4): init, sh, the utilities,
 * usertests. One xv6, xv6-riscv's semantics: the ports converging.
 *
 * The kernel: Types (the data), Machine (the board's machine.c's
 * primitives), Arch (what else differs between the boards), Mmu
 * (pages and address spaces), Proc (processes, sleep and wakeup, the
 * scheduler), Fs (the file system, in place on the RAM disk), File
 * (open files, pipes, the console), Exec, Syscall; this module handles
 * the traps start.s and machine.c hand to OCaml ("trap", "irq",
 * "fault", "process_start") and boots: the timer, the UART's input, the
 * first process, which runs /init (xv6's initcode, done by the kernel),
 * then the scheduler, forever.
 *
 *     a user program (xv6's own C: sh, ls, cat, usertests)
 *        |  a system call, a fault, the timer's interrupt: a trap
 *     ---+----------------------------------------- user / kernel
 *     Main          trap, irq, fault: whose it is, what to do
 *        | Syscall  the call's number and arguments, read in the trap
 *        |          frame and in the user's memory; fork, exit, wait
 *        |-- Proc   the table; sleep, wakeup, sched; the scheduler
 *        |-- Exec   a program's file made the process's memory
 *        |-- File   what a descriptor names: a pipe, an inode, the
 *        |    |     console
 *        |    '-- Fs   names, inodes, blocks, on a disk that is RAM
 *        '-- Mmu    the free pages; a process's table (Page, Arch)
 *     Machine       the trap frame, swtch, the timer, the UART
 *     ---+----------------------------------------- OCaml / C
 *     machine.c, start.s (the boot, the vectors, the switch), and
 *     the OCaml runtime with its collector
 *
 * A read(0, buf, n) typed at sh goes down that picture: the trap
 * enters Main.trap on the process's own kernel stack, Syscall finds
 * the number and the three arguments, File asks the console for a
 * line and, there being none yet, Proc.sleep leaves for the scheduler
 * in the middle of the call; a key's interrupt (File.intr) wakes the
 * process, which goes on where it slept, and Syscall copies the bytes
 * to the user's memory through its table (Mmu.copyout).
 *
 * Built up in kernels/steps/step1-5/ (on the Pi1): OCaml bare-metal, user mode and
 * system calls, processes on their own kernel stacks (the collector
 * seeing them all), the MMU, the timer.
 *
 * What is ours: the kernel is a garbage-collected program. Its data
 * are OCaml's values (Types), xv6's "return -1 and undo" is an option
 * or an exception, and nothing of it is locked (Proc says why it may
 * be so). What OCaml cannot say stays in C and assembly under
 * Machine: the vectors, the trap frame, the switch between kernel
 * stacks, and telling the collector where those stacks are.
 * mini-9pi, ix's larger kernel, is built on the same Machine, Mmu
 * and Arch.
 *
 * cs-history:
 * xv6 is the sixth edition of Unix (1975, Bell Labs, for the PDP-11)
 * written again. That kernel was small enough to be read whole, and
 * John Lions, at the University of New South Wales, printed it with a
 * commentary for his students (1977). From the seventh edition (1979)
 * AT&T's licence forbade teaching from the source, and the book went
 * from hand to hand as photocopies until it could be published
 * (1996). At MIT, Russ Cox, Frans Kaashoek and Robert Morris wrote
 * xv6 in 2006 for their operating systems course: V6's structure and
 * Lions' way of presenting it, in ANSI C, for a multiprocessor x86;
 * since 2019 the course's xv6 is for RISC-V. Its ports to other
 * processors are many; the two this kernel follows are
 * xv6-multiarch's.
 *
 * others:
 * The same licence is why Andrew Tanenbaum wrote Minix (1987): a Unix
 * of his own to teach from, a microkernel where V6 and xv6 are one
 * program. Linux was begun on Minix (1991). Kernels in a collected
 * language are older than they seem: the Lisp machines' and Oberon's
 * (mini-oberon, in this tree) had no other; Biscuit (MIT, 2018) is a
 * POSIX kernel in Go that measures what the collector costs.
 *
 * why-study:
 * An xv6 is the smallest kernel that still has every part a Unix
 * has: processes that fork and exec, a file system with inodes and
 * directories, pipes, a shell that is a user program. Each part is
 * the first version of what Linux has grown; read here, then there.
 *
 * References: Russ Cox, Frans Kaashoek and Robert Morris, "xv6: a
 * simple, Unix-like teaching operating system" (the course's book,
 * revised each year: the RISC-V edition is the one whose semantics
 * are here), to read with the source, chapter by module. John Lions,
 * "A Commentary on the UNIX Operating System" (1977; published as
 * "Lions' Commentary on UNIX 6th Edition, with Source Code", 1996):
 * the same walk through V6. Dennis Ritchie and Ken Thompson, "The
 * UNIX Time-Sharing System" (Communications of the ACM, 1974): what
 * the system is for. Cody Cutler, Frans Kaashoek and Robert Morris,
 * "The benefits and costs of writing a POSIX kernel in a high-level
 * language" (OSDI 2018): Biscuit. plan_kernel.md, and the tutorial,
 * notes_kernel.md. *)
