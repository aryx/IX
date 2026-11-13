(* Poly1305: a one-time authenticator. It makes a tag of 16 bytes that
   only someone who knows the key could have made for this message,
   with a key that must never be used twice (D. J. Bernstein, 2005;
   RFC 8439).

   The message is cut into blocks of 16 bytes, and each block is read
   as a number (little-endian) with a 1 appended above its top byte.
   The message is then a polynomial, which is evaluated at a secret
   point r, modulo the prime 2^130 - 5 (hence the name):

       acc = 0
       for each block:  acc = (acc + block) * r   mod 2^130 - 5
       tag = acc + s    mod 2^128

   r and s are the key's two halves, and r is "clamped" (some of its
   bits are cleared) so that the products stay small. It is done here
   as poly1305-donna does it: 130 bits are five limbs of 26 bits, their
   products have 52 bits, and since 2^130 = 5 (mod p), the reduction
   is a multiplication by 5.

   Worked example (RFC 8439 section 2.5.2, checked by the tests): the key
   85d6be78 57556d33 7f4452fe 42d506a8 0103808a fb0db2fd 4abff6af 4149f51b
   and "Cryptographic Forum Research Group" give a8061dc1 305136c6
   c22b8baf 0c0127a9.

   It uses native ints of 63 bits (the products need 55). Where an int
   has fewer bits (mini-ml for arm), [mac] is [mac_simple].

   Why a polynomial, and why once. Two messages of the same length
   have the same tag only if r is a root of their difference, a
   polynomial whose degree is the number of blocks. Of the 2^106 or so
   possible r, only a handful are roots. Someone who does not know r
   cannot do better than guess, whatever computer they have, because
   no assumption about a cipher is involved. But the tag, the
   polynomial's value plus s, is in the clear: subtract two tags under
   one key, and s is gone, leaving an equation in r to solve. Hence a
   key per message, here ChaCha20's block 0 for each nonce
   (Chacha20_poly1305.mli).

   Where it stands: Chacha20_poly1305 is the only caller. Gcm's GHASH
   is the same construction in a field of 2^128 elements, where adding
   is xor. That field was chosen for hardware, as this prime was chosen
   for a processor's multiplier.

   cs-history:
   The idea is Mark Wegman and Larry Carter's (1979, 1981): pick the
   hash function at random from a family, in secret, and the chance of
   fooling it is a matter of counting, not of how hard some problem
   is. Bernstein's contribution (2005) was a family that is fast in
   software. It uses a prime just above 2^128, so that a block of 16
   bytes fits and the reduction is a multiplication by 5, and limbs
   sized for the floating-point multiplier of the day. His paper's
   name, Poly1305-AES, comes from the one-time s, which is made there
   by encrypting a nonce with AES; with ChaCha20, the cipher that is
   there anyway makes it.

   References: Mark Wegman and Larry Carter, "New Hash Functions and
   Their Use in Authentication and Set Equality" (Journal of Computer
   and System Sciences, 1981);
   RFC 8439 (2018), section 2.5; D. J. Bernstein, "The
   Poly1305-AES message-authentication code" (FSE 2005); Andrew Moon,
   poly1305-donna (2011). *)

(* [mac ~key message] is the 16-byte tag; the key is 32 bytes *)
val mac : key:string -> string -> string

(* The same in ten limbs of 13 bits, by loops: what [mac] is where an
   int has less than 63 bits (mini-ml for arm), and what the tests hold
   the fast one against. *)
val mac_simple : key:string -> string -> string
