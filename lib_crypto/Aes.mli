(* Aes: the block cipher of the world -- 16 bytes in, 16 bytes out,
   under a key of 16, 24 or 32 (Joan Daemen and Vincent Rijmen's
   Rijndael, chosen by NIST in 2001, FIPS 197). TLS 1.3 uses it in GCM
   mode (Gcm.mli), for the servers that do not offer ChaCha20.

   The block is a 4x4 matrix of bytes, and each of the 10 rounds (for a
   128-bit key; 12, 14 for longer ones) is four steps:

       SubBytes     each byte through the S-box: its inverse in the field
                    GF(2^8), then an affine map (the only non-linear step)
       ShiftRows    row i rotated left by i
       MixColumns   each column multiplied by a fixed matrix in GF(2^8)
                    (not in the last round)
       AddRoundKey  xored with this round's 16 bytes of the expanded key

   The S-box is computed here from that definition, not typed in as its
   usual table of 256 numbers: the inverses from the field's powers of
   its generator 3, then the affine map x ^ rotl1 ^ rotl2 ^ rotl3 ^
   rotl4 ^ 0x63. The tests check it against the table's first entries.

   Worked example (FIPS 197 appendix C.1, checked by the tests): the key
   00010203...0f and the block 00112233...ff give 69c4e0d8 6a7b0430
   d8cdb780 70b4c55a.

   The 16 bytes fill the matrix a column at a time, so ShiftRows, which
   moves bytes along the rows, is what carries a byte from one column
   to the others, and MixColumns then spreads it over that column:
   after two rounds every byte of the block depends on every byte of
   the input.

       in:  b0 b1 b2 ... b15         b0  b4  b8  b12      row 0: stays
                                     b1  b5  b9  b13      row 1: <<< 1
                                     b2  b6  b10 b14      row 2: <<< 2
                                     b3  b7  b11 b15      row 3: <<< 3

   A byte is a polynomial of degree under 8 with coefficients 0 or 1
   (0x53 is x^6 + x^4 + x + 1); adding two is xor, multiplying is the
   product modulo x^8 + x^4 + x^3 + x + 1 (0x11b). FIPS 197's own
   example: the S-box of 0x53 is 0xed, and of 0x00, which has no
   inverse and is taken as 0, the affine map's constant, 0x63.

   Encryption only: GCM's counter mode never decrypts a block.

   Where it stands: Gcm is the only caller, and Tls13 the only caller
   of Gcm (the suite TLS_AES_128_GCM_SHA256). A block cipher alone
   encrypts 16 bytes; what to do with a message of another length is
   the *mode*'s business, Gcm's here.

   cs-history:
   AES replaced DES (IBM and the NSA, a standard in 1977), whose key
   of 56 bits a machine built for the purpose could try out in days by
   1998. NIST did not design the successor: it asked for candidates in
   the open (1997), got fifteen, and after three years of everyone
   attacking everyone's kept five (MARS, RC6, Rijndael, Serpent,
   Twofish) and chose Rijndael, the work of two Belgians, in October
   2000. A standard picked in public, from abroad, with its reasons
   written down: the opposite of how DES had come, and why it was
   trusted.

   modern:
   Nobody runs these four steps as written. Software merges SubBytes,
   ShiftRows and MixColumns into four tables of 256 words, a round
   being sixteen lookups and xors; and since 2010 or so a processor
   has a round as one instruction (Intel's AES-NI, ARMv8's AESE). The
   instruction is also the safe way: a table read at an index made of
   the key takes a time that depends on what the cache holds, and that
   time can be measured from another program (Bernstein, 2005). Ours
   reads [sbox] so, and is not for a machine shared with an attacker.

   References: FIPS 197, "Advanced Encryption Standard" (NIST, 2001);
   Joan Daemen and Vincent Rijmen, "The Design of Rijndael" (2002);
   D. J. Bernstein, "Cache-timing attacks on AES" (2005). *)

type key

(* the round keys of a 16-, 24- or 32-byte key *)
val expand : string -> key

val encrypt_block : key -> string -> string

(* the S-box, computed *)
val sbox : int array
