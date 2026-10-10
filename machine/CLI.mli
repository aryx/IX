(* mini-5i: an ARM program run on a machine that is not an ARM, as
 * its system would run it. The processor is interpreted, one
 * instruction after the other; the system is not: when the program
 * asks its kernel for something (svc), the request is answered here,
 * by the host's own files and processes.
 *
 *     hello (a file)                    the modules, a program's way
 *        | Elf, Plan9.parse   which machine, which system; the
 *        |                    segments and the entry
 *        | Linux.load         the segments in a Memory, the stack
 *        | (Plan9.load)       as exec leaves it: argc, argv, envp
 *     a state: 16 registers, 4 flags, the memory
 *        | Cpu.run32          the loop:
 *        |   Memory.load32      fetch the word at the pc
 *        |   Arm32.decode       to an Arm32_isa.t (kept: a cache)
 *        |   Arm32.execute      the registers, the flags, the memory
 *        |     svc -> Linux.syscall32   write, open, fork, exit...
 *        |              '-> Host_calls.t, a record: Host, on Unix
 *        '-- Linux.Exit       the program's status is ours
 *
 * Arm64, Arm64_isa and run64 for an arm64 ELF; Plan9 where Linux is,
 * for an a.out; Show_arm32 for -t's trace; Bits under all of them,
 * for the arithmetic of a 32-bit word in an OCaml int.
 *
 * The three parts are kept apart because each is used without the
 * others. The core (Arm32, Arm64) knows no system: mini-qemu runs
 * the same core as a whole machine, with an MMU, interrupts and
 * devices around it, and a kernel inside (Board, Pi4). A
 * personality (Linux, Plan9) knows a system's calls and no Unix.
 * Host is the only module that calls the real system; where there
 * is no Unix (a browser) another record would take its place.
 *
 * Where it stands: it is how ix's own arm programs are run and
 * tested on the machine they are built on, mini-asm, mini-ld,
 * mini-cc and mini-ml making them, without a board and without
 * QEMU. What it emulates is the two interfaces a program sees: the
 * instruction set below it, the system calls beside it.
 *
 * terminology:
 * User mode and system mode, QEMU's words. A user-mode emulator
 * (qemu-arm, this program) runs one program and plays the kernel
 * itself, in the host's terms: fast to start, and the program's
 * files are the host's. A system emulator (qemu-system-arm,
 * mini-qemu) plays the hardware and runs the kernel as it is: the
 * privileged instructions, the MMU, the devices, a disk's image.
 * The processor's core is the same in both, which is why it is a
 * module.
 *
 * cs-history:
 * The name is Plan 9's. vi (the v is the MIPS's letter) ran a MIPS
 * Plan 9 binary on any Plan 9 machine, as a debugger and as a
 * gatherer of statistics on the instructions run (vi(1), from
 * memory); ki, qi and 5i are the same for the sparc, the powerpc
 * and the arm. In a system where every machine's
 * compiler runs on every other, they closed the loop: a program
 * could be compiled for a machine one did not have, then run, and
 * profiled.
 *
 * modern:
 * Nobody interprets when speed matters: QEMU translates the guest's
 * code to the host's, a block at a time, and Apple's Rosetta 2
 * translates a whole program before it starts. Cpu.mli says what is
 * done here instead, and what it costs.
 *
 * The command line: [help] in CLI.ml, what mini-5i -h prints. *)

val main : < Cap.argv; Cap.open_in; Cap.open_out; Cap.stdout; Cap.stderr; Cap.fork; Cap.wait; Cap.chdir; Cap.kill; Cap.exec; Cap.env; .. > -> int
