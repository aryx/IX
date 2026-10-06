(* Characters in a string (Plan 9's runes; libc's chartorune,
 * runetochar and utflen): a text is its bytes, UTF-8, and a character
 * one to four of them. What draws, counts columns or matches goes by
 * characters. All of ix's UTF-8 is here: the decoding and the
 * encoding are the standard library's (String.get_utf_8_uchar,
 * Buffer.add_utf_8_uchar, Uchar), under shorter names, with numbers
 * for characters; and what it has not, a string taken by its
 * characters. *)

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
