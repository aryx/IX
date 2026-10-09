(* Indentation, asked: no key indents by itself (RET is a new line and
 * nothing more). Any language's: a line follows the one before it.
 * efuns' Indent is a mode's own indenter called. *)

(* TAB in a language's mode: the line's indentation made the one of
 * the line before it that is not blank, if it is less; two spaces
 * more otherwise *)
val indent_line : Efuns.action

(* C-j: a new line that starts with the spaces and tabs this one
 * starts with *)
val newline_and_indent : Efuns.action
