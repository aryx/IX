(* The arithmetic of 64-bit integers written as an int's, in a local
 * open: where Int64's functions read
 *
 *   Int64.logand (Int64.shift_right_logical v 32) mask
 *
 * this module's operators read
 *
 *   I64.((v lsr 32) land mask)
 *
 * Inside I64.( ... ) every +, land, lsl... is the 64-bit one: an int's
 * arithmetic (an index, a shift's amount) is computed outside, or
 * brought in by [int]. The comparisons stay OCaml's (signed). Not in
 * Int64 itself, whose interface is OCaml's: ix compiles with both. *)

val ( + ) : int64 -> int64 -> int64
val ( - ) : int64 -> int64 -> int64
val ( * ) : int64 -> int64 -> int64
val ( land ) : int64 -> int64 -> int64
val ( lor ) : int64 -> int64 -> int64
val ( lxor ) : int64 -> int64 -> int64
val lnot : int64 -> int64

(* by an int's number of bits; lsr the logical shift, asr the arithmetic one *)
val ( lsl ) : int64 -> int -> int64
val ( lsr ) : int64 -> int -> int64
val ( asr ) : int64 -> int -> int64

(* Int64.of_int *)
val int : int -> int64
