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
 * Int64 itself, whose interface is OCaml's: ix compiles with both.
 *
 * Where it stands: the 64-bit machine of mini-qemu (Arm64's
 * registers, Mmu64's page tables, Pi4's devices). A register of 64
 * bits does not fit an int, which has 63 bits on arm64 and 31 on arm
 * (Binary's header: one bit of the word tells a number from an
 * address), so the emulator's values are int64, each a block of the
 * heap, and nearly every line of it is this arithmetic. *)

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
