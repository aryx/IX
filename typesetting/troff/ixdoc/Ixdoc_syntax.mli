(* Ixdoc_syntax: the marks of the new format, with no document yet. It
 * says what kind of line a line is, and where a mark in a text ends.
 * Both the format's reader (Ixdoc) and its writer (To_ixdoc) use it.
 * The writer needs it to know what it must guard: a line that would
 * be read as a heading, an item or a command.
 *
 *   # NAME               Head (1, "NAME")
 *   - an item            Item (bullet, 2)
 *   :    its text        Define 5
 *   | a | b |            Row
 *   \figure{             Command "figure"
 *   a line of words      Words
 *)

val is_letter : char -> bool
val is_digit : char -> bool
(* (a letter, a digit, or a character that is not ASCII) *)
val is_alnum : char -> bool

(* how many spaces a line starts with *)
val indent_of : string -> int
val blank : string -> bool
(* s without its first n characters *)
val drop : string -> int -> string
val ends_with : string -> char -> bool

(* [closing s i o c]: s.[i] is an opening character [o] (a [ or a {),
 * and this returns where it is closed by [c]. What is between two back
 * quotes, and what follows a backslash, is not looked at. *)
val closing : string -> int -> char -> char -> int option

(* reads \name[options]{text}{text} at i, and returns its name, its
 * options, its texts, and where it ends *)
val command_at : string -> int -> string * string * string list * int

(* [find_close s from c k] returns where the * or the _ that was opened
 * before [from] is closed: by [k] of them, after a character that is
 * not a space. A ** inside *...* is skipped. *)
val find_close : string -> int -> char -> int -> int option

(* replaces the #1, #2 of a \newcommand's text by its arguments *)
val substitute : string -> string list -> string

(* the commands that start a line *)
val block_commands : string list

type kind =
  | Blank
  (* a line set in by four columns or more *)
  | Code
  (* ``` and the word after it *)
  | Fence of string * string
  | Head of int * string
  | Row
  | Quote
  (* its mark (- or 1.), and the column where its text starts *)
  | Item of string * int
  (* a line that starts with a colon, with the column where its text
   * starts *)
  | Define of int
  | Command of string
  | Html
  | Words

val classify : string -> kind
