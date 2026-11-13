(* Mime: everything that is not a short English letter, put into mail
   without changing mail (Nathaniel Borenstein and Ned Freed, RFC 1341,
   1992; RFCs 2045-2047, 1996).

   A message stays what Mail.mli says it is: headers, an empty line,
   and lines of 7-bit text. MIME adds a few header fields that say how
   to read the body:

     Content-Type: multipart/mixed; boundary="xyz"     what it is: a
                                                       type/subtype, and
                                                       parameters
     Content-Transfer-Encoding: base64                 how its bytes were
                                                       made into lines
     Content-Disposition: attachment; filename="a.png" to show, or to save

   A multipart body is cut by its boundary into parts, and each part is
   a message of its own (headers, empty line, body). A part can be
   multipart again, so a message is a tree whose leaves are the text and
   the attachments:

       --xyz                           <- a part starts
       Content-Type: text/plain
                                       <- (a part with no header is text)
       Here are the photos.
       --xyz
       Content-Type: image/png
       Content-Transfer-Encoding: base64

       iVBORw0KGgoAAAANSUhEUgAA...     <- the bytes, as lines of base64
       --xyz--                         <- the last part has ended

   There are two encodings. *base64* (Base64, in lib_networking/tls/,
   which writes three bytes as four letters) is for what is not text.
   *quoted-printable* is for text that is mostly ASCII: it stays
   readable, and what is not ASCII becomes "=" and two hex digits:

       caf=C3=A9 au lait, and a line too long to be sent as it is, so=
        cut here                 -> "café au lait, and a line too long
                                     to be sent as it is, so cut here"

   (é is two bytes in UTF-8, C3 A9; the "=" at a line's end is a *soft*
   line break, which is removed.) A header has no Content-Type of its
   own, so it holds non-ASCII text in *encoded words* (RFC 2047):
   "=?utf-8?Q?caf=C3=A9?=" is "café", and so is "=?utf-8?B?Y2Fmw6k=?="
   (Q is quoted-printable with "_" for a space, B is base64).

   Text is given back as UTF-8: ISO-8859-1, Windows-1252 and
   ISO-8859-15 are converted, and UTF-8 and US-ASCII are kept as they
   are. (ix: the playground read Windows-1252 as Latin-1, but real mail
   has its curly quotes and euros, in Latin-1's control characters.)

   The tests check worked examples: the quoted-printable above, and the
   two encoded words. [parameters "multipart/mixed; boundary=\"xyz\""]
   is ("multipart/mixed", [("boundary", "xyz")]). The multipart above
   is two leaves: the text, and a picture.png of type image/png, with
   its bytes decoded.

   References: RFC 2045 (the fields and the encodings: 6.7
   quoted-printable, 6.8 base64), RFC 2046 (the media types, 5.1
   multipart), RFC 2047 (encoded words), RFC 2183 (Content-Disposition);
   Nathaniel Borenstein, "The Hidden Value of MIME" (the first
   attachment, in 1992, was a picture of his barbershop quartet). *)

(* "text/plain; charset=utf-8" gives the type, lowercased, and the
 * parameters, with their names lowercased and their values unquoted *)
val parameters : string -> string * (string * string) list

(* the Content-Type of a message (or of a part). It is text/plain if it
 * says none, and message/rfc822 inside a multipart/digest. (ix: every
 * caller gives [~digest], because mini-ml has no optional argument.) *)
val content_type : digest:bool -> Mail.t -> string * (string * string) list

(* the parts of a multipart body, each a message; [] when the body is
 * not multipart *)
val parts : Mail.t -> Mail.t list

val quoted_printable_decode : string -> string

(* lines of at most 76 characters, with soft breaks where needed *)
val quoted_printable_encode : string -> string

(* the body's bytes, with its Content-Transfer-Encoding undone *)
val decoded : Mail.t -> string

(* [to_utf8 charset s]: [to_utf8 "windows-1252" "\x93caf\xe9\x94"] is
 * "“café”". For a charset that is not known, it is [s] as it is. *)
val to_utf8 : string -> string -> string

(* a header's encoded words, decoded to UTF-8 *)
val decode_words : string -> string

(* a header value as one encoded word, if it is not ASCII *)
val encode_words : string -> string

(* a leaf of the tree: its type, its file name if it has one, its
 * bytes decoded (and, for text, converted to UTF-8), and the part
 * itself *)
type leaf = { mime : string; filename : string option; data : string; part : Mail.t }

(* the leaves, depth first. A message/rfc822 part is a leaf (a message
 * forwarded whole, or in a digest), and [data] is its text. *)
val leaves : Mail.t -> leaf list

(* what to read: the text leaves that are not attachments, one after
 * the other, with an enclosed message introduced by its From: and
 * Subject: *)
val text : Mail.t -> string

(* the leaves to save: those with a file name, or that are not text *)
val attachments : Mail.t -> leaf list

(*****************************************************************************)
(* {1 Writing} *)
(*****************************************************************************)

(* The other way, for a message being sent: each part is a Mail.t whose
   headers say how to read it, as the reading side above expects. *)

(* a text part in UTF-8: as it is if it is ASCII (7bit), or else in
 * quoted-printable *)
val text_part : string -> Mail.t

(* [attachment ~filename bytes] is a part in base64, cut in lines of 76.
 * Its type comes from the name's extension (.png, .gif, .jpg, .txt,
 * .mbox), or else it is application/octet-stream. *)
val attachment : filename:string -> string -> Mail.t

(* the type that an extension gives *)
val type_of_filename : string -> string

(* [multipart ~boundary parts] is the headers and the body of a
 * multipart/mixed holding [parts]. The boundary must appear in none of
 * them (a caller makes it unique, as mailers do, from the time and a
 * counter). *)
val multipart : boundary:string -> Mail.t list -> (string * string) list * string
