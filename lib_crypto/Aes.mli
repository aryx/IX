(* Aes: the block cipher of the world. It turns 16 bytes into 16 bytes
   under a key of 16, 24 or 32 bytes (Joan Daemen and Vincent Rijmen's
   Rijndael, chosen by NIST in 2000, FIPS 197 in 2001). TLS 1.3 uses it in GCM
   mode (Gcm.mli), for the servers that do not offer ChaCha20.

   The block is a 4x4 matrix of bytes, and each of the 10 rounds (for a
   128-bit key; 12 and 14 for the longer ones) has four steps:

       SubBytes     each byte goes through the S-box: its inverse in the
                    field GF(2^8), then an affine map (the only
                    non-linear step)
       ShiftRows    row i is rotated left by i
       MixColumns   each column is multiplied by a fixed matrix in
                    GF(2^8) (not in the last round)
       AddRoundKey  the block is xored with this round's 16 bytes of the
                    expanded key

   The S-box is computed here from that definition, rather than typed in
   as the usual table of 256 numbers. The inverses come from the powers
   of the field's generator 3, and then the affine map x ^ rotl1 ^ rotl2
   ^ rotl3 ^ rotl4 ^ 0x63 is applied. The tests check the result against
   the table's first entries.

   Worked example (FIPS 197 appendix C.1, checked by the tests): the key
   00010203...0f and the block 00112233...ff give 69c4e0d8 6a7b0430
   d8cdb780 70b4c55a.

   The 16 bytes fill the matrix a column at a time. So ShiftRows, which
   moves bytes along the rows, is what carries a byte from one column
   to the others, and MixColumns then spreads it over that column.
   After two rounds every byte of the block depends on every byte of
   the input.

       in:  b0 b1 b2 ... b15         b0  b4  b8  b12      row 0: stays
                                     b1  b5  b9  b13      row 1: <<< 1
                                     b2  b6  b10 b14      row 2: <<< 2
                                     b3  b7  b11 b15      row 3: <<< 3

   A byte is a polynomial of degree under 8 with coefficients 0 or 1
   (0x53 is x^6 + x^4 + x + 1). Adding two bytes is a xor, and
   multiplying them is taking their product modulo x^8 + x^4 + x^3 + x
   + 1 (0x11b). FIPS 197's own example: the S-box of 0x53 is 0xed. The
   S-box of 0x00 is 0x63, the affine map's constant, because 0x00 has
   no inverse and is taken as 0.

   There is only encryption here, because GCM's counter mode never
   decrypts a block.

   Where it stands: Gcm is the only caller, and Gcm's callers are Tls13
   (the suite TLS_AES_128_GCM_SHA256) and Tls12 (its ECDHE suites with
   AES-128-GCM). A block cipher alone
   encrypts 16 bytes. What to do with a message of another length is
   the business of the *mode*, here Gcm.

   cs-history:
   AES replaced DES, which IBM and the NSA designed and which became a
   standard in 1977. By 1998 a machine built for the purpose could try
   out all of its 56-bit keys in days. NIST did not design the
   successor. It asked for candidates in the open (1997) and got
   fifteen. After three years in which everyone attacked everyone
   else's candidate, it kept five (MARS, RC6, Rijndael, Serpent,
   Twofish) and chose Rijndael, the work of two Belgians, in October
   2000. The standard was picked in public, from abroad, with its
   reasons written down. That is the opposite of how DES had come, and
   it is why AES was trusted.

   modern:
   Nobody runs these four steps as written. Software merges SubBytes,
   ShiftRows and MixColumns into four tables of 256 words, so that a
   round is sixteen lookups and xors. Since 2010 or so, a processor
   also has a round as one instruction (Intel's AES-NI, ARMv8's AESE).
   The instruction is also the safe way. A table read at an index made
   from the key takes a time that depends on what the cache holds, and
   that time can be measured from another program (Bernstein, 2005).
   Ours reads [sbox] that way, so it is not for a machine shared with
   an attacker.

   References: FIPS 197, "Advanced Encryption Standard" (NIST, 2001);
   Joan Daemen and Vincent Rijmen, "The Design of Rijndael" (2002);
   D. J. Bernstein, "Cache-timing attacks on AES" (2005). *)

type key

(* the round keys of a 16-, 24- or 32-byte key *)
val expand : string -> key

val encrypt_block : key -> string -> string

(* The same, by FIPS 197's four steps as the standard names them
   (SubBytes, ShiftRows, MixColumns, AddRoundKey). [encrypt_block] does
   a round in one pass over three tables, and the tests check it
   against this one. *)
val encrypt_block_simple : key -> string -> string

(* the S-box, computed *)
val sbox : int array
