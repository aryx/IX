(* Pic_lexer turns a picture's text into the words of pic's grammar
 * (Pic_parser), with its macros expanded. A macro is text put in place
 * of text.
 *
 *   define pair { box wid $1; box wid $2 }
 *   pair(0.2, 0.4)          is read as   box wid 0.2; box wid 0.4
 *
 * A macro's body is between two braces, or between two of any other
 * character (define m | ... |). Its arguments are $1 to $9, and a
 * name alone is a call with no arguments. Also done here:
 *   - a comment (# to the end of the line);
 *   - a troff request in the picture (a line that starts with a dot),
 *     which is skipped;
 *   - a file read in the middle (copy "file");
 *   - inches (1.5i is 1.5);
 *   - the end of a statement before a closing bracket, so that the
 *     grammar has only one way to end a statement.
 *
 * It is written by hand and not with lex, because what a word is
 * depends on the macros defined so far, and a macro's text goes back
 * in front of what is left to read. *)

(* [tokens load text] returns the picture's words. [load] reads a file
 * that a copy names (when it gives None, the copy is nothing). *)
val tokens : (string -> string option) -> string -> Pic_parser.token list
