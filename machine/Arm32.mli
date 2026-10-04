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

(* the user-mode state: r0-r15 (words), the flags; [next] is the address
 * the instruction running jumps to, pc + 4 unless it writes pc *)
type state = {
  r : int array;
  mutable n : bool;
  mutable z : bool;
  mutable c : bool;
  mutable v : bool;
  mutable next : int;
  mem : Memory.t;
  (* the privileged state, a system's (plan_pi.md, decision 1); user
   * mode keeps usr (0x10), no MMU. [mode]: the CPSR's mode bits; the
   * A, I, F masks; [banked]: r13 and r14 of each bank not current (usr
   * and sys, svc, abt, und, irq, fiq); [fiq_banked]: r8-r12, the other
   * modes' (0-4) or FIQ's (5-9), whichever is not current; [spsr] per
   * bank. [translate]: the MMU, a virtual address and an access (bit
   * 0 a write, bit 1 as user) to a physical one, or Abort, used when
   * [mmu]; [coproc]: mcr and mrc; [vectors]: 0 or 0xffff0000 *)
  mutable mode : int;
  mutable a_off : bool;
  mutable i_off : bool;
  mutable f_off : bool;
  banked : int array;
  fiq_banked : int array;
  spsr : int array;
  mutable mmu : bool;
  mutable translate : int -> int -> int;
  mutable coproc : state -> t -> unit;
  mutable vectors : int;
  mutable exclusive : int;          (* the monitor's physical address, -1 open *)
  mutable vfp_ok : bool;            (* VFP granted (CPACR) *)
  vfp : int array;                  (* d0-d31, two words each *)
  mutable fpscr : int;
  mutable fpexc : int;
  mutable fpsid : int;
}

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

type exn_kind = Reset | Undefined_instruction | Supervisor_call | Prefetch_abort | Data_abort | Irq | Fiq

(* an exception taken, [ret] into the new mode's lr; st.next the vector *)
val take : state -> exn_kind -> ret:int -> unit
