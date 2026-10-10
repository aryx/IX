(* Js_utf16: a string as JavaScript counts it -- in UTF-16's code
   units -- over the bytes it is kept in here, UTF-8's.

   A string of JavaScript is not a sequence of characters, nor of
   bytes: it is a sequence of 16-bit numbers, its "code units". Its
   length, s[i], charCodeAt, slice, indexOf and a regular expression's
   index all count those. A character of the first 65,536 (the Basic
   Multilingual Plane) is one unit, its code point; one beyond (an
   emoji, a mathematical digit) is two, a "surrogate pair": a high
   half, 0xD800 to 0xDBFF, then a low one, 0xDC00 to 0xDFFF.

     "a"        1 byte here    1 unit    97
     "é"        2 bytes        1 unit    233
     "٠"        2 bytes        1 unit    1632   (U+0660, the Arabic zero)
     "€"        3 bytes        1 unit    8364
     "😀"       4 bytes        2 units   55357, 56832   (U+1F600)

   The browser's text is UTF-8 everywhere else (the network's, the
   page's tree, the fonts'), so a string stays its UTF-8 bytes and
   this module is the translation: a unit's index to a byte's and
   back. Before it the language was given the bytes ("é".length was
   2, charCodeAt gave 195): right for ASCII, which is why it held so
   long, and wrong for everything else -- Gmail builds, when it starts,
   a table of the digit zero of thirty-seven scripts with charCodeAt,
   checks that it is in order, and stopped there, its list of mail
   empty.

   design:
   An ASCII string is its own table: a unit is a byte, and nothing is
   built ([ascii], asked first by every function here; the answer for
   the last strings asked about is kept, by their identity, so a loop
   over one string scans it once). For another, a table from each
   unit to its byte is made once and kept the same way: "for (i = 0;
   i < s.length; i++) s.charCodeAt(i)" stays linear.

   What is not UTF-8 is not refused: a byte that starts no character
   is a unit of its own, of the byte's value -- a string of raw bytes
   (an answer of the network read as text) is still gone through byte
   by byte, as it was.

   Half of a pair alone ("\uD83D", or what slice leaves when it cuts
   an emoji in two) has no UTF-8; it is kept as the three bytes its
   number would have (the encoding called WTF-8), and two halves that
   meet are made the four bytes of their character again ([seam],
   [of_units]) -- else "\uD83D" + "\uDE00" would not equal "😀".

   cs-history:
   Unicode was first to be 16 bits wide for good (1991: 65,536
   characters, "more than enough"), and the systems designed in those
   years took a 16-bit character as their string's unit: Windows NT
   (1993), Java (1995), and JavaScript after Java (ECMAScript 1,
   1997: "a 16-bit unsigned integer value"). In 1996 Unicode 2.0 went
   beyond, by the surrogates, and UTF-16 was that 16-bit code made
   variable; the three have counted in half-characters since. UTF-8
   (Ken Thompson and Rob Pike, Plan 9, 1992) is the web's and Unix's:
   ASCII unchanged, no byte order, and it won.

   modern:
   V8 keeps a string as one byte a character when all are below 256
   (Latin-1) and two otherwise, chosen a string at a time; Servo and
   Rust's own tools introduced WTF-8 for the same reason as here: UTF-8
   inside, JavaScript's or Windows's 16 bits at the door.

   Not done: the order of two strings is their bytes' (UTF-8's, which
   is the code points'; UTF-16's differs for the characters beyond the
   plane against U+E000 to U+FFFF); halves that meet inside a rope are
   not joined until it is cut.

   Reference: ECMA-262 section 6.1.4 (the String type); RFC 3629
   (UTF-8); RFC 2781 (UTF-16); Simon Sapin, "The WTF-8 encoding"
   (simonsapin.github.io/wtf-8). *)
(* ix: the author's mini-chrome's languages/javascript/values/Js_utf16.mli (its 8af888e) (docs/plans/plan_browser.md) *)

(* the character at a byte: how many bytes it is, and its code point
 * (a byte that starts none: itself, alone) *)
val decode : string -> int -> int * int

(* no byte of it is beyond ASCII: its units are its bytes *)
val ascii : string -> bool

(* how many units: s.length *)
val length : string -> int

(* the unit at an index, or -1 beyond its ends: s.charCodeAt(i) *)
val unit : string -> int -> int

(* a unit's index as its byte's (the second half of a pair: the byte
 * after its character), and a byte's as its unit's; an index beyond
 * the end is the end's *)
val byte_of : string -> int -> int
val unit_of : string -> int -> int

(* [sub s a b]: the units from a up to b (not included), 0 <= a <= b <=
 * length s. A pair cut in two leaves its half *)
val sub : string -> int -> int -> string

(* units made a string, the pairs among them made their character:
 * String.fromCharCode *)
val of_units : int list -> string

(* a code point's bytes (a half's: its three) *)
val of_code_point : int -> string

(* [seam a b]: a ^ b, a half ending a and the half starting b made
 * their character *)
val seam : string -> string -> string

(* a text whose halves written side by side are made their characters:
 * a literal's "😀", read escape by escape *)
val joined : string -> string

(* its code points, a pair as one (a half alone as itself): what
 * for-of and Array.from go through *)
val code_points : string -> int list

(* toUpperCase and toLowerCase: ASCII, and the alphabets whose two
 * cases are a fixed step apart (Latin's accented letters, Greek,
 * Cyrillic); another letter is left as it is *)
val recased : upper:bool -> string -> string
