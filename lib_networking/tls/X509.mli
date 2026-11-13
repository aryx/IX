(* X509: certificates, which say who a key belongs to, as said by
   someone we already trust (ITU-T X.509, 1988; for the web, RFC 5280).

   A certificate binds a name to a public key, and is signed by its
   *issuer*. The issuer's certificate is signed by its own issuer, and
   so on up to a *root* that the system trusts because it shipped with
   it:

       pop.gmail.com  --signed by-->  WE2  --signed by-->  GTS Root R4
       (the server's key)             (an intermediate)    (in /etc/ssl/certs)

   The server sends its certificate and the intermediates. The client
   builds the path up to one of its roots, and checks at each step that
   the issuer's name is the next one's subject, that the signature
   checks with the next one's key, that the next one is allowed to sign
   (it is a CA: basic constraints), and that today is within each one's
   dates. It also checks that the first one names the host we wanted
   (subjectAltName, where "*.wikipedia.org" covers one label). A
   certificate that the server sends but that we do not need (Gmail
   sends GTS Root R4 cross-signed by GlobalSign, for old clients) is
   ignored once a trusted root is reached.

       Certificate ::= SEQUENCE {
         tbsCertificate       -- "to be signed": version, serial,
                              -- issuer, validity, subject, key, extensions
         signatureAlgorithm   -- ecdsa-with-SHA384, sha256WithRSAEncryption...
         signatureValue       -- the issuer's signature over tbsCertificate }

   Not checked: revocation (CRLs, OCSP), name constraints, key usage,
   and policies. These are the parts a browser adds, and what this
   teaching client leaves out on purpose (the tutorial says so).

   Where it stands: Tls13 hands the chain it received to a [verify]
   that it was given (Tls_client's, with the system's roots from Pem
   and the time of day), and asks [verify_scheme] about
   CertificateVerify. Under it are Asn1 for the tree, and Rsa and Ecdsa
   for the signatures. It is the one part of TLS that rests on
   something outside the mathematics: a file of a hundred roots or more
   that came with the system.

   cs-history:
   A certificate was first the key of an entry in a directory: X.509 is
   a part of X.500 (1988), the telephone companies' plan for one
   world-wide directory of people and organizations, which would vouch
   for its entries. The directory never came. Netscape took the
   certificate alone for SSL (1994), and with it the question that the
   directory was to answer: who vouches? The answer went to companies,
   the certificate authorities (VeriSign, out of RSA, 1995), whose roots
   browsers ship. For twenty years a certificate cost money and a day's
   paperwork, and most of the web did without. Let's Encrypt (2015; the
   ACME protocol, RFC 8555) made one free and automatic, for a program
   that proves it controls the name, and encrypted page loads went from
   under half to nearly all.

   modern:
   A browser adds more, since an authority can be wrong or broken into
   (DigiNotar, 2011: false certificates for google.com, used against
   readers in Iran). It adds Certificate Transparency (RFC 6962, 2013),
   which is public logs in which every certificate must appear, so that
   a site can see what was issued in its name; and it has its own lists
   of revoked certificates.

   road-not-taken:
   Trust without authorities. PGP (1991) let each user sign the keys of
   people he had met, a web of trust with no root. SSH (1995) believes
   the key that a host shows the first time, and complains if it ever
   changes. The first asked too much of people; the second fits a
   machine one returns to, not a shop visited once. The web took the
   hierarchy, in which any root is able to vouch for any name, and that
   is its known weakness.

   The tests check worked examples, on real chains captured once with
   openssl, at a fixed date: Gmail's (ECDSA P-256, a P-384 root, and
   the extra cross-signed root), Google's (RSA), Wikipedia's (a wildcard
   name, and a cross-signed "Root YE"), and GitHub's (Sectigo's ECC).
   Each is refused for another host, after its dates, or with a byte
   changed; and the roots' own signatures are checked.

   References: RFC 5280, "Internet X.509 Public Key Infrastructure
   Certificate and CRL Profile" (2008): 4.1 the structure, 4.2.1.9
   basic constraints, 4.2.1.6 subjectAltName, 6 path validation; RFC
   6125 (2011), host names, wildcards. *)

type public_key =
  | Rsa of Bignum.t * Bignum.t (* n, e *)
  | Ec of Ecdsa.curve * string (* the point, SEC 1 *)
  | Other of string (* the OID of an algorithm we do not know *)

type t = {
  der : string;
  tbs : string; (* what the issuer signed *)
  issuer : string; (* the issuer's Name, as DER *)
  subject : string;
  common_name : string; (* the subject's CN, to show *)
  not_before : float;
  not_after : float;
  key : public_key;
  algorithm : string; (* the OID of the signature *)
  signature : string;
  names : string list; (* the dNSNames of subjectAltName *)
  ca : bool; (* basic constraints: it may sign certificates *)
}

val parse : string -> (t, string) result

(* was [cert] signed by [issuer]'s key? *)
val signed_by : issuer:t -> t -> bool

(* does it name this host? It looks at subjectAltName, where a wildcard
 * covers one label, or at the common name when there is no
 * subjectAltName. *)
val names_host : t -> string -> bool

(* The roots trusted. [roots] takes certificates already parsed (a
 * test's). [roots_of_der] takes their bytes, and parses each one when a
 * chain first names it as an issuer, because a system has 140 roots and
 * a chain ends at one. *)
type roots
val roots : t list -> roots
val roots_of_der : string list -> roots

(* [verify ~trust ~now ~host chain] checks the server's chain (its
 * certificate first) up to one of the roots in [trust] *)
val verify : trust:roots -> now:float -> host:string -> t list -> (unit, string) result

(* checks a signature by the certificate's key, in TLS 1.3's
 * SignatureScheme [scheme] (0x0403 ecdsa_secp256r1_sha256, 0x0503
 * ecdsa_secp384r1_sha384, 0x0804 rsa_pss_rsae_sha256, 0x0805, 0x0806,
 * 0x0401 rsa_pkcs1_sha256...) *)
val verify_scheme : t -> scheme:int -> message:string -> signature:string -> bool
