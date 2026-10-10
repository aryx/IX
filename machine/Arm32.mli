(* The arm core: an instruction decoded (Arm32_isa has its type) and run; the
 * state, the exceptions. Arm32_isa's header says how the decoder is tested.
 *
 * {b A word.} Every instruction is 32 bits, and its top four are a
 * condition: the instruction runs if the flags satisfy it, and is
 * nothing otherwise. Bits 27-25 give the class; the commonest, the
 * data-processing instructions:
 *
 *     31  28 27 26 25 24  21 20 19  16 15  12 11                0
 *     | cond | 0  0 | I| opcode| S|  Rn  |  Rd  |    operand 2    |
 *
 *     e0823103   1110 00 0 0100 0 0010 0011 00010 00 0 0011
 *                AL        ADD    r2   r3   #2    lsl  r3
 *                add r3, r2, r3, lsl #2        r3 = r2 + (r3 << 2)
 *
 * Rd = Rn op operand 2, the opcode one of sixteen (and, eor, sub,
 * rsb, add, adc, sbc, rsc, tst, teq, cmp, cmn, orr, mov, bic, mvn);
 * S says whether the flags are set from the result. The other
 * classes, by bits 27-26: loads and stores (01), block transfers
 * of several registers and branches (10), coprocessors and svc (11).
 *
 * {b Operand 2}, the barrel shifter. The second operand goes through
 * a shifter before the operation, in the same instruction and the
 * same cycle. With I = 0 it is a register shifted (lsl, lsr, asr,
 * ror) by a constant or by another register; with I = 1 it is 8
 * bits rotated right by twice 4 bits, the only immediates there are
 * ([imm_value]; the linker's Arm.mli says which constants that
 * makes). So a C expression as a[i], whose address is a + i * 4, is
 * one instruction, ldr r0, [r1, r2, lsl #2], and a multiplication
 * by 5 is add r0, r0, r0, lsl #2.
 *
 * {b The flags and the conditions.} Four bits of state, set by an
 * instruction with S and by the comparisons: N (the result is
 * negative), Z (zero), C (a carry out, or for a subtraction no
 * borrow), V (a signed overflow). The sixteen conditions are tests
 * of them ([cond_passed]):
 *
 *     0 EQ  Z            equal            8 HI  C and not Z   unsigned >
 *     1 NE  not Z                         9 LS  not C or Z    unsigned <=
 *     2 CS  C            unsigned >=     10 GE  N = V         signed >=
 *     3 CC  not C        unsigned <      11 LT  N <> V        signed <
 *     4 MI  N            negative        12 GT  not Z, N = V  signed >
 *     5 PL  not N                        13 LE  Z or N <> V   signed <=
 *     6 VS  V            overflow        14 AL  always
 *     7 VC  not V
 *
 * After cmp r0, r1, which is r0 - r1 with only the flags kept, GE
 * and CS are the two meanings of "r0 >= r1", for signed and
 * unsigned numbers: the processor has one subtraction, and the
 * difference between the two kinds of integers is in which
 * condition the compiler writes. An absolute value without a branch:
 *
 *     cmp   r0, #0
 *     rsblt r0, r0, #0        if r0 < 0 then r0 = 0 - r0
 *
 * {b The registers.} Sixteen, of which three have a job: r13 the
 * stack pointer by convention, r14 the link register, where bl puts
 * the return address, and r15 the pc itself, readable and writable
 * as any other: a return is mov pc, lr, a jump through a table is a
 * load into pc. Read, the pc is the instruction's address plus 8
 * ([execute]'s addr + 8): the first ARMs fetched two instructions
 * ahead of the one executing, and the programs came to depend on
 * what they saw.
 *
 * {b Exceptions} ([take]), what makes the core a system's and not
 * only a program's. An interrupt, a system call, a page fault all do
 * the same four things: the mode changes (bits of the CPSR, the
 * flags' register), the old CPSR is saved in the new mode's SPSR,
 * the address to come back to goes in the new mode's r14, and the
 * pc becomes a fixed address, a vector:
 *
 *     0x00 reset          svc mode      0x10 data abort    abt
 *     0x04 undefined      und           0x18 IRQ           irq
 *     0x08 svc            svc           0x1c FIQ           fiq
 *     0x0c prefetch abort abt
 *
 * Each mode has its own r13 and r14 (banked: [set_mode] swaps them),
 * so a handler starts with a stack of its own and the return
 * address without having saved anything, and nothing of the
 * interrupted program is touched. A kernel's first lines of
 * assembly are the eight branches at those addresses.
 *
 * Where it stands: Cpu's loop calls [decode] and [execute] for a
 * program (mini-5i), Board's for a kernel (mini-qemu), with Mmu32
 * as the state's translate and [take] called for the interrupts and
 * the faults. The words decoded here are the ones the linker's Arm
 * encodes, the same table read the other way, and Show_arm32 prints
 * them as objdump does.
 *
 * cs-history:
 * ARM is the Acorn RISC Machine. Acorn, in Cambridge, made the BBC
 * Micro around the 6502 and wanted a faster processor for its
 * successor; Sophie Wilson designed the instruction set and Steve
 * Furber the hardware, after the Berkeley RISC papers, and the
 * first chips, in April 1985, worked the first time. It was a few
 * people's work and about 25,000 transistors, where a 68020 had
 * some 200,000 (from memory). The Archimedes (1987) used its
 * successor; in 1990 the design became a company, ARM, with Apple,
 * which wanted the processor for the Newton, and it has sold the
 * design and not chips ever since.
 *
 * design:
 * A condition on every instruction is the idea most its own. A
 * short if costs no branch, and a branch, on a processor that has
 * fetched the next instructions already, costs their loss. It cost
 * four bits of each instruction for a condition that is nearly
 * always "always", and when branch predictors made a branch
 * nearly free the 64-bit ARM gave the bits to other uses
 * (Arm64.mli).
 *
 * others:
 * Against the other RISCs of its years (MIPS, SPARC): the same
 * fixed 32-bit instruction and the same rule that only loads and
 * stores touch memory; but flags and conditions where MIPS compares
 * into a register, a shifter in each operand, instructions that
 * load or store a set of registers at once (push and pop), and
 * sixteen registers, not thirty-two. Less pure, and denser code,
 * which mattered on a machine with little memory.
 *
 * References: ARM Architecture Reference Manual (ARM DDI 0100, the
 * ARMv6 edition; DDI 0406 for ARMv7; from memory), part A for the
 * instructions, part B for the modes and the exceptions; Steve
 * Furber, ARM System-on-Chip Architecture (2000), by one of the two
 * designers, for why it is so; principia's machine/5i, Plan 9's
 * interpreter. *)
open Arm32_isa

val decode : int -> t

(* the value of an Imm operand, and the shifter's carry out when the
 * rotation is not 0 (bit 31 of the value) *)
val imm_value : imm8:int -> rot:int -> int

(*****************************************************************************)
(* Execution *)
(*****************************************************************************)

exception Unimplemented of int * int  (* the word, its address *)

(* a translation fault: the address, the fault status (FSR's) *)
exception Abort of int * int

val create : Memory.t -> state

(* the instruction at [addr], r15 reading addr + 8; [svc] runs a
 * system call *)
val execute : state -> addr:int -> svc:(state -> int -> unit) -> t -> unit

val cond_passed : state -> cond -> bool

(* the privileged state *)
val cpsr : state -> int
val write_cpsr : state -> int -> int -> unit     (* the value, the fields f s x c *)
val set_mode : state -> int -> unit

(* an exception taken, [ret] into the new mode's lr; st.next the vector *)
val take : state -> exn_kind -> ret:int -> unit
