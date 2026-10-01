(* ix: OCaml's In_channel (4.14), the functions ix's programs use: a
 * file read and closed, whatever happens *)

type t = in_channel

(* f on the file opened, which is closed when f returns or raises *)
val with_open_bin : string -> (t -> 'a) -> 'a
val with_open_text : string -> (t -> 'a) -> 'a

(* the next line without its newline, None at the end *)
val input_line : t -> string option

(* what is left of the channel *)
val input_all : t -> string
