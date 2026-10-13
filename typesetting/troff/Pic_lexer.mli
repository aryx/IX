(* Pic_lexer: a picture's text as the words of pic's grammar
 * (Pic_parser), its macros done: they are text put for text.
 *
 *   define pair { box wid $1; box wid $2 }
 *   pair(0.2, 0.4)          is read as   box wid 0.2; box wid 0.4
 *
 * A macro's body is between two braces or two of any character
 * (define m | ... |); its arguments are $1 to $9, a name alone being a
 * call with none. Also done here: a comment (# to the line's end), a
 * request of troff's in the picture (a line that starts with a dot:
 * passed over), a file read in the middle (copy "file"), an inch said
 * (1.5i is 1.5), and the end of a statement before a closing bracket,
 * so that the grammar has one way to end one.
 *
 * By hand and not by lex: what a word is depends on the macros
 * defined so far, and a macro's text goes back in front of what is
 * left to read. *)

(* [tokens load text]: the picture's words; [load] reads a file that a
 * copy names (none: the copy is nothing) *)
val tokens : (string -> string option) -> string -> Pic_parser.token list
