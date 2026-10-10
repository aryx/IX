(* Sha512: SHA-256 (Sha256.mli) on 64-bit words, 80 rounds, blocks of
   128 bytes and a length on 128 bits -- and SHA-384, the same with
   other starting words, cut to 48 bytes: what a certificate signed
   with ECDSA over P-384 is hashed with (Google's roots are).

   The rounds are SHA-256's with other rotations (28, 34, 39 for S0; 14,
   18, 41 for S1; 1, 8, >>7 and 19, 61, >>6 for the schedule) and 80
   constants, the first 64 bits of the cube roots' fractional parts of
   the first 80 primes.

   Worked examples (FIPS 180's, checked by the tests): SHA-512 of "abc"
   starts ddaf35a1 93617aba, SHA-384 of "abc" cb00753f 45a35e8b.

   In Int64, which js_of_ocaml emulates: correct in a browser too, slower.

   Where it stands: Rsa's and X509's hash for the signatures that ask
   for SHA-384 or SHA-512, and Hmac.sha384.

   design:
   A hash cut short is not a weaker copy of the long one. SHA-384's
   48 bytes leave 16 bytes of the state unsaid, so its result cannot
   be extended as a Merkle-Damgard hash's can (Hmac.mli); and it
   starts from other words so that it is not SHA-512's first 48
   bytes, which would let one be passed off as part of the other. The
   64-bit words are for speed: on a 64-bit processor a block twice as
   long costs 80 rounds for 64, so more bytes a second than SHA-256.

   References: FIPS 180-4 (NIST, 2015), sections 4.2.3, 5.3.4, 5.3.5
   and 6.4. *)

val digest : string -> string (* SHA-512, 64 bytes *)
val digest384 : string -> string (* SHA-384, 48 bytes *)
