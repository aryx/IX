(* Bignum: natural numbers of any size. RSA (with numbers of 2048 bits)
   and the elliptic curves (256 and 384 bits) are computed with them,
   since OCaml has none without a library (Zarith, over GMP).

   A number is an array of *limbs* of 26 bits, the least significant
   first. The width is 26 so that the product of two limbs (52 bits)
   plus what is carried stays inside OCaml's 63-bit native int. Where
   an int has 31 or 32 bits (mini-ml for arm, a web page), limbs have
   28 bits. A product then has 56 bits and does not fit, so it is kept
   in two limbs, and Wide.mul_high (the processor's long
   multiplication) gives the high one; before, limbs there had 14 bits,
   so that each product fit in an int. The width comes from
   [Sys.int_size], and nothing else needs to know it. Addition,
   subtraction and multiplication are the schoolbook ones (Knuth, TAOCP
   vol. 2, 4.3.1). Division goes a bit at a time, for the few places
   that need it.

   What is done most is a*b mod m, thousands of times when a signature
   is checked. That goes by Montgomery's method instead (1985), which
   never divides. A number a is kept as aR mod m (R = 2^(26*limbs), or
   2^(28*limbs)), and

       mont_mul(aR, bR) = aR * bR / R  mod m  = (ab)R mod m

   where dividing by R is a shift, once a multiple of m has been added
   to make the low limbs zero. That is done one limb at a time, and the
   multiple is chosen with -1/m modulo a limb, which is computed once.
   m must be odd (a prime, or an RSA modulus).

       a --of_nat--> aR mod m --mont_mul, mont_add, ...--> --to_nat--> result

   Worked examples (checked by the tests): 2^255 - 19 is read from its
   bytes and written back; 3^200 mod 2^127 - 1 is computed by pow_mod
   and by repeated mul and rem; the inverse of 7 modulo the P-256 prime,
   times 7, is 1; and products and remainders of random numbers of 2048
   bits match Python's integers.

   Here is Montgomery's product on numbers one can follow, in decimal:
   m = 97, R = 100 (a power of the base above m), and -1/m mod R = 67
   (97 * 67 = 6499, which ends in 99). To multiply 7 by 15 modulo 97:

       into the form   7 * 100 mod 97 = 21      15 * 100 mod 97 = 45
       the product     21 * 45 = 945
       make it end 00  45 * 67 = 3015, ends in 15: add 15 * 97 = 1455
                       945 + 1455 = 2400, and 2400 / 100 = 24
       out of the form 24 * 67 = 1608, ends in 08: add 8 * 97 = 776
                       24 + 776 = 800, and 800 / 100 = 8

   and indeed 7 * 15 = 105 = 97 + 8. The only divisions were by 100,
   which in decimal means dropping two digits. The two divisions (mod
   97) that entering the form costs are done once, however many
   products follow. That is why the method pays for a power (thousands
   of products) and not for a single product.

   Where it stands: it is used by Rsa (s^e mod n), Ecdsa (the curve's
   field and its scalars), X25519 (the field of 2^255 - 19), and Asn1,
   which reads a certificate's INTEGERs into it. The other big numbers
   of ix are dc's (its Num). They are in base 100, a byte for two
   decimal digits, because dc is asked for a number's length in digits.
   Here the base is the biggest one whose products fit a machine's
   word.

   terminology:
   A limb is one digit of a big number, a machine word or nearly one.
   The word comes from GMP: a number has limbs as a body does. A radix
   of 2^26 rather than 2^64 is the price of a language with no 128-bit
   product and no carry flag; C libraries use the full word and a few
   lines of assembly.

   modern:
   The schoolbook product of two numbers of n limbs takes n^2 products
   of limbs. Karatsuba (1960) does it in about n^1.58, with three half
   products instead of four, and libraries switch to it past a few
   tens of limbs. RSA's 2048 bits are 79 of our limbs, which is at the
   edge, and a signature is checked with e = 65537, which takes
   seventeen products, so it is not worth it here. What a real library
   must add, and this one does not, is constant time: no branch and no
   array index that depends on a secret. Checking a signature involves
   no secret, but X25519's ladder does.

   References: Donald Knuth, "The Art of Computer Programming", vol. 2,
   section 4.3.1 (1969; 3rd ed. 1997); Peter Montgomery, "Modular
   Multiplication Without Trial Division" (Mathematics of Computation,
   1985); Cetin Koc et al., "Analyzing and Comparing Montgomery
   Multiplication Algorithms" (1996), whose CIOS is the method here. *)

type t

val zero : t
val one : t
val of_int : int -> t
val is_zero : t -> bool
val compare : t -> t -> int
val equal : t -> t -> bool

(* big-endian bytes, as the standards write numbers *)
val of_bytes : string -> t

(* [to_bytes ~len n] is n in [len] bytes, with zeros in front *)
val to_bytes : len:int -> t -> string

(* hexadecimal, with no prefix; of_hex ignores spaces *)
val of_hex : string -> t
val to_hex : t -> string

val add : t -> t -> t

(* [sub a b] needs a >= b *)
val sub : t -> t -> t

val mul : t -> t -> t
val shift_left : t -> int -> t
val shift_right : t -> int -> t
val bits : t -> int (* the position of the top bit, plus one; 0 for zero *)
val bit : t -> int -> bool

(* [rem a m] is a mod m, computed a bit at a time *)
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
(* the same, by the textbook's two rows for each limb (CIOS); [mont_mul]
   does the two rows in one loop, and the tests check it against this *)
val mont_mul_simple : modulus -> mont -> mont -> mont
(* the one loop for when a product does not fit an int (on 31 bits it
   is [mont_mul]), with each product's high limb from Wide.mul_high; it
   is right on 63 bits too, where the tests check it against
   [mont_mul_simple] *)
val mont_mul_wide : modulus -> mont -> mont -> mont
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
