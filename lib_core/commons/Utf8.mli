(* Characters in a string (Plan 9's runes; libc's chartorune,
 * runetochar and utflen): a text is its bytes, UTF-8, and a character
 * one to four of them. What draws, counts columns or matches goes by
 * characters. All of ix's UTF-8 is here: the decoding and the
 * encoding are the standard library's (String.get_utf_8_uchar,
 * Buffer.add_utf_8_uchar, Uchar), under shorter names, with numbers
 * for characters; and what it has not, a string taken by its
 * characters.
 *
 * A character's number is cut in pieces of 6 bits, the first byte
 * saying by its high bits how many bytes there are, the others
 * starting with 10:
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
 * Three properties make it the encoding a system can adopt without
 * being rewritten. An ASCII text is already UTF-8, byte for byte. No
 * byte of a longer character is below 0x80, so a program that looks
 * for a slash, a newline or a 0 in bytes (the kernel with a file's
 * name, C's strings, cat, the shell) finds none that is not one. And
 * a byte says what it is alone, a first byte or a following one
 * (10...): from anywhere in a text the next character's start is at
 * most three bytes away, and a damaged byte costs one character, not
 * the rest of the file. The price is that the n-th character is not
 * at a place known beforehand: [sub] and [length] walk.
 *
 * cs-history:
 * UTF-8 is Ken Thompson's, designed with Rob Pike in September 1992
 * for Plan 9, which was then converted to it in a few days (Pike's
 * account: the design drawn on a placemat in a New Jersey diner).
 * The standard's own encoding then (UTF-1) had bytes of ASCII's
 * range inside a longer character, slashes among them. Plan 9's
 * word for a character's number is a rune, and its libc's functions
 * are the ones named above.
 *
 * others:
 * Windows, Java and JavaScript took 16 bits a character, when
 * Unicode was thought to fit in them; it did not, and they are left
 * with UTF-16, where a character is one or two units of 16 bits and
 * the byte order is to be said. Their strings can still be indexed
 * by unit, which is not by character either.
 *
 * terminology:
 * A character here is a code point, Unicode's number. What a reader
 * calls a character may be several (a letter and a combining accent,
 * an emoji and its modifier), and what a terminal shows takes 0, 1
 * or 2 cells: [width].
 *
 * References: Rob Pike and Ken Thompson, "Hello World", USENIX
 * Winter 1993: Plan 9 made to work in UTF; RFC 3629 (2003), UTF-8
 * as it is today, four bytes at most; utf(6) and rune(2) of Plan 9. *)

(* the character at an offset of a string: its number (Unicode's) and
 * how many bytes it has (chartorune); 0xFFFD (Uchar.rep) and the
 * bytes passed over for bytes that are no character *)
val decode : string -> int -> int * int
(* a character added to a buffer, as its bytes (runetochar) *)
val add : Buffer.t -> int -> unit


(* a string's characters, each its bytes; and the bytes of a last one
 * that is not whole ("" when it is) *)
val chars : string -> string list * string
(* how many characters *)
val length : string -> int
(* [sub s from n]: n characters from the one of number from (fewer at the end) *)
val sub : string -> int -> int -> string
(* a character's number, from its bytes (decode's, at 0) *)
val code : string -> int

(* how many cells of a terminal a character takes: 2 for the wide
 * ones (Chinese, Japanese and Korean, the full-width forms, the
 * emoji), 0 for those that go over the character before (the
 * combining accents, the joiners and the variation selectors), 1 for
 * the others. The blocks that are popular, not all of Unicode's
 * tables (wcwidth's): what a terminal shows may differ for a rare
 * character. *)
val width : int -> int
