(* Asn1: reading DER, the bytes that certificates are written in (ITU-T
   X.690, which was X.209 in 1988; ASN.1, the notation, is X.680).

   Every value is a TLV: a tag byte, a length, and the value's bytes:

       30 82 01 0a  ...        SEQUENCE (30), 266 bytes long (82: the
                               length in the next 2 bytes, 01 0a)
          02 01 05             INTEGER, 1 byte: 5
          06 03 55 1d 11       OBJECT IDENTIFIER 2.5.29.17 (subjectAltName)
          a3 ...               [3], context-specific, constructed:
                               what the schema says tag 3 means here

   The bytes of a constructed value are more TLVs (a SEQUENCE's
   fields); the bytes of a primitive value are the thing itself. DER is
   the one Distinguished way, among those of BER, to write each value
   (the shortest length, and no indefinite ones), so that a signature
   over the bytes is a signature over the value.

   The tests check worked examples. 30 06 02 01 05 01 01 ff is a
   SEQUENCE of the INTEGER 5 and the BOOLEAN true. 06 08 2a 86 48 86 f7
   0d 01 01 is the OID 1.2.840.113549.1.1 (in base 128, with the first
   two numbers packed as 40*1+2). And a certificate's whole tree is
   checked by X509's tests.

   Where it stands: X509 reads the tree that this module makes, and Rsa
   compares against one small DER value that it builds (the
   DigestInfo). [raw] is kept beside [value] because a signature covers
   the bytes as they were sent: parse them, then hash the same bytes,
   never a value written out again. A kind and a length before each
   value is the answer wherever a reader must skip what it does not
   know: a PNG's chunks, a TLS handshake's extensions (Tls13), a DNS
   record (Dns). 9P (P9_wire) makes the opposite choice, with fixed
   fields and no tags, for a protocol whose two ends are written
   together.

   cs-history:
   A survivor. ASN.1 (Abstract Syntax Notation One, 1984) was made for
   OSI, the telephone companies' network standards. It is a notation to
   declare a message's fields, with rules (BER) to write any such
   message as bytes, which is what Protocol Buffers or JSON schemas are
   now. OSI lost to the Internet, whose protocols are mostly text. But
   what OSI had defined for directories and their certificates (X.500,
   X.509) was taken as it was, and so every TLS connection still begins
   by reading a binary format of the 1980s. Its lengths within lengths
   are easy to get wrong in C, and its parsers have been a steady
   source of security holes. That is one reason to read it with a
   function that cannot run past its bytes.

   References: ITU-T X.690 (2021), sections 8 and 10; Burton Kaliski,
   "A Layman's Guide to a Subset of ASN.1, BER, and DER" (RSA
   Laboratories, 1993). *)

type t = {
  tag : int; (* the identifier byte: 0x30 SEQUENCE, 0x02 INTEGER, 0xa3 [3]... *)
  value : string; (* the content bytes *)
  raw : string; (* the whole TLV, as it was: what a signature covers *)
}

(* the value at the start of the bytes, and where it ended *)
val parse : string -> int -> (t * int, string) result

(* the elements of a constructed value; [] for a primitive one *)
val children : t -> t list

(* the value of an OBJECT IDENTIFIER, dotted: "1.2.840.113549.1.1.11" *)
val oid : t -> string

(* an INTEGER as a natural (a negative one is an error in certificates) *)
val integer : t -> Bignum.t

(* the bytes of an OCTET STRING (the value itself) *)
val value_of : t -> string

(* the bytes of a BIT STRING, without the count of unused bits *)
val bit_string : t -> string

(* UTCTime (YYMMDDHHMMSSZ) or GeneralizedTime (YYYYMMDDHHMMSSZ), as
 * seconds since the epoch *)
val time : t -> float option

(* the text of a string type (UTF8String, PrintableString, IA5String...) *)
val text : t -> string
