(* Rsa: checking a signature made with RSA (Ron Rivest, Adi Shamir and
   Leonard Adleman, 1977) -- what signs most of the web's certificates.

   A public key is a modulus n (the product of two secret primes, 2048
   bits or more) and an exponent e (almost always 65537); signing is
   raising to the secret power d, checking is raising to e:

       m = s^e mod n       and m must be the message's hash, *encoded*

   The encoding is what keeps it safe, two of them in use (RFC 8017):

   - PKCS#1 v1.5 (1993): 00 01 FF FF ... FF 00, then the hash wrapped in
     its DigestInfo (the DER that names the hash algorithm), as long as
     n -- certificates are signed so;
   - PSS (Mihir Bellare and Phillip Rogaway, 1996): the hash with a
     random salt, masked by MGF1 (a hash stretched), ending in 0xbc --
     provably safe, and what TLS 1.3 wants a server's handshake signed
     with (RSA_PSS_RSAE_SHA256).

   The arithmetic on numbers one can check by hand (not a test: the
   code refuses a modulus under 1024 bits). Two primes 61 and 53: n =
   3233. e = 17, and d = 2753, chosen so that e*d = 1 modulo (61-1) *
   (53-1) = 3120, which only who knows the two primes can compute:

       sign 65:    65^2753 mod 3233 = 588
       check:      588^17  mod 3233 = 65

   because raising to e*d is raising to 1 modulo n (Euler). Finding d
   from n and e is as hard as splitting n into its primes; for 3233 a
   moment, for 2048 bits nobody knows how.

   Without the encoding that small example is forgeable three ways:
   1 signs 1; the product of two signatures signs the product of the
   two messages; and anyone can pick s first and call s^e a message.
   The fixed bytes around the hash leave no such freedom. And
   [verify_pkcs1] builds the whole encoded block it expects and
   compares, rather than parsing the one it got: parsers that skipped
   over what they did not check have let forged signatures through
   (Daniel Bleichenbacher's attack of 2006 on keys with e = 3; from
   memory).

   Where it stands: X509, for a certificate signed by an RSA key
   (PKCS#1 v1.5) and for a server's CertificateVerify (PSS), over
   Bignum's pow_mod. Checking only: with e = 65537 a check is
   seventeen modular products, where signing with d is thousands,
   which is the server's cost and not ours.

   cs-history:
   Whitfield Diffie and Martin Hellman had described what a public-key
   system would do (1976) without having one that signs; Rivest,
   Shamir and Adleman at MIT found this one the next year, and Martin
   Gardner's column in Scientific American (August 1977) made it known
   before the paper was out. Clifford Cocks had found the same at
   Britain's GCHQ in 1973, which was secret until 1997. It was
   patented in the United States until 2000, which is one reason the
   first free tools used other algorithms. Fifty years on it still
   signs most certificates; new keys are more and more often elliptic
   (Ecdsa.mli), for their size: 32 bytes where RSA needs 256.

   Worked examples (checked by the tests): signatures of both kinds made
   by Python's cryptography package with a 2048-bit key accepted, and
   refused for a changed message; a real root certificate's (X509's).

   References: RFC 8017, "PKCS #1: RSA Cryptography Specifications
   Version 2.2" (2016), sections 8.1.2, 8.2.2, 9.1.2 (EMSA-PSS-VERIFY),
   9.2 and appendix B.2.1 (MGF1). *)

type hash = Sha256 | Sha384 | Sha512

val digest : hash -> string -> string

val verify_pkcs1 : n:Bignum.t -> e:Bignum.t -> hash -> message:string -> signature:string -> bool

(* PSS, the salt as long as the hash, MGF1 with the same hash *)
val verify_pss : n:Bignum.t -> e:Bignum.t -> hash -> message:string -> signature:string -> bool
