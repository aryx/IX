(* Hkdf: keys from a secret, HMAC-based (Hugo Krawczyk, 2010; RFC
   5869) -- TLS 1.3's key schedule is made of nothing else (Tls13.mli).

   Two steps. Extract: a secret that may be lumpy (a Diffie-Hellman
   result, not uniformly random) made into a uniform key, PRK =
   HMAC(salt, IKM). Expand: as many bytes as wanted from it, blocks
   T(i) = HMAC(PRK, T(i-1) || info || i), info saying what they are
   for, so that the same PRK gives independent keys for independent
   uses:

       IKM --Extract(salt)--> PRK --Expand("c hs traffic")--> a key
                                  --Expand("s hs traffic")--> another

   Worked example (RFC 5869's test case 1, checked by the tests): IKM
   22 bytes 0x0b, salt 000102..0c, info f0f1..f9, 42 bytes: PRK 077709
   36 2c2e32df..., OKM 3cb25f25 faacd57a...

   Where it stands: Tls13 is the only caller, and calls nothing else
   to make a key: its hkdf_expand_label is [expand] with an info that
   holds a label and a transcript's hash, and its key schedule a chain
   of [extract]s (Tls13.mli draws it). The hash is an argument (~hmac:
   Hmac.sha256 there), since HKDF is a way of using any HMAC.

   cs-history:
   Every protocol had its own way from a shared secret to its keys --
   SSL 3's mixed MD5 and SHA-1, TLS 1.2's is a chain of HMACs with a
   label (its PRF), IKE's another -- each analysed apart, none with a
   reason for its shape. Krawczyk, who had co-written HMAC, proposed
   one for all in 2010, with the two steps named and a proof for each:
   extract, then expand. TLS 1.3 (2018) was rebuilt on it -- its whole
   key schedule is HKDF with different labels -- and so were Signal's
   ratchet, QUIC and WireGuard: the internet's key derivation, since.

   terminology:
   A key derivation function for secrets that are already strong, and
   fast on purpose. The slow ones (PBKDF2, scrypt, Argon2) are for a
   password, where each guess must cost the guesser: another problem
   with the same three letters.

   References: RFC 5869 (2010); Hugo Krawczyk, "Cryptographic Extraction
   and Key Derivation: The HKDF Scheme" (CRYPTO 2010). *)

(* [extract ~hmac ~salt ikm] *)
val extract : hmac:(string -> string -> string) -> salt:string -> string -> string

(* [expand ~hmac prk ~info length] *)
val expand : hmac:(string -> string -> string) -> string -> info:string -> int -> string
