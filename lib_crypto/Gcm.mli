(* Gcm: AES made an AEAD -- counter mode for the encryption, and a
   polynomial hash in GF(2^128) for the tag (David McGrew and John
   Viega, 2004; NIST SP 800-38D): TLS 1.3's AES_128_GCM.

       H  = AES(K, 0^128)                         the hash's key
       J0 = nonce (12 bytes) || 00000001
       ciphertext = plaintext xor AES(K, J0+1), AES(K, J0+2), ...
       S  = GHASH_H(aad | pad | ciphertext | pad | len aad | len ct, in bits)
       tag = AES(K, J0) xor S

   GHASH is Chacha20_poly1305's Poly1305 in another field: each 16-byte
   block xored into an accumulator, multiplied by H -- in GF(2^128),
   where adding is xor and multiplying is shifting and xoring with the
   polynomial x^128 + x^7 + x^2 + x + 1, the bits in GCM's reflected
   order. Here the plain way, a bit at a time (128 shifts a block):
   slow, and the easiest to read.

   Worked examples (checked by the tests): the GCM paper's test case 3
   (a 128-bit key feffe992..., its 64-byte plaintext d9313225...), and
   Python's cryptography package's output on other lengths.

   Int64 (emulated in a browser; correct there too).

   Counter mode turns the block cipher (Aes: 16 bytes in, 16 out) into
   a stream cipher like Chacha20: the blocks encrypted are not the
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
   A block cipher's modes. ECB is the cipher on each block of the
   message as it is: equal blocks give equal ciphertext, and a
   picture's outline shows through. CBC xors each block with the
   ciphertext of the one before, which hides that, cannot be done in
   parallel, needs the message padded to whole blocks, and has no tag:
   TLS's attacks of 2011 to 2014 were mostly on its padding. CTR is
   the diagram above (Whitfield Diffie and Martin Hellman, 1979). GCM
   is CTR and a tag; an AEAD (Chacha20_poly1305.mli).

   others:
   A nonce used twice with one key is worse here than the stream
   cipher's two texts xored: two tags under one H give an equation
   whose roots include H, and with H tags can be forged (Antoine
   Joux, 2006; from memory). TLS 1.3 counts its records, so it cannot
   repeat one; a protocol that picks 12 random bytes must change keys
   after 2^32 messages (the limit SP 800-38D sets).

   modern:
   The bit-at-a-time product is 128 shifts and xors a block. A
   processor since about 2010 has the product of two 64-bit
   polynomials as one instruction (PCLMULQDQ on x86, PMULL on ARMv8),
   and with AES's own instruction GCM runs at about a byte a cycle:
   why it is the web's most used cipher. Without them, the choice is
   tables indexed by secrets, with the cache's leak (Aes.mli), or this
   slow loop: the gap Chacha20_poly1305 was brought in to fill.

   References: NIST SP 800-38D (2007); David McGrew and John Viega,
   "The Galois/Counter Mode of Operation (GCM)" (2004), its test
   vectors. *)

val seal : key:string -> nonce:string -> aad:string -> string -> string
val open_ : key:string -> nonce:string -> aad:string -> string -> string option
