(* Gcm: AES made into an AEAD, with counter mode for the encryption and
   a polynomial hash in GF(2^128) for the tag (David McGrew and John
   Viega, 2004; NIST SP 800-38D). It is TLS 1.3's AES_128_GCM.

       H  = AES(K, 0^128)                         the hash's key
       J0 = nonce (12 bytes) || 00000001
       ciphertext = plaintext xor AES(K, J0+1), AES(K, J0+2), ...
       S  = GHASH_H(aad | pad | ciphertext | pad | len aad | len ct, in bits)
       tag = AES(K, J0) xor S

   GHASH is Chacha20_poly1305's Poly1305 in another field. Each 16-byte
   block is xored into an accumulator, which is then multiplied by H in
   GF(2^128). There, adding is a xor, and multiplying is shifting and
   xoring with the polynomial x^128 + x^7 + x^2 + x + 1, with the bits
   in GCM's reflected order. Here [ghash] does it four bits at a time,
   with Shoup's table, and [ghash_simple] does it the plain way, a bit
   at a time (128 shifts a block), which is slow but the easiest to read.

   Worked examples (checked by the tests): the GCM paper's test case 3
   (a 128-bit key feffe992..., and its 64-byte plaintext d9313225...),
   and the output of Python's cryptography package for other lengths.

   [ghash] uses ints of 16 bits, and [ghash_simple] and the block helpers
   use Int64, which a browser emulates, so both are correct there too.

   Counter mode turns the block cipher (Aes: 16 bytes in, 16 out) into
   a stream cipher like Chacha20. The blocks it encrypts are not the
   message's but a counter's values, and their output is xored with
   the message, whatever its length.

       J0+1          J0+2          J0+3
        | AES(K)      | AES(K)      | AES(K)       never the plaintext
        v             v             v              through the cipher
       pad 1         pad 2         pad 3
        xor p1        xor p2        xor p3 (cut to the last one's length)
        = c1          = c2          = c3

   So decrypting is the same xor, no padding is needed, the blocks can
   be computed in any order or all at once, and AES's decryption is
   never used (Aes has none).

   terminology:
   These are a block cipher's modes. ECB runs the cipher on each block
   of the message as it is, so equal blocks give equal ciphertext, and
   a picture's outline shows through. CBC xors each block with the
   ciphertext of the one before. That hides the outline, but CBC cannot
   be done in parallel, needs the message padded to whole blocks, and
   has no tag; TLS's attacks of 2011 to 2014 were mostly on its
   padding. CTR is the diagram above (Whitfield Diffie and Martin
   Hellman, 1979). GCM is CTR plus a tag, which makes it an AEAD
   (Chacha20_poly1305.mli).

   others:
   A nonce used twice with one key is worse here than the stream
   cipher's two texts xored. Two tags under one H give an equation
   whose roots include H, and with H one can forge tags (Antoine Joux,
   2006). TLS 1.3 counts its records, so it cannot repeat a nonce. A
   protocol that picks 12 random bytes must change keys after 2^32
   messages (the limit SP 800-38D sets).

   modern:
   The bit-at-a-time product takes 128 shifts and xors a block. Since
   about 2010, a processor has the product of two 64-bit polynomials as
   one instruction (PCLMULQDQ on x86, PMULL on ARMv8), and with AES's
   own instruction GCM runs at about a byte a cycle. That is why it is
   the web's most used cipher. Without those instructions, the choice
   is between tables indexed by secrets, with the cache's leak
   (Aes.mli), and a slow loop like [ghash_simple]'s. That is the gap
   Chacha20_poly1305 was brought in to fill.

   References: NIST SP 800-38D (2007); David McGrew and John Viega,
   "The Galois/Counter Mode of Operation (GCM)" (2004), its test
   vectors. *)

val seal : key:string -> nonce:string -> aad:string -> string -> string
val open_ : key:string -> nonce:string -> aad:string -> string -> string option

(* GHASH of [data] (whole blocks of 16 bytes) under the 16 bytes [h].
   [ghash] goes four bits at a time, with a table of H's sixteen
   multiples (Shoup's, 1996), in ints of 16 bits; it is what [seal] and
   [open_] use. [ghash_simple] is the definition, a bit at a time, and
   the tests check [ghash] against it. Neither takes the same time
   whatever the key: the simple one branches on each bit, and the table
   is read at places that the secret chooses (the cache's leak that the
   header tells of). *)
val ghash : string -> string -> string
val ghash_simple : string -> string -> string
