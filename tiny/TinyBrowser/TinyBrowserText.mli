(* The text of a page as tiny-machine's font can show it, and the few
 * string functions the reading needs: TinyBrowser's lowest part, under
 * TinyBrowserTokens (a tag's attributes, a page's text) and
 * TinyBrowserPage (classes, styles, numbers).
 *
 * The font has only 128 characters, so UTF-8 and HTML entities become
 * ASCII here: a dash becomes -, a curly quote a straight one, an
 * accented letter loses its accent (Latin-1's and Latin Extended-A's,
 * made from Unicode's decompositions), a few Greek letters their names,
 * and anything else ?.
 *
 *     "Caf&eacute; &ndash; na\xc3\xafve"  ──►  "Cafe - naive"
 *)

(* [find s pat i] is the position of pat in s, searching from i, or -1. *)
val find : string -> string -> int -> int

val is_space : char -> bool

(* Is w one of the space-separated words of a class attribute? *)
val has_class : string -> string -> bool

(* an attribute's number, 0 when it is not one *)
val number : string -> int

(* Converts a text to ASCII: entities and UTF-8 characters become what
 * the font can show. *)
val ascii : string -> string

(* [safe_end s i n]: where the text from i to the end n of a message
 * may be cut, the rest kept for the next message, which may continue
 * it: never in an entity or a UTF-8 character, and only after a space,
 * so that a word is never split in two (i when there is no such place). *)
val safe_end : string -> int -> int -> int
