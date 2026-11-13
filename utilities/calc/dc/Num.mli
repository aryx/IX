(* dc's integers, of any size. They are a sign and digits in base 100,
 * as dc.c keeps them (two decimal digits in a byte), because several
 * of dc's answers are about the bytes: a number's length, a string
 * printed as a number, a number run as a macro.
 *
 *     1234567      the digits, lowest first:        67  45  23  1
 *     -99          its complement to 100, then -1:   1  -1
 *
 *     the school's addition, a byte for each column, the carry going
 *     to the left:
 *            45 67
 *          + 78 90         67 + 90 = 157: write 57, carry 1
 *          ---------       45 + 78 + 1 = 124: write 24, carry 1
 *          1 24 57
 *
 * design:
 * The base is 100 and not 256. A byte could hold more, but dc's
 * numbers are decimal fractions with a scale (1.05 is 105 with a
 * scale of 2), and they are read and printed in decimal far more often
 * than they are multiplied. In base 100, printing is a table lookup
 * for each byte, and moving the point by two digits is moving it by a
 * byte. A binary base would make every p a long division.
 *
 * modern:
 * A library for large integers today (GMP) takes the machine's word
 * as its digit, base 2^64, with the multiplication in assembly, and
 * changes method as the numbers grow: first the school's, then
 * Karatsuba's (1962: three multiplications of halves where four seem
 * needed), then Toom's, then Fourier transforms. [mul] and [divmod]
 * here are the school's, which are quadratic: 2 1000 ^ p is instant,
 * but a million digits of pi is not a job for dc. lib_crypto's Bignum
 * makes the same choice in binary, for RSA.
 *
 * References: D. E. Knuth, "The Art of Computer Programming", volume
 * 2, section 4.3.1, "The Classical Algorithms"; principia's dc.c
 * (add, mult, div_). *)

type t

val zero : t
val of_int : int -> t
(* the nearest int when the number does not fit in one *)
val to_int : t -> int
val is_zero : t -> bool
val is_neg : t -> bool
val neg : t -> t
val compare : t -> t -> int

val add : t -> t -> t
val sub : t -> t -> t
val mul : t -> t -> t
(* the quotient, cut toward 0, and the remainder, which has the
 * dividend's sign (dc.c's div_); raises Division_by_zero *)
val divmod : t -> t -> t * t
(* 10^n *)
val pow10 : int -> t
(* x^n, n >= 0 *)
val pow : t -> int -> t
(* the integer part of a square root, of a number that is not negative *)
val sqrt : t -> t

(* its digits in base 100, the lowest first, without the sign; 0 has none *)
val digits : t -> int array

(* dc.c's bytes: the digits, the lowest first. A negative number is
 * written as its complement to a power of 100, with a last byte of -1
 * (-1 is \377, -99 is \001\377). [decode] goes back, and reads any
 * bytes that way, a string's too. *)
val encode : t -> string
val decode : string -> t
