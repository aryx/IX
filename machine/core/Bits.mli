(* The arithmetic that depends on the width of OCaml's int, which has
 * 63 bits natively and 32 under js_of_ocaml (plan_arm.md, decision 3).
 * A 32-bit machine word is an int that holds its 32 bits. Natively it
 * is between 0 and 2^32-1; under js_of_ocaml it has the same bits, read
 * as a signed int. The functions here give the same answers either
 * way, and nothing else in machine/ may compare, print or extend a word
 * without them.
 *
 *   field 0xe0823103 12 4 = 3           (bits 12-15: Rd)
 *   sign_extend 24 0xfffffe = -2        (a branch's imm24)
 *   ror32 0xff 8 = 0xff000000
 *   signed32 0xff000000 = -16777216 *)

(* true natively (with 63-bit ints), false under js_of_ocaml (with 32) *)
val native : bool

(* [field w lo n] is bits lo .. lo+n-1 of w, with n < 31 *)
val field : int -> int -> int -> int
val bit : int -> int -> bool

val sign_extend : int -> int -> int

(* the word with only its 32 bits kept *)
val mask32 : int -> int
val ror32 : int -> int -> int

(* the word read as signed, or as unsigned. The unsigned value is
 * right natively only: under js_of_ocaml an int cannot hold 2^31 and
 * above, so there unsigned32 is only for printing (see to_hex32). *)
val signed32 : int -> int
val unsigned32 : int -> int

(* the unsigned comparison of two words, which is the only kind the
 * machine does. A plain ( <= ) on words is wrong under js_of_ocaml,
 * where a word with bit 31 set is negative. *)
val ule32 : int -> int -> bool
val ult32 : int -> int -> bool

(* a word converted from and to the Int32 that the Bytes accessors use *)
val of_int32 : int32 -> int
val to_int32 : int -> int32

(* a + b + carry_in (0 or 1). It returns the sum, the carry out of
 * bit 31, and the signed overflow, which are ARM's C and V after an
 * addition. A subtraction a - b is a + lnot b + 1, so its C means "no
 * borrow". *)
val add_carry : int -> int -> int -> int * bool * bool

(* add_carry's result, carry and overflow, each computed apart. There
 * is no tuple because these are on the interpreters' hot path. *)
val add32 : int -> int -> int -> int
val carry32 : int -> int -> int -> bool     (* a, the result, cin *)
val overflow32 : int -> int -> int -> bool  (* a, b, the result *)

(* the low 32 bits of a product *)
val mul32 : int -> int -> int

(* the 64-bit product of two words, unsigned or signed, as (low, high) *)
val mul64 : signed:bool -> int -> int -> int * int

(* shifts of a word by 0 to 31 bits *)
val lsl32 : int -> int -> int
val lsr32 : int -> int -> int
val asr32 : int -> int -> int

(* the unsigned value printed as "0x%x", whatever the width *)
val to_hex32 : int -> string
