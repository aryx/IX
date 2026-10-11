(* tiny-arm: a tiny ARM CPU, run as Linux runs a user program: an
 * interpreter for the arm64 instructions the tiny toolchain's programs
 * execute, an executable of TinyAssembler's loaded, its system calls
 * answered here. Its usage and examples: [help], what tiny-arm -h
 * prints. mini-5i (machine/) is 5i's twin: every word the toolchains
 * emit, two architectures, a decode cache. This is what is left when
 * the programs run are TinyC's and TinyML's, with goken's libc.
 *
 * Why this and TinyLibCPU, two small CPUs: TinyCPU is a machine
 * designed, every choice ours, with an assembler because nothing else
 * writes its words. This one is a machine inherited, the one in a
 * Pi, a phone and a Mac, so its programs come from a real toolchain
 * and its check is outside it: the same executable gives the same
 * output on the real CPU, under mini-5i and here. Neither has
 * devices: a system call is where both stop. TinyCPU has its machine
 * below it, TinyMachine, which uses it as a library; this one has
 * none in t-ix: a Pi's is mini-qemu (raspberry/).
 *
 * What makes it small:
 *
 * - {b No assembler, no instruction type.} A word is decoded and run
 *   in one match, group by group as the architecture's manual tables
 *   them: an immediate operand, a branch, a load or a store, registers.
 *   The words are TinyAssembler's.
 * - {b The interpreter runs words.} Memory holds the program's bytes;
 *   each step fetches the word at pc and decodes it, as the hardware
 *   does. No decode cache: mini-5i has one.
 * - {b A subset, counted.} The groups below are the ones the test
 *   programs of TinyC and TinyML execute, goken's libc included (52
 *   mnemonics, plan_tiny_arm64.md), completed where a group's other
 *   forms cost a line. A word outside it stops the program with its
 *   address, so the subset is also a check.
 * - {b The operating system is four calls}, read, write, exit and
 *   getpid, as Linux numbers them on arm64 (x8): what the test
 *   programs of TinyC and TinyML make, goken's libc included. So the
 *   same file runs here, on the real CPU and under mini-5i, and the
 *   three are compared.
 *
 * How a word is read. Every instruction is 32 bits, and four of them,
 * 28 to 25, say which table of the manual the rest is read by; that
 * is [step]'s outer match:
 *
 *     bits 28-25   the group                             in [step]
 *     1 0 0 x      an immediate operand (add, mov, and,  8 | 9
 *                  a bitfield, adr)
 *     1 0 1 x      branches, and svc                     10 | 11
 *     x 1 x 0      loads and stores                      4 | 6 | 12 | 14
 *     x 1 0 1      registers (add, and, csel, mul, div)  5 | 13
 *     x 1 1 1      floating point and SIMD               not here
 *
 * For example the word d28acf01, the first of the two TinyAssembler
 * writes for MOV $0x12345678, R1:
 *
 *     1  10  100101  00  0101011001111000  00001
 *     sf opc         hw  imm16             rd
 *
 * Bits 28 to 25 are 1001, an immediate operand; 25 to 23 are 101, a
 * move of 16 bits; opc 10 is movz (00 movn, 11 movk); hw 00 puts them
 * at bit 0; sf 1 is all 64 bits. So x1 becomes 0x5678, and the next
 * word, a movk with hw 01, sets its bits 16 to 31 to 0x1234. Most
 * fields are where they are in every group (rd in the low five bits,
 * rn in the next five, sf at the top), which [step] reads once before
 * its match.
 *
 * The subset: add, sub and their flags (cmp, cmn) with an immediate, a
 * shifted or an extended register; the logical ones (and, orr, eor,
 * bic, orn, eon, tst) with a bitmask immediate or a shifted register;
 * movz, movn, movk; the bitfields (sbfm, bfm, ubfm: the shifts by a
 * constant, the extensions, ubfx); the shifts by a register; madd,
 * msub (mul), udiv, sdiv; csel and its three variants; adr, adrp; the
 * loads and stores of 1, 2, 4 and 8 bytes, zero or sign-extended,
 * with a scaled, an unscaled, a pre or post-indexed offset, or a
 * register's, and a pair's (stp, ldp); a literal's load; b, bl, br,
 * blr, ret, b.cond, cbz, cbnz, tbz, tbnz; svc. Left out, against
 * machine/'s Arm64: floating point and SIMD, the exclusive and atomic
 * loads, adc and sbc, ccmp, the multiplies' high halves, clz and the
 * byte reversals, extr.
 *
 * The program is an executable, TinyAssembler's: its segments copied
 * where they say, the stack as execve leaves it, the entry jumped to.
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
 * Exercises:
 * - floating point: the registers d0 to d31, fmov, fadd and the
 *   others, the conversions, for TinyML's floats;
 * - a decode cache, machine/'s: decode once per address;
 * - a trace, each instruction's address and word, as mini-5i -t's.
 *
 * Where it stands: the words are TinyAssembler's, from TinyC's and
 * TinyML's assembly. mini-5i's Arm64 is the same instruction
 * set whole, with Arm32 beside it, and TinyLibCPU is the same file's
 * plan for a machine that needed no manual: reading the two [step]s
 * side by side shows what forty years of compatibility cost in
 * cases.
 *
 * cs-history:
 * The ARM is Acorn's (Sophie Wilson's instruction set, Steve Furber's
 * design; first silicon in 1985), made for the computer after the BBC
 * Micro by a small team that had read the Berkeley RISC papers: few
 * transistors meant little power, which nobody had asked for and
 * which, in telephones, became the reason it is everywhere. Apple,
 * Acorn and VLSI made ARM a company of its own in 1990, for the
 * Newton. The 64-bit
 * architecture, ARMv8, was announced in 2011 and was in a telephone
 * in 2013; it is a new instruction set, not the old one widened.
 *
 * evolution:
 * What arm64 dropped from arm, each visible here by its absence:
 * the condition on every instruction (left on the branch, and on a
 * few selections: csel); the pc as a register any instruction may
 * write; the load and the store of a list of registers (a pair now:
 * stp, ldp); the shifter operand that could itself be a register.
 * What it added: thirty-one registers where there were sixteen, and
 * a register 31 that is zero or the stack pointer according to the
 * instruction ([reg] and [sp]).
 *
 * terminology:
 * AArch64 is the processor's 64-bit state, A64 its instruction set,
 * ARMv8-A the architecture's version that brought them, arm64 what
 * Linux and Apple call the lot. Plan 9 gives a machine a character:
 * 5 is arm (5a, 5c, 5l, and 5i the emulator, whence mini-5i), 7 is
 * arm64 (7a, 7c, 7l).
 *
 * An emulator of a user program and an emulator of a machine are two
 * programs, and QEMU ships both: qemu-aarch64 runs one Linux
 * executable and turns each of its system calls into the host's
 * (user mode), qemu-system-aarch64 runs a kernel on devices (system
 * mode). This file is of the first kind, as mini-5i (Linux and
 * Plan9, its two tables of calls) and Plan 9's 5i; mini-qemu is of
 * the second, and so is TinyMachine, around TinyCPU.
 *
 * plan9-is-cleaner:
 * What a process finds on its stack at its start is, on Linux, four
 * things one after the other (the arguments, the environment, and
 * the auxiliary vector of numbered facts about the machine and the
 * executable, added for the dynamic linker), each ended by a zero
 * because none says its length. On Plan 9 it is the arguments (and a
 * small structure the kernel fills, with the pid and the clock): the
 * environment is files, /env (mini-rc's Env), read when wanted.
 *
 * design:
 * A constant in a logical instruction (and, orr, eor) is not a number
 * of 12 bits as add's is, but a pattern in 13: a run of ones, rotated,
 * repeated across the register ([bitmask]). 0x00ff00ff is one;
 * 0x1234 is not, and must be built in a register first. It is the
 * one place
 * where decoding is not reading fields, and the reason TinyAssembler
 * never writes one.
 *
 * References: Arm Architecture Reference Manual for A-profile (ARM DDI
 * 0487): the encodings, by their tables' groups; machine/
 * in ix, run on the same programs: the behavior. *)

(* an executable's bytes, loaded and run with its arguments, its
 * system calls done here: to its exit status *)
val run : < Cap.stdin; Cap.stdout; Cap.stderr; .. > -> string -> string list -> int

(* the program: its arguments (-h: how) to its exit status *)
val main : < Cap.stdin; Cap.stdout; Cap.stderr; Cap.argv; Cap.open_in; .. > -> int
