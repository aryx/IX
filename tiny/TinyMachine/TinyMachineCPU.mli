(* A tiny CPU of our own: its instruction set, an assembler, and an
 * interpreter; a CPU and its memory, no devices. The library of two
 * programs: TinyCPU.ml, the CPU run alone, its system calls answered
 * by the host; and TinyMachine.ml, the CPU with what a kernel needs
 * around it, its system calls traps. Knuth's road with MIX and MMIX:
 * when the machine is for teaching, design it; mini-5i (machine/) and
 * TinyCPUArm.ml emulate the machine history left us, this one the machine
 * fifty years of hindsight would draw.
 *
 * Why an assembler, in a file about a machine: the machine is new, so
 * nothing else writes its words. TinyCPUArm.ml has none: its words are
 * TinyAssembler's, a real toolchain's; this one
 * has no toolchain to borrow, and a machine no one can program teaches
 * nothing. Programs by hand-encoded hex words would be the other way,
 * and MIX's lesson is that a machine for teaching comes with its
 * assembly language (MIXAL), the notation the book's programs are
 * written in. The assembler is kept small by the machine's design: one
 * format, every instruction 4 bytes, so two passes (the labels, then
 * the words) and no relaxation; its pseudo-instructions (li, la, call,
 * ret) are the only sequences it chooses.
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
 *     .tm files: by hand (tiny-os v0), by tiny-c -tm, by tiny-ml -tm
 *                  |
 *     this file:   the assembler ([image]: the files one after the
 *                  other, their labels one name space) and the CPU
 *                  ([step], given an [env])
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
 *   instructions (which
 *   the assembler and the listing learn by an [extension]). What
 *   happens between two instructions (an interrupt) is the loop's
 *   that calls [step], not [step]'s.
 * - {b The laws}: each program of TinyCPU_tests/ prints what is
 *   known otherwise (Python's answers); and a program's listing is
 *   assembly again, which reassembled gives the same words (print,
 *   parse, encode and decode agree; not for data, whose words may
 *   decode as instructions with bits the encoding ignores).
 *   TinyCPU_test.sh checks the first on its programs, the second
 *   on random programs of every instruction.
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
 *   RVC), the density measured on tiny-os's programs, the listing's
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
 * TinyCPUArm's [add] computes four of them at each s-instruction.
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

(* what is wrong in a program's text or in a run, said to the person *)
exception Error of string
val error : ('a, unit, string, 'b) format4 -> 'a

(* the memory's size, a power of two (a host sets it before [boot]);
 * the stack pointer's register; an address in the memory, and its
 * word's *)
val memsize : int ref
val sp : int
val addr : int -> int
val word : int -> int

(* the CPU: sixteen registers, a pc, the memory's bytes *)
type machine = { r : int array; mutable pc : int; mem : Bytes.t }
type size = W | B

(* what is around it, the host's or a machine's: how a word is
 * fetched, loaded and stored (plain memory, or pages and devices),
 * what a sys does, and a word the CPU does not know *)
type env = {
  fetch : machine -> int -> int;
  load : machine -> size -> int -> int;
  store : machine -> size -> int -> int -> unit;
  sys : machine -> int -> unit;
  illegal : machine -> int -> unit;
}

(* plain memory's load and store, and the env of a program alone *)
val load : machine -> size -> int -> int
val store : machine -> size -> int -> int -> unit
val plain : sys:(machine -> int -> unit) -> env

(* The interpreter: one instruction; and a machine with an image at 0 *)
val step : env -> machine -> unit
val boot : string -> machine

(* the assembler's items, for an extension: instructions of another's
 * (TinyMachineDevices's csrr, eret...), how a line is parsed and how a
 * word is listed *)
type expr = Num of int | Sym of string
type item = Label of string | Words of int * (int -> (expr -> int) -> int list) | Bytes_ of string | Align of int
type extension = { parse : string -> string list -> item option; show : int -> string option }
val no_extension : extension
val reg : string -> int

(* The assembler: lines to their bytes; files (a name, its text; .tm
 * assembled, another an image) linked from an origin; an image listed *)
val assemble : ext:extension -> string list -> string
val image : ext:extension -> origin:int -> (string * string) list -> string

(* the labels of .tm files (a name, its text) linked from an origin, as
 * image links them: each label and its address, by address (tiny-prof's) *)
val labels : ext:extension -> origin:int -> (string * string) list -> (string * int) list
val listing : ext:extension -> origin:int -> string -> string

(* An executable for tiny-kernel: a header of three words (a magic
 * number, the image's size, the memory the program asks for in bytes),
 * then the image, linked at 0. *)
val aout : memory:int -> string -> string

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

