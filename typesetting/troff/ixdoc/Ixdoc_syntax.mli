(* Ixdoc_syntax: the new format's marks, with no document yet -- what
 * a line is, and where a mark in a text ends. Its reader (Ixdoc) and
 * its writer (To_ixdoc) both ask: the writer to know what it must
 * guard, a line that would be read as a heading, an item, a command.
 *
 *   # NAME               Head (1, "NAME")
 *   - an item            Item (bullet, 2)
 *   :    its text        Define 5
 *   | a | b |            Row
 *   \figure{            Command "figure"
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

(* [closing s i o c]: s.[i] opens (o: a [ or a {); where it is closed
 * (c), what is between two back quotes and what follows a backslash
 * not looked at *)
val closing : string -> int -> char -> char -> int option

(* \name[options]{text}{text} at i: its name, its options, its texts,
 * and where it ends *)
val command_at : string -> int -> string * string * string list * int

(* [find_close s from c k]: where the * or the _ opened before [from]
 * is closed: [k] of them, after what is not a space; ** inside *...*
 * is passed over *)
val find_close : string -> int -> char -> int -> int option

(* #1, #2 of a \newcommand's text, replaced by its arguments *)
val substitute : string -> string list -> string

(* the commands that start a line *)
val block_commands : string list

type kind =
  | Blank
  (* set in by four columns or more *)
  | Code
  (* ``` and the word after it *)
  | Fence of string * string
  | Head of int * string
  | Row
  | Quote
  (* its mark (- or 1.), and the column of its text *)
  | Item of string * int
  (* a line that starts with a colon, and the column of its text *)
  | Define of int
  | Command of string
  | Html
  | Words

val classify : string -> kind
