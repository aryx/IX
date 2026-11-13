(* ix: the functions of OCaml's Out_channel (4.14) that ix's programs
 * use. They write a file and close it, whatever happens. *)

type t = out_channel

(* Opens the file (creating it, or emptying it) and calls f on it. The
 * file is closed when f returns or raises. with_open_gen opens the file
 * as open_out_gen does. *)
val with_open_bin : string -> (t -> 'a) -> 'a
val with_open_gen : open_flag list -> int -> string -> (t -> 'a) -> 'a

val output_string : t -> string -> unit
