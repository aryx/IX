(* Latex_input: the text that Latex reads, a character at a time, and
 * what a command takes from it.
 *
 * The text is a stack (Latex_state.frame). At the bottom is the file.
 * On it there may be a file that it names (\input, #include). On that
 * there may be a macro's text, put where the macro was, so that what
 * follows the macro is read after it (\xspace looks there). On top
 * there may be an argument read apart, and the reading stops at its
 * end. [peek] goes down the stack when a text is finished, but not
 * past an argument read apart.
 *
 * What a command takes is taken as it is written, not read yet. An
 * argument is the text between two braces, and it is read when the
 * command says so, in the look the command says. So the code that
 * looks for a closing brace must know what is not LaTeX on the way: a
 * comment, a character after a backslash, and noweb's [[code]] (mk's
 * rules have a % in them). *)

(* where the reading is: the file's name ("" for the first file) and
 * the line *)
val place : Latex_state.t -> string * int

(* puts a text in front of what is left to read: a macro's text *)
val push : Latex_state.t -> string -> unit

(* the next character; None at the end, or at the end of a text read
 * apart *)
val peek : Latex_state.t -> char option
val advance : Latex_state.t -> unit
(* the character k after the next, in the same text *)
val ahead : Latex_state.t -> int -> char option
val looking : Latex_state.t -> string -> bool
val skip : Latex_state.t -> int -> unit
(* whether the reading is at the start of a line of a file (not of a
 * macro's text) *)
val at_line_start : Latex_state.t -> bool
(* reads the rest of the line, and its end with it *)
val rest_of_line : Latex_state.t -> string

val is_letter : char -> bool
val is_digit : char -> bool
val is_blank : char -> bool
val blanks : Latex_state.t -> unit

(* skips the spaces after a command's name, which are not text: up to
 * the next line's first letter, but not past a blank line, which ends
 * a paragraph *)
val after_name : Latex_state.t -> unit

(* [quoted s from]: s.[from] is just after a [[. This returns where
 * the quoted code ends, past its ]] ([from] itself if the line has
 * none). *)
val quoted : string -> int -> int

(* [closing s from o c]: s.[from] is just after an opening [o]. This
 * returns where its closing [c] is. A comment, quoted code, and what
 * follows a backslash are not looked at. *)
val closing : string -> int -> char -> char -> int

(* what is between the next character, an opening, and its closing *)
val between : Latex_state.t -> char -> char -> string

(* reads a command's name, after its backslash has been read: letters,
 * or one character *)
val name : Latex_state.t -> string

(* an argument as it is written: what is between braces, or a command,
 * or a character *)
val arg : Latex_state.t -> string
(* an argument that may be missing: [text] (but not [[code]] nor
 * [<name>]) *)
val opt : Latex_state.t -> string option
val star : Latex_state.t -> bool

(* what comes before the next [mark], and reads past the mark *)
val until : Latex_state.t -> string -> string

(* skips a false branch: up to its \else (when the flag says so) or its
 * \fi, counting the conditionals inside it *)
val skip_branch : Latex_state.t -> bool -> unit

(* [to_end t env nested] returns what is written up to \end{env}, as
 * it is. When [nested] is true, the environments of the same name
 * inside it are counted. *)
val to_end : Latex_state.t -> string -> bool -> string

(* a macro's text with its arguments put for #1, #2; ## is a # *)
val substitute : string -> string list -> string
(* what a command names: \x, or {\x} *)
val named : string -> string
