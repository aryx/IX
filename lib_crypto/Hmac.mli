(* Hmac: a hash with a key -- a tag that only who knows the key can make
   (Mihir Bellare, Ran Canetti and Hugo Krawczyk, 1996; RFC 2104).

       HMAC(K, m) = H((K xor opad) || H((K xor ipad) || m))

   K padded with zeros to the hash's block (64 bytes for SHA-256, 128
   for SHA-384), or first hashed if longer; ipad the byte 0x36 repeated,
   opad 0x5c. Two hashes, one inside the other, so that knowing H(K ||
   m) -- which a Merkle-Damgard hash lets you extend to H(K || m || more)
   without K, the *length extension* -- tells nothing.

   Worked example (RFC 4231's test case 2, checked by the tests): the key
   "Jefe", "what do ya want for nothing?", HMAC-SHA-256 5bdcc146 bf60754e
   6a042426 089575c7 5a003f08 9d273983 9dec58b9 64ec3843.

   The extension, drawn: a Merkle-Damgard hash's result is its whole
   state after the last block (Sha1.mli), so who has the result can go
   on hashing from it:

       H(K || m)          = state after  [K m pad]
       H(K || m pad more) = state after  [K m pad][more pad']
                            computed from the first result and "more"
                            alone: a valid tag for a message never seen

   In HMAC what an outsider sees is the outer hash's result, and to
   extend that is to extend (K xor opad) || inner, which is not a tag
   of anything.

   Where it stands: Tls13's Finished is an HMAC of the transcript, and
   Hkdf, the key schedule, is HMAC twice over. [hmac] takes the hash
   and its block size, so the two instances are two lines.

   cs-history:
   It was made for the internet's own protocols. In the mid-1990s IPsec
   and SSL each needed to authenticate a packet with a shared key and a
   hash, and each had its recipe: the key before the message, after it,
   on both sides ("keyed MD5") -- some of them broken by the length
   extension above. Bellare, Canetti and Krawczyk, at IBM and UCSD,
   gave one construction with a proof: as strong as the hash's
   compression function is a good pseudo-random function, whatever
   else is found about the hash. That proof is why HMAC-MD5 and
   HMAC-SHA-1 outlived MD5 and SHA-1 themselves, and the IETF took it
   at once (RFC 2104, February 1997). TLS's key schedule (Hkdf,
   Tls13), a cookie signed by a site, an API's request signed by its
   client: all of them this.

   References: RFC 2104 (1997); RFC 4231 (2005), the SHA-2 test vectors;
   Bellare, Canetti, Krawczyk, "Keying Hash Functions for Message
   Authentication" (CRYPTO 1996). *)

(* [hmac ~hash ~block key message] *)
val hmac : hash:(string -> string) -> block:int -> string -> string -> string

val sha256 : string -> string -> string
val sha384 : string -> string -> string
