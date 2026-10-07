(* dc's integers, of any size: a sign and digits in base 100, as dc.c
 * keeps them (two decimal digits a byte), since several of dc's
 * answers are about the bytes: a number's length, a string printed as
 * a number, a number run as a macro. *)

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
