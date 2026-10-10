(* Sha256: SHA-1's construction (Sha1.mli) with a bigger state and
   more rounds -- the hash of TLS 1.3's transcript and key schedule
   (NSA, 2001; FIPS 180-2, 2002).

   The message padded as SHA-1's (a 1 bit, zeros, the length in bits
   on 64), in blocks of 64 bytes, each mixed into eight 32-bit words:

       h = 6a09e667 bb67ae85 3c6ef372 a54ff53a 510e527f 9b05688c 1f83d9ab 5be0cd19
           (the fractional parts of the square roots of the first 8 primes)

   the block's 16 words stretched to 64 (w[i] = s1(w[i-2]) + w[i-7] +
   s0(w[i-15]) + w[i-16], s0 and s1 rotations and a shift xored), then
   64 rounds, each

       t1 = h + S1(e) + ch(e, f, g) + K[i] + w[i]
       t2 = S0(a) + maj(a, b, c)
       h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2

   with K the fractional parts of the cube roots of the first 64
   primes -- constants chosen in the open, "nothing up my sleeve".

   Worked examples (checked by the tests; the first is FIPS 180's):
   "abc" is
   ba7816bf 8f01cfea 414140de 5dae2223 b00361a3 96177a9c b410ff61
   f20015ad; "" is e3b0c442 98fc1c14 9afbf4c8 996fb924 27ae41e4 649b934c
   a495991b 7852b855.

   In Int32: the same bits natively and in a browser. (Sha1 here is
   in ints, masked to 32 bits.)

   Where it stands: Tls13 hashes its transcript with it (every
   handshake message so far, hashed again at each step), Hmac and so
   Hkdf are built on it, and Rsa and X509 hash with it what a
   signature covers. [hex] is here because a digest is what one most
   often wants to print.

   design:
   Nothing up my sleeve. A cipher or a hash needs constants, and a
   designer who may pick them freely could pick ones that hide a
   weakness only he knows. So they are taken from somewhere with no
   freedom in it: square and cube roots of the first primes here, the
   digits of pi elsewhere, the ASCII of "expand 32-byte k" in ChaCha
   (Chacha20.mli). DES's S-boxes, which came with no explanation in
   1977, were suspected for fifteen years (they turned out to have
   been chosen against an attack not yet public), and the NIST
   curves' seeds still are (Ecdsa.mli).

   evolution:
   SHA-0 (1993) was withdrawn within two years for a flaw not said;
   SHA-1 (1995) is the fix, one rotation added. SHA-2 (2001) is this
   module and Sha512's: the same chain, more state, a better schedule,
   and unbroken. Because all three are one family, NIST ran an open
   competition for a hash of another kind in case SHA-2 fell as SHA-1
   was falling: Keccak won (2012; SHA-3, 2015), a *sponge*, with no
   length extension (Hmac.mli). SHA-2 did not fall, and the web
   still signs with it.

   References: FIPS 180-4, "Secure Hash Standard" (NIST, 2015),
   sections 4.2.2, 5.3.3 and 6.2; RFC 6234 (2011), with C code. *)

(* the 32 bytes of the hash *)
val digest : string -> string

(* bytes as hexadecimal digits (any bytes: a digest, a key) *)
val hex : string -> string
