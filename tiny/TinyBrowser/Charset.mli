(* A page's characters, made into what tiny-machine's font can show.
 * Tokens uses this module to read the text of a page.
 *
 * The font has only 128 characters, so UTF-8 and HTML entities are
 * turned into ASCII here:
 * - a dash becomes -, and a curly quote becomes a straight one;
 * - an accented letter loses its accent (for the letters of Latin-1 and
 *   Latin Extended-A, using Unicode's decompositions);
 * - a few Greek letters become their names;
 * - anything else becomes ?.
 *
 *     "Caf&eacute; &ndash; na\xc3\xafve"  ──►  "Cafe - naive"
 *)

val ascii : string -> string

(* [safe_end s i n] is where a message (from i to n) may be cut, the
 * rest being kept for the next one. The cut is just after a space, and
 * never inside an entity or a UTF-8 character. It is i when there is no
 * such place. *)
val safe_end : string -> int -> int -> int
