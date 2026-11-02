(* Wide: what of an int's arithmetic needs more bits than an int has.
 *
 * [mul_high a b] is the multiply-high of the processors (arm's UMULL,
 * arm64's UMULH, C compilers' __umulh): the bits of a * b above an
 * int's, where a * b keeps the Sys.int_size bits below. Together the
 * two make the whole product, of twice an int's bits:
 *
 *     the product  =  mul_high a b * 2^Sys.int_size  +  the bits of a * b
 *
 * (a * b's bits read as unsigned: it is negative when the top one is set)
 *
 * Where it stands: Bignum's limbs on arm, where an int has 31 bits. A
 * product of two limbs must fit an int, so limbs had 14 bits; with the
 * high part they have 28, half as many limbs and a quarter as many
 * products for a number.
 *
 * Two files: this directory's for mini-ml, an external, the
 * processor's instruction in its code (the runtime's ml_mul_high in
 * simple's); ocaml/'s for dune's build, in OCaml. *)

(* a and b not negative *)
val mul_high : int -> int -> int
