(* ix: the functions of OCaml's In_channel (4.14) that ix's programs use.
 * They read a file and close it, whatever happens. *)

type t = in_channel

(* Opens the file and calls f on it. The file is closed when f returns
 * or raises. *)
val with_open_bin : string -> (t -> 'a) -> 'a
val with_open_text : string -> (t -> 'a) -> 'a

(* The next line without its newline, or None at the end. *)
val input_line : t -> string option

(* Everything that is left in the channel. *)
val input_all : t -> string

(* [input ic b pos len] reads up to len bytes into b at pos. It takes
 * what the channel has, waiting until there is at least one byte, and
 * returns 0 at the end. (tiny/'s utilities use it to read a piece at a
 * time.) *)
val input : t -> bytes -> int -> int -> int
