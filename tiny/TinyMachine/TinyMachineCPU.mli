(* A tiny CPU of our own: its instruction set, its encoding, and an
 * interpreter; a CPU and its memory, no devices. The library of two
 * programs: TinyCPU.ml, the CPU run alone, its system calls answered
 * by the host; and TinyMachine.ml, the CPU with what a kernel needs
 * around it, its system calls traps. Knuth's road with MIX and MMIX:
 * when the machine is for teaching, design it; mini-5i (machine/)
 * emulates the machine history left us, this one the machine fifty
 * years of hindsight would draw.
 *
 * The machine is new, so nothing else writes its words: it comes with
 * its assembler, tiny-assembler (TinyAssembler.ml), and its linker,
 * tiny-linker (TinyLinker.ml), as MIX came with MIXAL, the notation
 * the book's programs are written in; mini-5i borrows a real
 * toolchain's, mini-asm's and mini-ld's. Both are kept small by the
 * machine's design: one format, every instruction 4 bytes, every
 * immediate its low 16 bits.
 *
 * The machine: 16 registers of 32 bits, r0 always 0 (a zero at hand
 * and a place to throw a result away, RISC-V's and MIPS's choice); a
 * byte-addressed memory of 2^20 bytes, the addresses taken modulo its
 * size (nothing faults), a word's two low address bits ignored (MMIX:
 * no alignment trap, and no alignment check either); no flags: a
 * branch compares two registers, slt makes a comparison a value (ARM's
 * flags are what an instruction set can do without). One format: an
 * 8-bit opcode, two 4-bit registers d and a, and a 16-bit immediate
 * whose low 4 bits name the third register of the three-register
 * instructions:
 *
 *     31      24 23  20 19  16 15                0
 *     |  opcode  |  d   |  a   |   immediate / b |
 *
 * add sub mul div rem and or xor shl shr sar slt sltu   d = a op b
 * addi andi ori xori shli shri sari slti sltiu        d = a op imm
 * lui                                                  d = imm << 16
 * ldw ldb stw stb                                      d, imm(a)
 * beq bne blt bge bltu bgeu                            d, a, label
 * jal jalr                                             d = pc + 4
 * sys                                                  imm: the call's number
 *
 * The immediate is signed but for andi, ori, xori (and lui); a shift
 * takes its amount modulo 32; a division by 0 gives -1 and leaves the
 * dividend as the remainder, and the one overflow (-2^31 / -1) gives
 * -2^31 and 0 (RISC-V's answers: an instruction set defines every
 * case). A system call takes its arguments in r1-r3 and answers in
 * r1 (what it does is the program's that runs the CPU). By
 * convention sp is r14 (the top of memory at the start), lr r15; the
 * assembler's pseudo-instructions: li, la (a value, an address: lui
 * and ori, or addi), mov, call, ret, j, nop.
 *
 * A program, and its listing (tiny-cpu -l: the address, the word, the
 * word decoded again):
 *
 *             li    r1, 3            0:   11100003   addi r1, r0, 3
 *     loop:   addi  r1, r1, -1       4:   1111ffff   addi r1, r1, -1
 *             bne   r1, r0, loop     8:   3110fffe   bne  r1, r0, 0x4
 *             li    r2, 0x12345678   c:   20201234   lui  r2, 0x1234
 *                                    10:  17225678   ori  r2, r2, 22136
 *             sys   0                14:  3f000000   sys  0
 *
 * A word reads off in hexadecimal, the format being cut at its
 * digits: 11 1 0 0003 is opcode 0x11 (addi), d 1, a 0, the immediate
 * 3. li is no instruction: a small value is an addi from r0, a large
 * one lui for the high half and ori for the low. A branch's immediate
 * is counted in words from the next instruction: from 0xc back to 4
 * is -2, fffe. Zero is no opcode, so memory never written stops a
 * program that runs into it.
 *
 * Who is around it:
 *
 *     .tm files: by hand (v0), by tiny-c, by tiny-ml
 *                  |  tiny-assembler, tiny-linker: an image
 *     this file:   the CPU ([step], given an [env]), the encoding
 *                  they use, the listing
 *                 /                          \
 *     TinyCPU: the env is memory and       TinyMachineDevices: the env is
 *     three calls of the host's            pages, devices and a trap;
 *                                          TinyMachine's and
 *                                          TinyMachineWeb's
 *
 * What makes it small:
 *
 * - {b The interpreter is the definition.} [step] is the machine's
 *   semantics, a match on the decoded word; memory holds the program,
 *   so a program may compute its code.
 * - {b A machine changes five things}, the fields of [env]: the fetch,
 *   a load, a store, a system call, and a word [decode] does not know.
 *   TinyCPU gives memory, the host's calls, and an error; a machine
 *   gives its pages, its devices behind addresses, a trap, and its own
 *   instructions (which the listing learns by a [show]). What
 *   happens between two instructions (an interrupt) is the loop's
 *   that calls [step], not [step]'s.
 * - {b The laws}: each program of TinyCPU_tests/ prints what is
 *   known otherwise (Python's answers); and a program's listing is
 *   assembly again, which reassembled gives the same words (print,
 *   parse, encode and decode agree; not for data, whose words may
 *   decode as instructions with bits the encoding ignores).
 *
 * Exercises, each cheap because the interpreter is the definition and
 * a machine changes the CPU only through env:
 * - a translator back (to arm32, as QEMU's): written once, 185 lines,
 *   then removed as a second topic (git history has it); the law, the
 *   same output interpreted and translated;
 * - a decode cache (threaded code): each word decoded once, into a
 *   closure kept by its address, and dropped when a store hits it;
 *   measure the speed against step;
 * - compressed instructions: 16-bit forms of the commonest (RISC-V's
 *   RVC), the density measured on tiny-kernel's programs, the listing's
 *   law checking them;
 * - a debugger by env: breakpoints as a word decode does not know,
 *   caught by illegal, the program's registers and memory then shown.
 *
 * cs-history:
 * Knuth designed MIX in the 1960s for The Art of Computer Programming
 * so that the book's programs would be real ones with costs one can
 * count, and tied to no manufacturer. It is a machine of its time: a
 * byte of 64 to 100 values so that it is neither binary nor decimal,
 * a sign apart from the magnitude, and a subroutine that returns by
 * storing its return address into its own last instruction. By the
 * 1990s no reader had seen such a machine, and he replaced it with
 * MMIX (1999), a RISC of 64 bits designed with advice from the
 * architects of MIPS and Alpha. The lesson kept here is
 * the first one: the machine a book is written for can be drawn to
 * fit the book.
 *
 * design:
 * Leaving out the flags removes a register that every instruction
 * writes and no instruction names. With them (ARM, x86) a comparison
 * and the branch that uses it are two instructions joined by hidden
 * state, which an interrupt must save and which a processor that
 * runs instructions out of order must rename like any register;
 * mini-5i's arm64 computes four of them at each s-instruction.
 * Without them (MIPS, Alpha, RISC-V, here) a branch reads two
 * registers, and a comparison kept for later is a value in a
 * register (slt). The price is on arithmetic wider than a register:
 * a carry is then computed, by an sltu, not found.
 *
 * design:
 * A register that is always zero costs one of sixteen and pays for
 * itself in opcodes not needed: mov is an addi of 0, li an addi from
 * r0, nop an addi into r0, a negation a sub from r0, a jump a jal
 * that throws its link into r0, and an absolute address (a device's,
 * a kernel's variable) an offset from r0, with no register to load
 * first.
 *
 * others:
 * The other machines drawn for a course: Hennessy and Patterson's
 * DLX (1990), MIPS with its accidents removed, the one this is
 * nearest to; Patt and Patel's LC-3, 16 bits and eight registers,
 * with flags; Nisan and Schocken's Hack, two kinds of instruction
 * and no call. RISC-V (Berkeley, 2010) began as a summer's project
 * for a laboratory's own research and courses, and is the case of an
 * academic machine that became an industry's.
 *
 * References: D. E. Knuth, The Art of Computer Programming, vol. 1
 * (MIX, 1968; MMIX, fascicle 1, 2005): a machine designed to teach;
 * D. A. Patterson and J. L. Hennessy, the MIPS and RISC-V books: the
 * load-store machine; J. R. Bell, "Threaded Code" (CACM,
 * 1973); F. Bellard, "QEMU, a Fast and Portable Dynamic Translator"
 * (USENIX, 2005); A. Waterman, "Design of the RISC-V
 * Instruction Set Architecture" (PhD thesis, 2016), the
 * compressed instructions. *)

(* a word's 32 bits of an int that may have more; a < b, both unsigned
 * words *)
val m32 : int -> int
val ult : int -> int -> bool

(* The instructions and their words are TinyMachineISA's (a load's
 * size, sp and lr, the exception Error); its error, by a format *)
val error : ('a, unit, string, 'b) format4 -> 'a

(* the memory's size, a power of two (a host sets it before [boot]);
 * an address in the memory, and its word's *)
val memsize : int ref
val addr : int -> int
val word : int -> int

(* the CPU: sixteen registers, a pc, the memory's bytes *)
type machine = { r : int array; mutable pc : int; mem : Bytes.t }

(* what is around it, the host's or a machine's: how a word is
 * fetched, loaded and stored (plain memory, or pages and devices),
 * what a sys does, and a word the CPU does not know *)
type env = {
  fetch : machine -> int -> int;
  load : machine -> TinyMachineISA.size -> int -> int;
  store : machine -> TinyMachineISA.size -> int -> int -> unit;
  sys : machine -> int -> unit;
  illegal : machine -> int -> unit;
}

(* plain memory's load and store, and the env of a program alone *)
val load : machine -> TinyMachineISA.size -> int -> int
val store : machine -> TinyMachineISA.size -> int -> int -> unit
val plain : sys:(machine -> int -> unit) -> env

(* The interpreter: one instruction; and a machine with an image at 0 *)
val step : env -> machine -> unit
val boot : string -> machine

(* An image: a file's bytes, checked to fit in the memory (its name,
 * for the error); its listing, the words a machine adds by [show]
 * (TinyMachineDevices.show) *)
val image : string -> string -> string
val listing : show:(int -> string option) -> origin:int -> string -> string

(* A profile: every instruction run, counted by where it was (the
 * kernel's or a program's, the base of the user's window, the address).
 * [profiled env p where] is env counting into p, [where m] the mode (1
 * the kernel's, 0 a program's) and the window's base; [profile_lines p]
 * the counts as lines "k|u base pc count" (hexadecimal addresses), the
 * most counted first, which tiny-prof reads (TinyProfiler.mli).
 * tiny-cpu's -prof and tiny-machine's write them. *)
type profile
val profile : unit -> profile
val profiled : env -> profile -> (machine -> int * int) -> env
val profile_lines : profile -> string

