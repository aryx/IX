(* Pem: certificates as text, the base64 of their DER between two lines
   (Privacy-Enhanced Mail, RFC 1421, 1993 -- mail again, Mail.mli; its
   format outlived it, RFC 7468):

       -----BEGIN CERTIFICATE-----
       MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
       ...
       -----END CERTIFICATE-----

   How the system keeps its trusted roots (a bundle of them, one file:
   /etc/ssl/certs/ca-certificates.crt) and how openssl shows a chain.

   Where it stands: Tls_client reads the system's bundle through
   [certificates] and gives each DER to X509.parse; mini-curl's
   --cacert reads a file of one's own the same way. The decoding is
   Base64's, which skips the line breaks.

   cs-history:
   Privacy-Enhanced Mail was the IETF's first design for signed and
   encrypted mail (1987 to 1993). It needed one hierarchy of
   certificate authorities for the whole Internet, which nobody built,
   and PGP (Phil Zimmermann, 1991), which needed none, took its place.
   What stayed is its way of putting binary in a text file: SSLeay
   (Eric Young, 1995), the library that became OpenSSL, used it for
   its keys and certificates, and every tool since has followed.

   References: RFC 7468, "Textual Encodings of PKIX, PKCS, and CMS
   Structures" (2015). *)

(* the DER of each "CERTIFICATE" block, in order *)
val certificates : string -> string list
