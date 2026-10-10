(* A string as the person sees it: characters, and the cells they sit
 * in -- which are two different things from the bytes it is made of.
 *
 * A character is not a byte. The playground hands a field whatever
 * the keyboard layout produced (Playground.keyboard's [typed]), and
 * an accented letter is two bytes of UTF-8:
 *
 *   "caf\xc3\xa9"   4 characters, 5 bytes
 *                        ^^^^^^^^ one character, in two bytes: the
 *                                 second has 10 as its top bits, which
 *                                 is what marks a continuation
 *
 * so backspace, which deletes one *character*, must step back over
 * the whole sequence, or leave half a letter behind.
 *
 * A cell is the second idea: a field here lays its text out one
 * character to a fixed width, like a terminal, rather than at the
 * widths the stroke font really draws. That is what lets a click say
 * exactly where the caret goes, and a caret say exactly where it is,
 * with no font to ask (Widget.text_width is an average, not a
 * measurement).
 *
 * Worked example, stepping back from the end of "caf\xc3\xa9" (byte
 * 5): byte 4 is \xa9 = 1010 1001, a continuation, so one more; byte
 * 3 is \xc3 = 1100 0011, a first byte: [prev_char s 5] is 3, and
 * backspace removes bytes 3 and 4 together. No table and no
 * decoding: the top two bits of a byte say whether a character
 * starts there.
 *
 * Where it stands: Text_edit is the same care over a piece table,
 * for texts of several lines; Utf8 is the whole encoding (a
 * character's number from its bytes and back), which a font needs
 * and a caret does not.
 *
 * cs-history:
 * That a caret can find its way with two bits is by design, and the
 * design is Plan 9's. Ken Thompson and Rob Pike made UTF-8 in
 * September 1992, for Plan 9, on a placemat in a New Jersey diner
 * by Pike's account, and the system ran on it within the week. The
 * encodings before it (the first UTF, and the double-byte ones of
 * Japan) could hold a byte that looked like an ASCII letter or a
 * slash inside a character, and could not be entered in the middle:
 * one had to read from the start to know where a character began.
 * UTF-8's three rules -- ASCII is itself, a first byte says how many
 * follow, a continuation byte is 10xxxxxx and nothing else is -- are
 * what [prev_char] and [next_char] read.
 *
 * References: Rob Pike and Ken Thompson, "Hello World or ...",
 * USENIX Winter 1993 (UTF-8 in Plan 9); RFC 3629 (2003). *)

(* [prev_char s i], [next_char s i]: the byte index a character before
 * or after [i], never inside one, never outside the string *)
val prev_char : string -> int -> int
val next_char : string -> int -> int

(* [chars s]: the characters of [s], each one still a string (a cell
 * holds a character, not a byte). ["caf\xc3\xa9"] gives four. *)
val chars : string -> string list

(* [column s i]: how many characters come before the byte index [i] --
 * which cell the caret is in *)
val column : string -> int -> int

(* [byte_of_column s col]: the other way round, for a click *)
val byte_of_column : string -> int -> int

(* [edit ~typed ~pressed text caret]: the text and the caret after one
 * frame of typing -- the characters the platform says were typed
 * inserted at the caret, and the keys that produce no character at
 * all (Backspace, Delete, the arrows, Home, End) doing what they do.
 *
 * It is here rather than in a widget because every architecture needs
 * it and none of them should differ in it: what a field does with a
 * key press is not an architectural question (notes_gui.md section
 * 4). [pressed] answers "did this key go down at this frame", which
 * *is* one -- each architecture knows where it keeps the frame
 * before. *)
val edit : typed:string -> pressed:(string -> bool) -> string -> int -> string * int
