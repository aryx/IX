(* Bignum: natural numbers of any size -- what RSA (numbers of 2048
   bits) and the elliptic curves (256, 384) are computed with, OCaml
   having none without a library (Zarith, over GMP).

   A number is an array of *limbs* of 26 bits, the least significant
   first: 26 so that the product of two limbs (52 bits) plus what is
   carried stays inside OCaml's 63-bit native int. Schoolbook
   addition, subtraction and multiplication (Knuth, TAOCP vol. 2, 4.3.1);
   division a bit at a time, for the few places that need it.

   What is done most -- a*b mod m, thousands of times in a signature's
   check -- is Montgomery's (1985) instead, which never divides: a
   number a is kept as aR mod m (R = 2^(26*limbs)), and

       mont_mul(aR, bR) = aR * bR / R  mod m  = (ab)R mod m

   where dividing by R is shifting, once a multiple of m has been added
   to make the low limbs zero -- one limb at a time, the multiple chosen
   by -1/m mod 2^26 (computed once). m must be odd (a prime, or an RSA
   modulus).

       a --of_nat--> aR mod m --mont_mul, mont_add, ...--> --to_nat--> result

   Worked examples (checked by the tests): 2^255 - 19 from its bytes and
   back; 3^200 mod 2^127 - 1 by pow_mod and by repeated mul and rem; the
   inverse of 7 mod the P-256 prime times 7 is 1; and Python's integers,
   for products and remainders of random numbers of 2048 bits.

   Montgomery's product on numbers one can follow, in decimal: m = 97,
   R = 100 (a power of the base above m), and -1/m mod R = 67 (97 * 67
   = 6499, which ends in 99). To multiply 7 by 15 modulo 97:

       into the form   7 * 100 mod 97 = 21      15 * 100 mod 97 = 45
       the product     21 * 45 = 945
       make it end 00  45 * 67 = 3015, ends in 15: add 15 * 97 = 1455
                       945 + 1455 = 2400, and 2400 / 100 = 24
       out of the form 24 * 67 = 1608, ends in 08: add 8 * 97 = 776
                       24 + 776 = 800, and 800 / 100 = 8

   and 7 * 15 = 105 = 97 + 8. The only divisions were by 100, which in
   decimal is dropping two digits; the two that entering the form
   costs (mod 97) are done once, however many products follow, which
   is why it pays for a power (thousands of products) and not for one.

   Native ints, 63 bits: not for a browser (TLS runs natively only).
   (ix: nor, as it stands, for mini-ml's arm, whose ints have 31 bits:
   plan_browser.md, "ints of 31 bits".)

   Where it stands: Rsa (s^e mod n), Ecdsa (the curve's field and its
   scalars), X25519 (the field of 2^255 - 19), and Asn1, which reads a
   certificate's INTEGERs into it. The other big numbers of ix are
   dc's (its Num): base 100, a byte for two decimal digits, because dc
   is asked for a number's length in digits; here the base is the
   biggest whose products fit a machine's word.

   terminology:
   A limb is one digit of a big number, a machine word or nearly: the
   word is GMP's, a number having limbs as a body does. Radix 2^26
   rather than 2^64 is the price of a language with no 128-bit
   product and no carry flag; C libraries use the full word and a few
   lines of assembly.

   modern:
   The schoolbook product of two numbers of n limbs is n^2 products
   of limbs. Karatsuba (1960) does it in about n^1.58 by three half
   products instead of four, and libraries switch to it past a few
   tens of limbs; RSA's 2048 bits are 79 of ours, at the edge, and a
   signature is checked with e = 65537, seventeen products: not worth
   it here. What a real library must add and this one does not is
   constant time: no branch and no array index that depends on a
   secret. Checking a signature has no secret; X25519's ladder has.

   References: Donald Knuth, "The Art of Computer Programming", vol. 2,
   section 4.3.1 (1969; 3rd ed. 1997); Peter Montgomery, "Modular
   Multiplication Without Trial Division" (Mathematics of Computation,
   1985); Cetin Koc et al., "Analyzing and Comparing Montgomery
   Multiplication Algorithms" (1996), its CIOS, the one here. *)

type t

val zero : t
val one : t
val of_int : int -> t
val is_zero : t -> bool
val compare : t -> t -> int
val equal : t -> t -> bool

(* big-endian bytes, as the standards write numbers *)
val of_bytes : string -> t

(* [to_bytes ~len n]: [len] bytes, zeros in front *)
val to_bytes : len:int -> t -> string

(* hexadecimal, no prefix; of_hex ignores spaces *)
val of_hex : string -> t
val to_hex : t -> string

val add : t -> t -> t

(* [sub a b], a >= b *)
val sub : t -> t -> t

val mul : t -> t -> t
val shift_left : t -> int -> t
val shift_right : t -> int -> t
val bits : t -> int (* the position of the top bit, plus one; 0 for zero *)
val bit : t -> int -> bool

(* [rem a m]: a mod m, a bit at a time *)
val rem : t -> t -> t

(*****************************************************************************)
(* {1 Modulo an odd m, Montgomery's way} *)
(*****************************************************************************)

type modulus

val modulus : t -> modulus
val modulus_value : modulus -> t

(* a number in Montgomery's form, for [modulus] *)
type mont

val of_nat : modulus -> t -> mont
val to_nat : modulus -> mont -> t
val mont_mul : modulus -> mont -> mont -> mont
val mont_add : modulus -> mont -> mont -> mont
val mont_sub : modulus -> mont -> mont -> mont
val mont_one : modulus -> mont
val mont_is_zero : mont -> bool
val mont_equal : mont -> mont -> bool

(* [pow_mod m base exp] *)
val pow_mod : modulus -> t -> t -> t

(* the inverse modulo a prime p, by Fermat: a^(p-2) *)
val inverse_prime : modulus -> t -> t

(* a*b mod m, and (a+b), (a-b) mod m, for numbers already below m *)
val mul_mod : modulus -> t -> t -> t
val add_mod : modulus -> t -> t -> t
val sub_mod : modulus -> t -> t -> t
