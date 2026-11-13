(* Hkdf: keys made from a secret, based on HMAC (Hugo Krawczyk, 2010;
   RFC 5869). TLS 1.3's key schedule is made of nothing else
   (Tls13.mli).

   It has two steps. Extract makes a secret that may be lumpy (a
   Diffie-Hellman result, which is not uniformly random) into a uniform
   key, PRK = HMAC(salt, IKM). Expand gets as many bytes as wanted from
   that key, in blocks T(i) = HMAC(PRK, T(i-1) || info || i). The info
   says what the bytes are for, so that the same PRK gives independent
   keys for independent uses:

       IKM --Extract(salt)--> PRK --Expand("c hs traffic")--> a key
                                  --Expand("s hs traffic")--> another

   Worked example (RFC 5869's test case 1, checked by the tests): the
   IKM is 22 bytes of 0x0b, the salt 000102..0c, the info f0f1..f9, and
   42 bytes are asked for. The PRK is 07770936 2c2e32df..., and the OKM
   3cb25f25 faacd57a...

   Where it stands: Tls13 is the only caller, and it calls nothing else
   to make a key. Its hkdf_expand_label is [expand] with an info that
   holds a label and a transcript's hash, and its key schedule is a
   chain of [extract]s (Tls13.mli draws it). The hash is an argument
   (~hmac is Hmac.sha256 there), since HKDF is a way of using any HMAC.

   cs-history:
   Every protocol had its own way from a shared secret to its keys.
   SSL 3's mixed MD5 and SHA-1, TLS 1.2's is a chain of HMACs with a
   label (its PRF), and IKE had another. Each was analysed on its own,
   and none had a reason for its shape. Krawczyk, who had co-written
   HMAC, proposed one way for all in 2010, with the two steps named and
   a proof for each: extract, then expand. TLS 1.3 (2018) was rebuilt
   on it (its whole key schedule is HKDF with different labels), and so
   were Signal's ratchet, QUIC and WireGuard. It has been the
   internet's key derivation since.

   terminology:
   HKDF is a key derivation function for secrets that are already
   strong, and it is fast on purpose. The slow ones (PBKDF2, scrypt,
   Argon2) are for passwords, where each guess must cost the guesser;
   that is another problem with the same three letters.

   References: RFC 5869 (2010); Hugo Krawczyk, "Cryptographic Extraction
   and Key Derivation: The HKDF Scheme" (CRYPTO 2010). *)

(* [extract ~hmac ~salt ikm] *)
val extract : hmac:(string -> string -> string) -> salt:string -> string -> string

(* [expand ~hmac prk ~info length] *)
val expand : hmac:(string -> string -> string) -> string -> info:string -> int -> string
