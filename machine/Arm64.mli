(* The arm64 core: an instruction decoded (Arm64_isa has its type) and run; the
 * state, the exceptions. Arm64_isa's header says how the decoder is tested. *)
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

(* the state: x0-x30 and sp (slot 31), the flags; [next] is the
 * address the instruction running jumps to, pc + 4 unless it
 * branches.
 *
 * And the privileged state (plan_pi.md, phase G), which user mode
 * (mini-5i) leaves at EL0 with the MMU off: the exception level, SPSel
 * and the stack pointers of each level (slot 31 the current one,
 * [sp_el] the others), DAIF (D 8, A 4, I 2, F 1), and per level ELR,
 * SPSR, ESR, FAR, VBAR. The board supplies the rest: the MMU's
 * translation (an address, bit 0 a write, bit 1 as user, to a
 * physical address, or Abort), the other system registers, and the
 * system instructions (hints, dc, ic, tlbi, at, hvc, smc, brk).
 * [monitor]: the exclusive monitor's physical address, -1 clear. *)
type state = {
  x : int64 array;
  mutable n : bool;
  mutable z : bool;
  mutable c : bool;
  mutable v : bool;
  mutable next : int;
  mem : Memory.t;
  mutable el : int;
  mutable spsel : bool;
  sp_el : int64 array;
  mutable daif : int;
  elr : int64 array;
  spsr : int64 array;
  esr : int64 array;
  far : int64 array;
  vbar : int64 array;
  mutable mmu : bool;
  mutable translate : int64 -> int -> int;
  mutable read_sysreg : int -> int64;
  mutable write_sysreg : int -> int64 -> unit;
  mutable system : state -> t -> unit;
  mutable monitor : int;
  (* claude: v0-v31's low 64 bits, the scalar floating point's s and d *)
  fp : int64 array;
  fph : int64 array;                (* claude: their high halves (a q's) *)
  mutable aarch32 : bool;           (* claude: EL0 in AArch32 (eret's M[4]): the board runs it *)
}

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
