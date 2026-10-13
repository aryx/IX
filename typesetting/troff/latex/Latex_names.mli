(* Latex_names: the commands of LaTeX that a table says all of -- a
 * size, a look, a character, or nothing -- for Latex and Latex_math.
 * What a package gives is here as the few commands the books use of
 * it; a new one is a line. *)

(* \small, \Large...: points more than the text, or less *)
val sizes : (string * int) list

(* a command with a text is the declaration in a group: \emph{x} is
 * {\em x}; a name and its declaration *)
val with_text : (string * string) list

(* the commands that are a character, or a few (\ldots, \times): what
 * the PDF's fonts have, and a word for the rest (\alpha, \leq) *)
val symbols : (string * string) list

(* the commands that say nothing here, with what they take: m an
 * argument, o one that may not be there, * a star *)
val nothing : (string * string) list

(* an accent and its letter (\'e is "'e"), and the letter with it *)
val accents : (string * string) list
