(* The arm core: an instruction decoded (Arm32_isa has its type) and run; the
 * state, the exceptions. Arm32_isa's header says how the decoder is tested. *)
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
