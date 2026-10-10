(* dc's integers, of any size: a sign and digits in base 100, as dc.c
 * keeps them (two decimal digits a byte), since several of dc's
 * answers are about the bytes: a number's length, a string printed as
 * a number, a number run as a macro.
 *
 *     1234567      the digits, lowest first:        67  45  23  1
 *     -99          its complement to 100, then -1:   1  -1
 *
 *     the school's addition, a byte a column, the carry to the left:
 *            45 67
 *          + 78 90         67 + 90 = 157: write 57, carry 1
 *          ---------       45 + 78 + 1 = 124: write 24, carry 1
 *          1 24 57
 *
 * design:
 * Base 100 and not base 256. A byte could hold more, but dc's
 * numbers are decimal fractions with a scale (1.05 is 105 with a
 * scale of 2), read and printed in decimal far more often than they
 * are multiplied: in base 100 printing is a table lookup a byte, and
 * moving the point by two digits is moving by a byte. A binary base
 * would make every p a long division.
 *
 * modern:
 * A library for large integers today (GMP) takes the machine's word
 * as its digit, base 2^64, with the multiplication in assembly, and
 * changes method as the numbers grow: the school's, then Karatsuba's
 * (1962: three multiplications of halves where four seem needed),
 * then Toom's, then Fourier transforms. [mul] and [divmod] here are
 * the school's, quadratic: 2 1000 ^ p is instant, a million digits
 * of pi is not for dc. lib_crypto's Bignum is the same choice in
 * binary, for RSA.
 *
 * References: D. E. Knuth, "The Art of Computer Programming", volume
 * 2, section 4.3.1, "The Classical Algorithms"; principia's dc.c
 * (add, mult, div_). *)

type t

val zero : t
val of_int : int -> t
(* the nearest int when it does not fit *)
val to_int : t -> int
val is_zero : t -> bool
val is_neg : t -> bool
val neg : t -> t
val compare : t -> t -> int

val add : t -> t -> t
val sub : t -> t -> t
val mul : t -> t -> t
(* the quotient cut toward 0 and the remainder, of the dividend's sign
 * (dc.c's div_); Division_by_zero *)
val divmod : t -> t -> t * t
(* 10^n *)
val pow10 : int -> t
(* x^n, n >= 0 *)
val pow : t -> int -> t
(* the integer part of a square root; of a number not negative *)
val sqrt : t -> t

(* its digits in base 100, the lowest first; none for 0 (the sign aside) *)
val digits : t -> int array

(* dc.c's bytes: the digits, the lowest first; a negative number as its
 * complement to a power of 100 with a last byte of -1 (-1 is \377, -99
 * is \001\377). And back, any bytes read so: a string's too. *)
val encode : t -> string
val decode : string -> t
