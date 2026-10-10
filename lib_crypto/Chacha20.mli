(* Chacha20: a stream cipher -- a key and a nonce make an endless
   stream of bytes that look random, xored with the message (Daniel
   J. Bernstein, 2008; RFC 8439). One of TLS 1.3's two ways to encrypt
   its records (Chacha20_poly1305.mli), the one fast without special
   hardware.

   A block of the stream is a 4x4 matrix of 32-bit words,

       "expa"  "nd 3"  "2-by"  "te k"       the constants
       key     key     key     key          256 bits of key
       key     key     key     key
       counter nonce   nonce   nonce        the block's number, and 96 bits of nonce

   mixed by 20 rounds of *quarter rounds* -- additions, xors and
   rotations only (ARX: no table, so no cache to leak through) --

       a += b; d ^= a; d <<<= 16;   c += d; b ^= c; b <<<= 12;
       a += b; d ^= a; d <<<= 8;    c += d; b ^= c; b <<<= 7;

   on the columns, then on the diagonals, ten times; and the matrix it
   started from added back in (without which the rounds could be run
   backwards to the key). Words little-endian.

   Worked example (RFC 8439 section 2.4.2, checked by the tests): the
   key 00..1f, the nonce 000000000000004a00000000, the counter 1, and
   "Ladies and Gentlemen of the class of '99: If I could offer you only
   one tip for the future, sunscreen would be it." encrypt to
   6e2e359a 2568f980 41ba0728 dd0d6981 ...

   Native ints, 63 bits, words masked to 32 (a browser's are 32 bits:
   TLS is native only anyway, Tls13.mli). (ix: wrong as it stands on
   mini-ml's arm, whose ints have 31 bits: plan_browser.md, "ints of
   31 bits".)

   Where it stands: Chacha20_poly1305 is the only caller, for the
   stream and for Poly1305's key (block 0). The counter is what makes
   it a stream one can enter anywhere: block n needs nothing of the
   blocks before it, where a cipher that chains (CBC) must have them.

   design:
   A stream cipher is the one-time pad made practical: a pad as long
   as the message, xored with it, cannot be broken if it is random and
   used once, and cannot be carried around either; so the pad is
   computed from a short key. All the cipher's strength is then in two
   things: that the stream cannot be told from random, and that no
   (key, nonce) pair is ever used for two messages, since the xor of
   the two ciphertexts would be the xor of the two texts. The nonce is
   the caller's promise; Tls13 keeps it by counting its records.

   cs-history:
   ChaCha is Bernstein's Salsa20 (2005) with the quarter round changed
   so that each word of input changes more words of output per round;
   Salsa20 was one of the stream ciphers the European eSTREAM project
   kept (2008) when it looked for successors to RC4, whose stream had
   by then been shown to be far from random. Bernstein's own ChaCha
   has a counter and a nonce of 64 bits each; the IETF's, here, 32
   and 96, a nonce a protocol can fill with a record's number. How
   the two ended up in TLS is told in Chacha20_poly1305.mli.

   References: RFC 8439, "ChaCha20 and Poly1305 for IETF Protocols"
   (2018), section 2.1-2.4; D. J. Bernstein, "ChaCha, a variant of
   Salsa20" (2008). *)

(* the 64 bytes of block [counter] *)
val block : key:string -> nonce:string -> int -> string

(* [encrypt ~key ~nonce ~counter data]: xored with the stream from
 * block [counter] on; decrypting is the same *)
val encrypt : key:string -> nonce:string -> counter:int -> string -> string
