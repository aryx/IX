(* Characters in a string (Plan 9's runes; libc's chartorune,
 * runetochar and utflen). A text is its bytes, in UTF-8, and a
 * character is one to four of those bytes. The code that draws,
 * counts columns or matches goes by characters. All of ix's UTF-8 is
 * here. The decoding and the encoding are the standard library's
 * (String.get_utf_8_uchar, Buffer.add_utf_8_uchar, Uchar), under
 * shorter names, with numbers for characters. The rest is what the
 * library does not have: a string taken character by character.
 *
 * A character's number is cut into pieces of 6 bits. The high bits of
 * the first byte say how many bytes there are, and the other bytes
 * start with 10:
 *
 *     up to 0x7F        0xxxxxxx                     ASCII, as it was
 *     up to 0x7FF       110xxxxx 10xxxxxx
 *     up to 0xFFFF      1110xxxx 10xxxxxx 10xxxxxx
 *     up to 0x10FFFF    11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
 *
 *     e with an acute accent, 0xE9 = 000 1110 1001 in 11 bits:
 *       110 00011  10 101001   =  C3 A9       decode s 0 = (0xE9, 2)
 *
 * design:
 * Three properties make it an encoding that a system can adopt without
 * being rewritten. First, an ASCII text is already UTF-8, byte for
 * byte. Second, no byte of a longer character is below 0x80, so a
 * program that looks for a slash, a newline or a 0 in bytes (the
 * kernel with a file's name, C's strings, cat, the shell) never finds
 * one that is not really that character. Third, a byte alone says
 * whether it is a first byte or a following one (10...). So from
 * anywhere in a text, the start of the next character is at most three
 * bytes away, and a damaged byte costs one character, not the rest of
 * the file. The price is that you cannot know beforehand where the
 * n-th character is, so [sub] and [length] must walk the string.
 *
 * cs-history:
 * UTF-8 is Ken Thompson's. He designed it with Rob Pike in September
 * 1992 for Plan 9, which was then converted to it in a few days (in
 * Pike's account, the design was drawn on a placemat in a New Jersey
 * diner). The standard's own encoding at the time (UTF-1) had bytes
 * of ASCII's range inside a longer character, slashes among them.
 * Plan 9's word for a character's number is a rune, and its libc's
 * functions are the ones named above.
 *
 * others:
 * Windows, Java and JavaScript took 16 bits for each character, when
 * Unicode was thought to fit in 16 bits. It did not, and they are left
 * with UTF-16, where a character is one or two units of 16 bits and
 * the byte order must be stated. Their strings can still be indexed
 * by unit, but that is not indexing by character either.
 *
 * terminology:
 * A character here is a code point, Unicode's number. What a reader
 * calls a character may be several code points (a letter and a
 * combining accent, an emoji and its modifier), and a terminal shows
 * a character in 0, 1 or 2 cells ([width]).
 *
 * References: Rob Pike and Ken Thompson, "Hello World", USENIX
 * Winter 1993, on how Plan 9 was made to work in UTF; RFC 3629 (2003),
 * UTF-8 as it is today, with four bytes at most; utf(6) and rune(2)
 * of Plan 9. *)

(* The character at an offset of a string: its number (Unicode's) and
 * how many bytes it has (chartorune). For bytes that are not a
 * character, it gives 0xFFFD (Uchar.rep) and the number of bytes
 * passed over. *)
val decode : string -> int -> int * int
(* Adds a character to a buffer, as its bytes (runetochar) *)
val add : Buffer.t -> int -> unit


(* The characters of a string, each as its bytes; and the bytes of a
 * last character that is not whole ("" when it is whole) *)
val chars : string -> string list * string
(* The number of characters *)
val length : string -> int
(* [sub s from n] is n characters, starting at the character numbered
 * from (fewer at the end of s) *)
val sub : string -> int -> int -> string
(* A character's number, from its bytes (what decode gives at 0) *)
val code : string -> int

(* How many cells of a terminal a character takes:
 *  - 2 for the wide ones (Chinese, Japanese and Korean, the full-width
 *    forms, the emoji);
 *  - 0 for those that go over the character before them (the
 *    combining accents, the joiners and the variation selectors);
 *  - 1 for the others.
 * It knows only the popular blocks, not all of Unicode's tables, which
 * wcwidth uses, so a terminal may show a rare character differently. *)
val width : int -> int
