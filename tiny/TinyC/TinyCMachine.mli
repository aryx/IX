(* tiny-c's code generator: the stack machine's code of a function as
 * TinyCPU's assembly, the stack's values in registers r1 to r12. Read
 * TinyCLower.mli first, and TinyMachine/TinyMachineCPU.mli for the
 * instructions. *)

(* the functions' assembly, as it is made *)
val out : Buffer.t

(* [machine f locals code]: f's assembly, its locals taking that many
 * bytes of its frame, added to out *)
val machine : TinyCTypes.sym -> int -> TinyCLower.ir list -> unit
