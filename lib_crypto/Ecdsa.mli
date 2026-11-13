(* Ecdsa: checking a signature made with an elliptic curve (NIST's
   curves P-256 and P-384, FIPS 186-4). The algorithm is DSA's, on a
   curve (Scott Vanstone, 1992). It is what signs Google's certificates
   and their servers' handshakes.

   A curve is y^2 = x^3 - 3x + b modulo a prime p, and its points (with
   a point at infinity, O) form a group: two points are added by the
   chord through them, and a point is doubled by its tangent. G is a
   point of prime order n (n*G = O). A private key is a number d, and
   the public key is Q = d*G. Going back from Q to d is the discrete
   logarithm, which nobody knows how to do on these curves.

   A signature of a hash e is two numbers (r, s); it checks if

       w = 1/s mod n,  u1 = e*w mod n,  u2 = r*w mod n
       (x, y) = u1*G + u2*Q          and x mod n = r

   The points are kept in Jacobian coordinates (X/Z^2, Y/Z^3), so that
   adding needs no division until the end, and the field's numbers are
   in Montgomery's form (Bignum.mli). a*P is computed by double and
   add, a bit of a at a time.

   The curves' constants are FIPS 186-4's. The tests check that each G
   is on its curve and that n*G = O, which a wrong digit would break.

   Worked examples (checked by the tests): signatures made by Python's
   cryptography package, over P-256 with SHA-256 and over P-384 with
   SHA-384, are accepted, and refused when the message or the signature
   is changed; a real certificate's signature is checked too (X509's
   tests).

   Why the check works. Signing picks a fresh random k and gives

       r = x of k*G mod n,        s = (e + r*d) / k  mod n

   so k = (e + r*d)/s = u1 + u2*d, and u1*G + u2*Q = (u1 + u2*d)*G =
   k*G, whose x is r. The verifier got to the signer's point without
   knowing k or d.

   Where it stands: X509 calls [verify] for two things in a handshake's
   life: for each certificate of a chain signed by an EC key
   (signed_by), and for the server's CertificateVerify (verify_scheme,
   for Tls13). Nothing here signs, because a web client has no key of
   its own. And so nothing here is secret, which is why arithmetic
   whose time depends on its numbers (Bignum) is no leak in this
   module. The exception is [multiply], for the key exchange with a
   TLS 1.2 server on P-256 or P-384 (Tls12), whose secret serves one
   handshake.

   cs-history:
   Elliptic curves for cryptography were proposed by Neal Koblitz and
   Victor Miller, independently, in 1985. They give the security of
   RSA's 3072 bits with 256 bits, since the tricks that make factoring
   and ordinary discrete logarithms easier than trying everything have
   no known equivalent on a curve. P-256 and P-384 are among the curves
   NIST published in 1999, each with its constant b made from a seed
   that nobody explained. That doubt is what, after 2013, sent new
   designs to Bernstein's Curve25519 (X25519.mli). For certificates the
   NIST curves stayed, because an authority's root lives for twenty
   years.

   others:
   The k must be new and secret for every signature: two signatures
   with the same k give d by two lines of algebra (subtract the two s).
   That is how the key that signed the PlayStation 3's software was
   found in 2010: its k was a constant. Signers now derive k from the
   message and the key by a hash (RFC 6979, 2013), with no dice rolled,
   and Ed25519, the signature that goes with Curve25519, was designed
   that way from the start.

   References: Neal Koblitz, "Elliptic Curve Cryptosystems"
   (Mathematics of Computation, 1987), and Victor Miller, "Use of
   Elliptic Curves in Cryptography" (CRYPTO 1985), the idea;
   FIPS 186-4, "Digital Signature Standard" (NIST, 2013),
   6.4 and appendix D (the curves); SEC 1 v2 (Certicom, 2009), 4.1.4
   (verifying); Henri Cohen et al., "Efficient Elliptic Curve
   Exponentiation Using Mixed Coordinates" (1998), Jacobian
   coordinates; the formulas of the Explicit-Formulas Database
   (dbl-2001-b, add-2007-bl). *)

type curve

val p256 : curve
val p384 : curve

(* the curve's size in bytes: 32, 48 *)
val size : curve -> int

(* [verify curve ~public ~hash ~r ~s]: [public] is the point as SEC 1
 * writes it uncompressed (04, x, y), and [hash] is the message's digest *)
val verify : curve -> public:string -> hash:string -> r:Bignum.t -> s:Bignum.t -> bool

(* The curves' points for a key exchange (ECDH, Tls12's). [generator
 * curve] is G, as SEC 1 writes a point uncompressed (04, x, y).
 * [multiply curve k point] is k (big-endian bytes) times the point, or
 * None if the point is not on the curve or the product is O. A secret
 * is used here, and the time taken depends on it, so k must be a key
 * made for one handshake and thrown away, never a key that is kept *)
val generator : curve -> string
val multiply : curve -> string -> string -> string option

(* for the tests: is G on the curve, and n*G the point at infinity? *)
val generator_ok : curve -> bool
