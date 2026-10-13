(* Latex_input: the text Latex reads, a character at a time, and what
 * a command takes from it.
 *
 * The text is a stack (Latex_state.frame): the file; on it a file
 * that it names (\input, #include); on it a macro's text, put where
 * the macro was, so that what follows the macro is read after it
 * (\xspace looks there); on it an argument read apart, at whose end
 * the reading of it stops. [peek] goes down the stack when a text is
 * finished, but not past an argument read apart.
 *
 * What a command takes is taken as it is written, not read yet: an
 * argument is the text between two braces, and is read when the
 * command says, in the look it says. So what looks for a closing
 * brace must know what is not LaTeX's on the way: a comment, a
 * backslash's character, noweb's [[code]] (mk's rules have a % in
 * them). *)

(* where the reading is: the file's name ("" for the first) and line *)
val place : Latex_state.t -> string * int

(* a text put in front of what is left to read: a macro's *)
val push : Latex_state.t -> string -> unit

(* the next character; none at the end, or at the end of a text read
 * apart *)
val peek : Latex_state.t -> char option
val advance : Latex_state.t -> unit
(* the character k after the next, in the same text *)
val ahead : Latex_state.t -> int -> char option
val looking : Latex_state.t -> string -> bool
val skip : Latex_state.t -> int -> unit
(* at the start of a line of a file (not of a macro's text) *)
val at_line_start : Latex_state.t -> bool
(* the rest of the line, read, and its end with it *)
val rest_of_line : Latex_state.t -> string

val is_letter : char -> bool
val is_digit : char -> bool
val is_blank : char -> bool
val blanks : Latex_state.t -> unit

(* the spaces after a command's name are not text: to the next line's
 * first letter, but not past a blank line, which ends a paragraph *)
val after_name : Latex_state.t -> unit

(* [quoted s from]: s.[from] is after a [[: where the code quoted
 * ends, past its ]] ([from] itself if the line has none) *)
val quoted : string -> int -> int

(* [closing s from o c]: s.[from] is after an opening o: where its
 * closing c is; a comment, a quoted code and what follows a backslash
 * are not looked at *)
val closing : string -> int -> char -> char -> int

(* what is between the next character, an opening, and its closing *)
val between : Latex_state.t -> char -> char -> string

(* a command's name, its backslash read: letters, or one character *)
val name : Latex_state.t -> string

(* an argument as it is written: what is between braces, or a command,
 * or a character *)
val arg : Latex_state.t -> string
(* one that may not be there: [text] (not [[code]] nor [<name>]) *)
val opt : Latex_state.t -> string option
val star : Latex_state.t -> bool

(* what is to the next [mark], and past it *)
val until : Latex_state.t -> string -> string

(* a false branch passed over: to its \else (when the flag says) or
 * its \fi, the conditionals inside it counted *)
val skip_branch : Latex_state.t -> bool -> unit

(* [to_end t env nested]: what is written to \end{env}, as it is; the
 * environments of the same name inside it counted when [nested] *)
val to_end : Latex_state.t -> string -> bool -> string

(* a macro's text with its arguments for #1, #2; ## is a # *)
val substitute : string -> string list -> string
(* what a command names: \x, or {\x} *)
val named : string -> string
