(* A tiny CPU of our own: its instruction set, its encoding, and an
 * interpreter. It is a CPU and its memory, with no devices. Two
 * programs use this library:
 * - TinyCPU.ml runs the CPU alone, and the host answers its system
 *   calls;
 * - TinyMachine.ml adds around the CPU what a kernel needs, and there a
 *   system call is a trap.
 * This follows Knuth's road with MIX and MMIX: when a machine is meant
 * for teaching, design it. mini-5i (machine/) emulates the machine that
 * history left us; this one is the machine that fifty years of
 * hindsight would draw.
 *
 * Since the machine is new, no existing tool writes its words, so it
 * comes with its own assembler, tiny-as (TinyAssembler.ml), and its own
 * linker, tiny-ld (TinyLinker.ml), as MIX came with MIXAL, the notation
 * in which the book's programs are written. mini-5i borrows a real
 * toolchain instead, mini-asm and mini-ld. The machine's design keeps
 * both tools small: there is one format, every instruction is 4 bytes,
 * and every immediate is the low 16 bits.
 *
 * The machine:
 * - 16 registers of 32 bits. r0 is always 0, which gives a zero at hand
 *   and a place to throw a result away (the choice of RISC-V and MIPS).
 * - A byte-addressed memory of 2^20 bytes. Addresses are taken modulo
 *   its size, so nothing faults. The two low bits of a word's address
 *   are ignored: as in MMIX, there is no alignment trap, and no
 *   alignment check either.
 * - No flags. A branch compares two registers, and slt turns a
 *   comparison into a value (ARM's flags are something an instruction
 *   set can do without).
 * - One format: an 8-bit opcode, two 4-bit registers d and a, and a
 *   16-bit immediate. In the three-register instructions, the low 4 bits
 *   of the immediate name the third register, b.
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
 * The immediate is signed, except for andi, ori, xori (and lui). A
 * shift takes its amount modulo 32. A division by 0 gives -1 and leaves
 * the dividend as the remainder, and the one overflow, -2^31 / -1,
 * gives -2^31 with remainder 0. These are RISC-V's answers: an
 * instruction set must define every case. A system call takes its
 * arguments in r1-r3 and answers in r1; what the call does is decided
 * by the program that runs the CPU. By convention, sp is r14 (set to
 * the top of memory at the start) and lr is r15. The assembler adds
 * pseudo-instructions: li and la (load a value or an address, as lui
 * and ori, or as one addi), mov, call, ret, j, nop.
 *
 * Here is a program and its listing (tiny-cpu -l prints the address,
 * the word, and the word decoded back into assembly):
 *
 *             li    r1, 3            0:   11100003   addi r1, r0, 3
 *     loop:   addi  r1, r1, -1       4:   1111ffff   addi r1, r1, -1
 *             bne   r1, r0, loop     8:   3110fffe   bne  r1, r0, 0x4
 *             li    r2, 0x12345678   c:   20201234   lui  r2, 0x1234
 *                                    10:  17225678   ori  r2, r2, 22136
 *             sys   0                14:  3f000000   sys  0
 *
 * A word can be read directly in hexadecimal, because the fields are
 * cut at hex digits: 11 1 0 0003 is opcode 0x11 (addi), d 1, a 0, and
 * the immediate 3. li is not an instruction: a small value becomes an
 * addi from r0, and a large one becomes lui for the high half and ori
 * for the low half. A branch's immediate counts words from the next
 * instruction: going from 0xc back to 4 is -2, fffe. Zero is not an
 * opcode, so a program that runs into memory never written stops.
 *
 * twin:
 * The twin, mini-5i, also keeps its decoded words as this CPU does, but
 * indexed by address (Cpu). So a program that wrote over its code would
 * run the old code, and mini-qemu's loop has to empty the cache when a
 * mapping changes. mini-5i also has a second execute function, which
 * allocates nothing, for what a kernel runs most (Arm32_fast), while
 * Arm32's remains the definition. Here [step] is both.
 *
 * kept:
 * - {b The interpreter is the definition.} [step] is the machine's
 *   semantics, a match on the decoded word. Memory holds the program,
 *   so a program may compute its own code.
 * - {b A machine can change five things}, the fields of [env]: the
 *   fetch, a load, a store, a system call, and what to do with a word
 *   that [decode] does not know. TinyCPU gives plain memory, the host's
 *   calls, and an error. A machine gives its pages, its devices behind
 *   addresses, a trap, and its own instructions (which the listing
 *   learns through [show]). What happens between two instructions, such
 *   as an interrupt, is the job of the loop that calls [step], not of
 *   [step].
 * - {b The laws.} Each program of TinyCPU_tests/ prints results known
 *   from elsewhere (Python's answers). And a program's listing is
 *   assembly again, which gives back the same words when reassembled
 *   (printing, parsing, encoding and decoding agree). This does not hold
 *   for data, whose words may decode as instructions with bits that the
 *   encoding ignores.
 *
 * twist:
 * The decoded words are indexed by the word itself ([keep_decoded], in
 * the .ml), not by their address as in the twin. No store can make
 * this cache wrong, so nothing ever empties it, and a program that
 * writes over its code runs the new code.
 *
 * context:
 *     objects: of .s files by hand (v0, tiny-as), of tiny-cc's
 *              and tiny-ml's   |  tiny-ld: an image
 *     this file:   the CPU ([step], given an [env]), the encoding
 *                  they use, the listing
 *                 /                          \
 *     TinyCPU: the env is memory and       TinyMachineDevices: the env is
 *     three calls of the host's            pages, devices and a trap;
 *                                          used by TinyMachine and
 *                                          TinyMachineWeb
 *
 * exercises:
 * Each one is cheap because the interpreter is the definition, and a
 * machine changes the CPU only through env:
 * - a translator back to arm32, as QEMU does. It was written once (185
 *   lines) and then removed as a second topic; git history has it. The
 *   law: the same output whether interpreted or translated.
 * - a decode cache (threaded code): each word decoded once into a
 *   closure kept by its address, and dropped when a store hits it.
 *   Measure its speed against step.
 * - compressed instructions: 16-bit forms of the most common ones
 *   (RISC-V's RVC). Measure the density on tiny-kernel's programs, with
 *   the listing's law checking them.
 * - a debugger through env: breakpoints are words that decode does not
 *   know, caught by illegal, which then shows the program's registers
 *   and memory.
 *
 * cs-history:
 * Knuth designed MIX in the 1960s for The Art of Computer Programming,
 * so that the book's programs would be real ones, with costs one can
 * count, and tied to no manufacturer. It is a machine of its time: a
 * byte holds 64 to 100 values, so that it is neither binary nor
 * decimal; the sign is kept apart from the magnitude; and a subroutine
 * returns by storing its return address into its own last instruction.
 * By the 1990s no reader had seen such a machine, and he replaced it
 * with MMIX (1999), a 64-bit RISC designed with advice from the
 * architects of MIPS and Alpha. The lesson kept here is the first one:
 * the machine a book is written for can be drawn to fit the book.
 *
 * others:
 * Other machines drawn for a course: Hennessy and Patterson's DLX
 * (1990), which is MIPS with its accidents removed and the one this CPU
 * is nearest to; Patt and Patel's LC-3, with 16 bits, eight registers
 * and flags; Nisan and Schocken's Hack, with two kinds of instruction
 * and no call. RISC-V (Berkeley, 2010) began as a summer project for a
 * laboratory's own research and courses, and is the case of an academic
 * machine that became an industry's.
 *
 * design:
 * Leaving out the flags removes a register that every instruction
 * writes and no instruction names. With flags (ARM, x86), a comparison
 * and the branch that uses it are two instructions joined by hidden
 * state, which an interrupt must save and which a processor running
 * instructions out of order must rename like any other register;
 * mini-5i's arm64 computes four of them at each s-instruction. Without
 * flags (MIPS, Alpha, RISC-V, here), a branch reads two registers, and
 * a comparison kept for later is a value in a register (slt). The price
 * is paid on arithmetic wider than a register: a carry must then be
 * computed, with an sltu, instead of read from a flag.
 *
 * design:
 * A register that is always zero costs one of the sixteen, and pays
 * for itself in opcodes that are no longer needed: mov is an addi of 0,
 * li an addi from r0, nop an addi into r0, a negation a sub from r0, a
 * jump a jal that throws its link into r0, and an absolute address (a
 * device's, a kernel variable's) is an offset from r0, with no register
 * to load first.
 *
 * references:
 *  - D. E. Knuth, The Art of Computer Programming, vol. 1 (MIX, 1968;
 *    MMIX, fascicle 1, 2005): a machine designed to teach
 *  - D. A. Patterson and J. L. Hennessy, the MIPS and RISC-V books: the
 *    load-store machine
 *  - J. R. Bell, "Threaded Code" (CACM, 1973)
 *  - F. Bellard, "QEMU, a Fast and Portable Dynamic Translator"
 *    (USENIX, 2005)
 *  - A. Waterman, "Design of the RISC-V Instruction Set Architecture"
 *    (PhD thesis, 2016): the compressed instructions
 *)

(* [m32] keeps the low 32 bits; [ult] compares unsigned words *)
val m32 : int -> int
val ult : int -> int -> bool

(* The instructions, their encoding and the exception Error are
 * TinyLibMachine's. *)
val error : ('a, unit, string, 'b) format4 -> 'a

(* A power of two, set before [boot]. [addr] wraps an address into the
 * memory; [word] also clears its two low bits. *)
val memsize : int ref
val addr : int -> int
val word : int -> int

type machine = { r : int array; mutable pc : int; mem : Bytes.t }

type env = {
  fetch : machine -> int -> int;
  load : machine -> TinyLibMachine.size -> int -> int;
  store : machine -> TinyLibMachine.size -> int -> int -> unit;
  sys : machine -> int -> unit;
  illegal : machine -> int -> unit;
}

(* [plain] is the env of a program alone, on plain memory *)
val load : machine -> TinyLibMachine.size -> int -> int
val store : machine -> TinyLibMachine.size -> int -> int -> unit
val plain : sys:(machine -> int -> unit) -> env

(* [boot] puts the image at 0 and sp at the top of memory *)
val step : env -> machine -> unit
val boot : string -> machine

(* [image name bytes] checks that the bytes fit in the memory. [show]
 * lists the instructions a machine adds (TinyMachineDevices.show). *)
val image : string -> string -> string
val listing : show:(int -> string option) -> origin:int -> string -> string

(* A profile counts each instruction by mode, window base and address;
 * the function given to [profiled] returns the mode (1 kernel, 0 user)
 * and the base. [profile_lines] gives "k|u base pc count" in hex, most
 * counted first, for tiny-prof (TinyProfiler.mli). *)
type profile
val profile : unit -> profile
val profiled : env -> profile -> (machine -> int * int) -> env
val profile_lines : profile -> string

