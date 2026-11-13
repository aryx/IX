(* X25519: Diffie-Hellman on Curve25519. Two strangers agree on a
   secret over a line everyone listens to (D. J. Bernstein, 2006; RFC
   7748). It is TLS 1.3's key exchange, with a new pair of keys for
   each connection.

       client: secret a, sends A = a*G         server: secret b, sends B = b*G
       client computes a*B      =      b*A     server computes
                        = ab*G, the shared secret: nobody else has a or b

   G is the point with x = 9 on the curve y^2 = x^3 + 486662 x^2 + x
   over the integers modulo the prime 2^255 - 19, and a*G is computed
   on x alone, by the *Montgomery ladder*. Two points are kept a step
   apart, and for each bit of a, one is doubled and the other added:
   the same work whatever the bit. That is a first defence against
   timing, but here it runs on Bignum's arithmetic, which is itself not
   constant time. The scalar is "clamped": its three low bits are
   cleared (which makes it a multiple of the cofactor 8) and its bit
   254 is set.

   Worked examples (RFC 7748, checked by the tests): section 5.2's two
   vectors, and 6.1's Alice and Bob, whose shared secret is 4a5d9d5b
   a4ce2de1 728e3bf4 80350f25 e07e21c9 47d19e33 76f09b3c 1e161742.

   Where it stands: it is Tls13's key_share, and Tls12's ECDHE. The
   client's secret is 32 of the bytes Tls_client reads from the kernel,
   and the shared secret goes into the key schedule (Hkdf, or Tls12's
   PRF) and nowhere else. What the
   exchange does not say is who is at the other end: someone in the
   middle can run it once with each side. Telling that is the job of
   the certificate (X509) and of CertificateVerify, a signature over
   the transcript, which has both public keys in it.

   cs-history:
   The exchange is Whitfield Diffie and Martin Hellman's (1976, with
   Ralph Merkle's ideas), in the integers modulo a prime: A = g^a,
   B = g^b, and the secret is g^ab. It was the first answer to a
   question that had seemed to have none, how two parties with no
   secret in common get one, and the start of public-key cryptography.
   On a curve the same exchange has keys ten times shorter (Ecdsa.mli).

   cs-history:
   Bernstein published the curve in 2006 as a speed record that was
   also hard to get wrong: every string of 32 bytes is a valid key,
   there is no point to check, and there is no special case in the
   arithmetic. It stayed a curiosity while the web's servers used
   NIST's curves (Ecdsa's), until 2013, when the documents Edward
   Snowden made public put in doubt the constants of those curves,
   chosen from seeds nobody had explained. Within three years it was
   everywhere: it became OpenSSH's default (2014), it went into Chrome
   and onto Google's servers, the IETF took it (RFC 7748, 2016), and it
   is the one group every TLS 1.3 client offers first.

   design:
   Forward secrecy. The pair of keys is made for one connection and
   forgotten. Before TLS 1.3 a client could instead encrypt the
   secret to the server's long-lived RSA key; whoever recorded the
   traffic and got that key years later read everything. Here there
   is no key to get: the server's long-lived key only signs.

   terminology:
   Curve25519 is the curve, named for its prime. X25519 is the
   function on x coordinates, this module. Ed25519 is a signature on
   the same curve in another form. The RFC fixed the names after years
   of "Curve25519" meaning all three.

   References: RFC 7748, "Elliptic Curves for Security" (2016), section
   5; D. J. Bernstein, "Curve25519: new Diffie-Hellman speed records"
   (PKC 2006); Whitfield Diffie and Martin Hellman, "New Directions in
   Cryptography" (IEEE Transactions on Information Theory, 1976). *)

(* [scalar_mult k u] is k (32 bytes, clamped here) times the point with
 * x = u (32 bytes); both are little-endian, as in the RFC *)
val scalar_mult : string -> string -> string

(* the public key of a secret: k times the base point, 9 *)
val public_key : string -> string
