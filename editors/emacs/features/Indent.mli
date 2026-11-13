(* Indentation, when it is asked for: no key indents by itself (RET
 * inserts a new line and nothing more). It is the same for every
 * language: a line follows the one before it. efuns' Indent calls a
 * mode's own indenter. *)

(* TAB in a language's mode. If the line's indentation is less than
 * that of the line before it that is not blank, it becomes that one;
 * otherwise it grows by two spaces. *)
val indent_line : Efuns.action

(* C-j: inserts a new line that starts with the spaces and tabs this
 * one starts with *)
val newline_and_indent : Efuns.action
