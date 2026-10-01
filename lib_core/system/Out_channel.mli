(* ix: OCaml's Out_channel (4.14), the functions ix's programs use: a
 * file written and closed, whatever happens *)

type t = out_channel

(* f on the file opened (created, or emptied), which is closed when f
 * returns or raises; with_open_gen's file opened as open_out_gen's *)
val with_open_bin : string -> (t -> 'a) -> 'a
val with_open_gen : open_flag list -> int -> string -> (t -> 'a) -> 'a

val output_string : t -> string -> unit
