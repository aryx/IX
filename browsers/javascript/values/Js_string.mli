(* Js_string: a string as JavaScript counts it here -- in its UTF-8
   bytes, the browser's text everywhere else (the network's, the page's
   tree, the fonts').

   A string of JavaScript is, by the standard, a sequence of 16-bit
   "code units": its length, s[i], charCodeAt, slice, indexOf and a
   regular expression's index all count those, a character of the
   first 65,536 one unit, one beyond (an emoji) two, a "surrogate
   pair". Here they count bytes:

     "a"     1 byte     length 1   charCodeAt(0) 97      (UTF-16: 1, 97)
     "é"     2 bytes    length 2   charCodeAt(0) 195     (UTF-16: 1, 233)
     "😀"    4 bytes    length 4   charCodeAt(0) 240     (UTF-16: 2, 55357)

   Right for ASCII, and for what most scripts do with a text that is
   not: pass it along, compare it, search it, put it in the page -- a
   piece cut out at an index found by indexOf is whole, both counted in
   bytes. What goes wrong is a script that counts characters (a
   field's 140 left) or reads charCodeAt beyond ASCII. A for-of over a
   string, Array.from and a regular expression's "." still take whole
   characters ([decode], [code_points]); toUpperCase and toLowerCase
   change ASCII letters alone.

   history:
   mini-chrome's first engine counted bytes too; it then counted
   UTF-16's units (Js_string, a table from each unit to its byte, the
   halves of a pair kept as WTF-8), for Gmail, whose startup builds a
   table of the digit zero of thirty-seven scripts with charCodeAt and
   stopped when it was given bytes. mini-netscape does not show Gmail,
   and the French, German, Spanish, Polish and Japanese Wikipedias
   looked the same both ways (2026-10-19, docs/plans/plan_browser.md,
   C): the bytes came back, 150 lines fewer.

   cs-history:
   Unicode was first to be 16 bits wide for good (1991), and the systems
   designed in those years took a 16-bit character as their string's
   unit: Windows NT (1993), Java (1995), and JavaScript after Java
   (ECMAScript 1, 1997). In 1996 Unicode 2.0 went beyond, by the
   surrogates, and they have counted in half-characters since. UTF-8
   (Ken Thompson and Rob Pike, Plan 9, 1992) is the web's and Unix's:
   ASCII unchanged, no byte order, and it won -- the rest of ix counts
   a text in Plan 9's runes (lib_core's Utf8).

   Reference: ECMA-262 section 6.1.4 (the String type); RFC 3629
   (UTF-8). *)

(* the character at a byte: how many bytes it is, and its code point
 * (a byte that starts none: itself, alone) *)
val decode : string -> int -> int * int

(* true: a string's units are its bytes (a caller's fast path) *)
val ascii : string -> bool

(* how many bytes: s.length *)
val length : string -> int

(* the byte at an index, or -1 beyond its ends: s.charCodeAt(i) *)
val unit : string -> int -> int

(* an index as a byte's, and back: itself (an index beyond the end is
 * the end's) *)
val byte_of : string -> int -> int
val unit_of : string -> int -> int

(* [sub s a b]: the bytes from a up to b (not included), each kept
 * within the string *)
val sub : string -> int -> int -> string

(* String.fromCharCode: each number a character, its UTF-8 bytes *)
val of_units : int list -> string

(* a code point's UTF-8 bytes *)
val of_code_point : int -> string

(* [seam a b]: a ^ b *)
val seam : string -> string -> string

(* a literal's text, as it is *)
val joined : string -> string

(* its code points, UTF-8 decoded: what for-of and Array.from go
 * through *)
val code_points : string -> int list

(* toUpperCase and toLowerCase: of ASCII's letters *)
val recased : upper:bool -> string -> string
