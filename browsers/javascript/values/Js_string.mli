(* Js_string treats a string as JavaScript counts it here: in its UTF-8
   bytes, as the browser's text is everywhere else (the network's, the
   page's tree, the fonts').

   By the standard, a JavaScript string is a sequence of 16-bit "code
   units". Its length, s[i], charCodeAt, slice, indexOf and a regular
   expression's index all count those: a character among the first
   65,536 is one unit, and one beyond them (an emoji) is two, a
   "surrogate pair". Here they count bytes:

     "a"     1 byte     length 1   charCodeAt(0) 97      (UTF-16: 1, 97)
     "é"     2 bytes    length 2   charCodeAt(0) 195     (UTF-16: 1, 233)
     "😀"    4 bytes    length 4   charCodeAt(0) 240     (UTF-16: 2, 55357)

   This is right for ASCII, and for what most scripts do with a text
   that is not ASCII: pass it along, compare it, search it, or put it
   in the page. A piece cut out at an index found by indexOf is whole,
   since both count in bytes. What goes wrong is a script that counts
   characters (a field's "140 left") or reads charCodeAt beyond ASCII.
   A for-of over a string, Array.from and a regular expression's "."
   still take whole characters ([decode], [code_points]), and
   toUpperCase and toLowerCase change only ASCII letters.

   history:
   mini-chrome's first engine counted bytes too. It then counted
   UTF-16's units (in Js_string, with a table from each unit to its
   byte, and the halves of a pair kept as WTF-8), for Gmail, whose
   startup builds a table of the digit zero of thirty-seven scripts
   with charCodeAt, and which stopped when it was given bytes.
   mini-netscape does not show Gmail, and the French, German, Spanish,
   Polish and Japanese Wikipedias looked the same both ways
   (2026-10-19, docs/plans/plan_browser.md, C). So the bytes came back,
   with 150 lines fewer.

   cs-history:
   Unicode was at first meant to be 16 bits wide for good (1991), and
   the systems designed in those years took a 16-bit character as their
   string's unit: Windows NT (1993), Java (1995), and JavaScript after
   Java (ECMAScript 1, 1997). In 1996 Unicode 2.0 went beyond 16 bits,
   by the surrogates, and these systems have counted in half-characters
   since. UTF-8 (Ken Thompson and Rob Pike, Plan 9, 1992) is the web's
   and Unix's encoding: ASCII is unchanged, there is no byte order, and
   it won. The rest of ix counts a text in Plan 9's runes (lib_core's
   Utf8).

   Reference: ECMA-262 section 6.1.4 (the String type); RFC 3629
   (UTF-8). *)

(* the character at a byte: how many bytes it is, and its code point
 * (a byte that starts no character is one of its own) *)
val decode : string -> int -> int * int

(* true when a string's units are its bytes (a caller's fast path) *)
val ascii : string -> bool

(* s.length, which is how many bytes it has *)
val length : string -> int

(* s.charCodeAt(i), which is the byte at an index, or -1 beyond the
 * ends *)
val unit : string -> int -> int

(* turns an index into a byte's index, and back. Here an index is
 * itself (but an index beyond the end is the end's). *)
val byte_of : string -> int -> int
val unit_of : string -> int -> int

(* [sub s a b] gives the bytes from a up to b (not included), with a
 * and b kept within the string *)
val sub : string -> int -> int -> string

(* String.fromCharCode: each number is a character, given as its UTF-8
 * bytes *)
val of_units : int list -> string

(* returns a code point's UTF-8 bytes *)
val of_code_point : int -> string

(* [seam a b] is a ^ b *)
val seam : string -> string -> string

(* returns a literal's text, as it is *)
val joined : string -> string

(* returns its code points, decoded from UTF-8, which is what for-of
 * and Array.from go through *)
val code_points : string -> int list

(* toUpperCase and toLowerCase, of ASCII's letters only *)
val recased : upper:bool -> string -> string
