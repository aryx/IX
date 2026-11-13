(* The arithmetic of 64-bit integers, written as you would write an int's,
 * inside a local open. Where Int64's functions read
 *
 *   Int64.logand (Int64.shift_right_logical v 32) mask
 *
 * this module's operators read
 *
 *   I64.((v lsr 32) land mask)
 *
 * Inside I64.( ... ) every +, land, lsl... is the 64-bit one. So an
 * int's arithmetic (an index, the amount of a shift) is computed
 * outside, or brought in by [int]. The comparisons stay OCaml's, which
 * are signed. These operators are not in Int64 itself, because its
 * interface is OCaml's and ix compiles with both.
 *
 * Where it stands: the 64-bit machine of mini-qemu uses it (Arm64's
 * registers, Mmu64's page tables, Pi4's devices). A register of 64
 * bits does not fit in an int, which has 63 bits on arm64 and 31 on
 * arm (Binary's header explains why: one bit of the word tells a
 * number from an address). So the emulator's values are int64s, each
 * a block of the heap, and nearly every line of it is this arithmetic. *)

val ( + ) : int64 -> int64 -> int64
val ( - ) : int64 -> int64 -> int64
val ( * ) : int64 -> int64 -> int64
val ( land ) : int64 -> int64 -> int64
val ( lor ) : int64 -> int64 -> int64
val ( lxor ) : int64 -> int64 -> int64
val lnot : int64 -> int64

(* The shifts are by an int number of bits; lsr is the logical shift,
 * and asr the arithmetic one *)
val ( lsl ) : int64 -> int -> int64
val ( lsr ) : int64 -> int -> int64
val ( asr ) : int64 -> int -> int64

(* Int64.of_int *)
val int : int -> int64
