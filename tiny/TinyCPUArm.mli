(* tiny-arm: a tiny ARM CPU that runs a program the way Linux runs a
 * user program. It is an interpreter for the arm64 instructions that
 * the programs of the tiny toolchain execute: it loads an executable
 * written by TinyAssembler and answers its system calls itself. Its
 * usage and examples are in [help] (what tiny-arm -h prints). mini-5i
 * (in machine/) is the counterpart of 5i: it handles every word the
 * toolchains emit, for two architectures, with a decode cache. This
 * file is what remains when the only programs to run are the ones
 * from TinyC and TinyML, with goken's libc.
 *
 * Why two small CPUs, this one and TinyMachineCPU? TinyCPU is a
 * designed machine, where every choice is ours, and it comes with its
 * own assembler because nothing else writes its words. This one is an
 * inherited machine, the one inside a Pi, a phone and a Mac, so its
 * programs come from a real toolchain and it can be checked from the
 * outside: the same executable must give the same output on the real
 * CPU, under mini-5i, and here. Neither CPU has devices: both stop at
 * the system call. TinyCPU has a machine around it, TinyMachine, which
 * uses it as a library; this one has none in t-ix (for a Pi, the
 * machine is mini-qemu, in raspberry/).
 *
 * What makes it small:
 *
 * - {b No assembler and no instruction type.} A word is decoded and
 *   executed in a single match, group by group, following the tables
 *   of the architecture manual: immediate operands, branches, loads
 *   and stores, registers. The words come from TinyAssembler.
 * - {b The interpreter runs the words themselves.} Memory holds the
 *   bytes of the program; each step fetches the word at pc and decodes
 *   it, as the hardware does. There is no decode cache (mini-5i has
 *   one).
 * - {b It implements a measured subset.} The groups below are the ones
 *   executed by the test programs of TinyC and TinyML, including
 *   goken's libc (52 mnemonics, see plan_tiny_arm64.md), completed
 *   where the other forms of a group cost only a line. A word outside
 *   the subset stops the program and reports its address, so the
 *   subset also acts as a check.
 * - {b The operating system is just four calls}: read, write, exit and
 *   getpid, numbered as Linux numbers them on arm64 (in x8). These are
 *   the calls the test programs of TinyC and TinyML make, goken's libc
 *   included. So the same file runs here, on the real CPU and under
 *   mini-5i, and the three outputs are compared.
 *
 * How a word is decoded. Every instruction is 32 bits, and four of
 * those bits, 28 to 25, select which table of the manual describes the
 * rest. That is the outer match of [step]:
 *
 *     bits 28-25   the group                             in [step]
 *     1 0 0 x      an immediate operand (add, mov, and,  8 | 9
 *                  a bitfield, adr)
 *     1 0 1 x      branches, and svc                     10 | 11
 *     x 1 x 0      loads and stores                      4 | 6 | 12 | 14
 *     x 1 0 1      registers (add, and, csel, mul, div)  5 | 13
 *     x 1 1 1      floating point and SIMD               not here
 *
 * For example, take the word d28acf01, the first of the two words
 * TinyAssembler writes for MOV $0x12345678, R1:
 *
 *     1  10  100101  00  0101011001111000  00001
 *     sf opc         hw  imm16             rd
 *
 * Bits 28 to 25 are 1001, so this is an immediate operand; bits 25 to
 * 23 are 101, so it is a 16-bit move; opc 10 means movz (00 is movn,
 * 11 is movk); hw 00 puts the 16 bits at bit 0; sf 1 means the whole
 * 64-bit register. So x1 becomes 0x5678, and the next word, a movk
 * with hw 01, sets bits 16 to 31 to 0x1234. Most fields sit at the
 * same place in every group (rd in the low five bits, rn in the next
 * five, sf at the top), so [step] reads them once, before its match.
 *
 * The subset: add, sub and their flag-setting forms (cmp, cmn) with an
 * immediate, a shifted register or an extended register; the logical
 * instructions (and, orr, eor, bic, orn, eon, tst) with a bitmask
 * immediate or a shifted register; movz, movn, movk; the bitfield
 * instructions (sbfm, bfm, ubfm, which give the shifts by a constant,
 * the extensions, and ubfx); the shifts by a register; madd, msub
 * (mul), udiv, sdiv; csel and its three variants; adr, adrp; the loads
 * and stores of 1, 2, 4 and 8 bytes, zero- or sign-extended, with a
 * scaled, unscaled, pre-indexed or post-indexed offset, or a register
 * offset, and the pair forms (stp, ldp); the load of a literal; b, bl,
 * br, blr, ret, b.cond, cbz, cbnz, tbz, tbnz; and svc. Left out,
 * compared to Arm64 in machine/: floating point and SIMD, the
 * exclusive and atomic loads, adc and sbc, ccmp, the high halves of
 * multiplies, clz and the byte reversals, and extr.
 *
 * The program is an executable written by TinyAssembler: its segments
 * are copied where they say, the stack is set up as execve leaves it,
 * and we jump to the entry. What is left out: the environment (envp is
 * empty), and every other system call (opening a file, asking for
 * memory), which fails with an error that names its number.
 *
 * Here is the memory when the first instruction runs, for a program
 * given n arguments (the first being its own name). It is what a
 * kernel's exec builds, and it is all a program is told about the
 * world:
 *
 *     the top             the argument strings, each followed by a 0
 *       ...
 *     sp + 8(n+1)         0, the end of argv; 0, the end of the
 *                         (empty) envp; 0 0, the end of the
 *                         auxiliary vector
 *     sp + 8              argv[0] ... argv[n-1]: the addresses of
 *                         the strings
 *     sp, 16-aligned      argc: n
 *       ...               the stack, 8 MB, growing down
 *     end, page rounded   after the bss
 *     0x400000            the single segment of the ELF: its header,
 *                         the text, the data, then the bss (there is
 *                         a picture in TinyAssembler's header)
 *     0                   memory too (an array starting at 0), but
 *                         never used
 *
 * A system call is an svc, with the call number in x8, the arguments
 * in x0 and up, and the result in x0: 63 is read, 64 write, 93 exit
 * (94, exit_group, is the same here), and 172 getpid, which returns 1.
 * These are the numbers of the newer Linux ports, which share one
 * table for arm64, RISC-V and the others, whereas each older port
 * (arm, x86) has its own.
 *
 * Exercises:
 * - floating point: the registers d0 to d31, fmov, fadd and the
 *   others, and the conversions, for TinyML's floats;
 * - a decode cache, as in machine/: decode each address only once;
 * - a trace printing the address and the word of each instruction, as
 *   mini-5i -t does.
 *
 * Where it fits: the words come from TinyAssembler, which assembles
 * the output of TinyC and TinyML. Arm64 in mini-5i is the same
 * instruction set in full, with Arm32 next to it, and TinyMachineCPU
 * is the same kind of file for a machine that never needed a manual:
 * reading the two [step]s side by side shows how many extra cases
 * forty years of compatibility cost.
 *
 * cs-history:
 * The ARM comes from Acorn (instruction set by Sophie Wilson, design by
 * Steve Furber; first silicon in 1985). It was made for the computer
 * that would follow the BBC Micro, by a small team that had read the
 * Berkeley RISC papers. Few transistors meant low power, which nobody
 * had asked for, but which later, in telephones, became the reason ARM
 * is everywhere. Apple, Acorn and VLSI spun ARM off as its own company
 * in 1990, for the Newton. The 64-bit architecture, ARMv8, was
 * announced in 2011 and shipped in a telephone in 2013; it is a new
 * instruction set, not the old one made wider.
 *
 * evolution:
 * What arm64 dropped from arm, each visible here by its absence: the
 * condition on every instruction (it remains on branches, and on a few
 * selections such as csel); the pc as a register that any instruction
 * can write; the load and store of a list of registers (now only a
 * pair: stp, ldp); and the shifter operand whose shift amount could
 * itself be a register. What it added: thirty-one registers instead of
 * sixteen, and a register 31 that means either zero or the stack
 * pointer, depending on the instruction ([reg] and [sp]).
 *
 * terminology:
 * AArch64 is the 64-bit state of the processor, A64 its instruction
 * set, ARMv8-A the version of the architecture that introduced them,
 * and arm64 is what Linux and Apple call all of it. Plan 9 gives each
 * machine a character: 5 is arm (5a, 5c, 5l, and 5i the emulator,
 * hence the name mini-5i), 7 is arm64 (7a, 7c, 7l).
 *
 * Emulating a user program and emulating a machine are two different
 * programs, and QEMU ships both: qemu-aarch64 runs a single Linux
 * executable and translates each of its system calls into one of the
 * host (user mode), while qemu-system-aarch64 runs a kernel on
 * emulated devices (system mode). This file is of the first kind, like
 * mini-5i (with its two tables of calls, Linux and Plan9) and Plan 9's
 * 5i; mini-qemu is of the second kind, and so is TinyMachine, built
 * around TinyCPU.
 *
 * plan9-is-cleaner:
 * On Linux, a process finds four things one after the other on its
 * stack when it starts: the arguments, the environment, and the
 * auxiliary vector (numbered facts about the machine and the
 * executable, added for the dynamic linker), each ended by a zero
 * because none of them gives its length. On Plan 9 there are only the
 * arguments (plus a small structure the kernel fills, with the pid and
 * the clock): the environment is a set of files in /env (mini-rc's
 * Env), read when needed.
 *
 * design:
 * The constant in a logical instruction (and, orr, eor) is not a
 * 12-bit number as in add, but a 13-bit encoding of a pattern: a run
 * of ones, rotated, and repeated across the register ([bitmask]).
 * 0x00ff00ff is such a pattern; 0x1234 is not, and must be built in a
 * register first. This is the one place where decoding is more than
 * reading fields, and it is the reason TinyAssembler never writes such
 * an immediate.
 *
 * References: Arm Architecture Reference Manual for A-profile (ARM DDI
 * 0487), for the encodings, organized by the groups of its tables; and
 * machine/ in ix, run on the same programs, for the behavior. *)

(* an executable's bytes, loaded and run with its arguments, its
 * system calls done here: to its exit status *)
val run : < Cap.stdin; Cap.stdout; Cap.stderr; .. > -> string -> string list -> int

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; .. > -> int
