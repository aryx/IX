(* tiny-arm: TinyLibArm's CPU run as Linux runs a user program; its
 * usage and examples: [help], what tiny-arm -h prints.
 *
 * The program is an executable, TinyAssembler's: its segments copied
 * where they say, the stack as execve leaves it, the entry jumped to.
 * The operating system is four calls, read, write, exit and getpid, as
 * Linux numbers them on arm64 (x8): what the test programs of TinyC
 * and TinyML make, goken's libc included. So the same file runs here,
 * on the real CPU and under mini-5i, and the three are compared.
 * TinyMachinePi runs the same CPU with the Pi 4's devices, where an
 * svc is an exception taken.
 *
 * What is dropped: the environment (envp is empty), and every other
 * call (a file opened, memory asked for): an error naming its number.
 *
 * The memory when the first instruction runs, for a program given n
 * arguments (its own name the first): what a kernel's exec builds,
 * and all a program is told about the world:
 *
 *     the top             the arguments' strings, a 0 after each
 *       ...
 *     sp + 8(n+1)         0, argv's end; 0, envp's (empty); 0 0, the
 *                         auxiliary vector's end
 *     sp + 8              argv[0] ... argv[n-1]: the strings' addresses
 *     sp, 16-aligned      argc: n
 *       ...               the stack, 8 MB, growing down
 *     end, page rounded   after the bss
 *     0x400000            the ELF's one segment: its header, the text,
 *                         the data, then the bss (TinyAssembler's
 *                         header has its picture)
 *     0                   memory too (an array from 0), never used
 *
 * A system call is svc with the call's number in x8 and its arguments
 * in x0 up, the answer in x0: 63 read, 64 write, 93 exit (94
 * exit_group, the same here), 172 getpid, which answers 1. The
 * numbers are those of Linux's newer ports, one table for arm64,
 * RISC-V and the others, where each older port (arm, x86) has its
 * own.
 *
 * terminology:
 * An emulator of a user program and an emulator of a machine are two
 * programs, and QEMU ships both: qemu-aarch64 runs one Linux
 * executable and turns each of its system calls into the host's
 * (user mode), qemu-system-aarch64 runs a kernel on devices (system
 * mode). This file is the first kind and TinyMachinePi the second,
 * around one CPU; mini-5i (Linux and Plan9, its two tables of calls)
 * and mini-qemu are the same pair in m-ix, and Plan 9's 5i was of
 * the first kind only.
 *
 * plan9-is-cleaner:
 * What a process finds on its stack at its start is, on Linux, four
 * things one after the other (the arguments, the environment, and
 * the auxiliary vector of numbered facts about the machine and the
 * executable, added for the dynamic linker), each ended by a zero
 * because none says its length. On Plan 9 it is the arguments (and a
 * small structure the kernel fills, with the pid and the clock): the
 * environment is files, /env (mini-rc's Env), read when wanted. *)

(* an executable's bytes, loaded and run with its arguments, its
 * system calls done here: to its exit status *)
val run : < Cap.stdin; Cap.stdout; Cap.stderr; .. > -> string -> string list -> int

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; .. > -> int
