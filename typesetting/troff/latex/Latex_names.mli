(* Latex_names: the LaTeX commands that a table describes completely,
 * each being a size, a look, a character, or nothing. Latex and
 * Latex_math use them. A package is here as the few of its commands
 * that the books use, and a new one takes a line. *)

(* \small, \Large...: how many points more than the text, or less *)
val sizes : (string * int) list

(* A command with a text is its declaration in a group: \emph{x} is
 * {\em x}. Each pair is a name and its declaration. *)
val with_text : (string * string) list

(* the commands that are a character, or a few characters (\ldots,
 * \times): what the PDF's fonts have, and a word for the rest
 * (\alpha, \leq) *)
val symbols : (string * string) list

(* the commands that do nothing here, with what they take: m for an
 * argument, o for one that may be missing, * for a star *)
val nothing : (string * string) list

(* an accent and its letter (\'e is "'e"), with the letter that has
 * the accent *)
val accents : (string * string) list
