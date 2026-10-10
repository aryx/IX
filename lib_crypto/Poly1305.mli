(* Poly1305: a one-time authenticator -- a tag of 16 bytes that only
   who knows the key could have made for this message, and a key that
   must never be used twice (D. J. Bernstein, 2005; RFC 8439).

   The message, cut in blocks of 16 bytes, each read as a number
   (little-endian) with a 1 appended above its top byte, is the
   polynomial evaluated at a secret point r, modulo the prime 2^130 - 5
   (hence the name):

       acc = 0
       for each block:  acc = (acc + block) * r   mod 2^130 - 5
       tag = acc + s    mod 2^128

   r and s are the key's two halves, r "clamped" (some bits cleared) so
   that the products stay small. Here as poly1305-donna does it: 130
   bits as five limbs of 26, their products 52 bits, the reduction by
   2^130 = 5 (mod p) a multiplication by 5.

   Worked example (RFC 8439 section 2.5.2, checked by the tests): the key
   85d6be78 57556d33 7f4452fe 42d506a8 0103808a fb0db2fd 4abff6af 4149f51b
   and "Cryptographic Forum Research Group" give a8061dc1 305136c6
   c22b8baf 0c0127a9.

   Native ints, 63 bits (the products need 55). (ix: wrong as it
   stands on mini-ml's arm, whose ints have 31 bits: plan_browser.md,
   "ints of 31 bits".)

   Why a polynomial, and why once. Two messages of the same length
   have the same tag only if r is a root of their difference, a
   polynomial of degree the number of blocks: of 2^106 or so possible
   r, a handful. Someone who does not know r cannot do better than
   guess, whatever computer they have: no assumption about a cipher is
   in it. But the tag is the polynomial's value plus s, in the clear:
   two tags under one key, subtracted, lose s and leave an equation in
   r to solve. Hence a key per message, here ChaCha20's block 0 for
   each nonce (Chacha20_poly1305.mli).

   Where it stands: Chacha20_poly1305 is the only caller. Gcm's GHASH
   is the same construction in a field of 2^128 elements, where
   adding is xor: chosen for hardware, as this prime was for a
   processor's multiplier.

   cs-history:
   The idea is Mark Wegman and Larry Carter's (1979, 1981): pick the
   hash function at random from a family, in secret, and the chance
   of fooling it is a matter of counting, not of how hard a problem
   is. Bernstein's contribution (2005) was a family fast in software:
   a prime just above 2^128, so that a block of 16 bytes fits and the
   reduction is a multiplication by 5, and limbs sized for the
   floating-point multiplier of the day. His paper's name, Poly1305-
   AES, is for the one-time s, made there by encrypting a nonce with
   AES; with ChaCha20 the cipher that is there anyway makes it.

   References: Mark Wegman and Larry Carter, "New Hash Functions and
   Their Use in Authentication and Set Equality" (Journal of Computer
   and System Sciences, 1981);
   RFC 8439 (2018), section 2.5; D. J. Bernstein, "The
   Poly1305-AES message-authentication code" (FSE 2005); Andrew Moon,
   poly1305-donna (2014). *)

(* [mac ~key message]: the 16-byte tag; the key is 32 bytes *)
val mac : key:string -> string -> string
