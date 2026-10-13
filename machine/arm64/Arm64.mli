(* The arm64 core: an instruction decoded (Arm64_isa has its type) and run; the
 * state, the exceptions. Arm64_isa's header says how the decoder is tested.
 *
 * A64 is not the 32-bit instruction set widened: it is another one,
 * with the same company's name. What stays is the word of 32 bits
 * and the four flags N, Z, C, V with their conditions (Arm32.mli's
 * table). An addition of a constant:
 *
 *     31 30 29 28    24 23 22 21        10 9    5 4    0
 *     |sf|op| S|1 0 0 0 1| 0|sh|   imm12   |  Rn  |  Rd  |
 *
 *     910043ff    1  0  0  10001  0  0  000000010000  11111  11111
 *                 64 add              #0x10           sp     sp
 *                 add sp, sp, #0x10
 *
 * sf chooses the width: x0-x30 are the 64-bit registers, w0-w30
 * their low halves, and writing a w register zeroes the high half
 * ([set]). Five bits name a register, so there are 32 numbers, and
 * the 32nd, 31, is not a register but two: the stack pointer in the
 * instructions that address memory or adjust the stack, a register
 * that reads zero and forgets what is written in the others ([get]
 * and [get_sp]). cmp is a subs whose result goes to the zero
 * register, mov a logical or with it: the aliases Show_arm64 prints.
 *
 * What went from A32: the condition on every instruction (branches
 * keep theirs; csel, csinc choose between two registers by one),
 * the pc as a register (bl puts the return address in x30, ret
 * jumps to it, and a load relative to the pc is its own
 * instruction), the instructions that load a set of registers
 * (ldp and stp move two), and operand 2's rotated 8 bits, replaced
 * by three kinds of immediates (the linker's Arm64.mli; [bitmask]
 * is the oddest, decoded here).
 *
 * {b Exception levels} replace A32's seven modes: EL0 for programs,
 * EL1 for a kernel, EL2 for a hypervisor, EL3 for the firmware, each
 * with its own stack pointer. An exception ([take]) goes up to a
 * level and leaves there, in system registers and not in banked
 * general ones:
 *
 *     ELR    where to come back          SPSR   the state before
 *     ESR    why: a class (svc, a data abort, an unknown
 *            instruction...) and details ([syndrome], the ec_ values)
 *     FAR    the address, for an abort
 *
 * and the pc becomes VBAR, the vector table's base, plus an offset
 * that says where it came from and what it is:
 *
 *     + 0x000  from this level, on SP_EL0     + 0x00  synchronous
 *     + 0x200  from this level, on its own sp + 0x80  IRQ
 *     + 0x400  from a lower level, 64-bit     + 0x100 FIQ
 *     + 0x600  from a lower level, 32-bit     + 0x180 SError
 *
 * One synchronous entry for a system call, a page fault and an
 * undefined instruction, told apart by ESR, where A32 has a vector
 * each: the kernel's handler starts by a switch on the class.
 *
 * Where it stands: Cpu.run64 for a program (mini-5i, Linux's arm64
 * calls), Pi4 for a kernel, one state a core, with Mmu64 behind
 * [phys]. A register is an Int64 here, an OCaml int having 63 bits
 * (or 32: Bits).
 *
 * evolution:
 * ARM announced the 64-bit architecture, ARMv8-A, in 2011, and the
 * first processor in many hands was Apple's A7, in a telephone of
 * 2013. By then the reasons for A32's peculiarities had gone: a
 * branch predictor makes a conditional instruction a small gain and
 * a real cost to a processor that runs instructions out of order,
 * and a pc among the registers makes every instruction a possible
 * branch. The designers kept the word's size, dropped the rest,
 * and doubled the registers. A processor of ARMv8 could still run
 * A32 programs under a 64-bit kernel; many of today's cannot.
 *
 * References: Arm Architecture Reference Manual for A-profile (ARM
 * DDI 0487): part C for the instructions, chapter D1 for the
 * exception model. *)
open Arm64_isa

val decode : int -> t

(* what the decoder and the executor share with the printer
 * (compat/Show_arm64): the conditions by their code; a register's
 * width, n ones; the bytes of an operand as a shift; a vector's and a
 * float's immediate expanded *)
val conds : cond array
val width : sf -> int
val ones : int -> int64
val fsize_shift : fsize -> int
val size_shift : size -> int
val movi_value : esize:int -> imm8:int -> amount:int -> int64
val fp_expand_imm : int -> int64

(* the value of a logical immediate, N:immr:imms, for the width; None
 * for the reserved encodings *)
val bitmask : sf -> int -> int -> int -> int64 option

(*****************************************************************************)
(* Execution *)
(*****************************************************************************)

exception Unimplemented of int * int  (* the word, its address *)

(* a translation fault: the virtual address, ESR's ISS (the fault
 * status code, bit 6 a write) *)
exception Abort of int64 * int

val create : Memory.t -> state

(* register r, 31 read as the zero register, or as sp *)
val get : state -> reg -> int64
val get_sp : state -> reg -> int64
val set : state -> sf -> reg -> int64 -> unit
val set_sp : state -> sf -> reg -> int64 -> unit

(* an address below 4GB, or Memory.Fault; and back, zero-extended *)
val address : int64 -> int
val of_address : int -> int64

val execute : state -> addr:int -> svc:(state -> int -> unit) -> t -> unit

val cond_passed : state -> cond -> bool

(* a system register's encoding, by its name ("sctlr_el1"), and back *)
val sysreg : string -> int
val sysreg_name : int -> string

(* a system operation's kind, name and whether it takes a register *)
val sysop : int -> string * string * bool

(* a program counter as a register holds it *)
val of_pc : int -> int64

(* the physical address of an access (bit 0 a write, bit 1 as user) *)
val phys : state -> int64 -> int -> int

(* PSTATE as SPSR keeps it *)
val pstate : state -> int64

(* an exception: [offset] 0 synchronous, 0x80 IRQ; [ret] ELR's; ESR
 * and FAR if some (a synchronous one's) *)
val take : state -> offset:int -> ret:int -> esr:int64 option -> far:int64 option -> unit -> unit

(* ESR's value: its class, the syndrome *)
val syndrome : int -> int -> int64
val ec_unknown : int
val ec_svc : int
val ec_hvc : int
val ec_smc : int
val ec_iabort_lower : int
val ec_iabort : int
val ec_dabort_lower : int
val ec_dabort : int
val ec_brk : int
