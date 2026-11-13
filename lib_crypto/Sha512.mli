(* Sha512: SHA-256 (Sha256.mli) on 64-bit words, with 80 rounds, blocks
   of 128 bytes and a length on 128 bits. It also has SHA-384, which is
   the same with other starting words, cut to 48 bytes. SHA-384 is what
   a certificate signed with ECDSA over P-384 is hashed with (Google's
   roots are signed so).

   The rounds are SHA-256's with other rotations (28, 34, 39 for S0; 14,
   18, 41 for S1; 1, 8, >>7 and 19, 61, >>6 for the schedule) and 80
   constants, which are the first 64 bits of the fractional parts of
   the cube roots of the first 80 primes.

   Worked examples (FIPS 180's, checked by the tests): SHA-512 of "abc"
   starts with ddaf35a1 93617aba, and SHA-384 of "abc" with cb00753f
   45a35e8b.

   It computes in Int64, which js_of_ocaml emulates, so it is correct
   in a browser too, only slower.

   Where it stands: it is Rsa's and X509's hash for the signatures that
   ask for SHA-384 or SHA-512, and Hmac.sha384 is built on it. Tls12
   makes its secret on a NIST curve with it.

   design:
   A hash cut short is not a weaker copy of the long one. SHA-384's
   48 bytes leave 16 bytes of the state unsaid, so its result cannot
   be extended as a Merkle-Damgard hash's can (Hmac.mli). It also
   starts from other words, so that it is not SHA-512's first 48
   bytes, which would let one be passed off as part of the other. The
   64-bit words are for speed: on a 64-bit processor, a block twice as
   long costs 80 rounds instead of 64, so SHA-512 hashes more bytes a
   second than SHA-256.

   References: FIPS 180-4 (NIST, 2015), sections 4.2.3, 5.3.4, 5.3.5
   and 6.4. *)

val digest : string -> string (* SHA-512, 64 bytes *)
val digest384 : string -> string (* SHA-384, 48 bytes *)
