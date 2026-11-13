(* Entities: the characters a page names instead of typing them.

   HTML reserves "<" and "&", and a 1991 keyboard (and many a 1995
   one) had no "é". So a page can name a character, by a word or by
   its number in Unicode (or in Latin-1, for the first 256, which are
   the same):

     &lt;      <          reserved: would start a tag
     &amp;     &          reserved: would start an entity
     &eacute;  é          named: HTML 2.0's Latin-1 set (RFC 1866, 1995)
     &#233;    é          by number, in decimal
     &#xE9;    é          and in hexadecimal (HTML 4)

   A reference ends at its ";". [decode] replaces every one it knows in
   a text. An unknown name ("&foo;") and an "&" that starts nothing
   ("AT&T", "fish & chips") are left as they are. That is what
   browsers do, and it is why pages that forgot to write "&amp;" still
   work.

   Here is a worked example (also in the tests):

     Caf&eacute; &amp; cr&#232;me &#147;br&ucirc;l&eacute;e&#148; &foo; AT&T
     Café & crème “brûlée” &foo; AT&T

   The two numbers in the middle are Windows-1252's curly quotes, bytes
   93 and 94, written as if they were Unicode, which they are not
   (U+0093 is a control character). Pages did it all the time (Word's
   quotes, pasted into an HTML editor on Windows), so the WHATWG says
   to read &#128; to &#159; through Windows-1252
   (Charset.windows_1252), and we do. Other numbers that name no
   character (0, a surrogate, or above U+10FFFF) become U+FFFD.

   The names are HTML 4's 252 and XHTML's &apos;. HTML 4 (1997) has
   the Latin-1 ones, 96 of them, of which HTML 2.0 had the 62 accented
   letters and proposed the rest; then the "special" set (the quotes,
   the dashes, the euro); and the "symbols" (Greek, arrows,
   mathematics). HTML5 has 2,231, adding MathML's; they are an
   exercise. A name needs its ";" here. HTML5 accepts the old Latin-1
   ones without it ("&copy 1995"), but not in an attribute value when
   followed by "=" ("?a=1&copy=2" is a URL, not a copyright sign).
   That rule is worth reading in the spec to see what compatibility
   costs.

   terminology:
   Entity, character reference. The words are SGML's. There, an entity
   is a named piece of text that a DTD declares and a document includes
   by "&name;" (HTML 2.0's DTD declares eacute so), and "&#233;" is
   another thing, a numeric character reference, which needs no
   declaration. HTML5, with no DTD, calls both of them character
   references, named and numeric; "entity" stayed in everyone's mouth,
   and in this module's name.

   Reference: RFC 1866 (HTML 2.0), section 9.7.2 (the Latin-1 entity
   set); HTML 4.01, section 24 ("Character entity references in HTML
   4"); WHATWG HTML, 13.2.5 (the tokenizer's character reference
   states) and 13.5 (the named character references). *)

(* the character that a name stands for, in UTF-8: "eacute" -> "é" *)
val lookup : string -> string option

(* how many names [lookup] knows (253: HTML 4's 252, and apos) *)
val count : int

(* the character of a numeric reference, in UTF-8, with the WHATWG's
 * repairs: 128-159 are read through Windows-1252, and 0, a surrogate
 * or a number above U+10FFFF gives U+FFFD *)
val of_code : int -> string

(* the text with every reference replaced by its character (the text is
 * UTF-8, and so is the result) *)
val decode : string -> string
