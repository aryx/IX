(* Wide: the parts of an int's arithmetic that need more bits than an
 * int has.
 *
 * [mul_high a b] is the processors' multiply-high (arm's UMULL, arm64's
 * UMULH, C compilers' __umulh). It gives the bits of a * b above an
 * int's, while a * b keeps the Sys.int_size bits below. Together the
 * two make the whole product, which has twice an int's bits:
 *
 *     the product  =  mul_high a b * 2^Sys.int_size  +  the bits of a * b
 *
 * (a * b's bits are read as unsigned: a * b is negative when its top
 * bit is set)
 *
 * Where it stands: it serves Bignum's limbs on arm, where an int has
 * 31 bits. A product of two limbs must fit an int, so limbs had 14
 * bits. With the high part they have 28, which means half as many
 * limbs, and a quarter as many products, for a number.
 *
 * There are two files. This directory's is for mini-ml: an external,
 * which is the processor's instruction in the code mini-ml makes (and
 * the runtime's ml_mul_high in the code of its simple back end).
 * ocaml/'s is for dune's build, and is written in OCaml. *)

(* a and b must not be negative *)
val mul_high : int -> int -> int
